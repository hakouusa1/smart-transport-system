import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

/// Represents a bus location from Realtime Database
class BusLocation {
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final double accuracy;
  final int timestamp;

  BusLocation({
    required this.latitude,
    required this.longitude,
    this.speed = 0.0,
    this.heading = 0.0,
    this.accuracy = 0.0,
    this.timestamp = 0,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  double get speedKmh => speed * 3.6;

  String get speedText => '${speedKmh.clamp(0, 200).toStringAsFixed(0)} km/h';

  /// Check if location is recent (within last 30 seconds)
  bool get isRecent {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - timestamp) < 30000;
  }

  /// Check if location is accurate (within 50 meters)
  bool get isAccurate => accuracy > 0 && accuracy < 50;

  factory BusLocation.fromMap(Map<dynamic, dynamic> map) {
    return BusLocation(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Stream of bus location updates from Realtime Database
  /// Filters out invalid/null data automatically
  Stream<BusLocation?> getBusLocationStream(String busId) {
    return _dbRef
        .child('locations/$busId')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;

      final location = BusLocation.fromMap(data as Map<dynamic, dynamic>);

      // Filter out obviously invalid coordinates
      if (location.latitude == 0.0 && location.longitude == 0.0) return null;

      return location;
    });
  }

  /// Get bus location once
  Future<BusLocation?> getBusLocation(String busId) async {
    try {
      final snapshot = await _dbRef.child('locations/$busId').get();
      if (!snapshot.exists || snapshot.value == null) return null;
      return BusLocation.fromMap(snapshot.value as Map<dynamic, dynamic>);
    } catch (_) {
      return null;
    }
  }
}