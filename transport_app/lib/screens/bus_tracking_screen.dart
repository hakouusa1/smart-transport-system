import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';
import '../services/location_service.dart';
import '../app_config.dart' as config;
import '../services/route_service.dart';
import '../theme_notifier.dart';
import '../widgets/bus_loading_indicator.dart';


class BusTrackingScreen extends StatefulWidget {
  final Bus bus;

  const BusTrackingScreen({super.key, required this.bus});

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  StreamSubscription<BusLocation?>? _busLocationSub;
  StreamSubscription<DocumentSnapshot>? _busSub;
  Timer? _etaRefreshTimer;

  BusLocation? _busLocation;
  Bus? _currentBus;
  bool _isLoading = true;
  bool _busOffline = false;
  String _lastUpdateTime = '--:--:--';
  bool _isZoomedOnBus = false;
  bool _mapReady = false;

  // ETA from Mapbox
  int _etaMinutes = 0;
  String _etaText = '--';
  String _distanceBusToArrivalText = '--';
  String _arrivalTimeText = '--:--';
  String _distanceDepartToBusText = '--';

  // Raw values for progress bar
  double _totalRouteDistanceMeters = 0;
  double _distanceBusToArrivalMeters = 0;

  // Route
  List<LatLng> _fullRoutePoints = [];
  List<LatLng> _remainingRoutePoints = [];
  List<LatLng> _completedRoutePoints = [];
  List<LatLng> _preRoute = [];
  bool _preRouteLoaded = false;
  bool _routeLoaded = false;

  LatLng? _lastEtaBusPosition;
  static const double _etaRefreshDistanceMeters = 100;

  final LatLng _defaultCenter = const LatLng(36.7538, 3.0588);

  double get _routeProgress {
    if (_totalRouteDistanceMeters <= 0 || _distanceBusToArrivalMeters <= 0) return 0;
    final completed = _totalRouteDistanceMeters - _distanceBusToArrivalMeters;
    return (completed / _totalRouteDistanceMeters).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _currentBus = widget.bus;
    _startListeningBus();
    _startListeningBusDoc();
    _loadFullRoute();

    _etaRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchETAFromMapbox(),
    );
  }

  @override
  void dispose() {
    _busLocationSub?.cancel();
    _busSub?.cancel();
    _etaRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFullRoute() async {
    final bus = _currentBus ?? widget.bus;
    if (!bus.hasDeparture || !bus.hasArrival) return;

    final from = LatLng(bus.departureLat!, bus.departureLng!);
    final to = LatLng(bus.arrivalLat!, bus.arrivalLng!);

    final result = await RouteService.getRoute(from, to);

    if (mounted && result != null && result.points.isNotEmpty) {
      setState(() {
        _fullRoutePoints = result.points;
        _remainingRoutePoints = List.from(result.points);
        _completedRoutePoints = [];
        _routeLoaded = true;
        _totalRouteDistanceMeters = result.distanceMeters;
      });
      _updateRouteProgress();
      if (_mapReady) _fitRoute();
    }
  }

  void _onMapReady() {
    _mapReady = true;
    if (_routeLoaded && _fullRoutePoints.isNotEmpty) {
      _fitRoute();
    } else {
      _fitDepartureArrival();
    }
  }

  void _fitDepartureArrival() {
    final bus = _currentBus ?? widget.bus;
    if (!bus.hasDeparture || !bus.hasArrival) return;
    final points = [
      LatLng(bus.departureLat!, bus.departureLng!),
      LatLng(bus.arrivalLat!, bus.arrivalLng!),
    ];
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  Future<void> _fetchETAFromMapbox() async {
    final bus = _currentBus ?? widget.bus;
    if (_busLocation == null || !bus.hasArrival) return;

    final busPos = _busLocation!.latLng;
    final arrivalPos = LatLng(bus.arrivalLat!, bus.arrivalLng!);

    final result = await RouteService.getRoute(busPos, arrivalPos);

    if (mounted && result != null) {
      final arrivalTime = DateTime.now().add(
        Duration(seconds: result.durationSeconds.round()),
      );

      setState(() {
        _etaMinutes = result.etaMinutes;
        _etaText = result.etaText;
        _distanceBusToArrivalText = result.distanceText;
        _distanceBusToArrivalMeters = result.distanceMeters;
        _arrivalTimeText = DateFormat('HH:mm').format(arrivalTime);
        _lastEtaBusPosition = busPos;
      });
    }
  }

  void _updateRouteProgress() {
    if (!_routeLoaded || _fullRoutePoints.isEmpty || _busLocation == null) return;

    double minDist = double.infinity;
    int closestIndex = 0;
    const dist = Distance();

    for (int i = 0; i < _fullRoutePoints.length; i++) {
      final d = dist.as(LengthUnit.Meter, _busLocation!.latLng, _fullRoutePoints[i]);
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }

    if (closestIndex == 0 && minDist > 100) {
      setState(() {
        _completedRoutePoints = [];
        _remainingRoutePoints = List.from(_fullRoutePoints);
      });
      if (!_preRouteLoaded) _fetchPreRoute();
    } else {
      if (_preRoute.isNotEmpty) setState(() { _preRoute = []; _preRouteLoaded = false; });
      setState(() {
        _completedRoutePoints = [
          ..._fullRoutePoints.sublist(0, closestIndex + 1),
          _busLocation!.latLng,
        ];
        _remainingRoutePoints = [
          _busLocation!.latLng,
          ..._fullRoutePoints.sublist(closestIndex),
        ];
      });
    }
  }

  Future<void> _fetchPreRoute() async {
    final bus = _currentBus ?? widget.bus;
    if (_busLocation == null || !bus.hasDeparture) return;
    _preRouteLoaded = true;
    final r = await RouteService.getRoute(_busLocation!.latLng, LatLng(bus.departureLat!, bus.departureLng!));
    if (mounted && r != null && r.points.isNotEmpty) {
      setState(() => _preRoute = r.points);
    }
  }

  bool _shouldRefreshEta() {
    if (_lastEtaBusPosition == null || _busLocation == null) return true;
    const dist = Distance();
    final moved = dist.as(LengthUnit.Meter, _lastEtaBusPosition!, _busLocation!.latLng);
    return moved >= _etaRefreshDistanceMeters;
  }

  void _startListeningBus() {
    _busLocationSub = _locationService
        .getBusLocationStream(widget.bus.busId)
        .listen((location) {
      if (!mounted) return;

      if (location == null) {
        setState(() {
          _busOffline = true;
          _isLoading = false;
          _etaText = 'Bus hors ligne';
          _distanceBusToArrivalText = '--';
          _arrivalTimeText = '--:--';
        });
        return;
      }

      setState(() {
        _busLocation = location;
        _busOffline = false;
        _isLoading = false;
        _lastUpdateTime = DateFormat('HH:mm:ss').format(DateTime.now());
      });

      _updateDepartToBus();
      _updateRouteProgress();

      if (_shouldRefreshEta()) {
        _fetchETAFromMapbox();
      }

      if (_isZoomedOnBus) {
        _mapController.move(location.latLng, 16.0);
      }
    });
  }

  void _startListeningBusDoc() {
    _busSub = FirebaseFirestore.instance
        .collection('buses')
        .doc(widget.bus.busId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || !snapshot.exists) return;
      setState(() {
        _currentBus = Bus.fromMap(snapshot.data() as Map<String, dynamic>);
      });
    });
  }

  void _updateDepartToBus() {
    final bus = _currentBus ?? widget.bus;
    if (_busLocation != null && bus.hasDeparture) {
      const dist = Distance();
      final m = dist.as(
        LengthUnit.Meter,
        LatLng(bus.departureLat!, bus.departureLng!),
        _busLocation!.latLng,
      );
      setState(() {
        _distanceDepartToBusText = m < 1000
            ? '${m.toStringAsFixed(0)} m'
            : '${(m / 1000).toStringAsFixed(1)} km';
      });
    }
  }

  void _fitAllMarkers() {
    if (_routeLoaded && _fullRoutePoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_fullRoutePoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
      _mapController.rotate(0);
    } else {
      final bus = _currentBus ?? widget.bus;
      final points = <LatLng>[];
      if (_busLocation != null) points.add(_busLocation!.latLng);
      if (bus.hasDeparture) points.add(LatLng(bus.departureLat!, bus.departureLng!));
      if (bus.hasArrival) points.add(LatLng(bus.arrivalLat!, bus.arrivalLng!));
      if (points.length >= 2) {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(60)),
        );
        _mapController.rotate(0);
      }
    }
  }

  void _fitRoute() {
    if (_fullRoutePoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_fullRoutePoints);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
    _mapController.rotate(0);
  }

  void _toggleZoom() {
    if (_busLocation == null) return;
    setState(() => _isZoomedOnBus = !_isZoomedOnBus);
    if (_isZoomedOnBus) {
      _mapController.move(_busLocation!.latLng, 16.0);
    } else {
      if (_fullRoutePoints.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(_fullRoutePoints),
            padding: const EdgeInsets.all(60),
          ),
        );
      }
    }
  }

  Color get _etaColor {
    if (_etaMinutes <= 5) return Colors.green;
    if (_etaMinutes <= 15) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final bus = _currentBus ?? widget.bus;
    final hasLocation = _busLocation != null;
    final isDark = context.isDark;

    LatLng mapCenter = _defaultCenter;
    if (bus.hasDeparture && bus.hasArrival) {
      final dep = LatLng(bus.departureLat!, bus.departureLng!);
      final arr = LatLng(bus.arrivalLat!, bus.arrivalLng!);
      mapCenter = LatLng(
        (dep.latitude + arr.latitude) / 2,
        (dep.longitude + arr.longitude) / 2,
      );
    } else if (hasLocation) {
      mapCenter = _busLocation!.latLng;
    }

    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(bus.displayLineName),
        actions: [
          if (hasLocation && !_busOffline)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 6, color: Colors.white),
                  const SizedBox(width: 4),
                  const Text('LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BusLoadingIndicator(),
                  const SizedBox(height: 16),
                  const Text('Recherche du bus...'),
                ],
              ),
            )
          : Column(
              children: [
                // ── Map — top 40% ─────────────────────────────────────────
                Flexible(
                  flex: 40,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: mapCenter,
                          initialZoom: (bus.hasDeparture && bus.hasArrival)
                              ? 10
                              : hasLocation
                                  ? 14
                                  : 12,
                          onMapReady: _onMapReady,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: RouteService.tileUrl,
                            userAgentPackageName: 'com.example.transporteur_app',
                            tileSize: config.mapTileSize,
                            zoomOffset: config.mapZoomOffset,
                          ),
                          if (_preRoute.length >= 2)
                            PolylineLayer(polylines: [
                              Polyline(
                                  points: _preRoute,
                                  color: Colors.blue.withValues(alpha: 0.5),
                                  strokeWidth: 4,
                                  pattern: const StrokePattern.dotted()),
                            ]),
                          if (_completedRoutePoints.length >= 2)
                            PolylineLayer(polylines: [
                              Polyline(
                                  points: _completedRoutePoints,
                                  color: Colors.blue.withValues(alpha: 0.35),
                                  strokeWidth: 5),
                            ]),
                          if (_remainingRoutePoints.length >= 2)
                            PolylineLayer(polylines: [
                              Polyline(
                                  points: _remainingRoutePoints,
                                  color: Colors.blue,
                                  strokeWidth: 5),
                            ]),
                          if (!_routeLoaded && hasLocation && !_busOffline && bus.hasArrival)
                            PolylineLayer(polylines: [
                              Polyline(
                                points: [
                                  _busLocation!.latLng,
                                  LatLng(bus.arrivalLat!, bus.arrivalLng!)
                                ],
                                color: Colors.blue.withValues(alpha: 0.5),
                                strokeWidth: 3,
                                pattern: const StrokePattern.dotted(),
                              ),
                            ]),
                          MarkerLayer(
                            markers: [
                              if (bus.hasDeparture)
                                Marker(
                                  point: LatLng(bus.departureLat!, bus.departureLng!),
                                  width: 70,
                                  height: 60,
                                  alignment: Alignment.bottomCenter,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 3)
                                            ]),
                                        child: const Text('Départ',
                                            style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green)),
                                      ),
                                      const Icon(Icons.trip_origin,
                                          color: Colors.green, size: 28),
                                    ],
                                  ),
                                ),
                              if (bus.hasArrival)
                                Marker(
                                  point: LatLng(bus.arrivalLat!, bus.arrivalLng!),
                                  width: 70,
                                  height: 60,
                                  alignment: Alignment.bottomCenter,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 3)
                                            ]),
                                        child: const Text('Arrivée',
                                            style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red)),
                                      ),
                                      const Icon(Icons.location_on,
                                          color: Colors.red, size: 30),
                                    ],
                                  ),
                                ),
                              if (hasLocation && !_busOffline)
                                Marker(
                                  point: _busLocation!.latLng,
                                  width: 52,
                                  height: 52,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.green.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            spreadRadius: 4)
                                      ],
                                    ),
                                    child: const Icon(Icons.directions_bus,
                                        color: Colors.white, size: 24),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Offline banner
                      if (_busOffline)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            color: Colors.orange.shade100,
                            child: Row(children: [
                              Icon(Icons.wifi_off,
                                  color: Colors.orange.shade800, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ce bus n\'est pas en trajet actuellement.',
                                  style: TextStyle(
                                      color: Colors.orange.shade900, fontSize: 12),
                                ),
                              ),
                            ]),
                          ),
                        ),

                      // Zoom + fit controls
                      Positioned(
                        top: _busOffline ? 48 : 10,
                        right: 10,
                        child: Column(children: [
                          _MapBtn(
                            icon: Icons.add,
                            onTap: () => _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom + 1),
                          ),
                          const SizedBox(height: 6),
                          _MapBtn(
                            icon: Icons.remove,
                            onTap: () => _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom - 1),
                          ),
                          const SizedBox(height: 6),
                          _MapBtn(
                            icon: Icons.fit_screen,
                            color: Colors.purple,
                            onTap: _fitAllMarkers,
                          ),
                          if (hasLocation && !_busOffline) ...[
                            const SizedBox(height: 6),
                            _MapBtn(
                              icon: _isZoomedOnBus ? Icons.map : Icons.directions_bus,
                              color: Colors.green,
                              onTap: _toggleZoom,
                            ),
                          ],
                        ]),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable details — bottom 60% ───────────────────────
                Flexible(
                  flex: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      color: sheetBg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ─ Bus header ─
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: bus.isOnTrip
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.directions_bus,
                                color: bus.isOnTrip ? Colors.green : Colors.grey,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(bus.displayLineName,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    bus.busName.isNotEmpty
                                        ? bus.busName
                                        : 'Bus ${bus.busNumber}',
                                    style: TextStyle(
                                        color: textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: bus.isOnTrip
                                    ? Colors.green.shade50
                                    : bus.isOnline
                                        ? Colors.blue.shade50
                                        : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                bus.statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: bus.isOnTrip
                                      ? Colors.green.shade700
                                      : bus.isOnline
                                          ? Colors.blue.shade700
                                          : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ]),

                          Divider(height: 28, color: dividerColor),

                          if (hasLocation && !_busOffline) ...[
                            // Progress bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progression du trajet',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary),
                                ),
                                Text(
                                  '${(_routeProgress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _routeProgress,
                                minHeight: 8,
                                backgroundColor: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _distanceDepartToBusText == '--'
                                        ? 'Départ'
                                        : _distanceDepartToBusText,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (_distanceDepartToBusText != '--')
                                    Text(' parcourus',
                                        style: TextStyle(fontSize: 10, color: textSecondary)),
                                ]),
                                Row(children: [
                                  Text(
                                    _distanceBusToArrivalText == '--'
                                        ? 'Arrivée'
                                        : _distanceBusToArrivalText,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red.shade400,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (_distanceBusToArrivalText != '--')
                                    Text(' restants',
                                        style: TextStyle(fontSize: 10, color: textSecondary)),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ]),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // ETA card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _etaColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: _etaColor.withValues(alpha: 0.25)),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Temps estimé',
                                          style: TextStyle(
                                              fontSize: 11, color: textSecondary)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _etaText,
                                        style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: _etaColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 50, color: dividerColor),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Arrivée estimée',
                                        style: TextStyle(
                                            fontSize: 11, color: textSecondary)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      const Icon(Icons.schedule,
                                          size: 16, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        _arrivalTimeText,
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary),
                                      ),
                                    ]),
                                  ],
                                ),
                              ]),
                            ),

                            const SizedBox(height: 14),

                            // Speed + last update
                            Row(children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.speed,
                                  label: 'Vitesse',
                                  value: _busLocation!.speedText,
                                  color: Colors.blue,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.update,
                                  label: 'Mise à jour',
                                  value: _lastUpdateTime,
                                  color: Colors.teal,
                                  isDark: isDark,
                                ),
                              ),
                            ]),

                            const SizedBox(height: 14),

                            // Route legend
                            Row(children: [
                              Expanded(
                                  child: _LegendItem(
                                      color: Colors.blue.withValues(alpha: 0.4),
                                      label: 'Parcouru')),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _LegendItem(
                                      color: Colors.blue, label: 'Restant')),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _LegendItem(
                                      color: Colors.blue.shade300,
                                      label: 'Avant départ')),
                            ]),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                Icon(Icons.wifi_off, color: Colors.orange, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Bus hors ligne — aucune donnée disponible.',
                                    style: TextStyle(
                                        color: Colors.orange.shade800, fontSize: 13),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Small map control button ──────────────────────────────────────────────────

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _MapBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
          ],
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600)),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Route legend item ─────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 20,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}
