/// ticket_card_shape.dart
///
/// Two reusable ticket-shaped card widgets:
///
///  • [TicketCardShape]   — notches on left & right + dashed divider line
///  • [TicketCutoutCard] — half-circle notches on ALL FOUR sides (shape only)
///
/// Both are fully theme-aware (dark / light). No hardcoded colors.
///
/// Created:       2026-04-29
/// Author:        AI (Antigravity)
/// Last Modified: 2026-04-29

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1.  TICKET CARD SHAPE — left & right notches + dashed divider
// ═════════════════════════════════════════════════════════════════════════════

/// A ticket-shaped card with:
/// - Rounded outer corners
/// - Semi-circular notches cut from the **left & right** edges
/// - A dashed separator line between the header and body zones
/// - Soft elevation shadow that respects dark / light mode
///
/// Usage:
/// ```dart
/// TicketCardShape(
///   child: YourContentHere(),
/// )
/// ```
class TicketCardShape extends StatelessWidget {
  final Widget child;
  final double horizontalPadding;
  final EdgeInsetsGeometry contentPadding;
  final double borderRadius;
  final double notchRadius;

  /// 0 = top of card, 1 = bottom. Dashed line is drawn here.
  final double dividerFraction;
  final int dashCount;

  const TicketCardShape({
    super.key,
    required this.child,
    this.horizontalPadding = 16,
    this.contentPadding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
    this.borderRadius = 20,
    this.notchRadius = 13,
    this.dividerFraction = 0.30,
    this.dashCount = 14,
  });

  @override
  Widget build(BuildContext context) {
    final bg = context.appCardBg;
    final shadowColor = context.isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.12);

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 6),
      child: CustomPaint(
        painter: _SideCutoutPainter(
          backgroundColor: bg,
          shadowColor: shadowColor,
          borderRadius: borderRadius,
          notchRadius: notchRadius,
          dividerFraction: dividerFraction,
          dashCount: dashCount,
          dashColor: context.appBorder,
          isDark: context.isDark,
        ),
        child: Padding(padding: contentPadding, child: child),
      ),
    );
  }
}

class _SideCutoutPainter extends CustomPainter {
  final Color backgroundColor;
  final Color shadowColor;
  final Color dashColor;
  final double borderRadius;
  final double notchRadius;
  final double dividerFraction;
  final int dashCount;
  final bool isDark;

  const _SideCutoutPainter({
    required this.backgroundColor,
    required this.shadowColor,
    required this.dashColor,
    required this.borderRadius,
    required this.notchRadius,
    required this.dividerFraction,
    required this.dashCount,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final nr = notchRadius;
    final divY = h * dividerFraction;
    final path = _buildPath(w, h, r, nr, divY);

    canvas.drawShadow(path, shadowColor, isDark ? 6 : 5, true);
    canvas.drawPath(path, Paint()..color = backgroundColor);
    _drawDashes(canvas, w, divY, nr);
  }

  Path _buildPath(double w, double h, double r, double nr, double divY) {
    final p = Path();
    p.moveTo(r, 0);
    // top edge + top-right corner
    p.lineTo(w - r, 0);
    p.arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true);
    // right edge: top → notch → bottom
    p.lineTo(w, divY - nr);
    p.arcToPoint(Offset(w, divY + nr),
        radius: Radius.circular(nr), clockwise: false);
    p.lineTo(w, h - r);
    // bottom-right corner + bottom edge
    p.arcToPoint(Offset(w - r, h),
        radius: Radius.circular(r), clockwise: true);
    p.lineTo(r, h);
    // bottom-left corner
    p.arcToPoint(Offset(0, h - r),
        radius: Radius.circular(r), clockwise: true);
    // left edge: bottom → notch → top
    p.lineTo(0, divY + nr);
    p.arcToPoint(Offset(0, divY - nr),
        radius: Radius.circular(nr), clockwise: false);
    p.lineTo(0, r);
    // top-left corner
    p.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);
    p.close();
    return p;
  }

  void _drawDashes(Canvas canvas, double w, double y, double nr) {
    final paint = Paint()
      ..color = dashColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final startX = nr * 2;
    final endX = w - nr * 2;
    final total = endX - startX;
    final seg = total / (dashCount * 2 - 1);
    for (int i = 0; i < dashCount; i++) {
      final dx = startX + i * (seg * 2);
      canvas.drawLine(Offset(dx, y), Offset(dx + seg, y), paint);
    }
  }

  @override
  bool shouldRepaint(_SideCutoutPainter o) =>
      o.backgroundColor != backgroundColor || o.isDark != isDark;
}

// ═════════════════════════════════════════════════════════════════════════════
// 2.  TICKET CUTOUT CARD — half-circle notches on ALL FOUR sides (shape only)
// ═════════════════════════════════════════════════════════════════════════════

/// A pure card-shape widget with semi-circular cutouts on **left, right,
/// top, and bottom** edges — like a punched coupon / stamp.
///
/// Renders ONLY the shape. Drop any [child] inside to add content.
/// Fully theme-aware; no hardcoded colors.
///
/// Usage:
/// ```dart
/// TicketCutoutCard(
///   child: YourContentHere(),
/// )
/// ```
class TicketCutoutCard extends StatelessWidget {
  /// Widget rendered inside the card shape.
  final Widget child;

  /// Padding between the card edges and [child].
  final EdgeInsetsGeometry contentPadding;

  /// Corner rounding radius of the outer border.
  final double borderRadius;

  /// Radius of each half-circle notch (same for all four sides).
  final double notchRadius;

  /// Optional explicit background color. Falls back to [ThemeColors.appCardBg].
  final Color? backgroundColor;

  const TicketCutoutCard({
    super.key,
    required this.child,
    this.contentPadding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.notchRadius = 12,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.appCardBg;
    final shadowColor = context.isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.13);

    return CustomPaint(
      painter: _FourCutoutPainter(
        backgroundColor: bg,
        shadowColor: shadowColor,
        borderRadius: borderRadius,
        notchRadius: notchRadius,
      ),
      child: Padding(padding: contentPadding, child: child),
    );
  }
}

class _FourCutoutPainter extends CustomPainter {
  final Color backgroundColor;
  final Color shadowColor;
  final double borderRadius;
  final double notchRadius;

  const _FourCutoutPainter({
    required this.backgroundColor,
    required this.shadowColor,
    required this.borderRadius,
    required this.notchRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    canvas.drawShadow(path, shadowColor, 6, true);
    canvas.drawPath(path, Paint()..color = backgroundColor);
  }

  /// Builds a rounded-rectangle path with one inward half-circle notch
  /// centred on each of the four sides.
  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final nr = notchRadius;

    final cx = w / 2; // centre X for top & bottom notches
    final cy = h / 2; // centre Y for left & right notches

    final p = Path();

    // ── Start just after top-left corner ─────────────────────────────────────
    p.moveTo(r, 0);

    // ── Top edge: left segment → notch (arc goes DOWN = inward) → right segment
    p.lineTo(cx - nr, 0);
    p.arcToPoint(Offset(cx + nr, 0),
        radius: Radius.circular(nr), clockwise: false);
    p.lineTo(w - r, 0);

    // ── Top-right corner ──────────────────────────────────────────────────────
    p.arcToPoint(Offset(w, r),
        radius: Radius.circular(r), clockwise: true);

    // ── Right edge: top segment → notch (arc goes LEFT = inward) → bottom segment
    p.lineTo(w, cy - nr);
    p.arcToPoint(Offset(w, cy + nr),
        radius: Radius.circular(nr), clockwise: false);
    p.lineTo(w, h - r);

    // ── Bottom-right corner ───────────────────────────────────────────────────
    p.arcToPoint(Offset(w - r, h),
        radius: Radius.circular(r), clockwise: true);

    // ── Bottom edge: right segment → notch (arc goes UP = inward) → left segment
    p.lineTo(cx + nr, h);
    p.arcToPoint(Offset(cx - nr, h),
        radius: Radius.circular(nr), clockwise: false);
    p.lineTo(r, h);

    // ── Bottom-left corner ────────────────────────────────────────────────────
    p.arcToPoint(Offset(0, h - r),
        radius: Radius.circular(r), clockwise: true);

    // ── Left edge: bottom segment → notch (arc goes RIGHT = inward) → top segment
    p.lineTo(0, cy + nr);
    p.arcToPoint(Offset(0, cy - nr),
        radius: Radius.circular(nr), clockwise: false);
    p.lineTo(0, r);

    // ── Top-left corner ───────────────────────────────────────────────────────
    p.arcToPoint(Offset(r, 0),
        radius: Radius.circular(r), clockwise: true);

    p.close();
    return p;
  }

  @override
  bool shouldRepaint(_FourCutoutPainter o) =>
      o.backgroundColor != backgroundColor || o.notchRadius != notchRadius;
}
