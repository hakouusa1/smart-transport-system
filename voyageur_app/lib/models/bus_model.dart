import 'package:cloud_firestore/cloud_firestore.dart';

class Bus {
  final String busId;
  final String lineName;
  final String busName;
  final String busNumber;
  final bool isActive;
  final DateTime createdAt;
  final String ownerId;
  final String driverId;
  final String driverStatus;

  // Departure position
  final double? departureLat;
  final double? departureLng;

  // Arrival position
  final double? arrivalLat;
  final double? arrivalLng;

  Bus({
    required this.busId,
    required this.lineName,
    this.busName = '',
    this.busNumber = '',
    this.isActive = true,
    DateTime? createdAt,
    this.ownerId = '',
    this.driverId = '',
    this.driverStatus = 'offline',
    this.departureLat,
    this.departureLng,
    this.arrivalLat,
    this.arrivalLng,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Bus.fromMap(Map<String, dynamic> map) {
    return Bus(
      busId: map['busId'] ?? '',
      lineName: map['lineName'] ?? '',
      busName: map['busName'] ?? '',
      busNumber: map['busNumber'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ownerId: map['ownerId'] ?? '',
      driverId: map['driverId'] ?? '',
      driverStatus: map['driverStatus'] ?? 'offline',
      departureLat: (map['departureLat'] as num?)?.toDouble(),
      departureLng: (map['departureLng'] as num?)?.toDouble(),
      arrivalLat: (map['arrivalLat'] as num?)?.toDouble(),
      arrivalLng: (map['arrivalLng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busId': busId,
      'lineName': lineName,
      'busName': busName,
      'busNumber': busNumber,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'ownerId': ownerId,
      'driverId': driverId,
      'driverStatus': driverStatus,
      'departureLat': departureLat,
      'departureLng': departureLng,
      'arrivalLat': arrivalLat,
      'arrivalLng': arrivalLng,
    };
  }

  String get statusText {
    switch (driverStatus) {
      case 'on_trip':
        return 'En trajet';
      case 'online':
        return 'En ligne';
      case 'offline':
      default:
        return 'Hors ligne';
    }
  }

  bool get isOnTrip => driverStatus == 'on_trip';
  bool get isOnline => driverStatus == 'online' || driverStatus == 'on_trip';

  bool get hasDeparture => departureLat != null && departureLng != null;
  bool get hasArrival => arrivalLat != null && arrivalLng != null;
}