import 'package:flutter/material.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final int priceDA;
  final int maxBuses;
  final int durationDays;
  final List<String> features;
  final Color color;
  final bool recommended;
  final int order;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceDA,
    required this.maxBuses,
    required this.features,
    required this.color,
    this.durationDays = 30,
    this.recommended = false,
    this.order = 0,
  });

  String get price => '${_formatPrice(priceDA)} DA';

  static String _formatPrice(int price) {
    final s = price.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  factory SubscriptionPlan.fromFirestore(Map<String, dynamic> data, String docId) {
    final hex = (data['colorHex'] as String? ?? '#5483B3').replaceAll('#', '');
    Color color;
    try {
      color = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      color = const Color(0xFF5483B3);
    }
    return SubscriptionPlan(
      id: docId,
      name: data['name'] as String? ?? docId,
      priceDA: (data['priceDA'] as num?)?.toInt() ?? 0,
      maxBuses: (data['maxBuses'] as num?)?.toInt() ?? 0,
      durationDays: (data['durationDays'] as num?)?.toInt() ?? 30,
      features: List<String>.from(data['features'] ?? []),
      color: color,
      recommended: data['recommended'] == true,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  // Fallback static list used while Firestore loads or if unavailable.
  static List<SubscriptionPlan> get defaults => [
        const SubscriptionPlan(
          id: 'starter',
          name: 'Starter',
          priceDA: 2000,
          maxBuses: 3,
          features: ['Jusqu\'à 3 bus', 'Suivi GPS basique', 'Support email'],
          color: Color(0xFF1565C0),
          order: 0,
        ),
        const SubscriptionPlan(
          id: 'pro',
          name: 'Pro',
          priceDA: 5000,
          maxBuses: 10,
          features: ['Jusqu\'à 10 bus', 'Suivi GPS avancé', 'Statistiques', 'Support prioritaire'],
          color: Color(0xFFF57C00),
          recommended: true,
          order: 1,
        ),
        const SubscriptionPlan(
          id: 'enterprise',
          name: 'Enterprise',
          priceDA: 10000,
          maxBuses: 0,
          features: ['Bus illimités', 'Suivi GPS en temps réel', 'Tableau de bord avancé', 'API access', 'Support 24/7'],
          color: Color(0xFF2E7D32),
          order: 2,
        ),
      ];
}
