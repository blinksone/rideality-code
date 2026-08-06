import 'dart:io';

import 'package:flutter/material.dart';

import '../services/image_picker_service.dart';
import '../theme/app_colors.dart';

class ProfilePhotoPicker extends StatelessWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.image,
    required this.onPick,
    this.isUploading = false,
  });

  final PickedImageFile? image;
  final VoidCallback onPick;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = image != null;

    return GestureDetector(
      onTap: isUploading ? null : onPick,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                painter: hasPhoto ? null : _DashedCirclePainter(
                  color: AppColors.outlineVariant,
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasPhoto
                        ? Colors.transparent
                        : AppColors.surfaceContainerLowest,
                    border: hasPhoto
                        ? Border.all(color: AppColors.secondary, width: 2)
                        : null,
                    image: hasPhoto
                        ? DecorationImage(
                            image: FileImage(File(image!.file.path)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasPhoto
                      ? null
                      : const Icon(
                          Icons.add_a_photo_outlined,
                          size: 36,
                          color: AppColors.outline,
                        ),
                ),
              ),
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'UPLOAD PROFILE PHOTO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final radius = size.width / 2;
    const dash = 5.0;
    const gap = 4.0;
    final circumference = 2 * 3.141592653589793 * radius;
    final count = (circumference / (dash + gap)).floor();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    for (var i = 0; i < count; i++) {
      final start = (i * (dash + gap)) / radius;
      final sweep = dash / radius;
      canvas.drawArc(rect, start - 1.5708, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
