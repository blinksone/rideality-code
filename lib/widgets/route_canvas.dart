import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Illustrated route canvas — dot grid + glowing path (not a street map).
class RouteCanvas extends StatelessWidget {
  const RouteCanvas({
    super.key,
    this.etaMinutes = 6,
    this.showBack = false,
    this.onBack,
    this.compact = false,
  });

  final int etaMinutes;
  final bool showBack;
  final VoidCallback? onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(
          painter: _RouteCanvasPainter(),
          child: SizedBox.expand(),
        ),
        // Soft vignette so sheet content reads cleanly.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x330B1220),
                Color(0x000B1220),
                Color(0xE60B1220),
              ],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        if (showBack && onBack != null)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: AppColors.surfaceContainerLowest.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onBack,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.onSurface,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // ETA callout near route midpoint
        Positioned(
          left: 0,
          right: 0,
          top: compact ? 72 : 120,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                '$etaMinutes min',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteCanvasPainter extends CustomPainter {
  const _RouteCanvasPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Base
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.canvasDark,
    );

    // Subtle radial wash
    final wash = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.55, size.height * 0.38),
        size.shortestSide * 0.7,
        [
          AppColors.accent.withValues(alpha: 0.14),
          Colors.transparent,
        ],
      );
    canvas.drawRect(Offset.zero & size, wash);

    // Dot grid
    final dotPaint = Paint()
      ..color = AppColors.canvasDot.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    const step = 18.0;
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.15, dotPaint);
      }
    }

    // Route path points (abstract, not geo-projected)
    final p0 = Offset(size.width * 0.22, size.height * 0.62);
    final p1 = Offset(size.width * 0.42, size.height * 0.38);
    final p2 = Offset(size.width * 0.68, size.height * 0.46);
    final p3 = Offset(size.width * 0.82, size.height * 0.28);

    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(
        p0.dx + 40,
        p0.dy - 30,
        p1.dx - 20,
        p1.dy + 20,
        p1.dx,
        p1.dy,
      )
      ..cubicTo(
        p1.dx + 36,
        p1.dy - 24,
        p2.dx - 24,
        p2.dy + 12,
        p2.dx,
        p2.dy,
      )
      ..cubicTo(
        p2.dx + 28,
        p2.dy - 10,
        p3.dx - 16,
        p3.dy + 16,
        p3.dx,
        p3.dy,
      );

    // Glow under route
    final glow = Paint()
      ..color = AppColors.accentMuted.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(path, glow);

    // Gradient stroke
    final metrics = path.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      final extract = metric.extractPath(0, metric.length);
      final line = Paint()
        ..shader = ui.Gradient.linear(
          p0,
          p3,
          [
            AppColors.accentSoft,
            AppColors.accent,
            AppColors.accentMuted,
          ],
          const [0, 0.55, 1],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(extract, line);
    }

    // Pickup — filled accent circle
    _drawMarker(canvas, p0, pickup: true);
    // Dropoff — pin shape
    _drawMarker(canvas, p3, pickup: false);
  }

  void _drawMarker(Canvas canvas, Offset c, {required bool pickup}) {
    if (pickup) {
      canvas.drawCircle(
        c,
        14,
        Paint()..color = AppColors.accent.withValues(alpha: 0.28),
      );
      canvas.drawCircle(
        c,
        8,
        Paint()..color = AppColors.accent,
      );
      canvas.drawCircle(
        c,
        3.5,
        Paint()..color = Colors.white,
      );
      return;
    }

    // Dropoff pin
    final pinPath = Path()
      ..moveTo(c.dx, c.dy + 14)
      ..quadraticBezierTo(c.dx - 12, c.dy + 2, c.dx - 12, c.dy - 6)
      ..arcToPoint(
        Offset(c.dx + 12, c.dy - 6),
        radius: const Radius.circular(12),
        clockwise: true,
      )
      ..quadraticBezierTo(c.dx + 12, c.dy + 2, c.dx, c.dy + 14)
      ..close();
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      Offset(c.dx, c.dy - 6),
      4,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Flat vehicle glyphs — one consistent line style for the confirm screen.
class VehicleGlyph extends StatelessWidget {
  const VehicleGlyph({
    super.key,
    required this.kind,
    this.size = 40,
    this.color = AppColors.accent,
  });

  final VehicleGlyphKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VehicleGlyphPainter(kind: kind, color: color),
      ),
    );
  }
}

enum VehicleGlyphKind { bike, rickshaw, economy, cargo }

class _VehicleGlyphPainter extends CustomPainter {
  _VehicleGlyphPainter({required this.kind, required this.color});

  final VehicleGlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, size.width * 0.07)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final s = size.shortestSide;
    final o = Offset(size.width / 2, size.height / 2);

    switch (kind) {
      case VehicleGlyphKind.bike:
        // Two wheels + frame
        canvas.drawCircle(Offset(o.dx - s * 0.28, o.dy + s * 0.12), s * 0.16, stroke);
        canvas.drawCircle(Offset(o.dx + s * 0.28, o.dy + s * 0.12), s * 0.16, stroke);
        final frame = Path()
          ..moveTo(o.dx - s * 0.28, o.dy + s * 0.12)
          ..lineTo(o.dx - s * 0.05, o.dy - s * 0.12)
          ..lineTo(o.dx + s * 0.2, o.dy - s * 0.12)
          ..lineTo(o.dx + s * 0.28, o.dy + s * 0.12)
          ..moveTo(o.dx - s * 0.05, o.dy - s * 0.12)
          ..lineTo(o.dx + s * 0.02, o.dy + s * 0.12)
          ..moveTo(o.dx + s * 0.2, o.dy - s * 0.12)
          ..lineTo(o.dx + s * 0.08, o.dy - s * 0.28);
        canvas.drawPath(frame, stroke);
      case VehicleGlyphKind.rickshaw:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(o.dx + s * 0.05, o.dy - s * 0.02),
              width: s * 0.55,
              height: s * 0.38,
            ),
            Radius.circular(s * 0.08),
          ),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(o.dx + s * 0.05, o.dy - s * 0.02),
              width: s * 0.55,
              height: s * 0.38,
            ),
            Radius.circular(s * 0.08),
          ),
          stroke,
        );
        canvas.drawCircle(Offset(o.dx - s * 0.22, o.dy + s * 0.2), s * 0.12, stroke);
        canvas.drawCircle(Offset(o.dx + s * 0.22, o.dy + s * 0.2), s * 0.12, stroke);
        canvas.drawLine(
          Offset(o.dx - s * 0.22, o.dy - s * 0.02),
          Offset(o.dx - s * 0.38, o.dy + s * 0.05),
          stroke,
        );
      case VehicleGlyphKind.economy:
        // Simple sedan silhouette
        final body = Path()
          ..moveTo(o.dx - s * 0.38, o.dy + s * 0.05)
          ..lineTo(o.dx - s * 0.28, o.dy + s * 0.05)
          ..lineTo(o.dx - s * 0.18, o.dy - s * 0.14)
          ..lineTo(o.dx + s * 0.12, o.dy - s * 0.14)
          ..lineTo(o.dx + s * 0.28, o.dy + s * 0.05)
          ..lineTo(o.dx + s * 0.38, o.dy + s * 0.05)
          ..lineTo(o.dx + s * 0.38, o.dy + s * 0.16)
          ..lineTo(o.dx - s * 0.38, o.dy + s * 0.16)
          ..close();
        canvas.drawPath(body, fill);
        canvas.drawPath(body, stroke);
        canvas.drawCircle(Offset(o.dx - s * 0.2, o.dy + s * 0.16), s * 0.1, stroke);
        canvas.drawCircle(Offset(o.dx + s * 0.2, o.dy + s * 0.16), s * 0.1, stroke);
      case VehicleGlyphKind.cargo:
        // Compact pickup / box truck — same stroke language as economy
        final cab = Path()
          ..moveTo(o.dx - s * 0.38, o.dy + s * 0.08)
          ..lineTo(o.dx - s * 0.38, o.dy - s * 0.02)
          ..lineTo(o.dx - s * 0.22, o.dy - s * 0.16)
          ..lineTo(o.dx - s * 0.02, o.dy - s * 0.16)
          ..lineTo(o.dx - s * 0.02, o.dy + s * 0.08)
          ..close();
        final bed = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            o.dx - s * 0.02,
            o.dy - s * 0.18,
            s * 0.4,
            s * 0.26,
          ),
          Radius.circular(s * 0.04),
        );
        canvas.drawPath(cab, fill);
        canvas.drawPath(cab, stroke);
        canvas.drawRRect(bed, fill);
        canvas.drawRRect(bed, stroke);
        canvas.drawCircle(Offset(o.dx - s * 0.22, o.dy + s * 0.16), s * 0.1, stroke);
        canvas.drawCircle(Offset(o.dx + s * 0.22, o.dy + s * 0.16), s * 0.1, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _VehicleGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}
