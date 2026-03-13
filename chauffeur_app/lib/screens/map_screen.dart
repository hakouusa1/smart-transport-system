import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

const _mapboxToken =
    'pk.eyJ1IjoiaGFrb3UwODgiLCJhIjoiY21tZXgxMTJvMDF5eDJyc2hxY2Y3OW1rOCJ9.v74bMi9y79UmP4ixwsuLJw';

class MapScreen extends StatefulWidget {
  final String busId;

  const MapScreen({super.key, required this.busId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}



class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _etaTimer;

  LatLng _currentPosition = const LatLng(36.7538, 3.0588);
  double _currentSpeed = 0.0;
  double _currentHeading = 0.0;
  bool _isLoading = true;
  String _lastUpdateTime = '--:--:--';
  String? _errorMsg;

  // Departure & Arrival
  double? _departureLat;
  double? _departureLng;
  double? _arrivalLat;
  double? _arrivalLng;

  // Route
  List<LatLng> _fullRoutePoints = [];
  List<LatLng> _completedRoutePoints = [];
  List<LatLng> _remainingRoutePoints = [];

  // ETA
  double? _etaMinutes;
  double? _distanceKm;
  String _arrivalTimeText = '--:--';

  LatLng? _lastEtaPosition;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  // ============================================
  // INIT - step by step with error handling
  // ============================================
  Future<void> _init() async {
    // Step 1: Get GPS position
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

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _currentSpeed = pos.speed;
          _currentHeading = pos.heading;
          _isLoading = false;
          _lastUpdateTime = DateFormat('HH:mm:ss').format(DateTime.now());
        });
      }

      debugPrint('GPS OK: ${pos.latitude}, ${pos.longitude}');
    } catch (e) {
      debugPrint('GPS error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Erreur GPS: $e';
        });
      }
      return;
    }

    // Step 2: Fetch bus coordinates from Firestore
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

        debugPrint('Departure: $_departureLat, $_departureLng');
        debugPrint('Arrival: $_arrivalLat, $_arrivalLng');

        if (_departureLat == null || _arrivalLat == null) {
          debugPrint('WARNING: No departure/arrival set for this bus');
        }
      } else {
        debugPrint('WARNING: Bus document not found: ${widget.busId}');
      }
    } catch (e) {
      debugPrint('Firestore error: $e');
    }

    // Step 3: Fetch route from Mapbox
    await _fetchFullRoute();

    // Step 4: Fetch ETA from Mapbox
    await _fetchEta();

    // Step 5: Start ETA refresh timer
    _etaTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _fetchEta(),
    );

    // Step 6: Listen to GPS updates
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
        _currentHeading = pos.heading;
        _lastUpdateTime = DateFormat('HH:mm:ss').format(DateTime.now());
      });

      _mapController.move(_currentPosition, _mapController.camera.zoom);
      _updateRouteProgress();

      // Refresh ETA every 100m
      if (_shouldRefreshEta()) {
        _fetchEta();
      }
    });

    if (mounted) setState(() {});
  }

  // ============================================
  // FETCH FULL ROUTE: departure → arrival
  // ============================================
  Future<void> _fetchFullRoute() async {
    if (_departureLat == null || _departureLng == null ||
        _arrivalLat == null || _arrivalLng == null) {
      debugPrint('Cannot fetch route: missing coordinates');
      return;
    }

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
            '$_departureLng,$_departureLat;$_arrivalLng,$_arrivalLat'
            '?geometries=geojson&overview=false&steps=true&access_token=$_mapboxToken',
      );

      debugPrint('Fetching route: $url');
      final response = await http.get(url);
      debugPrint('Route response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          // Collect ALL step geometries for maximum detail
          final List<LatLng> allPoints = [];
          final legs = routes[0]['legs'] as List?;

          if (legs != null) {
            for (final leg in legs) {
              final steps = leg['steps'] as List?;
              if (steps != null) {
                for (final step in steps) {
                  final coords = step['geometry']['coordinates'] as List;
                  for (final c in coords) {
                    final point = LatLng(
                      (c[1] as num).toDouble(),
                      (c[0] as num).toDouble(),
                    );
                    // Avoid duplicate consecutive points
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
            });
            debugPrint('Route loaded: ${_fullRoutePoints.length} points (from steps)');
            _updateRouteProgress();
          }
        } else {
          debugPrint('No routes in response');
        }
      } else {
        debugPrint('Route error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Route exception: $e');
    }
  }

  // ============================================
  // FETCH ETA: bus → arrival
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
            debugPrint('ETA: ${_etaMinutes?.round()} min, ${_distanceKm?.toStringAsFixed(1)} km');
          }
        }
      } else {
        debugPrint('ETA error: ${response.statusCode}');
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

  bool _shouldRefreshEta() {
    if (_lastEtaPosition == null) return true;
    const dist = Distance();
    return dist.as(LengthUnit.Meter, _lastEtaPosition!, _currentPosition) >= 100;
  }

  // ============================================
  // HELPERS
  // ============================================
  Color get _etaColor {
    if (_etaMinutes == null) return Colors.grey;
    if (_etaMinutes! <= 5) return Colors.green;
    if (_etaMinutes! <= 15) return Colors.orange;
    return Colors.red;
  }

  String get _etaText {
    if (_etaMinutes == null) return '--';
    final min = _etaMinutes!.round();
    if (min < 1) return 'Imminente';
    if (min < 60) return '$min min';
    return '${min ~/ 60}h ${min % 60}min';
  }

  String get _distanceText {
    if (_distanceKm == null) return '--';
    if (_distanceKm! < 1) return '${(_distanceKm! * 1000).toStringAsFixed(0)} m';
    return '${_distanceKm!.toStringAsFixed(1)} km';
  }

  String get _speedText => '${(_currentSpeed * 3.6).clamp(0, 200).toStringAsFixed(0)} km/h';

  void _centerOnDriver() => _mapController.move(_currentPosition, 16);

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

  // ============================================
  // BUILD
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte en direct'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Voir tout',
            onPressed: _fitAll,
          ),
        ],
      ),
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
          // ============================================
          // MAP
          // ============================================
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=$_mapboxToken',
                userAgentPackageName: 'com.example.chauffeur_app',
                tileSize: 512,
                zoomOffset: -1,
              ),

              // Completed route (green)
              if (_completedRoutePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _completedRoutePoints,
                      color: Colors.green.withValues(alpha: 0.8),
                      strokeWidth: 5,
                    ),
                  ],
                ),

              // Remaining route (red dashed)
              if (_remainingRoutePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _remainingRoutePoints,
                      color: Colors.red.withValues(alpha: 0.7),
                      strokeWidth: 4,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Departure
                  if (_departureLat != null && _departureLng != null)
                    Marker(
                      point: LatLng(_departureLat!, _departureLng!),
                      width: 70, height: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3)],
                            ),
                            child: const Text('Départ',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                          ),
                          const Icon(Icons.trip_origin, color: Colors.green, size: 28),
                        ],
                      ),
                    ),

                  // Arrival
                  if (_arrivalLat != null && _arrivalLng != null)
                    Marker(
                      point: LatLng(_arrivalLat!, _arrivalLng!),
                      width: 70, height: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3)],
                            ),
                            child: const Text('Arrivée',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
                          ),
                          const Icon(Icons.location_on, color: Colors.red, size: 30),
                        ],
                      ),
                    ),

                  // Bus marker
                  Marker(
                    point: _currentPosition,
                    width: 52, height: 52,
                    child: Transform.rotate(
                      angle: _currentHeading * (3.14159 / 180),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 3)],
                        ),
                        child: const Icon(Icons.directions_bus, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ============================================
          // ETA CARD
          // ============================================
          if (_etaMinutes != null || _distanceKm != null)
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text('ETA via Mapbox',
                          style: TextStyle(fontSize: 9, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                    ),
                    _ETARow(icon: Icons.access_time_filled, color: _etaColor, value: _etaText, label: 'Temps estimé'),
                    const SizedBox(height: 10),
                    _ETARow(icon: Icons.social_distance, color: Colors.purple, value: _distanceText, label: 'Bus → Arrivée'),
                    const SizedBox(height: 10),
                    _ETARow(icon: Icons.schedule, color: Colors.blue, value: _arrivalTimeText, label: 'Heure d\'arrivée'),
                  ],
                ),
              ),
            ),

          // ============================================
          // BOTTOM PANEL
          // ============================================
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
