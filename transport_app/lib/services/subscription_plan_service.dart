import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_plan.dart';

class SubscriptionPlanService {
  static final _db = FirebaseFirestore.instance;

  static Stream<List<SubscriptionPlan>> streamPlans() {
    return _db
        .collection('subscription_plans')
        .orderBy('order')
        .snapshots()
        .map((s) => s.docs.isEmpty
            ? SubscriptionPlan.defaults
            : s.docs.map((d) => SubscriptionPlan.fromFirestore(d.data(), d.id)).toList());
  }

  static Future<List<SubscriptionPlan>> fetchPlans() async {
    try {
      final snap = await _db.collection('subscription_plans').orderBy('order').get();
      if (snap.docs.isEmpty) return SubscriptionPlan.defaults;
      return snap.docs.map((d) => SubscriptionPlan.fromFirestore(d.data(), d.id)).toList();
    } catch (_) {
      return SubscriptionPlan.defaults;
    }
  }

  static Future<SubscriptionPlan> fetchById(String planId) async {
    try {
      final plans = await fetchPlans();
      return plans.firstWhere(
        (p) => p.id == planId || p.name.toLowerCase() == planId.toLowerCase(),
        orElse: () => plans.isNotEmpty ? plans.first : SubscriptionPlan.defaults.first,
      );
    } catch (_) {
      return SubscriptionPlan.defaults.first;
    }
  }
}
