import 'package:flutter/material.dart';
import '../models/bus_model.dart';

/// A fully static canvas thumbnail showing the trip line + bus position.
/// No map tiles — renders instantly with no loading state.
class TripThumbnail extends StatelessWidget {
  final Bus bus;
  final double width;
  final double height;

  const TripThumbnail({
    super.key,
    required this.bus,
    this.width = 90,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2A3A) : const Color(0xFFE8F0FC);
    final lineColor = isDark ? const Color(0xFF1154A8) : const Color(0xFF1565C0);
    final dotColor = isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
    final busColor = bus.isOnTrip
        ? (isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32))
        : (isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0));
    final labelColor = isDark ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);

    // Parse city names from lineName (e.g. "Alger - Bouira")
    final parts = bus.lineName.split(RegExp(r'\s*[-–→]\s*'));
    final fromCity = parts.isNotEmpty ? _shortCity(parts.first) : 'A';
    final toCity = parts.length > 1 ? _shortCity(parts.last) : 'B';

    // Bus progress ratio along the line (0.0 → 1.0)
    double busRatio = 0.5;
    // busRatio stays 0.5 — thumbnail shows static midpoint, no live pos needed

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CustomPaint(
        size: Size(width, height),
        painter: _TripPainter(
          fromCity: fromCity,
          toCity: toCity,
          busRatio: busRatio,
          isOnTrip: bus.isOnTrip,
          bgColor: bgColor,
          lineColor: lineColor,
          dotColor: dotColor,
          busColor: busColor,
          labelColor: labelColor,
        ),
      ),
    );
  }

  String _shortCity(String name) {
    final trimmed = name.trim();
    // Keep max 6 chars so it fits
    return trimmed.length > 6 ? trimmed.substring(0, 6) : trimmed;
  }
}

class _TripPainter extends CustomPainter {
  final String fromCity;
  final String toCity;
  final double busRatio;
  final bool isOnTrip;
  final Color bgColor;
  final Color lineColor;
  final Color dotColor;
  final Color busColor;
  final Color labelColor;

  const _TripPainter({
    required this.fromCity,
    required this.toCity,
    required this.busRatio,
    required this.isOnTrip,
    required this.bgColor,
    required this.lineColor,
    required this.dotColor,
    required this.busColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = bgColor,
    );

    // Road-like grid lines (subtle)
    final gridPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double y = 8; y < h; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final centerY = h * 0.52;
    const padX = 14.0;
    final startX = padX;
    final endX = w - padX;

    // Dashed background track
    final trackPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.18)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    _drawDashed(canvas, Offset(startX, centerY), Offset(endX, centerY), trackPaint, 4, 4);

    // Solid line (done portion up to bus)
    final donePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final busX = startX + (endX - startX) * busRatio.clamp(0.0, 1.0);
    canvas.drawLine(Offset(startX, centerY), Offset(busX, centerY), donePaint);

    // Departure dot
    canvas.drawCircle(Offset(startX, centerY), 4, Paint()..color = dotColor);
    canvas.drawCircle(Offset(startX, centerY), 2.5, Paint()..color = bgColor);

    // Arrival dot
    canvas.drawCircle(Offset(endX, centerY), 4, Paint()..color = dotColor.withValues(alpha: 0.45));
    canvas.drawCircle(Offset(endX, centerY), 2.5, Paint()..color = bgColor);

    // Bus icon circle
    final busPaint = Paint()..color = busColor;
    canvas.drawCircle(Offset(busX, centerY), 7, busPaint);
    // Mini bus symbol — just a white rect
    final iconRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(busX, centerY), width: 8, height: 6),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(iconRect, Paint()..color = Colors.white);
    // Wheels
    canvas.drawCircle(Offset(busX - 2.5, centerY + 3.5), 1.2, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(busX + 2.5, centerY + 3.5), 1.2, Paint()..color = Colors.white);

    // City labels
    _drawLabel(canvas, fromCity, Offset(startX, centerY + 11), labelColor);
    _drawLabel(canvas, toCity, Offset(endX, centerY + 11), labelColor, align: TextAlign.right);
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint, double dashLen, double gapLen) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final total = (dx * dx + dy * dy);
    if (total == 0) return;
    final len = total.abs() < 1e-9 ? 0.0 : (dx.abs() > dy.abs() ? dx.abs() : dy.abs());
    final norm = Offset(dx / len, dy / len);
    double traveled = 0;
    bool drawing = true;
    Offset pos = start;
    while (traveled < len) {
      final step = drawing ? dashLen : gapLen;
      final next = traveled + step > len ? len - traveled : step;
      final nextPos = Offset(pos.dx + norm.dx * next, pos.dy + norm.dy * next);
      if (drawing) canvas.drawLine(pos, nextPos, paint);
      pos = nextPos;
      traveled += step;
      drawing = !drawing;
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color, {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w600),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 36);

    final dx = align == TextAlign.right ? position.dx - tp.width : position.dx - tp.width / 2;
    tp.paint(canvas, Offset(dx, position.dy));
  }

  @override
  bool shouldRepaint(_TripPainter old) =>
      old.busRatio != busRatio || old.isOnTrip != isOnTrip || old.fromCity != fromCity;
}
