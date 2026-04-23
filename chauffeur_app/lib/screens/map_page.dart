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

const _mapboxToken = config.mapboxToken;

class MapPage extends StatefulWidget {
  final String busId;

  const MapPage({super.key, required this.busId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  Timer? _etaTimer;

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

  // Offline map caching
  bool _mapInitialized = false;
  bool _isCachingMap = false;
  double _cacheProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initOfflineMap();
    _init();
  }

  @override
  void dispose() {
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

    // Step 3: Compass — rotate map AND icon with phone heading (capped at 10 Hz, Fix D)
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final h = event.heading;
      if (h == null || !mounted) return;
      final now = DateTime.now();
      if (_lastCompassUpdate != null &&
          now.difference(_lastCompassUpdate!).inMilliseconds < 100) { return; }
      _lastCompassUpdate = now;
      setState(() => _currentHeading = h);
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
    // GPS fix is truly fire-and-forget: a slow/cold GPS lock must never
    // block the Firestore → route → ETA pipeline.
    unawaited(_fetchAccurateGpsFix());

    await _fetchFirestoreData();

    // Route and ETA both need Firestore data; run them in parallel.
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

  /// Gets a high-accuracy GPS fix with a 15-second hard timeout.
  /// On success it snaps the map to the accurate position.
  /// On failure (cold GPS, timeout, denied) it exits silently — the
  /// position stream handles all subsequent updates.
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
    } catch (_) {
      // Timed out or failed — position stream handles ongoing updates.
    }
  }

  /// Fetches bus departure/arrival coordinates from Firestore.
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
  Future<void> _fetchFullRoute() async {
    if (_departureLat == null || _departureLng == null ||
        _arrivalLat == null || _arrivalLng == null) {
      return;
    }

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
            '$_departureLng,$_departureLat;$_arrivalLng,$_arrivalLat'
            '?geometries=geojson&overview=false&steps=true&access_token=$_mapboxToken',
      );

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
    }
  }

  // ============================================
  // FETCH ETA
  // ============================================
  Future<void> _fetchEta() async {
    if (_arrivalLat == null || _arrivalLng == null) return;

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
            '${_currentPosition.longitude},${_currentPosition.latitude};'
            '$_arrivalLng,$_arrivalLat'
            '?access_token=$_mapboxToken',
      );

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

    // Calculate distance to next turn
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
      
      // Update current step index based on position
      // Search forward from current index only — never go backwards
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
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
            '${_currentPosition.longitude},${_currentPosition.latitude};'
            '$_departureLng,$_departureLat'
            '?overview=full&geometries=geojson&access_token=$_mapboxToken',
      );
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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Recherche de votre position GPS...'),
                ],
              ),
            )
          : _errorMsg != null
              ? Center(
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
                )
              : Stack(
                  children: [
                    // Perspective-tilted map (simulates Google Maps navigation angle)
                    ClipRect(
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0006) // perspective depth
                          ..rotateX(-0.30),          // ~17° forward tilt
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
                            urlTemplate:
                                'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=$_mapboxToken',
                            userAgentPackageName: 'com.example.chauffeur_app',
                            tileSize: 512,
                            zoomOffset: -1,
                          ),

                        // Pre-route (bus to departure, when bus hasn't reached route start)
                        if (_preRoute.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _preRoute,
                                color: const Color(0xFF4285F4).withValues(alpha: 0.2),
                                strokeWidth: 12,
                              ),
                              Polyline(
                                points: _preRoute,
                                color: const Color(0xFF4285F4).withValues(alpha: 0.45),
                                strokeWidth: 6,
                              ),
                            ],
                          ),

                        // Completed route — orange glow + solid (Google Maps style)
                        if (_completedRoutePoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _completedRoutePoints,
                                color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                                strokeWidth: 16,
                              ),
                              Polyline(
                                points: _completedRoutePoints,
                                color: const Color(0xFFFF9800),
                                strokeWidth: 8,
                              ),
                            ],
                          ),

                        // Remaining route — blue glow + solid (Google Maps style)
                        if (_remainingRoutePoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _remainingRoutePoints,
                                color: const Color(0xFF4285F4).withValues(alpha: 0.25),
                                strokeWidth: 16,
                              ),
                              Polyline(
                                points: _remainingRoutePoints,
                                color: const Color(0xFF4285F4),
                                strokeWidth: 8,
                              ),
                            ],
                          ),

                        // Departure
                        if (_departureLat != null && _departureLng != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_departureLat!, _departureLng!),
                                width: 50, height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)
                                    ],
                                  ),
                                  child: const Icon(Icons.trip_origin, color: Colors.white, size: 24),
                                ),
                              ),
                            ],
                          ),

                        // Arrival
                        if (_arrivalLat != null && _arrivalLng != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_arrivalLat!, _arrivalLng!),
                                width: 50, height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)
                                    ],
                                  ),
                                  child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                                ),
                              ),
                            ],
                          ),

                        // Current position — Google Maps-style navigation chevron (self-rotates with compass)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentPosition,
                              width: 80,
                              height: 80,
                              child: AnimatedRotation(
                                turns: _currentHeading / 360,
                                duration: const Duration(milliseconds: 150),
                                child: Stack(alignment: Alignment.center, children: [
                                Container(
                                  width: 80, height: 80,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0x334285F4),
                                  ),
                                ),
                                Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 2)],
                                  ),
                                ),
                                const Icon(Icons.navigation, color: Color(0xFF4285F4), size: 40),
                              ]),
                              ),  // Transform.rotate
                            ),
                          ],
                        ),
                      ],
                          ),  // FlutterMap
                          ),  // SizedBox.expand
                        ),  // Transform.scale
                      ),  // Transform (perspective+tilt)
                    ),  // ClipRect

                    // ============================================
                    // NAVIGATION TOP BAR - Green bar like in the image
                    // ============================================
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          color: Colors.green.shade700,
                          child: Column(
                            children: [
                              // Main navigation info
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Turn arrow icon
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getManeuverIcon(),
                                        color: Colors.green.shade700,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Distance and street name
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getDistanceToTurn(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getNextStreet(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom info card
                    Positioned(
                      bottom: 0, left: 0, right: 0,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('Trajet en cours',
                          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(_lastUpdateTime,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      _MapStat(icon: Icons.speed, label: 'Vitesse', value: _speedText, color: Colors.blue),
                      const SizedBox(width: 16),
                      _MapStat(icon: Icons.route, label: 'Distance', value: _distanceText, color: Colors.orange),
                      const SizedBox(width: 16),
                      _MapStat(icon: Icons.access_time_rounded, label: 'ETA', value: _etaText, color: Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ============================================
          // CONTROLS
          // ============================================
          Positioned(
            bottom: 160, right: 16,
            child: FloatingActionButton.small(
              heroTag: 'center',
              onPressed: _centerOnDriver,
              backgroundColor: Colors.white,
              child: Icon(Icons.my_location, color: Theme.of(context).colorScheme.primary),
            ),
          ),

          Positioned(
            top: 16, right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoomIn',
                  onPressed: () => _mapController.move(
                      _mapController.camera.center, _mapController.camera.zoom + 1),
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomOut',
                  onPressed: () => _mapController.move(
                      _mapController.camera.center, _mapController.camera.zoom - 1),
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ETARow extends StatelessWidget {
  final IconData icon; final Color color; final String value; final String label;
  const _ETARow({required this.icon, required this.color, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ]),
    ]);
  }
}


class _MapStat extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _MapStat({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
    ]));
  }
}
