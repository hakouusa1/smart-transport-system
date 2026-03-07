import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: config.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getConfig(String status) {
    switch (status) {
      case 'online':
        return _StatusConfig(label: 'En ligne', color: Colors.green);
      case 'on_trip':
        return _StatusConfig(label: 'En trajet', color: Colors.blue);
      case 'offline':
      default:
        return _StatusConfig(label: 'Hors ligne', color: Colors.grey);
    }
  }
}

class _StatusConfig {
  final String label;
  final Color color;

  _StatusConfig({required this.label, required this.color});
}
