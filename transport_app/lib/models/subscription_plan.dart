import 'package:flutter/material.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String price;
  final List<String> features;
  final Color color;
  final bool recommended;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.features,
    required this.color,
    this.recommended = false,
  });

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      id: 'starter',
      name: 'Starter',
      price: '2 000 DA',
      features: ['Jusqu\'à 3 bus', 'Suivi GPS basique', 'Support email'],
      color: Color(0xFF1565C0),
    ),
    SubscriptionPlan(
      id: 'pro',
      name: 'Pro',
      price: '5 000 DA',
      features: ['Jusqu\'à 10 bus', 'Suivi GPS avancé', 'Statistiques', 'Support prioritaire'],
      color: Color(0xFFF57C00),
      recommended: true,
    ),
    SubscriptionPlan(
      id: 'enterprise',
      name: 'Enterprise',
      price: '10 000 DA',
      features: ['Bus illimités', 'Suivi GPS en temps réel', 'Tableau de bord avancé', 'API access', 'Support 24/7'],
      color: Color(0xFF2E7D32),
    ),
  ];

  static SubscriptionPlan getById(String id) {
    return plans.firstWhere((p) => p.id == id, orElse: () => plans.first);
  }
}
