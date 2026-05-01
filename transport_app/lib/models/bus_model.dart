import 'package:cloud_firestore/cloud_firestore.dart';

class Bus {
  final String busId;
  final String? lineId;
  final String lineName;
  final String busName;
  final String busNumber;
  final bool isActive;
  final DateTime createdAt;
  final String ownerId;
  final String driverId;
  final num? salary;
  final num? recipientSalary;
  final String driverStatus;

  // Departure position
  final double? departureLat;
  final double? departureLng;

  // Arrival position
  final double? arrivalLat;
  final double? arrivalLng;

  // Document validation
  final String validationStatus; // 'pending' | 'approved' | 'rejected'
  final String? ligneValidationUrl;
  final String? assuranceUrl;
  final String? validationNote;

  // Per-document review by admin ('pending' | 'ok' | 'issue')
  final String? ligneValidationStatus;
  final String? ligneValidationNote;
  final String? assuranceStatus;
  final String? assuranceNote;

  // Assurance expiry
  final DateTime? insuranceEndDate;

  // Maintenance
  final DateTime? lastVidangeDate;
  final int? lastVidangeKm;
  final int? currentKm;
  final int? weightKg;
  final DateTime? lastSalaryDate;

  // Schedule
  final String? scheduleTime; // legacy single time "HH:mm"
  final int numberOfTrips;
  final List<String> tripSchedules; // ["HH:mm", "HH:mm", ...]
  final int currentTripIndex;

  // Salary types
  final String chauffeurSalaryType; // 'monthly' | 'per_trip'
  final String receveurSalaryType;  // 'monthly' | 'per_trip'

  Bus({
    required this.busId,
    this.lineId,
    required this.lineName,
    this.busName = '',
    this.busNumber = '',
    this.isActive = true,
    DateTime? createdAt,
    this.ownerId = '',
    this.driverId = '',
    this.salary,
    this.recipientSalary,
    this.driverStatus = 'offline',
    this.departureLat,
    this.departureLng,
    this.arrivalLat,
    this.arrivalLng,
    this.validationStatus = 'pending',
    this.ligneValidationUrl,
    this.assuranceUrl,
    this.validationNote,
    this.ligneValidationStatus,
    this.ligneValidationNote,
    this.assuranceStatus,
    this.assuranceNote,
    this.insuranceEndDate,
    this.lastVidangeDate,
    this.lastVidangeKm,
    this.currentKm,
    this.weightKg,
    this.lastSalaryDate,
    this.scheduleTime,
    this.numberOfTrips = 1,
    this.tripSchedules = const [],
    this.chauffeurSalaryType = 'monthly',
    this.receveurSalaryType = 'monthly',
    this.currentTripIndex = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  List<String> get allSchedules {
    if (tripSchedules.isNotEmpty) return tripSchedules;
    if (scheduleTime != null) return [scheduleTime!];
    return [];
  }

  factory Bus.fromMap(Map<String, dynamic> map) {
    return Bus(
      busId: map['busId'] ?? '',
      lineId: map['lineId'] as String?,
      lineName: map['lineName'] ?? '',
      busName: map['busName'] ?? map['driverName'] ?? '',
      busNumber: map['busNumber'] ?? map['driverPhone'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ownerId: map['ownerId'] ?? '',
      driverId: map['driverId'] ?? '',
      salary: map['salary'] as num?,
      recipientSalary: map['recipient'] as num?,
      driverStatus: map['driverStatus'] ?? 'offline',
      departureLat: (map['departureLat'] as num?)?.toDouble(),
      departureLng: (map['departureLng'] as num?)?.toDouble(),
      arrivalLat: (map['arrivalLat'] as num?)?.toDouble(),
      arrivalLng: (map['arrivalLng'] as num?)?.toDouble(),
      // Default 'approved' for legacy buses created before this feature
      validationStatus: map['validationStatus'] ?? 'approved',
      ligneValidationUrl: map['ligneValidationUrl'] as String?,
      assuranceUrl: map['assuranceUrl'] as String?,
      validationNote: map['validationNote'] as String?,
      ligneValidationStatus: map['ligneValidationStatus'] as String?,
      ligneValidationNote: map['ligneValidationNote'] as String?,
      assuranceStatus: map['assuranceStatus'] as String?,
      assuranceNote: map['assuranceNote'] as String?,
      insuranceEndDate: (map['assuranceEndDate'] as Timestamp?)?.toDate(),
      lastVidangeDate: (map['lastVidangeDate'] as Timestamp?)?.toDate(),
      lastVidangeKm: (map['lastVidangeKm'] as num?)?.toInt(),
      currentKm: (map['currentKm'] as num?)?.toInt(),
      weightKg: (map['poids'] as num?)?.toInt(),
      lastSalaryDate: (map['lastSalaryDate'] as Timestamp?)?.toDate(),
      scheduleTime: map['scheduleTime'] as String?,
      numberOfTrips: (map['numberOfTrips'] as num?)?.toInt() ?? 1,
      tripSchedules: (map['tripSchedules'] as List?)?.cast<String>() ?? [],
      chauffeurSalaryType: map['chauffeurSalaryType'] as String? ?? 'monthly',
      receveurSalaryType: map['receveurSalaryType'] as String? ?? 'monthly',
      currentTripIndex: (map['currentTripIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busId': busId,
      'lineId': lineId,
      'lineName': lineName,
      'busName': busName,
      'busNumber': busNumber,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'ownerId': ownerId,
      'driverId': driverId,
      'salary': salary,
      'recipient': recipientSalary,
      'driverStatus': driverStatus,
      'departureLat': departureLat,
      'departureLng': departureLng,
      'arrivalLat': arrivalLat,
      'arrivalLng': arrivalLng,
      'validationStatus': validationStatus,
      'ligneValidationUrl': ligneValidationUrl,
      'assuranceUrl': assuranceUrl,
      'validationNote': validationNote,
      'ligneValidationStatus': ligneValidationStatus,
      'ligneValidationNote': ligneValidationNote,
      'assuranceStatus': assuranceStatus,
      'assuranceNote': assuranceNote,
      'assuranceEndDate': insuranceEndDate != null ? Timestamp.fromDate(insuranceEndDate!) : null,
      'lastVidangeDate': lastVidangeDate != null ? Timestamp.fromDate(lastVidangeDate!) : null,
      'lastVidangeKm': lastVidangeKm,
      'currentKm': currentKm,
      'poids': weightKg,
      'lastSalaryDate': lastSalaryDate != null ? Timestamp.fromDate(lastSalaryDate!) : null,
      'scheduleTime': scheduleTime,
      'numberOfTrips': numberOfTrips,
      'tripSchedules': tripSchedules,
      'chauffeurSalaryType': chauffeurSalaryType,
      'receveurSalaryType': receveurSalaryType,
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

  bool get isOnTrip => driverStatus == 'on_trip';
  bool get isOnline => driverStatus == 'online' || driverStatus == 'on_trip';

  bool get hasDeparture => departureLat != null && departureLng != null;
  bool get hasArrival => arrivalLat != null && arrivalLng != null;

  bool get isPending => validationStatus == 'pending';
  bool get isApproved => validationStatus == 'approved';
  bool get isRejected => validationStatus == 'rejected';

  bool get isReversed => currentTripIndex % 2 != 0;

  String get displayLineName {
    if (isReversed && lineName.contains('-')) {
      return lineName.split('-').reversed.map((e) => e.trim()).join(' - ');
    }
    return lineName;
  }
}