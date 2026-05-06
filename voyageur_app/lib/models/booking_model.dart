import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String bookingId;
  final String busId;
  final String passengerId;
  final String passengerName;
  final String lineName;
  final String busName;
  final String status;
  final double? passengerLat;
  final double? passengerLng;
  final DateTime? boardedAt;
  final DateTime createdAt;

  Booking({
    required this.bookingId,
    required this.busId,
    required this.passengerId,
    this.passengerName = '',
    this.lineName = '',
    this.busName = '',
    this.status = 'pending',
    this.passengerLat,
    this.passengerLng,
    this.boardedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      bookingId: map['bookingId'] ?? '',
      busId: map['busId'] ?? '',
      passengerId: map['passengerId'] ?? '',
      passengerName: map['passengerName'] ?? '',
      lineName: map['lineName'] ?? '',
      busName: map['busName'] ?? '',
      status: map['status'] ?? 'pending',
      passengerLat: (map['passengerLat'] as num?)?.toDouble(),
      passengerLng: (map['passengerLng'] as num?)?.toDouble(),
      boardedAt: (map['boardedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'busId': busId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'lineName': lineName,
      'busName': busName,
      'status': status,
      'passengerLat': passengerLat,
      'passengerLng': passengerLng,
      if (boardedAt != null) 'boardedAt': Timestamp.fromDate(boardedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get hasLocation => passengerLat != null && passengerLng != null;
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isWaiting => status == 'waiting';
  bool get isBoarded => status == 'boarded';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => isWaiting || isBoarded || isPending || isConfirmed;

  String get statusText {
    switch (status) {
      case 'confirmed': return 'Confirmée';
      case 'waiting': return 'En attente';
      case 'boarded': return 'À bord';
      case 'completed': return 'Terminée';
      case 'cancelled': return 'Annulée';
      case 'pending':
      default: return 'En attente';
    }
  }
}