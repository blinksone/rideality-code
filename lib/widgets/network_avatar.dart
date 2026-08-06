import 'package:flutter/material.dart';

import '../core/api/api_config.dart';
import '../theme/app_colors.dart';

/// Network avatar that never passes relative API paths to ImageProviders.
/// Relative paths like `/uploads/x.jpg` cause "No host specified in URI".
class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.backgroundColor = AppColors.surfaceTint,
    this.foregroundColor = AppColors.secondary,
  });

  final String name;
  final String? photoUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;

  String get _initial {
    final t = name.trim();
    return t.isNotEmpty ? t[0].toUpperCase() : '?';
  }

  /// Only `http`/`https` URLs with a host are loadable.
  static String? safeUrl(String? raw) {
    final resolved = ApiConfig.resolveMediaUrl(raw);
    if (resolved == null || resolved.isEmpty) return null;
    final uri = Uri.tryParse(resolved);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final url = safeUrl(photoUrl);
    final size = radius * 2;
    final placeholder = Text(
      _initial,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: foregroundColor,
            fontSize: radius * 0.75,
          ),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      // Never use backgroundImage/NetworkImage — relative URLs throw hard
      // before errorBuilder runs when used as DecorationImage.
      child: url == null
          ? placeholder
          : ClipOval(
              child: Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Center(child: placeholder),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: radius * 0.6,
                      height: radius * 0.6,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foregroundColor,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
