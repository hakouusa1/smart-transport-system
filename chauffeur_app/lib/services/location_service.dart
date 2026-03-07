import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Timer? _locationTimer;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  // ============================================
  // PERMISSIONS
  // ============================================

  /// Check and request location permissions
  /// Returns true if all permissions are granted
  Future<bool> checkAndRequestPermissions() async {
    // Check if location services are enabled on the device
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Les services de localisation sont désactivés. '
          'Veuillez les activer dans les paramètres.';
    }

    // Request location permission
    PermissionStatus status = await Permission.location.request();

    if (status.isDenied) {
      throw 'Permission de localisation refusée. '
          'L\'application a besoin de votre position pour fonctionner.';
    }

    if (status.isPermanentlyDenied) {
      throw 'Permission de localisation refusée définitivement. '
          'Veuillez l\'activer dans les paramètres de l\'application.';
    }

    return status.isGranted;
  }

  /// Open device location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app permission settings
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  // ============================================
  // GET CURRENT POSITION
  // ============================================

  /// Get current GPS position (one-time)
  Future<Position> getCurrentPosition() async {
    await checkAndRequestPermissions();

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // minimum 5 meters before update
      ),
    );
  }

  // ============================================
  // REAL-TIME TRACKING
  // ============================================

  /// Start sending GPS location to Firebase Realtime Database every 4 seconds
  Future<void> startTracking(String busId) async {
    // Ensure permissions first
    await checkAndRequestPermissions();

    if (_isTracking) return; // Already tracking

    _isTracking = true;

    // Send location immediately on start
    await _sendLocation(busId);

    // Then send every 4 seconds
    _locationTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _sendLocation(busId),
    );
  }

  /// Stop sending GPS location
  Future<void> stopTracking(String busId) async {
    _isTracking = false;
    _locationTimer?.cancel();
    _locationTimer = null;

    // Clear location from Realtime Database
    try {
      await _dbRef.child('locations/$busId').remove();
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Send current position to Firebase Realtime Database
  Future<void> _sendLocation(String busId) async {
    if (!_isTracking) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _dbRef.child('locations/$busId').set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed, // meters per second
        'heading': position.heading, // direction in degrees
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      // Don't stop tracking on a single failed update
      // The next tick will try again
    }
  }

  // ============================================
  // LISTEN TO LOCATION (for Map Screen)
  // ============================================

  /// Stream of position updates from the device GPS
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 meters of movement
      ),
    );
  }

  /// Stream of location from Realtime Database (for reading other bus positions)
  Stream<DatabaseEvent> getBusLocationStream(String busId) {
    return _dbRef.child('locations/$busId').onValue;
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Dispose resources
  void dispose() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isTracking = false;
  }
}
