import 'dart:async';
import 'dart:math' as Math;
import 'dart:ui' as ui;
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

import '../theme/app_theme.dart';
import '../widgets/bus_loading_indicator.dart';

// Fixed map-overlay color — used on top of map tiles, not on surfaces
const _navy = Color(0xFF1E293B);

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

class _AllBusesMapScreenState extends State<AllBusesMapScreen> with TickerProviderStateMixin {
  final BusService _busService = BusService();
  final MapController _mapController = MapController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  LatLng? _myPosition;
  List<Bus> _buses = [];
  final Map<String, LatLng> _busPositions = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _locationSubs = {};
  final Map<String, List<LatLng>> _busRoutes = {};

  List<Map<String, dynamic>> _lines = [];
  final Map<String, List<LatLng>> _lineRoutes = {};
  bool _linesLoaded = false;
  StreamSubscription? _linesSub;

  bool _isLoading = true;
  bool _routesLoaded = false;
  double _currentZoom = 13;
  StreamSubscription? _busesSub;

  late AnimationController _moveAnim;
  VoidCallback? _moveAnimListener;

  final LatLng _defaultCenter = const LatLng(36.7538, 3.0588);

  @override
  void initState() {
    super.initState();
    _moveAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _initMyLocation();
    _loadBuses();
    _loadLines();
  }

  @override
  void dispose() {
    _moveAnim.dispose();
    _busesSub?.cancel();
    _linesSub?.cancel();
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


  // ── Load active lines + fetch their routes ──
  void _loadLines() {
    _linesSub = BusService.getActiveLines().listen((lines) {
      if (!mounted) return;
      setState(() => _lines = lines);
      if (!_linesLoaded) {
        _linesLoaded = true;
        _fetchAllLineRoutes(lines);
      }
    });
  }

  Future<void> _fetchAllLineRoutes(List<Map<String, dynamic>> lines) async {
    for (final line in lines) {
      final depLat = (line['departureLat'] as num?)?.toDouble();
      final depLng = (line['departureLng'] as num?)?.toDouble();
      final arrLat = (line['arrivalLat'] as num?)?.toDouble();
      final arrLng = (line['arrivalLng'] as num?)?.toDouble();
      if (depLat == null || depLng == null || arrLat == null || arrLng == null) continue;
      final result = await RouteService.getRoute(LatLng(depLat, depLng), LatLng(arrLat, arrLng));
      if (mounted && result != null && result.points.isNotEmpty) {
        setState(() => _lineRoutes[line['lineId'] as String] = result.points);
      }
    }
  }

  Color _colorForLine(String lineId) {
    final idx = _lines.indexWhere((l) => l['lineId'] == lineId);
    return _routeColors[(idx >= 0 ? idx : 0) % _routeColors.length];
  }

  void _animatedMoveTo(LatLng target, double targetZoom) {
    _moveAnim.stop();
    _moveAnim.removeListener(_moveAnimListener ?? (){});

    final startCenter = _mapController.camera.center;
    final startZoom   = _mapController.camera.zoom;

    final latTween = Tween<double>(begin: startCenter.latitude, end: target.latitude);
    final lngTween = Tween<double>(begin: startCenter.longitude, end: target.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: targetZoom);

    final curved = CurvedAnimation(parent: _moveAnim, curve: Curves.easeInOutCubic);

    _moveAnimListener = () {
      _mapController.move(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
      );
    };

    _moveAnim
      ..addListener(_moveAnimListener!)
      ..reset()
      ..forward().whenComplete(() {
        _moveAnim.removeListener(_moveAnimListener!);
        _moveAnimListener = null;
      });
  }

  void _centerOnMe() {
    if (_myPosition != null) _animatedMoveTo(_myPosition!, 14);
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
    final parts = bus.lineName.split('-');
    final fromCity = parts.first.trim();
    final toCity = parts.length > 1 ? parts.last.trim() : '';
    final isLive = _busPositions.containsKey(bus.busId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle bar
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),

          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Route cities
            Row(children: [
              // From
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: AppTheme.success, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5))),
                const SizedBox(height: 6),
                Text(fromCity, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const Text('Départ', style: TextStyle(fontSize: 11, color: Colors.white54)),
              ])),

              // Route line + bus icon
              Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 24, height: 1.5, color: Colors.white.withValues(alpha: 0.3)),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]),
                  child: const Icon(Icons.directions_bus, color: Colors.white, size: 16),
                ),
                Container(width: 24, height: 1.5, color: Colors.white.withValues(alpha: 0.3)),
              ])),

              // To
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Align(alignment: Alignment.centerRight,
                    child: Container(width: 10, height: 10, decoration: BoxDecoration(color: AppTheme.error, shape: BoxShape.circle))),
                const SizedBox(height: 6),
                Text(toCity.isNotEmpty ? toCity : 'Arrivée',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.end),
                const Text('Arrivée', style: TextStyle(fontSize: 11, color: Colors.white54), textAlign: TextAlign.end),
              ])),
            ]),

            const SizedBox(height: 20),

            // Bus info row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(children: [
                const Icon(Icons.directions_bus_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bus.busName.isNotEmpty ? bus.busName : bus.lineName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  if (bus.busNumber.isNotEmpty)
                    Text('N° ${bus.busNumber}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isLive ? AppTheme.success.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isLive ? AppTheme.success.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5,
                        decoration: BoxDecoration(color: isLive ? AppTheme.success : Colors.white54, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(isLive ? 'En trajet' : 'Hors ligne',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isLive ? AppTheme.success : Colors.white54)),
                  ]),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // Track button
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(bus: bus)));
                },
                icon: const Icon(Icons.near_me_rounded, size: 18),
                label: const Text('Suivre ce bus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
              ),
            ),
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
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: context.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: context.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: _isLoading
            ? Container(color: context.appBg, child: Center(child: BusLoadingIndicator(color: context.appPrimary, strokeWidth: 3)))
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

              // ── Static route lines for each active ligne ──
              ..._lines.asMap().entries.expand((lineEntry) {
                final lineId = lineEntry.value['lineId'] as String;
                final color = _colorForLine(lineId);
                final route = _lineRoutes[lineId];

                if (route == null || route.length < 2) return <Widget>[];

                final zoomFactor = Math.pow(2, 15 - _currentZoom).toDouble().clamp(1.0, 50.0);
                final offsetMeters = 15.0 * zoomFactor;
                final offsetRoute = _offsetRoute(route, lineEntry.key, _lines.length, offsetMeters);
                final stroke = (_currentZoom >= 13) ? 6.0 : (_currentZoom >= 10) ? 4.0 : 3.0;

                return [
                  PolylineLayer(polylines: [
                    Polyline(points: offsetRoute, color: color.withValues(alpha: 0.15), strokeWidth: stroke + 4),
                    Polyline(points: offsetRoute, color: color.withValues(alpha: 0.8), strokeWidth: stroke),
                  ]),
                ];
              }),

              // ── Route lines for each bus (offset scales with zoom) ──
              ..._buses.asMap().entries.expand((busEntry) {
                final busIndex = busEntry.key;
                final bus = busEntry.value;
                final color = bus.lineId.isNotEmpty ? _colorForLine(bus.lineId) : _colorForBus(busIndex);
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
                            color: context.appPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: context.appPrimary.withValues(alpha: 0.3), blurRadius: 8)],
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
                        color: context.appGreen, shape: BoxShape.circle,
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
                        color: context.appRed, shape: BoxShape.circle,
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
                  final color = busIndex >= 0 ? _colorForBus(busIndex) : context.appPrimary;

                  return Marker(
                    point: position,
                    width: 110,
                    height: 64,
                    child: GestureDetector(
                      onTap: () => _showBusInfo(context, bus, color),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Dark navy label pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _navy,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Text(bus.lineName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white), overflow: TextOverflow.ellipsis),
                        ),
                        // Triangle connector
                        CustomPaint(size: const Size(8, 4), painter: _NavyTriangle()),
                        // Icon circle with glow
                        Container(width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1),
                                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6),
                              ],
                            ),
                            child: Center(child: Container(width: 28, height: 28,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                child: const Icon(Icons.directions_bus, color: Colors.white, size: 15)))),
                      ]),
                    ),
                  );
                }),
              ]),
            ],
          ),

          // ═══════════════════════════════════════
          // TOP BAR — floating search pill
          // ═══════════════════════════════════════
Positioned(top: 0, left: 0, right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, top + 10, 12, 10),
              child: Material(
                color: context.appCardBg,
                borderRadius: BorderRadius.circular(32),
                elevation: 6,
                shadowColor: Colors.black26,
                child: InkWell(
                  borderRadius: BorderRadius.circular(32),
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(children: [
                      Icon(Icons.arrow_back, size: 20, color: context.appText),
                      const SizedBox(width: 12),
                      Icon(Icons.search, size: 20, color: context.appSub),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          liveCount > 0 ? '$liveCount bus en trajet' : 'Carte des bus',
                          style: TextStyle(
                            fontSize: 14,
                            color: liveCount > 0 ? context.appText : context.appSub,
                            fontWeight: liveCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (liveCount > 0)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: context.appGreen, shape: BoxShape.circle),
                        ),
                    ]),
                  ),
                ),
              ),
            )),

          // ═══════════════════════════════════════
          // NO BUSES / NO LIVE LOCATION — dark navy pill
          // ═══════════════════════════════════════
          if (_busPositions.isEmpty && !_isLoading && _buses.isEmpty)
            Positioned(
              bottom: 100, left: 24, right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.white70, size: 18),
                  SizedBox(width: 12),
                  Expanded(child: Text('Aucun bus actif. Ajoutez un bus dans l\'application chauffeur.',
                    style: TextStyle(fontSize: 13, color: Colors.white, height: 1.4))),
                ]),
              ),
            ),

          if (_busPositions.isEmpty && !_isLoading && _buses.isNotEmpty)
            Positioned(
              bottom: 100, left: 24, right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: const Row(children: [
                  Icon(Icons.directions_bus, color: Colors.white70, size: 18),
                  SizedBox(width: 12),
                  Expanded(child: Text('Les bus apparaîtront sur la carte quand le chauffeur aura démarré le trajet.',
                    style: TextStyle(fontSize: 13, color: Colors.white, height: 1.4))),
                ]),
              ),
            ),

          // ═══════════════════════════════════════
          // BOTTOM PILL — dark navy "En cours" style
          // ═══════════════════════════════════════
          Positioned(
            bottom: 30, left: 24, right: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: liveCount > 0
                    ? RichText(text: TextSpan(
                        children: [
                          TextSpan(text: '$liveCount ', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          const TextSpan(text: 'bus en trajet', style: TextStyle(fontSize: 13, color: Colors.white70)),
                        ]))
                    : Text(
                        _buses.isEmpty ? 'Aucun bus actif' : '${_buses.length} bus enregistré${_buses.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                ),
                if (liveCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.appGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.appGreen.withValues(alpha: 0.4)),
                    ),
                    child: Text('En cours', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.appGreen)),
                  ),
              ]),
            ),
          ),

          // ═══════════════════════════════════════
          // CONTROLS (right side)
          // ═══════════════════════════════════════
          Positioned(bottom: 30, right: 16,
              child: Column(children: [
                if (_busPositions.isNotEmpty || _buses.isNotEmpty) ...[
                  _GBtn(Icons.crop_free, _fitAllMarkers),
                  const SizedBox(height: 10),
                ],
                if (_myPosition != null)
                  _GBtn(Icons.my_location, _centerOnMe, tint: context.appPrimary),
              ])),
        ]),
      ),
    );
  }
}

class _NavyTriangle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = _navy..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(_NavyTriangle o) => false;
}

class _GBtn extends StatefulWidget {
  final IconData icon; final VoidCallback onTap; final Color? tint;
  const _GBtn(this.icon, this.onTap, {this.tint});
  @override
  State<_GBtn> createState() => _GBtnState();
}

class _GBtnState extends State<_GBtn> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTap() {
    _animController.forward().then((_) => _animController.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Material(color: context.appCardBg, shape: const CircleBorder(), elevation: 2, shadowColor: Colors.black26,
        child: InkWell(customBorder: const CircleBorder(), onTap: _onTap,
            child: Padding(padding: const EdgeInsets.all(11),
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(scale: _scaleAnimation.value, child: child);
                  },
                  child: Icon(widget.icon, size: 22, color: widget.tint ?? context.appSub),
                ))));
  }
}