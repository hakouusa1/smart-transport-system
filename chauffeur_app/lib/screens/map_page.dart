import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart' as config;
import '../services/offline_map_service.dart';

class MapPage extends StatefulWidget {
  final String busId;

  const MapPage({super.key, required this.busId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  Timer? _etaTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  LatLng _currentPosition = const LatLng(36.7538, 3.0588);
  double _currentSpeed = 0.0;
  double _currentHeading = 0.0;
  bool _isLoading = true;
  String _lastUpdateTime = '--:--:--';
  String? _errorMsg;
  String _currentStreet = '';

  // Departure & Arrival
  double? _departureLat;
  double? _departureLng;
  double? _arrivalLat;
  double? _arrivalLng;
  String? _arrivalName;

  // Route
  List<LatLng> _fullRoutePoints = [];
  List<LatLng> _completedRoutePoints = [];
  List<LatLng> _remainingRoutePoints = [];
  List<LatLng> _preRoute = [];
  bool _preRouteLoaded = false;
  List<Map<String, dynamic>> _routeSteps = [];
  int _currentStepIndex = 0;

  // ETA
  double? _etaMinutes;
  double? _distanceKm;
  String _arrivalTimeText = '--:--';
  double _distanceToNextTurn = 0;

  LatLng? _lastEtaPosition;
  DateTime? _lastCompassUpdate;
  double _lastRotatedHeading = 0.0;

  // Offline map caching
  bool _mapInitialized = false;
  bool _isCachingMap = false;
  double _cacheProgress = 0.0;
  bool _isRerouting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initOfflineMap();
    _init();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  /// Initialize offline map service
  Future<void> _initOfflineMap() async {
    await OfflineMapService.initialize();
    if (mounted) {
      setState(() => _mapInitialized = true);
    }
  }

  /// Start caching the map area for the route
  void _startMapCaching() {
    if (_isCachingMap || _departureLat == null || _arrivalLat == null) return;
    if (!OfflineMapService.isReady) return;

    OfflineMapService.hasCachedTiles().then((hasCached) {
      if (hasCached) return;

      setState(() => _isCachingMap = true);

      OfflineMapService.cacheRouteArea(
        departure: LatLng(_departureLat!, _departureLng!),
        arrival: LatLng(_arrivalLat!, _arrivalLng!),
        onProgress: (progress) {
          if (mounted) {
            setState(() => _cacheProgress = progress);
          }
        },
      ).then((_) {
        if (mounted) {
          setState(() => _isCachingMap = false);
        }
      });
    });
  }

  // ============================================
  // INIT
  // ============================================
  Future<void> _init() async {
    // Step 1: Check permissions
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'GPS désactivé. Activez la localisation.';
        });
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Permission de localisation refusée.';
        });
        return;
      }

      // Step 2: Show map immediately with last known position (Fix B)
      final lastPos = await Geolocator.getLastKnownPosition();
      if (mounted) {
        setState(() {
          if (lastPos != null) {
            _currentPosition = LatLng(lastPos.latitude, lastPos.longitude);
            _currentSpeed = lastPos.speed;
            _currentHeading = lastPos.heading;
            _lastUpdateTime = DateFormat('HH:mm:ss').format(DateTime.now());
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Erreur GPS: $e';
        });
      }
      return;
    }

    // Step 3: Compass — rotate map AND icon with phone heading.
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final h = event.heading;
      if (h == null || !mounted) return;
      final now = DateTime.now();
      if (_lastCompassUpdate != null &&
          now.difference(_lastCompassUpdate!).inMilliseconds < 500) { return; }
      _lastCompassUpdate = now;
      setState(() => _currentHeading = h);
      final diff = ((h - _lastRotatedHeading) % 360).abs();
      final wrappedDiff = diff > 180 ? 360 - diff : diff;
      if (wrappedDiff < 5.0) return;
      _lastRotatedHeading = h;
      _mapController.moveAndRotate(
          _currentPosition,
          _mapController.camera.zoom,
          -h);
    });

    // Step 4: Listen to GPS updates (position + speed)
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _currentSpeed = pos.speed;
        _lastUpdateTime = DateFormat('HH:mm:ss').format(DateTime.now());
      });

      _mapController.moveAndRotate(
          _currentPosition,
          _mapController.camera.zoom,
          -_currentHeading);
      _updateRouteProgress();

      if (_shouldRefreshEta()) {
        _fetchEta();
      }
    });

    // Step 5: Fetch accurate GPS, Firestore, route, and ETA concurrently in background (Fix B)
    unawaited(_fetchBackgroundData());
  }

  /// Fetches Firestore, route, and ETA in sequence. The GPS fix runs independently.
  Future<void> _fetchBackgroundData() async {
    unawaited(_fetchAccurateGpsFix());

    await _fetchFirestoreData();

    await Future.wait([
      _fetchFullRoute(),
      _fetchEta(),
    ]);

    _startMapCaching();

    _etaTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchEta(),
    );

    if (mounted) setState(() {});
  }

  Future<void> _fetchAccurateGpsFix() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _currentSpeed = pos.speed;
        _currentHeading = pos.heading;
        _lastUpdateTime = DateFormat('HH:mm:ss').format(DateTime.now());
      });
      _mapController.moveAndRotate(
        _currentPosition,
        _mapController.camera.zoom,
        -_currentHeading,
      );
    } catch (_) {}
  }

  Future<void> _fetchFirestoreData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.busId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _departureLat = (data['departureLat'] as num?)?.toDouble();
        _departureLng = (data['departureLng'] as num?)?.toDouble();
        _arrivalLat = (data['arrivalLat'] as num?)?.toDouble();
        _arrivalLng = (data['arrivalLng'] as num?)?.toDouble();
        _arrivalName = data['arrivalLocation'] as String?;

        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Firestore error: $e');
    }
  }

  // ============================================
  // FETCH FULL ROUTE
  // ============================================
  Future<void> _fetchFullRoute({LatLng? from}) async {
    if ((_departureLat == null || _departureLng == null) && from == null) {
      return;
    }
    if (_arrivalLat == null || _arrivalLng == null) {
      return;
    }

    final startLat = from?.latitude ?? _departureLat!;
    final startLng = from?.longitude ?? _departureLng!;

    try {
      final url = Uri.parse(config.getDirectionsUrl(startLng, startLat, _arrivalLng!, _arrivalLat!));

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final List<LatLng> allPoints = [];
          final List<Map<String, dynamic>> steps = [];
          final legs = routes[0]['legs'] as List?;

          if (legs != null) {
            for (final leg in legs) {
              final legSteps = leg['steps'] as List?;
              if (legSteps != null) {
                for (final step in legSteps) {
                  steps.add({
                    'maneuver': step['maneuver'],
                    'distance': (step['distance'] as num).toDouble(),
                    'name': step['name'] ?? '',
                  });

                  final coords = step['geometry']['coordinates'] as List;
                  for (final c in coords) {
                    final point = LatLng(
                      (c[1] as num).toDouble(),
                      (c[0] as num).toDouble(),
                    );
                    if (allPoints.isEmpty || allPoints.last != point) {
                      allPoints.add(point);
                    }
                  }
                }
              }
            }
          }

          if (mounted && allPoints.isNotEmpty) {
            setState(() {
              _currentStepIndex = 0;
              _fullRoutePoints = allPoints;
              _remainingRoutePoints = List.from(_fullRoutePoints);
              _completedRoutePoints = [];
              _routeSteps = steps;
            });
            _updateRouteProgress();
          }
        }
      }
    } catch (e) {
      debugPrint('Route exception: $e');
      _showSnack('Impossible de charger l\'itinéraire. Vérifiez votre connexion.');
    } finally {
      if (from != null) _isRerouting = false;
    }
  }

  // ============================================
  // FETCH ETA
  // ============================================
  Future<void> _fetchEta() async {
    if (_arrivalLat == null || _arrivalLng == null) return;

    try {
      final url = Uri.parse(config.getDirectionsUrl(_currentPosition.longitude, _currentPosition.latitude, _arrivalLng!, _arrivalLat!));

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final durationSec = (routes[0]['duration'] as num).toDouble();
          final distanceM = (routes[0]['distance'] as num).toDouble();
          final arrival = DateTime.now().add(Duration(seconds: durationSec.round()));

          if (mounted) {
            setState(() {
              _etaMinutes = durationSec / 60;
              _distanceKm = distanceM / 1000;
              _arrivalTimeText = DateFormat('HH:mm').format(arrival);
              _lastEtaPosition = _currentPosition;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('ETA exception: $e');
    }
  }

  // ============================================
  // UPDATE ROUTE PROGRESS
  // ============================================
  void _updateRouteProgress() {
    if (_fullRoutePoints.isEmpty) return;

    double minDist = double.infinity;
    int closestIndex = 0;
    const dist = Distance();

    for (int i = 0; i < _fullRoutePoints.length; i++) {
      final d = dist.as(LengthUnit.Meter, _currentPosition, _fullRoutePoints[i]);
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }

    if (_currentStepIndex < _routeSteps.length) {
      final step = _routeSteps[_currentStepIndex];
      final maneuver = step['maneuver'] as Map<String, dynamic>?;
      if (maneuver != null) {
        final location = maneuver['location'] as List?;
        if (location != null) {
          final turnPoint = LatLng(location[1].toDouble(), location[0].toDouble());
          _distanceToNextTurn = dist.as(LengthUnit.Meter, _currentPosition, turnPoint);
        }
      }

      for (int i = _currentStepIndex; i < _routeSteps.length; i++) {
        final stepManeuver = _routeSteps[i]['maneuver'] as Map<String, dynamic>?;
        if (stepManeuver != null) {
          final loc = stepManeuver['location'] as List?;
          if (loc != null) {
            final stepPoint = LatLng(loc[1].toDouble(), loc[0].toDouble());
            if (dist.as(LengthUnit.Meter, _currentPosition, stepPoint) < 50) {
              _currentStepIndex = i + 1;
              if (_currentStepIndex < _routeSteps.length) {
                _currentStreet = _routeSteps[_currentStepIndex]['name'] ?? '';
              }
              break;
            }
          }
        }
      }
    }

    if (minDist > 100) {
      if (!_isRerouting) {
        _isRerouting = true;
        _fetchFullRoute(from: _currentPosition);
      }
    } else {
      if (_preRoute.isNotEmpty) setState(() { _preRoute = []; _preRouteLoaded = false; });
      setState(() {
        _completedRoutePoints = [
          ..._fullRoutePoints.sublist(0, closestIndex + 1),
          _currentPosition,
        ];
        _remainingRoutePoints = [
          _currentPosition,
          ..._fullRoutePoints.sublist(closestIndex),
        ];
      });
    }
  }

  Future<void> _fetchPreRoute() async {
    if (_departureLat == null || _departureLng == null) return;
    _preRouteLoaded = true;
    try {
      final url = Uri.parse(config.getDirectionsUrl(_currentPosition.longitude, _currentPosition.latitude, _departureLng!, _departureLat!));
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final coords = jsonDecode(res.body)['routes'][0]['geometry']['coordinates'] as List;
        final pts = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        if (mounted && pts.isNotEmpty) setState(() => _preRoute = pts);
      }
    } catch (_) {}
  }

  bool _shouldRefreshEta() {
    if (_lastEtaPosition == null) return true;
    const dist = Distance();
    return dist.as(LengthUnit.Meter, _lastEtaPosition!, _currentPosition) >= 100;
  }

  // ============================================
  // HELPERS
  // ============================================
  String get _speedText => '${(_currentSpeed * 3.6).clamp(0, 200).toStringAsFixed(0)} km/h';
  String get _distanceText {
    if (_distanceKm == null) return '--';
    if (_distanceKm! < 1) return '${(_distanceKm! * 1000).toStringAsFixed(0)} m';
    return '${_distanceKm!.toStringAsFixed(1)} km';
  }

  String get _etaText {
    if (_etaMinutes == null) return '--';
    final min = _etaMinutes!.round();
    if (min < 1) return 'Imminente';
    if (min < 60) return '$min min';
    return '${min ~/ 60}h ${min % 60}min';
  }

  IconData _getManeuverIcon() {
    if (_currentStepIndex >= _routeSteps.length) {
      return Icons.location_on;
    }

    final step = _routeSteps[_currentStepIndex];
    final maneuver = step['maneuver'] as Map<String, dynamic>?;
    final type = maneuver?['type'] as String? ?? '';
    final modifier = maneuver?['modifier'] as String? ?? '';

    if (type.contains('arrive')) return Icons.location_on;
    if (type.contains('uturn')) return Icons.u_turn_left;
    if (type.contains('roundabout')) return Icons.roundabout_left;
    if (modifier.contains('left') || type.contains('left')) return Icons.turn_left;
    if (modifier.contains('right') || type.contains('right')) return Icons.turn_right;
    if (type.contains('fork')) return Icons.call_split;
    if (type.contains('merge')) return Icons.merge_type;
    return Icons.straight;
  }

  String _getDistanceToTurn() {
    if (_distanceToNextTurn < 1000) {
      return '${_distanceToNextTurn.round()} m';
    }
    return '${(_distanceToNextTurn / 1000).toStringAsFixed(1)} km';
  }

  String _getNextStreet() {
    if (_currentStepIndex < _routeSteps.length - 1) {
      return _routeSteps[_currentStepIndex + 1]['name'] ?? 'Destination';
    }
    return _arrivalName ?? 'Destination';
  }

  void _centerOnDriver() {
    _mapController.moveAndRotate(_currentPosition, 19, -_currentHeading);
  }

  void _fitAll() {
    final points = <LatLng>[_currentPosition];
    if (_departureLat != null && _departureLng != null) {
      points.add(LatLng(_departureLat!, _departureLng!));
    }
    if (_arrivalLat != null && _arrivalLng != null) {
      points.add(LatLng(_arrivalLat!, _arrivalLng!));
    }
    if (points.length >= 2) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(60),
        ),
      );
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  // ============================================
  // BUILD
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildLoadingScreen()
          : _errorMsg != null
              ? _buildErrorScreen()
              : _buildMapScreen(),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A237E), Color(0xFF1565C0)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            const SizedBox(height: 18),
            const Text(
              'Recherche de votre position GPS...',
              style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_errorMsg!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await Geolocator.openAppSettings();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Ouvrir les paramètres'),
            ),
          ],
        ),
      ),
    );
  }

  String get _mapTileUrl {
    if (!config.useMapbox) return config.mapTileUrl;
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=${config.mapboxToken}';
  }

  Widget _buildMapScreen() {
    return Stack(
      children: [
        // Perspective-tilted map
        ClipRect(
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0006)
              ..rotateX(-0.30),
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scaleX: 1.5,
              scaleY: 1.4,
              alignment: Alignment.bottomCenter,
              child: SizedBox.expand(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition,
                    initialZoom: 17,
                  ),
                  children: [
                    if (_mapInitialized)
                      OfflineMapService.getTileLayer()
                    else
                      TileLayer(
                        urlTemplate: _mapTileUrl,
                        userAgentPackageName: 'com.example.chauffeur_app',
                        tileSize: config.mapTileSize,
                        zoomOffset: config.mapZoomOffset,
                      ),

                    // Pre-route (bus to departure)
                    if (_preRoute.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _preRoute,
                            color: const Color(0xFF4285F4).withValues(alpha: 0.18),
                            strokeWidth: 14,
                          ),
                          Polyline(
                            points: _preRoute,
                            color: const Color(0xFF4285F4).withValues(alpha: 0.5),
                            strokeWidth: 5,
                            strokeCap: StrokeCap.round,
                          ),
                        ],
                      ),

                    // Completed route — amber glow
                    if (_completedRoutePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _completedRoutePoints,
                            color: const Color(0xFFFFA726).withValues(alpha: 0.25),
                            strokeWidth: 18,
                            strokeCap: StrokeCap.round,
                          ),
                          Polyline(
                            points: _completedRoutePoints,
                            color: const Color(0xFFFFA726),
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                          ),
                        ],
                      ),

                    // Remaining route — blue glow
                    if (_remainingRoutePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _remainingRoutePoints,
                            color: const Color(0xFF1E88E5).withValues(alpha: 0.22),
                            strokeWidth: 18,
                            strokeCap: StrokeCap.round,
                          ),
                          Polyline(
                            points: _remainingRoutePoints,
                            color: const Color(0xFF1E88E5),
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                          ),
                        ],
                      ),

                    // Departure marker
                    if (_departureLat != null && _departureLng != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_departureLat!, _departureLng!),
                            width: 52, height: 64,
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2),
                                    ],
                                  ),
                                  child: const Icon(Icons.trip_origin, color: Colors.white, size: 22),
                                ),
                                Container(width: 3, height: 10, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),

                    // Arrival marker
                    if (_arrivalLat != null && _arrivalLng != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_arrivalLat!, _arrivalLng!),
                            width: 52, height: 64,
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFEF5350), Color(0xFFB71C1C)],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2),
                                    ],
                                  ),
                                  child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
                                ),
                                Container(width: 3, height: 10, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),

                    // Current position — pulsing blue chevron
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPosition,
                          width: 90,
                          height: 90,
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (_, __) => AnimatedRotation(
                              turns: _currentHeading / 360,
                              duration: const Duration(milliseconds: 150),
                              child: Stack(alignment: Alignment.center, children: [
                                Container(
                                  width: 90 * _pulseAnimation.value,
                                  height: 90 * _pulseAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0x221E88E5),
                                  ),
                                ),
                                Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1E88E5).withValues(alpha: 0.45),
                                        blurRadius: 18,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.navigation, color: Colors.white, size: 36),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Cache progress indicator
        if (_isCachingMap)
          Positioned(
            top: 0, left: 0, right: 0,
            child: LinearProgressIndicator(
              value: _cacheProgress,
              backgroundColor: Colors.transparent,
              color: Colors.lightBlue.withValues(alpha: 0.7),
              minHeight: 3,
            ),
          ),

        // ============================================
        // NAVIGATION TOP BAR — dark blue gradient
        // ============================================
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A237E), Color(0xFF1565C0)],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                child: Row(
                  children: [
                    // Maneuver icon
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Icon(_getManeuverIcon(), color: Colors.white, size: 40),
                    ),
                    const SizedBox(width: 14),
                    // Distance + street
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDistanceToTurn(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _getNextStreet(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // ETA chip
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Text(
                            _arrivalTimeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _etaText,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ============================================
        // BOTTOM INFO CARD — dark themed
        // ============================================
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Destination + live indicator
                    Row(
                      children: [
                        const Icon(Icons.flag_rounded, color: Color(0xFFEF5350), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _arrivalName ?? 'Destination',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'En cours',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Stats row
                    Row(
                      children: [
                        _DarkStat(
                          icon: Icons.speed_rounded,
                          label: 'Vitesse',
                          value: _speedText,
                          color: const Color(0xFF42A5F5),
                        ),
                        const SizedBox(width: 8),
                        _DarkStat(
                          icon: Icons.route_rounded,
                          label: 'Distance',
                          value: _distanceText,
                          color: const Color(0xFFFFB74D),
                        ),
                        const SizedBox(width: 8),
                        _DarkStat(
                          icon: Icons.access_time_rounded,
                          label: 'Arrivée',
                          value: _arrivalTimeText,
                          color: const Color(0xFF66BB6A),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ============================================
        // MAP CONTROLS — grouped right side
        // ============================================
        Positioned(
          right: 12,
          bottom: 155,
          child: Column(
            children: [
              _MapButton(
                icon: Icons.my_location_rounded,
                onTap: _centerOnDriver,
                accent: const Color(0xFF1E88E5),
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.fit_screen_rounded,
                onTap: _fitAll,
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.add_rounded,
                onTap: () => _mapController.move(
                    _mapController.camera.center, _mapController.camera.zoom + 1),
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.remove_rounded,
                onTap: () => _mapController.move(
                    _mapController.camera.center, _mapController.camera.zoom - 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DarkStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _DarkStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;
  const _MapButton({required this.icon, required this.onTap, this.accent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      elevation: 5,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: accent ?? Colors.black87, size: 22),
        ),
      ),
    );
  }
}
