import 'package:cloud_firestore/cloud_firestore.dart';

/// Stop model representing a transport stop entity
///
/// Created: 2026-04-27
/// Author: Kilo

class Stop {
  final String id;
  final String name;
  final String type; // 'wilaya' or 'commune'
  final DateTime createdAt;
  final DateTime updatedAt;

  Stop({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Stop.fromMap(Map<String, dynamic> map) {
    return Stop(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}