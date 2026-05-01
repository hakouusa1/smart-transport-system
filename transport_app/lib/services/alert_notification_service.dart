import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_model.dart';
import '../constants.dart';
import '../app_settings_notifier.dart';
import 'notification_service.dart';

class AlertNotificationService {

  static Future<void> checkAndNotify({bool forceAll = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final snap = await FirebaseFirestore.instance
        .collection('buses')
        .where('ownerId', isEqualTo: uid)
        .get();

    final buses = snap.docs.map((d) => Bus.fromMap(d.data())).toList();

    for (final bus in buses) {
      final name = bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}';

      // ── Assurance (15 days) ────────────────────────────────────────────────
      if (bus.insuranceEndDate != null) {
        final days = bus.insuranceEndDate!.difference(now).inDays;
        if (days == kAssuranceThresholdDays) {
          final key = 'alert_assurance_${bus.busId}_$todayKey';
          if (forceAll || prefs.getBool(key) != true) {
            await NotificationService.showNotification(
              title: 'Assurance — $name',
              body: 'L\'assurance expire dans $kAssuranceThresholdDays jours.',
              id: 'assurance_${bus.busId}'.hashCode.abs() % 100000,
            );
            await prefs.setBool(key, true);
          }
        }
      }

      // ── Salary (3 days) ───────────────────────────────────────────────────
      final positions = <String>[];
      if (bus.driverId.isNotEmpty) positions.add('Chauffeur');
      if (bus.recipientSalary != null && bus.recipientSalary! > 0) {
        positions.add('Receveur');
      }

      if (positions.isNotEmpty) {
        DateTime nextSalary = DateTime(now.year, now.month + 1, 1);
        if (bus.lastSalaryDate != null &&
            now.difference(bus.lastSalaryDate!).inDays < 20) {
          nextSalary = DateTime(now.year, now.month + 2, 1);
        }
        final days = nextSalary.difference(now).inDays;
        if (days == kSalaryThresholdDays) {
          final key = 'alert_salary_${bus.busId}_$todayKey';
          if (forceAll || prefs.getBool(key) != true) {
            await NotificationService.showNotification(
              title: 'Salaires — $name',
              body:
                  'Les salaires (${positions.join(' & ')}) sont dans $kSalaryThresholdDays jours.',
              id: 'salary_${bus.busId}'.hashCode.abs() % 100000,
            );
            await prefs.setBool(key, true);
          }
        }
      }

      // ── Vidange (1000 km warn / 500 km urgent) ────────────────────────────
      Query query = FirebaseFirestore.instance
          .collection('trips')
          .where('busId', isEqualTo: bus.busId);
      if (bus.lastVidangeDate != null) {
        query = query.where('timestamp',
            isGreaterThan: Timestamp.fromDate(bus.lastVidangeDate!));
      }
      double traveled = 0.0;
      try {
        final agg = await query.aggregate(sum('distanceKm')).get();
        traveled = agg.getSum('distanceKm') ?? 0.0;
      } catch (_) {}

      final kmRemaining = (appSettingsNotifier.value.vidangeIntervalKm - traveled).toInt();

      if (kmRemaining <= kVidangeUrgentKm && kmRemaining > 0) {
        // 500 km urgent reminder
        final key = 'alert_vidange_urgent_${bus.busId}_$todayKey';
        if (forceAll || prefs.getBool(key) != true) {
          await NotificationService.showNotification(
            title: 'Vidange urgente — $name',
            body: 'Seulement $kmRemaining km avant la prochaine vidange !',
            id: 'vidange_urgent_${bus.busId}'.hashCode.abs() % 100000,
          );
          await prefs.setBool(key, true);
        }
      } else if (kmRemaining <= kVidangeWarnKm) {
        // 1000 km warning
        final key = 'alert_vidange_warn_${bus.busId}_$todayKey';
        if (forceAll || prefs.getBool(key) != true) {
          await NotificationService.showNotification(
            title: 'Vidange — $name',
            body: 'La vidange est dans $kmRemaining km.',
            id: 'vidange_warn_${bus.busId}'.hashCode.abs() % 100000,
          );
          await prefs.setBool(key, true);
        }
      }
    }
  }

  /// Fires one notification per bus with its real current values,
  /// ignoring all thresholds and the daily-seen cache.
  /// Only available in debug builds.
  static Future<void> testAll() async {
    if (!kDebugMode) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('buses')
        .where('ownerId', isEqualTo: uid)
        .get();

    final buses = snap.docs.map((d) => Bus.fromMap(d.data())).toList();

    if (buses.isEmpty) {
      await NotificationService.showNotification(
        title: 'Test alertes',
        body: 'Aucun bus trouvé pour ce compte.',
        id: 0,
      );
      return;
    }

    int id = 90000;
    for (final bus in buses) {
      final name = bus.busName.isNotEmpty ? bus.busName : 'Bus ${bus.busNumber}';
      final now  = DateTime.now();

      // Assurance
      final assuranceText = bus.insuranceEndDate != null
          ? 'expire dans ${bus.insuranceEndDate!.difference(now).inDays} jours'
          : 'date non renseignée';
      await NotificationService.showNotification(
        title: 'TEST — Assurance · $name',
        body: 'Assurance $assuranceText.',
        id: id++,
      );

      // Vidange
      Query query = FirebaseFirestore.instance
          .collection('trips')
          .where('busId', isEqualTo: bus.busId);
      if (bus.lastVidangeDate != null) {
        query = query.where('timestamp',
            isGreaterThan: Timestamp.fromDate(bus.lastVidangeDate!));
      }
      double traveled = 0.0;
      try {
        final agg = await query.aggregate(sum('distanceKm')).get();
        traveled = agg.getSum('distanceKm') ?? 0.0;
      } catch (_) {}
      final kmRemaining = (appSettingsNotifier.value.vidangeIntervalKm - traveled).toInt();
      await NotificationService.showNotification(
        title: 'TEST — Vidange · $name',
        body: 'Il reste $kmRemaining km avant la prochaine vidange.',
        id: id++,
      );

      // Salary
      final positions = <String>[];
      if (bus.driverId.isNotEmpty) positions.add('Chauffeur');
      if (bus.recipientSalary != null && bus.recipientSalary! > 0) {
        positions.add('Receveur');
      }
      if (positions.isNotEmpty) {
        DateTime nextSalary = DateTime(now.year, now.month + 1, 1);
        if (bus.lastSalaryDate != null &&
            now.difference(bus.lastSalaryDate!).inDays < 20) {
          nextSalary = DateTime(now.year, now.month + 2, 1);
        }
        final days = nextSalary.difference(now).inDays;
        await NotificationService.showNotification(
          title: 'TEST — Salaires · $name',
          body:
              'Salaires (${positions.join(' & ')}) dans $days jours.',
          id: id++,
        );
      }
    }
  }
}
