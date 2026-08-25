import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Direction the user is being asked to turn their head.
enum HeadDirection { none, left, right, up, down }

class FaceGuideOverlay extends StatelessWidget {
  const FaceGuideOverlay({
    super.key,
    required this.ok,
    this.activeDirection = HeadDirection.none,
    this.completedDirections = const {},
  });

  final bool ok;
  final HeadDirection activeDirection;
  final Set<HeadDirection> completedDirections;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CircleGuidePainter(
        color: ok ? AppColors.success : Colors.white,
        activeDirection: activeDirection,
        completedDirections: completedDirections,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CircleGuidePainter extends CustomPainter {
  _CircleGuidePainter({
    required this.color,
    required this.activeDirection,
    required this.completedDirections,
  });

  final Color color;
  final HeadDirection activeDirection;
  final Set<HeadDirection> completedDirections;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width * 0.76, size.height * 0.52);
    final center = Offset(size.width / 2, size.height * 0.40);
    final radius = diameter / 2;

    final circlePath = Path()..addOval(
      Rect.fromCircle(center: center, radius: radius),
    );
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addPath(circlePath, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    const directions = [
      HeadDirection.left,
      HeadDirection.up,
      HeadDirection.right,
      HeadDirection.down,
    ];
    const angles = [-math.pi, -math.pi / 2, 0, math.pi / 2];
    const icons = [Icons.chevron_left, Icons.expand_less, Icons.chevron_right, Icons.expand_more];

    for (var i = 0; i < directions.length; i++) {
      final dir = directions[i];
      final angle = angles[i];
      final isActive = activeDirection == dir;
      final isDone = completedDirections.contains(dir);

      final iconCenter = Offset(
        center.dx + (radius + 22) * math.cos(angle),
        center.dy + (radius + 22) * math.sin(angle),
      );

      final dotColor = isDone
          ? AppColors.success
          : isActive
              ? AppColors.accent
              : Colors.white38;

      canvas.drawCircle(
        iconCenter,
        14,
        Paint()..color = dotColor.withValues(alpha: isDone ? 0.85 : isActive ? 0.8 : 0.3),
      );

      final iconData = isDone ? Icons.check : icons[i];
      final builder = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            fontSize: isDone ? 16 : 20,
            color: isDone ? Colors.white : (isActive ? Colors.white : Colors.white54),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      builder.paint(
        canvas,
        iconCenter - Offset(builder.width / 2, builder.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircleGuidePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.activeDirection != activeDirection ||
      oldDelegate.completedDirections != completedDirections;
}
