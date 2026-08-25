import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Shared pill / button language for ride confirm: same height, radius, stroke.
enum RidealityPillVariant { primary, ghost, soft }

class RidealityPill extends StatelessWidget {
  const RidealityPill({
    super.key,
    required this.onPressed,
    this.label,
    this.subtitle,
    this.icon,
    this.trailing,
    this.variant = RidealityPillVariant.ghost,
    this.expand = false,
    this.isLoading = false,
    this.height,
  });

  final VoidCallback? onPressed;
  final String? label;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final RidealityPillVariant variant;
  final bool expand;
  final bool isLoading;
  final double? height;

  static const double radius = 16;
  static const double defaultHeight = 52;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final resolvedHeight =
        height ?? (subtitle != null ? 60.0 : defaultHeight);

    final Color bg;
    final Color fg;
    final BorderSide border;

    switch (variant) {
      case RidealityPillVariant.primary:
        bg = AppColors.accent;
        fg = AppColors.onAccent;
        border = BorderSide.none;
      case RidealityPillVariant.ghost:
        bg = AppColors.surfaceContainerLowest;
        fg = AppColors.onSurface;
        border = const BorderSide(color: AppColors.outlineVariant, width: 1);
      case RidealityPillVariant.soft:
        bg = AppColors.accentSoft;
        fg = AppColors.accent;
        border = BorderSide.none;
    }

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: fg,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                if (label != null) const SizedBox(width: 8),
              ],
              if (label != null)
                Flexible(
                  child: subtitle == null
                      ? Text(
                          label!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 20 / 15,
                            color: fg,
                            letterSpacing: -0.1,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                height: 20 / 16,
                                color: fg,
                                letterSpacing: -0.15,
                              ),
                            ),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                height: 16 / 12,
                                color: fg.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          );

    final button = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: border,
      ),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: resolvedHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? 0 : 16,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }
    if (label == null && icon != null) {
      return SizedBox(
        width: resolvedHeight,
        height: resolvedHeight,
        child: button,
      );
    }
    return button;
  }
}

/// Compact soft pill (e.g. Stops, Fastest badge).
class RidealityChip extends StatelessWidget {
  const RidealityChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.accentSoft : AppColors.surfaceContainerLow;
    final fg = selected ? AppColors.accent : AppColors.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(RidealityPill.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RidealityPill.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 16 / 12,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
