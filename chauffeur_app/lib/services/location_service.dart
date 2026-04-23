import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  StreamSubscription<Position>? _positionSub;
  Timer? _uploadTimer;
  Position? _lastPosition;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  // ════════════════════════════════════════
  // PERMISSIONS
  // ════════════════════════════════════════
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Les services de localisation sont désactivés.';
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        throw 'Permission de localisation refusée.';
      }
    }
    if (perm == LocationPermission.deniedForever) {
      throw 'Permission refusée définitivement.';
    }

    return true;
  }

  // ════════════════════════════════════════
  // START TRACKING
  // ════════════════════════════════════════
  Future<void> startTracking(String busId) async {
    await checkAndRequestPermissions();
    if (_isTracking) return;
    _isTracking = true;

    // Write last known position immediately so passengers see the bus right away,
    // before the 5-second upload timer fires for the first time.
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null && _isTracking) {
      final speed = lastKnown.speed < 1.0 ? 0.0 : lastKnown.speed;
      _dbRef.child('locations/$busId').set({
        'latitude': lastKnown.latitude,
        'longitude': lastKnown.longitude,
        'speed': speed,
        'heading': lastKnown.heading,
        'timestamp': ServerValue.timestamp,
      });
    }

    // Upload on every significant position change (≥20 m) for accurate tracking.
    // A 2-second fallback timer covers the stationary case so passengers always
    // see a recent timestamp even when the bus isn't moving.
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((position) {
      if (!_isTracking) return;
      _lastPosition = position;
      double speed = position.speed < 1.0 ? 0.0 : position.speed;
      _dbRef.child('locations/$busId').set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': speed,
        'heading': position.heading,
        'timestamp': ServerValue.timestamp,
      });
    }, onError: (_) {});

    // Fallback: refresh timestamp every 2 s when stationary
    _uploadTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isTracking || _lastPosition == null) return;
      _dbRef.child('locations/$busId/timestamp').set(ServerValue.timestamp);
    });
  }

  // ════════════════════════════════════════
  // STOP TRACKING
  // ════════════════════════════════════════
  Future<void> stopTracking(String busId) async {
    _isTracking = false;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _lastPosition = null;
    await _positionSub?.cancel();
    _positionSub = null;

    try {
      await _dbRef.child('locations/$busId').remove();
    } catch (_) {}
  }

  // ════════════════════════════════════════
  // GPS STREAM (for chauffeur map screen)
  // ════════════════════════════════════════
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }

  // ════════════════════════════════════════
  // READ BUS LOCATION
  // ════════════════════════════════════════
  Stream<DatabaseEvent> getBusLocationStream(String busId) {
    return _dbRef.child('locations/$busId').onValue;
  }

  // ════════════════════════════════════════
  // CLEANUP
  // ════════════════════════════════════════
  void dispose() {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _isTracking = false;
  }
}