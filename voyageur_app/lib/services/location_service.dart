import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

/// Represents a bus location from Realtime Database
class BusLocation {
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final int timestamp;

  BusLocation({
    required this.latitude,
    required this.longitude,
    this.speed = 0.0,
    this.heading = 0.0,
    this.timestamp = 0,
  });

  /// Convert to LatLng for flutter_map
  LatLng get latLng => LatLng(latitude, longitude);

  /// Speed in km/h
  double get speedKmh => speed * 3.6;

  /// Format speed as string
  String get speedText => '${speedKmh.clamp(0, 200).toStringAsFixed(0)} km/h';

  /// Check if location data is recent (within last 30 seconds)
  bool get isRecent {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - timestamp) < 30000; // 30 seconds
  }

  factory BusLocation.fromMap(Map<dynamic, dynamic> map) {
    return BusLocation(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Stream of bus location updates from Realtime Database
  /// This is what makes the marker move in real-time on the map
  Stream<BusLocation?> getBusLocationStream(String busId) {
    return _dbRef.child('locations/$busId').onValue.map((event) {
      final data = event.snapshot.value;

      if (data == null) return null;

      return BusLocation.fromMap(data as Map<dynamic, dynamic>);
    });
  }

  /// Get bus location once (not a stream)
  Future<BusLocation?> getBusLocation(String busId) async {
    try {
      final snapshot = await _dbRef.child('locations/$busId').get();

      if (!snapshot.exists || snapshot.value == null) return null;

      return BusLocation.fromMap(snapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      return null;
    }
  }
}
