import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/admin_service.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Statistiques',
            style: TextStyle(fontSize: isMobile ? 20 : 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
        const SizedBox(height: 6),
        const Text("Analyse de l'activité du système.",
            style: TextStyle(color: AppColors.sub, fontSize: 13)),
        const SizedBox(height: 24),
        const Text('Lignes les plus populaires',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.dark)),
        const SizedBox(height: 14),
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: AdminService.getBookings(),
          builder: (_, snap) {
            final bookings = snap.data ?? [];
            final lineCount = <String, int>{};
            for (final b in bookings) {
              final l = b['lineName'] ?? 'Inconnu';
              lineCount[l] = (lineCount[l] ?? 0) + 1;
            }
            final sorted = lineCount.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            if (sorted.isEmpty) {
              return const Center(
                  child: Text('Pas de données', style: TextStyle(color: AppColors.sub)));
            }
            return ListView(
              children: sorted.take(10).map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(isMobile ? 12 : 14),
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.route, color: AppColors.navy, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.key,
                      style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.dark),
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${e.value}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  ),
                ]),
              )).toList(),
            );
          },
        )),
      ]),
    );
  }
}
