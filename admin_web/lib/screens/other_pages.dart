import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/admin_service.dart';

// ══════════════════════════════════════
// BUSES PAGE
// ══════════════════════════════════════
class BusesPage extends StatelessWidget {
  const BusesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tous les bus', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
      const SizedBox(height: 6),
      const Text('Liste de tous les bus enregistrés dans le système.', style: TextStyle(color: AppColors.sub, fontSize: 13)),
      const SizedBox(height: 24),
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AdminService.getAllBuses(),
        builder: (_, snap) {
          final buses = snap.data ?? [];
          if (buses.isEmpty) return const Center(child: Text('Aucun bus', style: TextStyle(color: AppColors.sub)));
          return ListView.builder(itemCount: buses.length, itemBuilder: (_, i) {
            final b = buses[i];
            final status = b['driverStatus'] ?? 'offline';
            final statusColor = status == 'on_trip' ? AppColors.green : status == 'online' ? AppColors.blue : AppColors.sub;
            final statusText = status == 'on_trip' ? 'En trajet' : status == 'online' ? 'En ligne' : 'Hors ligne';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.directions_bus, color: AppColors.navy, size: 20)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b['lineName'] ?? '--', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                  Text('${b['busName'] ?? ''} ${b['busNumber'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                    color: statusColor.withValues(alpha: 0.1), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                  child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor))),
                const SizedBox(width: 10),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                    color: ((b['isActive'] ?? true) ? AppColors.green : AppColors.sub).withValues(alpha: 0.1)),
                  child: Text((b['isActive'] ?? true) ? 'Actif' : 'Inactif',
                    style: TextStyle(fontSize: 10, color: (b['isActive'] ?? true) ? AppColors.green : AppColors.sub))),
              ]),
            );
          });
        },
      )),
    ]));
  }
}

// ══════════════════════════════════════
// BOOKINGS PAGE
// ══════════════════════════════════════
class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Réservations', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
      const SizedBox(height: 6),
      const Text('Toutes les réservations des voyageurs.', style: TextStyle(color: AppColors.sub, fontSize: 13)),
      const SizedBox(height: 24),
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AdminService.getBookings(),
        builder: (_, snap) {
          final bookings = snap.data ?? [];
          if (bookings.isEmpty) return const Center(child: Text('Aucune réservation', style: TextStyle(color: AppColors.sub)));
          return ListView.builder(itemCount: bookings.length, itemBuilder: (_, i) {
            final b = bookings[i];
            final status = b['status'] ?? 'pending';
            final statusColor = status == 'confirmed' ? AppColors.green : status == 'pending' ? AppColors.orange : AppColors.red;
            final date = (b['createdAt'] as Timestamp?)?.toDate();
            final dateStr = date != null ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : '--';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.bookmark, color: AppColors.blue, size: 20)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b['passengerName'] ?? 'Passager inconnu', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                  Text('${b['lineName'] ?? '--'} · ${b['busName'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                ])),
                Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                const SizedBox(width: 10),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                    color: statusColor.withValues(alpha: 0.1), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                  child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor))),
              ]),
            );
          });
        },
      )),
    ]));
  }
}

// ══════════════════════════════════════
// STATS PAGE
// ══════════════════════════════════════
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Statistiques', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
      const SizedBox(height: 6),
      const Text('Analyse de l\'activité du système.', style: TextStyle(color: AppColors.sub, fontSize: 13)),
      const SizedBox(height: 32),
      // Most popular lines
      const Text('Lignes les plus populaires', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.dark)),
      const SizedBox(height: 14),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: AdminService.getBookings(),
        builder: (_, snap) {
          final bookings = snap.data ?? [];
          final lineCount = <String, int>{};
          for (final b in bookings) { final l = b['lineName'] ?? 'Inconnu'; lineCount[l] = (lineCount[l] ?? 0) + 1; }
          final sorted = lineCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          if (sorted.isEmpty) return const Text('Pas de données', style: TextStyle(color: AppColors.sub));
          return Column(children: sorted.take(10).map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.route, color: AppColors.navy, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.dark))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('${e.value} réservations', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy))),
            ]),
          )).toList());
        },
      ),
    ]));
  }
}

// ══════════════════════════════════════
// INCIDENTS PAGE
// ══════════════════════════════════════
class IncidentsPage extends StatelessWidget {
  const IncidentsPage({super.key});

  String _typeLabel(String type) {
    switch (type) {
      case 'accident': return '🚗 Accident';
      case 'delay': return '⏱ Retard';
      case 'mechanical': return '🔧 Panne';
      case 'road_blocked': return '🚧 Route bloquée';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Incidents', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
      const SizedBox(height: 6),
      const Text('Tous les incidents signalés par les chauffeurs.', style: TextStyle(color: AppColors.sub, fontSize: 13)),
      const SizedBox(height: 24),
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AdminService.getIncidents(),
        builder: (_, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty) return const Center(child: Text('Aucun incident', style: TextStyle(color: AppColors.sub)));
          return ListView.builder(itemCount: items.length, itemBuilder: (_, i) {
            final inc = items[i];
            final resolved = inc['resolved'] == true;
            final ts = (inc['timestamp'] as Timestamp?)?.toDate();
            final date = ts != null ? '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}' : '--';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: (resolved ? AppColors.green : AppColors.red).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(resolved ? Icons.check_circle : Icons.warning, color: resolved ? AppColors.green : AppColors.red, size: 20)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_typeLabel(inc['type'] ?? ''), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                  Text('${inc['lineName'] ?? '--'} · $date', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                  if (inc['message'] != null) Text(inc['message'], style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                    color: (resolved ? AppColors.green : AppColors.orange).withValues(alpha: 0.1),
                    border: Border.all(color: (resolved ? AppColors.green : AppColors.orange).withValues(alpha: 0.3))),
                  child: Text(resolved ? 'Résolu' : 'Non résolu',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: resolved ? AppColors.green : AppColors.orange))),
                if (!resolved) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => AdminService.resolveIncident(inc['id']),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Résoudre', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                ],
              ]),
            );
          });
        },
      )),
    ]));
  }
}
