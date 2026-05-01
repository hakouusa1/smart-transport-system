import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class BusTripCard extends StatelessWidget {
  final BusTrip trip;
  final double? basePrice;
  final bool isOnTrip;
  final VoidCallback? onTap;

  const BusTripCard({
    super.key,
    required this.trip,
    this.basePrice,
    this.isOnTrip = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bus = trip.bus;
    final tr = context.tr;
    final timeStr = trip.scheduleTime ?? bus.nextScheduleTime ?? '--:--';
    final dotColor = context.appGreen;

    final iconColors = [
      context.appPrimary,
      context.appOrange,
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];
    final colorIndex = (bus.busName + bus.busNumber).hashCode.abs() % iconColors.length;
    final busIconColor = iconColors[colorIndex];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.appCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOnTrip ? tr.onTripDot : tr.upcomingDot,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dotColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800,
                    color: context.appText, height: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.displayLineName,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appText),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    bus.busName.isNotEmpty ? bus.busName : 'N° ${bus.busNumber}',
                    style: TextStyle(fontSize: 11, color: context.appSub),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  BusPriceChip(price: basePrice),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: busIconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_bus_rounded, color: busIconColor, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class BusPriceChip extends StatelessWidget {
  final double? price;
  const BusPriceChip({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final label = price != null ? '${price!.toStringAsFixed(0)} ${tr.currencyDA}' : '---';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.appGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.payments_outlined, size: 12, color: context.appGreen),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.appGreen),
        ),
      ]),
    );
  }
}
