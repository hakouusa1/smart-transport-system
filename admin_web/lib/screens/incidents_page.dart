import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/admin_service.dart';

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
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return Padding(padding: EdgeInsets.all(pad), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Incidents', style: TextStyle(fontSize: isMobile ? 20 : 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
      const SizedBox(height: 6),
      const Text('Tous les incidents signalés par les chauffeurs.', style: TextStyle(color: AppColors.sub, fontSize: 13)),
      const SizedBox(height: 20),
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

            if (isMobile) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: (resolved ? AppColors.green : AppColors.red).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(resolved ? Icons.check_circle : Icons.warning, color: resolved ? AppColors.green : AppColors.red, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_typeLabel(inc['type'] ?? ''), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                        color: (resolved ? AppColors.green : AppColors.orange).withValues(alpha: 0.1),
                        border: Border.all(color: (resolved ? AppColors.green : AppColors.orange).withValues(alpha: 0.3))),
                      child: Text(resolved ? 'Résolu' : 'Non résolu',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: resolved ? AppColors.green : AppColors.orange))),
                  ]),
                  const SizedBox(height: 8),
                  Text('${inc['lineName'] ?? '--'} · $date', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                  if (inc['message'] != null) ...[
                    const SizedBox(height: 4),
                    Text(inc['message'], style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                  ],
                  if (!resolved) ...[
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: () => AdminService.resolveIncident(inc['id']),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Résoudre', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(vertical: 10)),
                    )),
                  ],
                ]),
              );
            }

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
