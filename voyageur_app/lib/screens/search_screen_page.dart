import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/bus_model.dart';
import '../app_config.dart' as config;
import '../services/route_service.dart';
import '../services/price_service.dart';
import 'map_screen.dart';
import 'pick_on_map_screen.dart';
import '../theme/app_theme.dart';
import '../data/algeria_stops.dart';
import '../widgets/bus_loading_indicator.dart';
import '../l10n/app_localizations.dart';

const _mapboxToken = config.mapboxToken;

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
  LatLng? _myPosition;

  List<_Place> _suggestions = [];
  String _activeField = '';
  Timer? _debounce;

  List<Bus> _matchedBuses = [];
  Map<String, double> _linePrices = {};
  Map<String, double?> _segmentPrices = {};
  bool _hasSearched = false;
  bool _isLoadingResults = false;

  static const double _matchRadiusKm = 2.0;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
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

  Future<void> _initUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myPosition = latLng;
        _departureLatLng = latLng;
        _departureController.text = 'Ma position';
      });
      _reverseGeocode(latLng, isDeparture: true);
    } catch (_) {}
  }

  Future<void> _reverseGeocode(LatLng pos, {required bool isDeparture}) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${pos.longitude},${pos.latitude}.json'
            '?access_token=$_mapboxToken&language=fr&limit=1',
      );
      final res = await http.get(url);
      if (res.statusCode == 200 && mounted) {
        final features = jsonDecode(res.body)['features'] as List;
        if (features.isNotEmpty) {
          final name = features.first['text'] as String? ?? 'Ma position';
          setState(() {
            if (isDeparture) {
              _departureController.text = name;
            } else {
              _arrivalController.text = name;
            }
          });
        }
      }
    } catch (_) {}
  }

  void _resetToMyPosition() {
    if (_myPosition == null) return;
    setState(() {
      _departureLatLng = _myPosition;
      _departureController.text = 'Ma position';
      _suggestions = [];
      _activeField = '';
    });
    _reverseGeocode(_myPosition!, isDeparture: true);
    if (_departureLatLng != null && _arrivalLatLng != null) _search();
  }

  /// Filters local Algeria stops instantly (no network), returns matches.
  List<_Place> _filterLocalStops(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    return kAlgeriaStops
        .where((s) => s.name.toLowerCase().contains(q))
        .take(5)
        .map((s) => _Place(
              name: s.name,
              fullName: s.name,
              latLng: LatLng(s.lat, s.lng),
            ))
        .toList();
  }

  void _onChanged(String query, String field) {
    setState(() => _activeField = field);

    // Show local results immediately (no delay)
    final local = _filterLocalStops(query);
    setState(() => _suggestions = local);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query.trim().length >= 2) {
        _fetch(query, local);
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  Future<void> _fetch(String query, List<_Place> localResults) async {
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
          final mapboxResults = features.map((f) {
            final c = f['geometry']['coordinates'] as List;
            return _Place(
              name: f['text'] ?? '',
              fullName: f['place_name'] ?? '',
              latLng: LatLng(c[1].toDouble(), c[0].toDouble()),
            );
          }).toList();

          // Merge: local first, then Mapbox results (skip duplicates)
          final localNames = localResults.map((p) => p.name.toLowerCase()).toSet();
          final merged = <_Place>[
            ...localResults,
            ...mapboxResults.where((p) => !localNames.contains(p.name.toLowerCase())),
          ];
          setState(() => _suggestions = merged.take(7).toList());
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

  Future<void> _pickArrivalOnMap() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => PickOnMapScreen(title: 'Point d\'arrivée', pinColor: context.appRed),
      ),
    );
    if (result != null && mounted) {
      _arrivalLatLng = LatLng(result['latitude']!, result['longitude']!);
      _arrivalController.text = 'Ma destination';
      setState(() {});
      _reverseGeocode(_arrivalLatLng!, isDeparture: false);
      if (_departureLatLng != null && _arrivalLatLng != null) _search();
    }
  }

  Future<Map<String, double>> _fetchLinePrices(Set<String> lineIds) async {
    if (lineIds.isEmpty) return const {};
    final result = <String, double>{};
    final list = lineIds.toList();
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.sublist(
        i,
        i + 30 > list.length ? list.length : i + 30,
      );
      final snap = await FirebaseFirestore.instance
          .collection('lines')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final price = (doc.data()['basePrice'] as num?)?.toDouble();
        if (price != null) result[doc.id] = price;
      }
    }
    return result;
  }

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
      final needsRouteCheck = <Bus>[];
      const dist = Distance();

      // Fast path: compare user's cities to bus endpoints (covers wilaya-level search).
      // A 15 km radius handles city-center vs terminal distance in Algerian cities.
      for (final bus in all) {
        final busDepart = LatLng(bus.departureLat!, bus.departureLng!);
        final busArrive = LatLng(bus.arrivalLat!, bus.arrivalLng!);
        final departDist = dist.as(LengthUnit.Kilometer, _departureLatLng!, busDepart);
        final arriveDist = dist.as(LengthUnit.Kilometer, _arrivalLatLng!, busArrive);
        if (departDist <= 15.0 && arriveDist <= 15.0) {
          ids.add(bus.busId);
        } else {
          needsRouteCheck.add(bus);
        }
      }

      // Slow path: route polyline check for buses not matched above
      // (handles users at intermediate stops along a route).
      for (final bus in needsRouteCheck) {
        final from = LatLng(bus.departureLat!, bus.departureLng!);
        final to = LatLng(bus.arrivalLat!, bus.arrivalLng!);
        final route = await RouteService.getRoute(from, to);
        if (route == null || route.points.isEmpty) continue;

        final departNear = _isNearRoute(_departureLatLng!, route.points, _matchRadiusKm);
        final arriveNear = _isNearRoute(_arrivalLatLng!, route.points, _matchRadiusKm);

        if (departNear && arriveNear) {
          final departIdx = _closestRouteIndex(_departureLatLng!, route.points);
          final arriveIdx = _closestRouteIndex(_arrivalLatLng!, route.points);
          if (departIdx < arriveIdx) ids.add(bus.busId);
        }
      }

      final matched = all.where((b) => ids.contains(b.busId)).toList()
        ..sort((a, b) {
          if (a.isOnTrip && !b.isOnTrip) return -1;
          if (!a.isOnTrip && b.isOnTrip) return 1;
          return 0;
        });

      final lineIds = matched.map((b) => b.lineId).where((id) => id.isNotEmpty).toSet();
      final basePrices = await _fetchLinePrices(lineIds);

      final segmentPrices = <String, double?>{};
      for (final lineId in lineIds) {
        try {
          segmentPrices[lineId] = await PriceService.calculateSegmentPriceForCoords(
            lineId: lineId,
            from: _departureLatLng!,
            to: _arrivalLatLng!,
          );
        } catch (_) {
          segmentPrices[lineId] = null;
        }
      }

      setState(() {
        _matchedBuses = matched;
        _linePrices = basePrices;
        _segmentPrices = segmentPrices;
        _isLoadingResults = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingResults = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Erreur lors de la recherche. Veuillez réessayer.'),
          backgroundColor: context.appRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  bool _isNearRoute(LatLng point, List<LatLng> route, double radiusKm) {
    const dist = Distance();
    for (final rp in route) {
      if (dist.as(LengthUnit.Kilometer, point, rp) <= radiusKm) return true;
    }
    return false;
  }

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
      backgroundColor: context.appBg,
      body: Column(
        children: [
          // ════════════════════════════════════════
          // SEARCH HEADER
          // ════════════════════════════════════════
          Container(
            padding: EdgeInsets.fromLTRB(4, top + 4, 8, 14),
            decoration: BoxDecoration(
              color: context.appCardBg,
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.06),
                blurRadius: 8, offset: const Offset(0, 2),
              )],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: context.appText, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Route dots + line
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(children: [
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: context.appGreen, shape: BoxShape.circle,
                          border: Border.all(color: context.appGreen.withValues(alpha: 0.3), width: 2),
                        )),
                    Container(width: 2, height: 20, color: context.appBorder),
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: context.appRed, shape: BoxShape.circle,
                          border: Border.all(color: context.appRed.withValues(alpha: 0.3), width: 2),
                        )),
                  ]),
                ),
                const SizedBox(width: 10),

                // Text fields
                Expanded(
                  child: Column(children: [
                    // ── Departure ──
                    Container(
                      height: 42,
                      decoration: BoxDecoration(color: context.appCardBg2, borderRadius: BorderRadius.circular(8)),
                      child: TextField(
                        controller: _departureController, focusNode: _departureFocus,
                        onChanged: (v) => _onChanged(v, 'departure'),
                        style: TextStyle(fontSize: 14, color: context.appText),
                        decoration: InputDecoration(
                          hintText: 'Point de départ',
                          hintStyle: TextStyle(color: context.appSub, fontSize: 14),
                          border: InputBorder.none, isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_departureController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _departureController.clear();
                                    setState(() { _departureLatLng = null; _hasSearched = false; _matchedBuses = []; });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.close, size: 16, color: context.appSub),
                                  ),
                                ),
                              if (_myPosition != null)
                                GestureDetector(
                                  onTap: _resetToMyPosition,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8, left: 2),
                                    child: Icon(Icons.my_location, size: 16, color: context.appPrimary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ── Arrival ──
                    Container(
                      height: 42,
                      decoration: BoxDecoration(color: context.appCardBg2, borderRadius: BorderRadius.circular(8)),
                      child: TextField(
                        controller: _arrivalController, focusNode: _arrivalFocus,
                        onChanged: (v) => _onChanged(v, 'arrival'),
                        style: TextStyle(fontSize: 14, color: context.appText),
                        decoration: InputDecoration(
                          hintText: 'Point d\'arrivée',
                          hintStyle: TextStyle(color: context.appSub, fontSize: 14),
                          border: InputBorder.none, isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_arrivalController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _arrivalController.clear();
                                    setState(() { _arrivalLatLng = null; _hasSearched = false; _matchedBuses = []; });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.close, size: 16, color: context.appSub),
                                  ),
                                ),
                              GestureDetector(
                                onTap: _pickArrivalOnMap,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8, left: 2),
                                  child: Icon(Icons.map_outlined, size: 16, color: context.appPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),

                // Swap button
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 4),
                  child: GestureDetector(
                    onTap: _swap,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: context.appCardBg2, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.swap_vert_rounded, color: context.appPrimary, size: 20),
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
                    ? Center(child: BusLoadingIndicator(color: context.appPrimary, strokeWidth: 2.5))
                    : _hasSearched
                        ? _buildResults()
                        : _buildHint(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: context.appBorder, indent: 56),
      itemBuilder: (_, i) {
        final p = _suggestions[i];
        return ListTile(
          leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: context.appCardBg2, shape: BoxShape.circle),
              child: Icon(Icons.location_on_outlined, color: context.appSub, size: 18)),
          title: Text(p.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.appText)),
          subtitle: Text(p.fullName, style: TextStyle(fontSize: 11, color: context.appSub), maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _selectPlace(p),
        );
      },
    );
  }

  Widget _buildResults() {
    if (_matchedBuses.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_outlined, size: 56, color: context.appBorder),
          const SizedBox(height: 16),
          Text('Aucun bus trouvé', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: context.appText)),
          const SizedBox(height: 8),
          Text('Aucun bus ne dessert ce trajet.\nEssayez des points plus proches.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: context.appSub, height: 1.4)),
        ],
      )));
    }

    final allTrips = _matchedBuses.expand((b) => b.activeTrips).toList();
    final onTripBuses = allTrips.where((t) => t.isEnTrajet).toList();
    final otherBuses = allTrips.where((t) => !t.isEnTrajet).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            '${_matchedBuses.length} bus trouvé${_matchedBuses.length > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              // ── En trajet section ──
              if (onTripBuses.isNotEmpty) ...[
                _sectionHeader('En trajet', onTripBuses.length, context.appGreen),
                const SizedBox(height: 8),
                ...onTripBuses.map((trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SearchBusCard(
                    trip: trip,
                    segmentPrice: _segmentPrices[trip.bus.lineId],
                    basePrice: _linePrices[trip.bus.lineId],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: trip.bus))),
                  ),
                )),
                if (otherBuses.isNotEmpty) const SizedBox(height: 8),
              ],
              // ── En ligne section ──
              if (otherBuses.isNotEmpty) ...[
                _sectionHeader('En ligne', otherBuses.length, context.appOrange),
                const SizedBox(height: 8),
                ...otherBuses.map((trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SearchBusCard(
                    trip: trip,
                    segmentPrice: _segmentPrices[trip.bus.lineId],
                    basePrice: _linePrices[trip.bus.lineId],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: trip.bus))),
                  ),
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String label, int count, Color color) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appText)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }

  Widget _buildHint() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _MapPickBtn(
            icon: Icons.map_outlined,
            color: context.appRed,
            label: 'Choisir l\'arrivée sur la carte',
            onTap: _pickArrivalOnMap,
          ),
          const SizedBox(height: 30),
          Icon(Icons.search_rounded, size: 40, color: context.appBorder),
          const SizedBox(height: 10),
          Text('Recherchez votre destination',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.appText)),
          const SizedBox(height: 4),
          Text('Entrez un nom ou choisissez sur la carte',
              style: TextStyle(fontSize: 12, color: context.appSub)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════
// SEARCH RESULT BUS CARD
// ════════════════════════════════════════
class _SearchBusCard extends StatelessWidget {
  final BusTrip trip;
  final VoidCallback onTap;
  final double? segmentPrice;
  final double? basePrice;
  const _SearchBusCard({
    required this.trip,
    required this.onTap,
    this.segmentPrice,
    this.basePrice,
  });

  Widget _buildPriceChip(BuildContext context) {
    final price = segmentPrice ?? basePrice;
    final label = price != null
        ? '${price.toStringAsFixed(0)} ${context.tr.currencyDA}'
        : '---';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.appGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.payments_outlined, size: 12, color: context.appGreen),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.appGreen),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bus = trip.bus;
    final live = trip.isEnTrajet;
    final statusColor = live ? context.appGreen : context.appOrange;
    final statusLabel = live ? 'En trajet' : 'En ligne';
    final nextTime = !live ? trip.scheduleTime : null;

    return Material(
      color: context.appCardBg,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: live ? context.appPrimary.withValues(alpha: 0.3) : context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: live ? context.appPrimary.withValues(alpha: 0.1) : context.appCardBg2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.directions_bus_rounded, color: live ? context.appPrimary : context.appSub, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trip.displayLineName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appText)),
                const SizedBox(height: 2),
                Text(bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
                    style: TextStyle(fontSize: 11, color: context.appSub)),
                const SizedBox(height: 6),
                _buildPriceChip(context),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 4, height: 4, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                  ]),
                ),
                const SizedBox(height: 5),
                if (nextTime != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_rounded, size: 10, color: context.appSub),
                    const SizedBox(width: 3),
                    Text(nextTime,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.appPrimary)),
                  ])
                else
                  Icon(Icons.arrow_forward_ios, size: 12, color: context.appBorder),
              ]),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: trip.bus))),
                icon: Icon(Icons.map, size: 16),
                label: Text('Voir sur carte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appPrimary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPickBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _MapPickBtn({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.appText))),
            Icon(Icons.arrow_forward_ios, size: 14, color: context.appBorder),
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
