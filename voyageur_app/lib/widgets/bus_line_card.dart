import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../theme/app_theme.dart';
import 'trip_thumbnail.dart';

class BusLineCard extends StatelessWidget {
  final Bus bus;
  final VoidCallback onTap;

  const BusLineCard({super.key, required this.bus, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = bus.isOnTrip
        ? context.appGreen
        : bus.isOnline
            ? context.appPrimary
            : context.appSub;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Bus icon with status color
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_bus, size: 28, color: statusColor),
              ),
              const SizedBox(width: 14),

              // Bus info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.lineName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: context.appText,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 14, color: context.appSub),
                        const SizedBox(width: 4),
                        Text(
                          bus.busName,
                          style: TextStyle(color: context.appSub, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            bus.statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Trip thumbnail + arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (bus.isOnTrip)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.appGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  TripThumbnail(bus: bus),
                  const SizedBox(height: 4),
                  Icon(Icons.arrow_forward_ios, size: 14, color: context.appBorder),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
