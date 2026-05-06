import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/admin_service.dart';

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    final pad = isMobile ? 16.0 : 28.0;

    return Padding(padding: EdgeInsets.all(pad), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Réservations', style: TextStyle(fontSize: isMobile ? 20 : 26, fontWeight: FontWeight.w700, color: AppColors.dark)),
      const SizedBox(height: 6),
      const Text('Toutes les réservations des voyageurs.', style: TextStyle(color: AppColors.sub, fontSize: 13)),
      const SizedBox(height: 20),
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

            if (isMobile) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.bookmark, color: AppColors.blue, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(b['passengerName'] ?? 'Passager inconnu',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                        color: statusColor.withValues(alpha: 0.1), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor))),
                  ]),
                  const SizedBox(height: 8),
                  Text('${b['lineName'] ?? '--'} · ${b['busName'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                  const SizedBox(height: 4),
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                ]),
              );
            }

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
