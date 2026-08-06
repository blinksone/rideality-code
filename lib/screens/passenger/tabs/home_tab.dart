import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../../models/api_models.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/network_avatar.dart';
import '../destination_search_sheet.dart';
import '../notifications_screen.dart';
import '../save_location_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.profile,
    required this.passenger,
    required this.onboarding,
    required this.profileProgress,
    required this.hideProfileBanner,
    required this.hidePromoBanner,
    required this.onRefresh,
    required this.onDismissProfileBanner,
    required this.onDismissPromoBanner,
    required this.onOpenProfile,
    required this.onOpenWallet,
    required this.onCompleteProfile,
    required this.onSavedPlacesChanged,
  });

  final UserProfile? profile;
  final PassengerView passenger;
  final OnboardingStatus onboarding;
  final double profileProgress;
  final bool hideProfileBanner;
  final bool hidePromoBanner;
  final Future<void> Function() onRefresh;
  final VoidCallback onDismissProfileBanner;
  final VoidCallback onDismissPromoBanner;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenWallet;
  final VoidCallback onCompleteProfile;
  final Future<void> Function() onSavedPlacesChanged;

  SavedPlace? _placeByLabel(String label) {
    for (final p in passenger.savedPlaces) {
      if (p.label.toLowerCase() == label) return p;
    }
    return null;
  }

  Future<void> _openSearch(
    BuildContext context, {
    String? initial,
    SavedPlace? place,
  }) async {
    final dest = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DestinationSearchSheet(
        places: passenger.savedPlaces,
        initialQuery: initial ?? place?.address,
        canBook: profile?.canBook == true || onboarding.canBook || onboarding.personalInfo,
      ),
    );
    if (dest != null && dest.isNotEmpty) {
      await DashboardPrefs.instance.setLastDestination(dest);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Looking for rides to $dest…'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = _placeByLabel('home');
    final work = _placeByLabel('work');
    final status = (profile?.status ?? '').toUpperCase();
    final incomplete = status == 'PROFILE_INCOMPLETE' ||
        !onboarding.profileComplete ||
        profileProgress < 1.0;
    final showProfileCard = !hideProfileBanner && incomplete;
    final needsEmail = profile?.email == null || profile!.email!.isEmpty;
    final needsPlace =
        !onboarding.locationsSaved && passenger.savedPlaces.isEmpty;
    String completeHint;
    if (needsEmail && needsPlace) {
      completeHint = 'Add your email and a saved place to activate.';
    } else if (needsEmail) {
      completeHint = 'Add your email to get ride receipts.';
    } else if (needsPlace) {
      completeHint = 'Save home or work to complete your profile.';
    } else {
      completeHint = 'Tap to finish profile setup.';
    }
    final name = profile?.fullName ?? passenger.fullName;

    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Map + top overlays
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.48,
              child: Stack(
                children: [
                  const Positioned.fill(child: _HomeMapBackdrop()),
                  // Header
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          _RoundIconButton(
                            onTap: onOpenProfile,
                            backgroundColor: AppColors.surfaceTint,
                            elevation: 0,
                            child: NetworkAvatar(
                              name: name.isNotEmpty ? name : 'R',
                              photoUrl:
                                  profile?.photoUrl ?? passenger.photoUrl,
                              radius: 20,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Rideality',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const Spacer(),
                          _RoundIconButton(
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                NotificationsScreen.routeName,
                              );
                            },
                            child: FutureBuilder<int>(
                              future: NotificationInbox.instance.unreadCount(),
                              builder: (context, snap) {
                                final count = snap.data ?? 0;
                                return Badge(
                                  isLabelVisible: count > 0,
                                  smallSize: 8,
                                  label: count > 9
                                      ? const Text('9+')
                                      : (count > 0
                                          ? Text('$count')
                                          : null),
                                  backgroundColor: AppColors.secondary,
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: AppColors.onSurface,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // My location pill
                  Positioned(
                    right: 18,
                    bottom: 108,
                    child: Material(
                      color: AppColors.secondary,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Centered on your location'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.near_me_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Search + quick chips
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      children: [
                        Material(
                          color: AppColors.surfaceContainerLowest,
                          elevation: 8,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openSearch(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Where to?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.search_rounded,
                                    color: AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickChip(
                                icon: Icons.home_rounded,
                                label: 'Home',
                                onTap: () {
                                  if (home != null) {
                                    _openSearch(context, place: home);
                                  } else {
                                    Navigator.of(context)
                                        .pushNamed(
                                      SaveLocationScreen.routeName,
                                      arguments: true,
                                    )
                                        .then((_) => onSavedPlacesChanged());
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickChip(
                                icon: Icons.work_rounded,
                                label: 'Work',
                                onTap: () {
                                  if (work != null) {
                                    _openSearch(context, place: work);
                                  } else {
                                    Navigator.of(context)
                                        .pushNamed(
                                      SaveLocationScreen.routeName,
                                      arguments: true,
                                    )
                                        .then((_) => onSavedPlacesChanged());
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickChip(
                                icon: Icons.add_rounded,
                                label: 'Add place',
                                onTap: () {
                                  Navigator.of(context)
                                      .pushNamed(
                                    SaveLocationScreen.routeName,
                                    arguments: true,
                                  )
                                      .then((_) => onSavedPlacesChanged());
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom sheet-ish content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hidePromoBanner) ...[
                    _PromoCard(onDismiss: onDismissPromoBanner),
                    SizedBox(height: showProfileCard ? 16 : 24),
                  ],
                  if (showProfileCard) ...[
                    _ProfileProgressCard(
                      progress: profileProgress,
                      subtitle: completeHint,
                      onDismiss: onDismissProfileBanner,
                      onTap: onCompleteProfile,
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Choose a ride',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ...[
                    ('Rideality Go', 'Affordable everyday trips', 'PKR 280+',
                        Icons.directions_car_filled_rounded),
                    ('Rideality XL', 'More space for groups', 'PKR 420+',
                        Icons.airport_shuttle_rounded),
                    ('Rideality Comfort', 'Top-rated drivers', 'PKR 360+',
                        Icons.airline_seat_recline_extra_rounded),
                  ].map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RideOptionTile(
                        title: r.$1,
                        subtitle: r.$2,
                        priceHint: r.$3,
                        icon: r.$4,
                        onTap: () => _openSearch(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surfaceTint,
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppColors.secondary,
                      ),
                    ),
                    title: Text(
                      'Wallet · ${passenger.wallet.currency} ${passenger.wallet.balance.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    subtitle: Text(
                      'Loyalty ${passenger.loyaltyTier} · ${passenger.loyaltyPoints} pts',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: onOpenWallet,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.child,
    required this.onTap,
    this.backgroundColor = AppColors.surfaceContainerLowest,
    this.elevation = 3,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color backgroundColor;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      elevation: elevation,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Center(child: child)),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Unified: white surface + soft ambient shadow.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppColors.ambientShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: AppColors.secondary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '50% off next 3 rides',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Valid until Friday',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.confirmation_number_rounded,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _ProfileProgressCard extends StatelessWidget {
  const _ProfileProgressCard({
    required this.progress,
    required this.subtitle,
    required this.onDismiss,
    required this.onTap,
  });

  final double progress;
  final String subtitle;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.ambientShadow,
            color: AppColors.surfaceContainerLowest,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: AppColors.surfaceContainer,
                      color: AppColors.secondary,
                    ),
                    Text(
                      '$pct%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete your profile',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideOptionTile extends StatelessWidget {
  const _RideOptionTile({
    required this.title,
    required this.subtitle,
    required this.priceHint,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String priceHint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.ambientShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.secondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                priceHint,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Map-style backdrop inlined so hot-reload does not break on a separate file.
class _HomeMapBackdrop extends StatelessWidget {
  const _HomeMapBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _HomeMapPainter()),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.transparent,
                AppColors.background.withValues(alpha: 0.2),
                AppColors.background,
              ],
              stops: const [0, 0.35, 0.82, 1],
            ),
          ),
        ),
        const Center(
          child: Icon(
            Icons.location_on_rounded,
            size: 42,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _HomeMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8EEF5),
    );

    final road = Paint()
      ..color = const Color(0xFFD5DDE8)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadThin = Paint()
      ..color = const Color(0xFFC8D2E0)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final block = Paint()..color = const Color(0xFFDCE5F0);
    final park =
        Paint()..color = const Color(0xFFC8E6C9).withValues(alpha: 0.55);
    final water =
        Paint()..color = const Color(0xFFBBDEFB).withValues(alpha: 0.7);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.55,
          size.height * 0.12,
          size.width * 0.5,
          size.height * 0.28,
        ),
        const Radius.circular(40),
      ),
      water,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.55,
          size.width * 0.28,
          size.height * 0.18,
        ),
        const Radius.circular(20),
      ),
      park,
    );

    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 5; c++) {
        final rect = Rect.fromLTWH(
          20 + c * (size.width / 4.2),
          40 + r * (size.height / 7.5),
          size.width / 5.5,
          size.height / 10,
        );
        if ((r + c).isEven) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(6), const Radius.circular(4)),
            block,
          );
        }
      }
    }

    canvas.drawLine(
      Offset(0, size.height * 0.42),
      Offset(size.width, size.height * 0.38),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.45, size.height),
      road,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.75),
      roadThin,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width * 0.55, size.height),
      roadThin,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
