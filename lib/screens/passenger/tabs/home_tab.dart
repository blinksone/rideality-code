import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/vehicle_catalog.dart';
import '../../../models/api_models.dart';
import '../../../theme/app_colors.dart';
import '../notifications_screen.dart';
import '../rides_destination_screen.dart';
import '../save_location_screen.dart';

/// Passenger home — multi-service layout (bottom tabs live in dashboard shell).
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
    this.rides = const [],
    this.onOpenActiveRide,
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
  final List<RideSummary> rides;
  final Future<void> Function(RideSummary ride)? onOpenActiveRide;

  RideSummary? get _activeRide {
    for (final r in rides) {
      if (r.isActive) return r;
    }
    return null;
  }

  bool get _canBook =>
      profile?.canBook == true ||
      onboarding.canBook ||
      onboarding.personalInfo;

  SavedPlace? _placeByLabel(String label) {
    for (final p in passenger.savedPlaces) {
      if (p.label.toLowerCase() == label) return p;
    }
    return null;
  }

  /// Short city/region line for the header (e.g. "Karachi").
  String _cityLabel() {
    final home = _placeByLabel('home');
    final source = home?.address.isNotEmpty == true
        ? home!.address
        : (passenger.savedPlaces.isNotEmpty
            ? passenger.savedPlaces.first.address
            : '');
    if (source.isEmpty) return 'Your location';
    final parts = source
        .split(RegExp(r'[,|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return source;
    // Prefer a recognized city token; else last meaningful segment.
    const cities = {
      'karachi',
      'lahore',
      'islamabad',
      'rawalpindi',
      'peshawar',
      'multan',
      'faisalabad',
      'hyderabad',
      'quetta',
    };
    for (final p in parts) {
      if (cities.contains(p.toLowerCase())) return p;
    }
    return parts.length > 1 ? parts[parts.length - 1] : parts.first;
  }

  void _comingSoon(BuildContext context, String service) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        final isCarpool = service == 'Carpool';
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppColors.ambientShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (isCarpool
                          ? const Color(0xFF0D9488)
                          : const Color(0xFFD97706))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  isCarpool
                      ? Icons.groups_rounded
                      : Icons.local_shipping_rounded,
                  size: 36,
                  color: isCarpool
                      ? const Color(0xFF0D9488)
                      : const Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '$service is coming soon',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isCarpool
                    ? 'Share rides with people going your way. We\'ll notify you when it launches.'
                    : 'Move larger items with cargo vehicles. We\'re building this for you.',
                style: tt.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRides(
    BuildContext context, {
    String? initialDestination,
    String vehicleType = 'economy',
  }) async {
    await Navigator.of(context).pushNamed(
      RidesDestinationScreen.routeName,
      arguments: RidesDestinationArgs(
        places: passenger.savedPlaces,
        canBook: _canBook,
        initialDestination: initialDestination,
        vehicleType: VehicleCatalog.normalize(vehicleType),
      ),
    );
  }

  Future<void> _openOrSavePlace(
    BuildContext context,
    SavedPlace? place,
    String label,
  ) async {
    if (place != null && place.address.isNotEmpty) {
      await _openRides(context, initialDestination: place.address);
      return;
    }
    await Navigator.of(context).pushNamed(
      SaveLocationScreen.routeName,
      arguments: true,
    );
    onSavedPlacesChanged();
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
    final completeHint = needsEmail && needsPlace
        ? 'Add email and a saved place to activate.'
        : needsEmail
            ? 'Add your email for ride receipts.'
            : needsPlace
                ? 'Save home or work to finish setup.'
                : 'Tap to finish profile setup.';
    final city = _cityLabel();
    final tt = Theme.of(context).textTheme;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        color: AppColors.secondary,
        displacement: 48,
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // —— Header ————————————————
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rideality',
                                  style: tt.headlineMedium?.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _openRides(context),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                        horizontal: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.location_on_rounded,
                                            size: 16,
                                            color: AppColors.secondary
                                                .withValues(alpha: 0.85),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              city,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: tt.titleSmall?.copyWith(
                                                color: AppColors.onSurface,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 22,
                                            color: AppColors.onSurface,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _HeaderIconButton(
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                NotificationsScreen.routeName,
                              );
                            },
                            child: FutureBuilder<int>(
                              future:
                                  NotificationInbox.instance.unreadCount(),
                              builder: (context, snap) {
                                final count = snap.data ?? 0;
                                return Badge(
                                  isLabelVisible: count > 0,
                                  smallSize: 8,
                                  backgroundColor: AppColors.secondary,
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: AppColors.secondary,
                                    size: 24,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // —— Active ride —————————————
                      if (_activeRide != null) ...[
                        const SizedBox(height: 16),
                        _ActiveRideBanner(
                          ride: _activeRide!,
                          onTap: onOpenActiveRide == null
                              ? null
                              : () => onOpenActiveRide!(_activeRide!),
                        ),
                      ],

                      // —— Promo ————————————————
                      if (!hidePromoBanner) ...[
                        const SizedBox(height: 18),
                        _PromoBanner(
                          onWallet: onOpenWallet,
                          onDismiss: onDismissPromoBanner,
                        ),
                      ],

                      const SizedBox(height: 22),

                      // —— Services ——————————————
                      Text(
                        'Services',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ServiceCard(
                              title: 'Carpool',
                              subtitle: 'Coming soon',
                              icon: Icons.groups_rounded,
                              accent: const Color(0xFF0D9488),
                              onTap: () =>
                                  _comingSoon(context, 'Carpool'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ServiceCard(
                              title: 'Cargo',
                              subtitle: 'Move large items',
                              icon: Icons.local_shipping_rounded,
                              accent: const Color(0xFFD97706),
                              onTap: () => _openRides(
                                context,
                                vehicleType: 'cargo',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // —— Where to? —————————————
                      _WhereToBar(
                        onTap: () => _openRides(context),
                        onMic: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Voice search is coming soon',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 26),

                      // —— Go somewhere ———————————
                      Text(
                        'Go somewhere',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PlaceRow(
                        icon: Icons.home_rounded,
                        title: 'Home',
                        subtitle: home?.address.isNotEmpty == true
                            ? home!.address
                            : 'Set destination',
                        hint: home == null,
                        onTap: () =>
                            _openOrSavePlace(context, home, 'home'),
                      ),
                      const SizedBox(height: 10),
                      _PlaceRow(
                        icon: Icons.work_rounded,
                        title: 'Work',
                        subtitle: work?.address.isNotEmpty == true
                            ? work!.address
                            : 'Set destination',
                        hint: work == null,
                        onTap: () =>
                            _openOrSavePlace(context, work, 'work'),
                      ),

                      // Extra saved places (not home/work)
                      ...passenger.savedPlaces
                          .where((p) => !p.isHome && !p.isWork)
                          .take(2)
                          .map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _PlaceRow(
                                icon: Icons.place_rounded,
                                title: p.label.isNotEmpty
                                    ? _titleCase(p.label)
                                    : 'Saved place',
                                subtitle: p.address,
                                onTap: () => _openRides(
                                  context,
                                  initialDestination: p.address,
                                ),
                              ),
                            ),
                          ),

                      if (showProfileCard) ...[
                        const SizedBox(height: 20),
                        _ProfileNudgeCard(
                          progress: profileProgress,
                          subtitle: completeHint,
                          onDismiss: onDismissProfileBanner,
                          onTap: onCompleteProfile,
                        ),
                      ],

                      const SizedBox(height: 12),
                      _WalletStrip(
                        currency: passenger.wallet.currency,
                        balance: passenger.wallet.balance,
                        tier: passenger.loyaltyTier,
                        points: passenger.loyaltyPoints,
                        onTap: onOpenWallet,
                      ),

                      SizedBox(height: 24 + bottomSafe),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleCase(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Place';
    return t[0].toUpperCase() + (t.length > 1 ? t.substring(1) : '');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.ride, this.onTap});

  final RideSummary ride;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dest = ride.dropoffAddress?.trim();
    final subtitle = (dest != null && dest.isNotEmpty)
        ? dest
        : 'Tap to track your trip';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.ambientShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.statusLabel,
                      style: tt.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ride.vehicleTypeLabel.isNotEmpty
                          ? '${ride.vehicleTypeLabel} · Ongoing'
                          : 'Ongoing ride',
                      style: tt.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTint,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.onWallet,
    required this.onDismiss,
  });

  final VoidCallback onWallet;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              color: Color(0xFF15803D),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '50% off next 3 rides',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onWallet,
                  child: Text(
                    'Wallet',
                    style: tt.labelMedium?.copyWith(
                      color: const Color(0xFF166534),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: const Color(0xFF166534),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          height: 118,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.ambientShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: tt.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhereToBar extends StatelessWidget {
  const _WhereToBar({
    required this.onTap,
    required this.onMic,
  });

  final VoidCallback onTap;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14111827),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Where to?',
                  style: tt.titleMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Material(
                color: AppColors.surfaceTint,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onMic,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.mic_none_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.hint = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool hint;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.ambientShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: hint
                            ? AppColors.secondary
                            : AppColors.onSurfaceVariant,
                        fontWeight: hint ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hint ? Icons.add_rounded : Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileNudgeCard extends StatelessWidget {
  const _ProfileNudgeCard({
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
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.ambientShadow,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress.clamp(0.05, 1.0),
                      strokeWidth: 4.5,
                      backgroundColor: AppColors.surfaceContainer,
                      color: AppColors.secondary,
                    ),
                    Text(
                      '$pct%',
                      style: tt.labelSmall?.copyWith(
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
                      style:
                          tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: tt.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
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

class _WalletStrip extends StatelessWidget {
  const _WalletStrip({
    required this.currency,
    required this.balance,
    required this.tier,
    required this.points,
    required this.onTap,
  });

  final String currency;
  final double balance;
  final String tier;
  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final symbol = currency.toUpperCase() == 'PKR' ? 'Rs' : currency;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet · $symbol ${balance.toStringAsFixed(0)}',
                      style:
                          tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Loyalty $tier · $points pts',
                      style: tt.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
