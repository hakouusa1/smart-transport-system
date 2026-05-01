import 'package:cloud_firestore/cloud_firestore.dart';

/// LineStop model representing the association between a line and a stop with order
///
/// Created: 2026-04-27
/// Author: Kilo

class LineStop {
  final String id;
  final String lineId;
  final String stopId;
  final int orderIndex;
  final DateTime createdAt;

  LineStop({
    required this.id,
    required this.lineId,
    required this.stopId,
    required this.orderIndex,
    required this.createdAt,
  });

  factory LineStop.fromMap(Map<String, dynamic> map) {
    return LineStop(
      id: map['id'] as String,
      lineId: map['lineId'] as String,
      stopId: map['stopId'] as String,
      orderIndex: map['orderIndex'] as int,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lineId': lineId,
      'stopId': stopId,
      'orderIndex': orderIndex,
      'createdAt': createdAt,
    };
  }
}