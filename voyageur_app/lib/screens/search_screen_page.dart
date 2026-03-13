import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/bus_model.dart';
import '../services/route_service.dart';
import 'map_screen.dart';
import 'pick_on_map_screen.dart';

const _mapboxToken =
    'pk.eyJ1IjoiaGFrb3UwODgiLCJhIjoiY21tZXgxMTJvMDF5eDJyc2hxY2Y3OW1rOCJ9.v74bMi9y79UmP4ixwsuLJw';

const _gBlue = Color(0xFF4285F4);
const _gGreen = Color(0xFF34A853);
const _gRed = Color(0xFFEA4335);
const _gDark = Color(0xFF202124);
const _gText = Color(0xFF3C4043);
const _gSub = Color(0xFF5F6368);
const _gBorder = Color(0xFFDADCE0);
const _gLight = Color(0xFFF8F9FA);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  final _departureFocus = FocusNode();
  final _arrivalFocus = FocusNode();

  LatLng? _departureLatLng;
  LatLng? _arrivalLatLng;

  List<_Place> _suggestions = [];
  String _activeField = '';
  Timer? _debounce;

  List<Bus> _matchedBuses = [];
  bool _hasSearched = false;
  bool _isLoadingResults = false;

  static const double _matchRadiusKm = 2.0; // 2km from any point on the route

  @override
  void initState() {
    super.initState();
    // Auto focus departure on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _departureFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _departureController.dispose();
    _arrivalController.dispose();
    _departureFocus.dispose();
    _arrivalFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Mapbox Geocoding ──
  void _onChanged(String query, String field) {
    setState(() => _activeField = field);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query.trim().length >= 2) _fetch(query);
      else setState(() => _suggestions = []);
    });
  }

  Future<void> _fetch(String query) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
            '?access_token=$_mapboxToken&country=dz&language=fr&limit=5'
            '&types=place,locality,neighborhood,address,poi',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final features = jsonDecode(res.body)['features'] as List;
        if (mounted) {
          setState(() {
            _suggestions = features.map((f) {
              final c = f['geometry']['coordinates'] as List;
              return _Place(
                name: f['text'] ?? '',
                fullName: f['place_name'] ?? '',
                latLng: LatLng(c[1].toDouble(), c[0].toDouble()),
              );
            }).toList();
          });
        }
      }
    } catch (_) {}
  }

  void _selectPlace(_Place place) {
    if (_activeField == 'departure') {
      _departureLatLng = place.latLng;
      _departureController.text = place.name;
      FocusScope.of(context).requestFocus(_arrivalFocus);
    } else {
      _arrivalLatLng = place.latLng;
      _arrivalController.text = place.name;
      FocusScope.of(context).unfocus();
    }
    setState(() { _suggestions = []; _activeField = ''; });
    if (_departureLatLng != null && _arrivalLatLng != null) _search();
  }

  // ── Match buses ──
  // Checks if user's departure AND arrival are near the bus route (any point on the route)
  Future<void> _search() async {
    if (_departureLatLng == null || _arrivalLatLng == null) return;
    setState(() { _isLoadingResults = true; _hasSearched = true; _matchedBuses = []; });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('buses').where('isActive', isEqualTo: true).get();

      final all = snap.docs
          .map((d) => Bus.fromMap(d.data()))
          .where((b) => b.hasDeparture && b.hasArrival)
          .toList();

      final ids = <String>{};

      for (final bus in all) {
        // Get the full route for this bus
        final from = LatLng(bus.departureLat!, bus.departureLng!);
        final to = LatLng(bus.arrivalLat!, bus.arrivalLng!);

        final route = await RouteService.getRoute(from, to);
        if (route == null || route.points.isEmpty) continue;

        // Check if user's departure is near any point on the route
        final departNear = _isNearRoute(_departureLatLng!, route.points, _matchRadiusKm);
        // Check if user's arrival is near any point on the route
        final arriveNear = _isNearRoute(_arrivalLatLng!, route.points, _matchRadiusKm);

        // Also check that departure comes BEFORE arrival on the route
        // (user is going in the same direction as the bus)
        if (departNear && arriveNear) {
          final departIdx = _closestRouteIndex(_departureLatLng!, route.points);
          final arriveIdx = _closestRouteIndex(_arrivalLatLng!, route.points);
          // Forward direction: depart index < arrive index
          // OR reverse: we accept both directions
          if (departIdx < arriveIdx) {
            ids.add(bus.busId);
          }
        }
      }

      setState(() { _matchedBuses = all.where((b) => ids.contains(b.busId)).toList(); _isLoadingResults = false; });
    } catch (_) {
      setState(() => _isLoadingResults = false);
    }
  }

  /// Check if a point is within radiusKm of any point on the route
  bool _isNearRoute(LatLng point, List<LatLng> route, double radiusKm) {
    const dist = Distance();
    for (final rp in route) {
      if (dist.as(LengthUnit.Kilometer, point, rp) <= radiusKm) return true;
    }
    return false;
  }

  /// Find the index of the closest point on the route
  int _closestRouteIndex(LatLng point, List<LatLng> route) {
    double min = double.infinity;
    int idx = 0;
    const dist = Distance();
    for (int i = 0; i < route.length; i++) {
      final d = dist.as(LengthUnit.Meter, point, route[i]);
      if (d < min) { min = d; idx = i; }
    }
    return idx;
  }

  void _swap() {
    final tl = _departureLatLng; final tt = _departureController.text;
    _departureLatLng = _arrivalLatLng; _departureController.text = _arrivalController.text;
    _arrivalLatLng = tl; _arrivalController.text = tt;
    setState(() {});
    if (_departureLatLng != null && _arrivalLatLng != null) _search();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ════════════════════════════════════════
          // SEARCH HEADER
          // ════════════════════════════════════════
          Container(
            padding: EdgeInsets.fromLTRB(4, top + 4, 8, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: _gText, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Dots + line
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(children: [
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(color: _gGreen, shape: BoxShape.circle,
                            border: Border.all(color: _gGreen.withValues(alpha: 0.3), width: 2))),
                    Container(width: 2, height: 20, color: _gBorder),
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(color: _gRed, shape: BoxShape.circle,
                            border: Border.all(color: _gRed.withValues(alpha: 0.3), width: 2))),
                  ]),
                ),
                const SizedBox(width: 10),

                // Fields
                Expanded(
                  child: Column(children: [
                    // Departure
                    Container(
                      height: 42,
                      decoration: BoxDecoration(color: _gLight, borderRadius: BorderRadius.circular(8)),
                      child: TextField(
                        controller: _departureController, focusNode: _departureFocus,
                        onChanged: (v) => _onChanged(v, 'departure'),
                        style: const TextStyle(fontSize: 14, color: _gDark),
                        decoration: InputDecoration(
                          hintText: 'Point de départ', hintStyle: const TextStyle(color: _gSub, fontSize: 14),
                          border: InputBorder.none, isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          suffixIcon: _departureController.text.isNotEmpty
                              ? GestureDetector(
                              onTap: () { _departureController.clear(); setState(() { _departureLatLng = null; _hasSearched = false; _matchedBuses = []; }); },
                              child: const Icon(Icons.close, size: 16, color: _gSub))
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Arrival
                    Container(
                      height: 42,
                      decoration: BoxDecoration(color: _gLight, borderRadius: BorderRadius.circular(8)),
                      child: TextField(
                        controller: _arrivalController, focusNode: _arrivalFocus,
                        onChanged: (v) => _onChanged(v, 'arrival'),
                        style: const TextStyle(fontSize: 14, color: _gDark),
                        decoration: InputDecoration(
                          hintText: 'Point d\'arrivée', hintStyle: const TextStyle(color: _gSub, fontSize: 14),
                          border: InputBorder.none, isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          suffixIcon: _arrivalController.text.isNotEmpty
                              ? GestureDetector(
                              onTap: () { _arrivalController.clear(); setState(() { _arrivalLatLng = null; _hasSearched = false; _matchedBuses = []; }); },
                              child: const Icon(Icons.close, size: 16, color: _gSub))
                              : null,
                        ),
                      ),
                    ),
                  ]),
                ),

                // Swap
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 4),
                  child: GestureDetector(
                    onTap: _swap,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _gLight, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.swap_vert_rounded, color: _gBlue, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ════════════════════════════════════════
          // CONTENT
          // ════════════════════════════════════════
          Expanded(
            child: _suggestions.isNotEmpty
                ? _buildSuggestions()
                : _isLoadingResults
                ? const Center(child: CircularProgressIndicator(color: _gBlue, strokeWidth: 2.5))
                : _hasSearched
                ? _buildResults()
                : _buildHint(),
          ),
        ],
      ),
    );
  }

  // ── Suggestions ──
  Widget _buildSuggestions() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: _gBorder, indent: 56),
      itemBuilder: (_, i) {
        final p = _suggestions[i];
        return ListTile(
          leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _gLight, shape: BoxShape.circle),
              child: const Icon(Icons.location_on_outlined, color: _gSub, size: 18)),
          title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _gDark)),
          subtitle: Text(p.fullName, style: const TextStyle(fontSize: 11, color: _gSub), maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _selectPlace(p),
        );
      },
    );
  }

  // ── Results ──
  Widget _buildResults() {
    if (_matchedBuses.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_outlined, size: 56, color: _gBorder),
          const SizedBox(height: 16),
          const Text('Aucun bus trouvé', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: _gDark)),
          const SizedBox(height: 8),
          const Text('Aucun bus ne dessert ce trajet.\nEssayez des points plus proches.', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _gSub, height: 1.4)),
        ],
      )));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text('${_matchedBuses.length} bus trouvé${_matchedBuses.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _gDark)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _matchedBuses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final bus = _matchedBuses[i];
              final live = bus.driverStatus == 'on_trip';
              return Material(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: bus))),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: live ? _gBlue.withValues(alpha: 0.3) : _gBorder)),
                    child: Row(children: [
                      Container(width: 44, height: 44,
                          decoration: BoxDecoration(color: live ? _gBlue.withValues(alpha: 0.1) : _gLight, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.directions_bus_rounded, color: live ? _gBlue : _gSub, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(bus.lineName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _gDark)),
                        const SizedBox(height: 2),
                        Text(bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}', style: const TextStyle(fontSize: 11, color: _gSub)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: live ? _gGreen.withValues(alpha: 0.1) : _gLight, borderRadius: BorderRadius.circular(8)),
                            child: Text(live ? 'En trajet' : bus.statusText,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: live ? _gGreen : _gSub))),
                        const SizedBox(height: 6),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: _gBorder),
                      ]),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Hint ──
  Widget _buildHint() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Choose on map buttons
          _MapPickBtn(
            icon: Icons.map_outlined,
            color: _gGreen,
            label: 'Choisir le départ sur la carte',
            onTap: () async {
              final result = await Navigator.push<Map<String, double>>(
                context,
                MaterialPageRoute(builder: (_) => const PickOnMapScreen(title: 'Point de départ', pinColor: _gGreen)),
              );
              if (result != null) {
                _departureLatLng = LatLng(result['latitude']!, result['longitude']!);
                _departureController.text = '${result['latitude']!.toStringAsFixed(4)}, ${result['longitude']!.toStringAsFixed(4)}';
                setState(() {});
                if (_departureLatLng != null && _arrivalLatLng != null) _search();
              }
            },
          ),
          const SizedBox(height: 10),
          _MapPickBtn(
            icon: Icons.map_outlined,
            color: _gRed,
            label: 'Choisir l\'arrivée sur la carte',
            onTap: () async {
              final result = await Navigator.push<Map<String, double>>(
                context,
                MaterialPageRoute(builder: (_) => const PickOnMapScreen(title: 'Point d\'arrivée', pinColor: _gRed)),
              );
              if (result != null) {
                _arrivalLatLng = LatLng(result['latitude']!, result['longitude']!);
                _arrivalController.text = '${result['latitude']!.toStringAsFixed(4)}, ${result['longitude']!.toStringAsFixed(4)}';
                setState(() {});
                if (_departureLatLng != null && _arrivalLatLng != null) _search();
              }
            },
          ),

          const SizedBox(height: 30),
          Icon(Icons.search_rounded, size: 40, color: _gBorder),
          const SizedBox(height: 10),
          const Text('Recherchez ou choisissez sur la carte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _gDark)),
          const SizedBox(height: 4),
          const Text('Entrez un nom ou appuyez sur la carte', style: TextStyle(fontSize: 12, color: _gSub)),
        ],
      ),
    );
  }
}

// ── Map pick button ──
class _MapPickBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _MapPickBtn({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gBorder),
          ),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _gDark))),
            Icon(Icons.arrow_forward_ios, size: 14, color: _gBorder),
          ]),
        ),
      ),
    );
  }
}

class _Place {
  final String name; final String fullName; final LatLng latLng;
  _Place({required this.name, required this.fullName, required this.latLng});
}