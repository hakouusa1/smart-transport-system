import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/bus_model.dart';
import '../services/bus_service.dart';
import '../services/route_service.dart';
import 'map_screen.dart';

const _gBlue = Color(0xFF4285F4);
const _gGreen = Color(0xFF34A853);
const _gRed = Color(0xFFEA4335);
const _gYellow = Color(0xFFFBBC05);
const _gDark = Color(0xFF202124);
const _gText = Color(0xFF3C4043);
const _gSub = Color(0xFF5F6368);
const _gBorder = Color(0xFFDADCE0);

// Distinct colors for each bus route
const _routeColors = [
  Color(0xFF4285F4), // blue
  Color(0xFF34A853), // green
  Color(0xFFEA4335), // red
  Color(0xFFFBBC05), // yellow
  Color(0xFF9C27B0), // purple
  Color(0xFFFF6D00), // orange
  Color(0xFF00BCD4), // cyan
  Color(0xFFE91E63), // pink
];

class AllBusesMapScreen extends StatefulWidget {
  const AllBusesMapScreen({super.key});
  @override
  State<AllBusesMapScreen> createState() => _AllBusesMapScreenState();
}

class _AllBusesMapScreenState extends State<AllBusesMapScreen> {
  final BusService _busService = BusService();
  final MapController _mapController = MapController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  LatLng? _myPosition;
  List<Bus> _buses = [];
  final Map<String, LatLng> _busPositions = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _locationSubs = {};
  final Map<String, List<LatLng>> _busRoutes = {};

  bool _isLoading = true;
  bool _routesLoaded = false;
  double _currentZoom = 13;
  StreamSubscription? _busesSub;

  final LatLng _defaultCenter = const LatLng(36.7538, 3.0588);

  @override
  void initState() {
    super.initState();
    _initMyLocation();
    _loadBuses();
  }

  @override
  void dispose() {
    _busesSub?.cancel();
    for (final sub in _locationSubs.values) sub.cancel();
    super.dispose();
  }

  // ── My location (centers map here first) ──
  Future<void> _initMyLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() => _myPosition = LatLng(pos.latitude, pos.longitude));
        // Center map on my position
        _mapController.move(_myPosition!, 13);
      }
    } catch (_) {}
  }

  // ── Load buses + listen to locations + fetch routes ──
  void _loadBuses() {
    _busesSub = _busService.getActiveBuses().listen((buses) {
      if (!mounted) return;
      setState(() { _buses = buses; _isLoading = false; });

      for (final sub in _locationSubs.values) sub.cancel();
      _locationSubs.clear();

      // Listen to each bus location
      for (final bus in buses) {
        final sub = _dbRef.child('locations/${bus.busId}').onValue.listen((event) {
          if (!mounted) return;
          final data = event.snapshot.value;
          if (data == null) { setState(() => _busPositions.remove(bus.busId)); return; }
          final map = data as Map<dynamic, dynamic>;
          final lat = (map['latitude'] as num?)?.toDouble();
          final lng = (map['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) setState(() => _busPositions[bus.busId] = LatLng(lat, lng));
        });
        _locationSubs[bus.busId] = sub;
      }

      // Fetch routes for all buses
      if (!_routesLoaded) {
        _routesLoaded = true;
        _fetchAllRoutes(buses);
      }
    });
  }

  // ── Fetch route for each bus ──
  Future<void> _fetchAllRoutes(List<Bus> buses) async {
    for (final bus in buses) {
      if (bus.hasDeparture && bus.hasArrival) {
        final from = LatLng(bus.departureLat!, bus.departureLng!);
        final to = LatLng(bus.arrivalLat!, bus.arrivalLng!);
        final result = await RouteService.getRoute(from, to);
        if (mounted && result != null && result.points.isNotEmpty) {
          setState(() => _busRoutes[bus.busId] = result.points);
        }
      }
    }
  }

  void _centerOnMe() {
    if (_myPosition != null) _mapController.move(_myPosition!, 14);
  }

  void _fitAllMarkers() {
    final points = <LatLng>[];
    if (_myPosition != null) points.add(_myPosition!);
    points.addAll(_busPositions.values);
    // Also include departure/arrival
    for (final bus in _buses) {
      if (bus.hasDeparture) points.add(LatLng(bus.departureLat!, bus.departureLng!));
      if (bus.hasArrival) points.add(LatLng(bus.arrivalLat!, bus.arrivalLng!));
    }
    if (points.length >= 2) {
      _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(60)));
    } else if (points.length == 1) {
      _mapController.move(points.first, 14);
    }
  }

  Color _colorForBus(int index) => _routeColors[index % _routeColors.length];

  /// Offset route points perpendicular to the line direction
  /// so parallel routes sit side by side instead of on top of each other
  List<LatLng> _offsetRoute(List<LatLng> points, int index, int total, double baseOffset) {
    if (total <= 1) return points;

    // Spread routes: index 0 = left, index 1 = right, etc.
    final center = (total - 1) / 2.0;
    final offsetMeters = (index - center) * baseOffset;

    if (offsetMeters.abs() < 1) return points;

    final result = <LatLng>[];
    for (int i = 0; i < points.length; i++) {
      double bearing;
      if (i < points.length - 1) {
        bearing = _bearingBetween(points[i], points[i + 1]);
      } else {
        bearing = _bearingBetween(points[i - 1], points[i]);
      }

      // Perpendicular bearing (90 degrees right)
      final perpBearing = bearing + 90;
      final offsetPoint = _movePoint(points[i], offsetMeters, perpBearing);
      result.add(offsetPoint);
    }
    return result;
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final dLng = (to.longitude - from.longitude) * 3.14159 / 180;
    final lat1 = from.latitude * 3.14159 / 180;
    final lat2 = to.latitude * 3.14159 / 180;

    final x = Math.sin(dLng) * Math.cos(lat2);
    final y = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
    final bearing = Math.atan2(x, y) * 180 / 3.14159;
    return (bearing + 360) % 360;
  }

  LatLng _movePoint(LatLng point, double distanceMeters, double bearingDegrees) {
    const earthRadius = 6371000.0; // meters
    final bearing = bearingDegrees * 3.14159 / 180;
    final lat1 = point.latitude * 3.14159 / 180;
    final lng1 = point.longitude * 3.14159 / 180;
    final d = distanceMeters / earthRadius;

    final lat2 = Math.asin(Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) * Math.sin(d) * Math.cos(bearing));
    final lng2 = lng1 + Math.atan2(Math.sin(bearing) * Math.sin(d) * Math.cos(lat1), Math.cos(d) - Math.sin(lat1) * Math.sin(lat2));

    return LatLng(lat2 * 180 / 3.14159, lng2 * 180 / 3.14159);
  }

  void _showBusInfo(BuildContext context, Bus bus, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(color: _gBorder, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.directions_bus, color: color, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bus.lineName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 17, color: _gDark)),
                const SizedBox(height: 2),
                Text(bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}',
                    style: const TextStyle(color: _gSub, fontSize: 13)),
              ])),
              if (_busPositions.containsKey(bus.busId))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _gGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: _gGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('En trajet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _gGreen)),
                  ]),
                ),
            ]),
            const SizedBox(height: 16),

            // Route info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                // Departure
                Expanded(child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _gGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Départ', style: TextStyle(fontSize: 12, color: _gSub))),
                ])),
                // Arrow
                Icon(Icons.arrow_forward, size: 14, color: color),
                // Arrival
                Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Expanded(child: Text('Arrivée', style: TextStyle(fontSize: 12, color: _gSub), textAlign: TextAlign.right)),
                  const SizedBox(width: 8),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _gRed, shape: BoxShape.circle)),
                ])),
              ]),
            ),
            const SizedBox(height: 16),

            // Track button
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: bus)));
                },
                icon: const Icon(Icons.near_me, size: 18),
                label: const Text('Suivre ce bus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveCount = _busPositions.length;
    final mapCenter = _myPosition ?? _defaultCenter;
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: _isLoading
            ? Container(color: Colors.white, child: const Center(child: CircularProgressIndicator(color: _gBlue, strokeWidth: 3)))
            : Stack(children: [

          // ═══════════════════════════════════════
          // MAP
          // ═══════════════════════════════════════
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: _myPosition != null ? 13 : 12,
              onPositionChanged: (camera, hasGesture) {
                final newZoom = _mapController.camera.zoom;
                if ((newZoom - _currentZoom).abs() > 0.3) {
                  setState(() => _currentZoom = newZoom);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: RouteService.tileUrl,
                userAgentPackageName: 'com.example.voyageur_app',
                tileSize: 512,
                zoomOffset: -1,
              ),

              // ── Route lines for each bus (offset scales with zoom) ──
              ..._buses.asMap().entries.expand((busEntry) {
                final busIndex = busEntry.key;
                final bus = busEntry.value;
                final color = _colorForBus(busIndex);
                final route = _busRoutes[bus.busId];

                if (route == null || route.length < 2) return <Widget>[];

                // Scale offset with zoom: bigger offset when zoomed out so lines stay visible
                final zoomFactor = Math.pow(2, 15 - _currentZoom).toDouble().clamp(1.0, 50.0);
                final offsetMeters = 15.0 * zoomFactor; // base 15m, scales up when zoomed out

                final offsetRoute = _offsetRoute(route, busIndex, _buses.length, offsetMeters);

                // Scale stroke: thinner when zoomed out, thicker when zoomed in
                final stroke = (_currentZoom >= 13) ? 6.0 : (_currentZoom >= 10) ? 4.0 : 3.0;

                return [
                  PolylineLayer(polylines: [
                    Polyline(points: offsetRoute, color: color.withValues(alpha: 0.15), strokeWidth: stroke + 4),
                    Polyline(points: offsetRoute, color: color.withValues(alpha: 0.8), strokeWidth: stroke),
                  ]),
                ];
              }),

              // ── Markers ──
              MarkerLayer(markers: [
                // My position (Google blue dot)
                if (_myPosition != null)
                  Marker(point: _myPosition!, width: 24, height: 24,
                      child: Container(
                          decoration: BoxDecoration(
                            color: _gBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: _gBlue.withValues(alpha: 0.3), blurRadius: 8)],
                          ))),

                // Departure + Arrival markers for each bus
                ..._buses.asMap().entries.expand((busEntry) {
                  final busIndex = busEntry.key;
                  final bus = busEntry.value;
                  final markers = <Marker>[];

                  // Departure (green small dot)
                  if (bus.hasDeparture) {
                    markers.add(Marker(
                      point: LatLng(bus.departureLat!, bus.departureLng!),
                      width: 14, height: 14,
                      child: Container(decoration: BoxDecoration(
                        color: _gGreen, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      )),
                    ));
                  }

                  // Arrival (red small dot)
                  if (bus.hasArrival) {
                    markers.add(Marker(
                      point: LatLng(bus.arrivalLat!, bus.arrivalLng!),
                      width: 14, height: 14,
                      child: Container(decoration: BoxDecoration(
                        color: _gRed, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      )),
                    ));
                  }

                  return markers;
                }),

                // Bus markers (on top of everything)
                ..._busPositions.entries.map((entry) {
                  final busId = entry.key;
                  final position = entry.value;
                  final busIndex = _buses.indexWhere((b) => b.busId == busId);
                  final bus = busIndex >= 0
                      ? _buses[busIndex]
                      : Bus(busId: busId, lineName: 'Bus', busName: '');
                  final color = busIndex >= 0 ? _colorForBus(busIndex) : _gBlue;

                  return Marker(
                    point: position,
                    width: 110,
                    height: 56,
                    child: GestureDetector(
                      onTap: () => _showBusInfo(context, bus, color),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Label
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Text(bus.lineName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(height: 2),
                        // Icon
                        Container(width: 34, height: 34,
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))]),
                            child: Center(child: Container(width: 26, height: 26,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                child: const Icon(Icons.directions_bus, color: Colors.white, size: 14)))),
                      ]),
                    ),
                  );
                }),
              ]),
            ],
          ),

          // ═══════════════════════════════════════
          // TOP BAR
          // ═══════════════════════════════════════
          Positioned(top: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(8, top + 8, 16, 8),
                child: Row(children: [
                  Material(color: Colors.white, shape: const CircleBorder(), elevation: 2, shadowColor: Colors.black26,
                      child: InkWell(customBorder: const CircleBorder(), onTap: () => Navigator.pop(context),
                          child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.arrow_back, size: 22, color: _gText)))),
                  const SizedBox(width: 8),
                  Expanded(child: Material(color: Colors.white, borderRadius: BorderRadius.circular(28), elevation: 2, shadowColor: Colors.black26,
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(children: [
                            const Expanded(child: Text('Carte des bus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _gDark))),
                            if (liveCount > 0)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: _gGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Text('$liveCount en ligne', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _gGreen))),
                          ])))),
                ]),
              )),

          // ═══════════════════════════════════════
          // NO BUSES
          // ═══════════════════════════════════════
          if (_busPositions.isEmpty && !_isLoading)
            Positioned(top: top + 72, left: 16, right: 16,
                child: Material(color: Colors.white, borderRadius: BorderRadius.circular(8), elevation: 1,
                    child: const Padding(padding: EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(Icons.info_outline, color: _gYellow, size: 18),
                          SizedBox(width: 10),
                          Text('Aucun bus en trajet actuellement', style: TextStyle(fontSize: 13, color: _gText)),
                        ])))),

          // ═══════════════════════════════════════
          // LEGEND (bottom left)
          // ═══════════════════════════════════════
          if (_buses.isNotEmpty)
            Positioned(bottom: 24, left: 16,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Text('Lignes', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _gSub)),
                    const SizedBox(height: 6),
                    ..._buses.asMap().entries.take(6).map((e) {
                      final color = _colorForBus(e.key);
                      final bus = e.value;
                      final isLive = _busPositions.containsKey(bus.busId);
                      return Padding(padding: const EdgeInsets.only(bottom: 4),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 16, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 6),
                            Text(bus.lineName, style: TextStyle(fontSize: 10, color: isLive ? _gDark : _gSub, fontWeight: isLive ? FontWeight.w500 : FontWeight.normal)),
                            if (isLive) ...[
                              const SizedBox(width: 4),
                              Container(width: 4, height: 4, decoration: const BoxDecoration(color: _gGreen, shape: BoxShape.circle)),
                            ],
                          ]));
                    }),
                  ]),
                )),

          // ═══════════════════════════════════════
          // CONTROLS (right side)
          // ═══════════════════════════════════════
          Positioned(bottom: 24, right: 16,
              child: Column(children: [
                if (_busPositions.isNotEmpty || _buses.isNotEmpty) ...[
                  _GBtn(Icons.crop_free, _fitAllMarkers),
                  const SizedBox(height: 10),
                ],
                if (_myPosition != null)
                  _GBtn(Icons.my_location, _centerOnMe, tint: _gBlue),
              ])),
        ]),
      ),
    );
  }
}

class _GBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color? tint;
  const _GBtn(this.icon, this.onTap, {this.tint});
  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.white, shape: const CircleBorder(), elevation: 2, shadowColor: Colors.black26,
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(11), child: Icon(icon, size: 22, color: tint ?? _gSub))));
  }
}