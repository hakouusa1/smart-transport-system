import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Single GPS source broadcast to all subscribers. Firebase writes are gated
  // to ≥20 m movement inside startTracking(); the map display subscribes to
  // the same stream without opening a second GPS session.
  final StreamController<Position> _broadcastCtrl =
      StreamController<Position>.broadcast();
  StreamSubscription<Position>? _sourceSub;

  Timer? _uploadTimer;
  Position? _lastPosition;
  Position? _lastWrittenPosition;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  /// GPS broadcast stream. Subscribe here instead of calling Geolocator directly.
  Stream<Position> get positionStream => _broadcastCtrl.stream;

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

    // Write last known position immediately so passengers see the bus right away.
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
      _lastWrittenPosition = lastKnown;
    }

    // On Android, run GPS as a foreground service so it survives screen lock.
    // On iOS, standard settings suffice (OS allows background location).
    final LocationSettings locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Massar Chauffeur',
              notificationText: 'GPS actif — trajet en cours',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          );

    _sourceSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      if (!_isTracking) return;
      _lastPosition = position;
      _broadcastCtrl.add(position);

      final last = _lastWrittenPosition;
      final movedEnough = last == null ||
          Geolocator.distanceBetween(
                last.latitude,
                last.longitude,
                position.latitude,
                position.longitude,
              ) >=
              20;

      if (movedEnough) {
        _lastWrittenPosition = position;
        final speed = position.speed < 1.0 ? 0.0 : position.speed;
        _dbRef.child('locations/$busId').set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': speed,
          'heading': position.heading,
          'timestamp': ServerValue.timestamp,
        });
      }
    }, onError: (_) {});

    // Heartbeat: refresh timestamp every 30 s when stationary so passengers
    // always see a recent "last seen" time even when the bus hasn't moved.
    _uploadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
    _lastWrittenPosition = null;
    await _sourceSub?.cancel();
    _sourceSub = null;

    try {
      await _dbRef.child('locations/$busId').remove();
    } catch (_) {}
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
    _sourceSub?.cancel();
    _sourceSub = null;
    _broadcastCtrl.close();
    _isTracking = false;
  }
}
