import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RidealityAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RidealityAppBar({
    super.key,
    this.showBack = true,
    this.onBack,
    this.centerTitle = true,
  });

  final bool showBack;
  final VoidCallback? onBack;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
            )
          : null,
      title: Text(
        'Rideality',
        style: Theme.of(context).appBarTheme.titleTextStyle,
      ),
      centerTitle: centerTitle,
    );
  }
}
