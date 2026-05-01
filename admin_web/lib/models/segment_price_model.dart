import 'package:cloud_firestore/cloud_firestore.dart';

/// SegmentPrice model representing the price for a segment between two consecutive stops in a line
///
/// Created: 2026-04-27
/// Author: Kilo

class SegmentPrice {
  final String id;
  final String lineId;
  final String fromStopId;
  final String toStopId;
  final double price;
  final DateTime createdAt;

  SegmentPrice({
    required this.id,
    required this.lineId,
    required this.fromStopId,
    required this.toStopId,
    required this.price,
    required this.createdAt,
  });

  factory SegmentPrice.fromMap(Map<String, dynamic> map) {
    return SegmentPrice(
      id: map['id'] as String,
      lineId: map['lineId'] as String,
      fromStopId: map['fromStopId'] as String,
      toStopId: map['toStopId'] as String,
      price: (map['price'] as num).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lineId': lineId,
      'fromStopId': fromStopId,
      'toStopId': toStopId,
      'price': price,
      'createdAt': createdAt,
    };
  }
}