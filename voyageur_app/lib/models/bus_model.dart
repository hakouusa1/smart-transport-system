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
  final String lineId;

  // Departure position
  final double? departureLat;
  final double? departureLng;

  // Arrival position
  final double? arrivalLat;
  final double? arrivalLng;

  final DateTime? onlineAt;
  final String? scheduleTime;
  final List<String> tripSchedules;
  final int currentTripIndex;
  final int capacity;

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
    this.lineId = '',
    this.departureLat,
    this.departureLng,
    this.arrivalLat,
    this.arrivalLng,
    this.onlineAt,
    this.scheduleTime,
    this.tripSchedules = const [],
    this.currentTripIndex = 0,
    this.capacity = 50,
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
      lineId: map['lineId'] ?? '',
      departureLat: (map['departureLat'] as num?)?.toDouble(),
      departureLng: (map['departureLng'] as num?)?.toDouble(),
      arrivalLat: (map['arrivalLat'] as num?)?.toDouble(),
      arrivalLng: (map['arrivalLng'] as num?)?.toDouble(),
      onlineAt: (map['onlineAt'] as Timestamp?)?.toDate(),
      scheduleTime: map['scheduleTime'] as String?,
      tripSchedules: (map['tripSchedules'] as List?)?.cast<String>() ?? [],
      currentTripIndex: (map['currentTripIndex'] as num?)?.toInt() ?? 0,
      capacity: (map['capacity'] as num?)?.toInt() ?? 50,
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
      'lineId': lineId,
      'departureLat': departureLat,
      'departureLng': departureLng,
      'arrivalLat': arrivalLat,
      'arrivalLng': arrivalLng,
      if (onlineAt != null) 'onlineAt': Timestamp.fromDate(onlineAt!),
      'scheduleTime': scheduleTime,
      'tripSchedules': tripSchedules,
      'currentTripIndex': currentTripIndex,
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

  String? get firstScheduleTime =>
      tripSchedules.isNotEmpty ? tripSchedules.first : scheduleTime;

  /// Returns the next upcoming scheduled trip time based on current time.
  /// If all trips have passed today, returns the first one (next day).
  String? get nextScheduleTime {
    if (tripSchedules.isEmpty) return scheduleTime;
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    for (final t in tripSchedules) {
      final parts = t.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        if (h * 60 + m >= nowMinutes) return t;
      }
    }
    return tripSchedules.first;
  }

  bool get isOnTrip => driverStatus == 'on_trip';
  bool get isOnline => driverStatus == 'online' || driverStatus == 'on_trip';

  bool get hasDeparture => departureLat != null && departureLng != null;
  bool get hasArrival => arrivalLat != null && arrivalLng != null;
}

class BusTrip {
  final Bus bus;
  final int tripIndex;
  final bool isEnTrajet;
  final String? scheduleTime;
  
  BusTrip({
    required this.bus,
    required this.tripIndex,
    required this.isEnTrajet,
    this.scheduleTime,
  });

  String get displayLineName {
    final name = bus.lineName;
    if (tripIndex % 2 != 0 && name.contains('-')) {
      final parts = name.split('-');
      return parts.reversed.map((e) => e.trim()).join(' - ');
    }
    return name;
  }
}

extension BusTripExtension on Bus {
  List<BusTrip> get activeTrips {
    if (tripSchedules.isEmpty) {
      return [
        BusTrip(
          bus: this,
          tripIndex: currentTripIndex,
          isEnTrajet: isOnTrip,
          scheduleTime: scheduleTime,
        )
      ];
    }

    final count = tripSchedules.length;
    final startIdx = currentTripIndex % count;

    List<BusTrip> trips = [];
    for (int offset = 0; offset < count - startIdx; offset++) {
      final scheduleIdx = startIdx + offset;
      final tripIdx = currentTripIndex + offset;
      trips.add(BusTrip(
        bus: this,
        tripIndex: tripIdx,
        isEnTrajet: offset == 0 ? isOnTrip : false,
        scheduleTime: tripSchedules[scheduleIdx],
      ));
    }
    return trips;
  }
}