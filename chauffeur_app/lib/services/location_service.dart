import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  StreamSubscription<Position>? _positionSub;
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

    // DON'T call getCurrentPosition() — it's slow and returns cached position
    // Just start the stream immediately — first accurate position comes in 1-2 seconds

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
          (position) {
        if (!_isTracking) return;

        // FILTER 1: Ignore inaccurate GPS (> 25 meters accuracy)
        if (position.accuracy > 25) return;

        // FILTER 2: Fix false speed — GPS reports small speed even when stationary
        // If speed < 1 m/s (3.6 km/h) and accuracy > 10m, it's noise — set speed to 0
        double speed = position.speed;
        if (speed < 1.0) speed = 0.0;

        _dbRef.child('locations/$busId').set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': speed,
          'heading': position.heading,
          'timestamp': ServerValue.timestamp,
        });
      },
      onError: (_) {},
    );
  }

  // ════════════════════════════════════════
  // STOP TRACKING
  // ════════════════════════════════════════
  Future<void> stopTracking(String busId) async {
    _isTracking = false;
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
    _positionSub?.cancel();
    _positionSub = null;
    _isTracking = false;
  }
}