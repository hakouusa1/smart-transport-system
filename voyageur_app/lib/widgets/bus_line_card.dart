import 'package:flutter/material.dart';
import '../models/bus_model.dart';

class BusLineCard extends StatelessWidget {
  final Bus bus;
  final VoidCallback onTap;

  const BusLineCard({
    super.key,
    required this.bus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Bus icon with status color
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bus.isOnTrip
                      ? Colors.green.withValues(alpha: 0.1)
                      : bus.isOnline
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_bus,
                  size: 28,
                  color: bus.isOnTrip
                      ? Colors.green
                      : bus.isOnline
                          ? Colors.blue
                          : Colors.grey,
                ),
              ),
              const SizedBox(width: 14),

              // Bus info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line name
                    Text(
                      bus.lineName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Driver name
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          bus.busName,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bus.isOnTrip
                            ? Colors.green.shade50
                            : bus.isOnline
                                ? Colors.blue.shade50
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: bus.isOnTrip
                              ? Colors.green.shade200
                              : bus.isOnline
                                  ? Colors.blue.shade200
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: bus.isOnTrip
                                  ? Colors.green
                                  : bus.isOnline
                                      ? Colors.blue
                                      : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            bus.statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: bus.isOnTrip
                                  ? Colors.green.shade700
                                  : bus.isOnline
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow + live indicator
              Column(
                children: [
                  if (bus.isOnTrip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
