import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../models/api_models.dart';
import '../../models/trip_models.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../shared/active_ride_screen.dart';
import 'complete_profile_screen.dart';
import 'tabs/activity_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/wallet_tab.dart';

class PassengerDashboardScreen extends StatefulWidget {
  const PassengerDashboardScreen({super.key, this.initialIndex = 0});

  static const routeName = '/home';

  final int initialIndex;

  @override
  State<PassengerDashboardScreen> createState() =>
      _PassengerDashboardScreenState();
}

class _PassengerDashboardScreenState extends State<PassengerDashboardScreen> {
  late int _index;
  bool _loading = true;
  String? _error;

  UserProfile? _profile;
  PassengerView _passenger = PassengerView.empty;
  WalletInfo _wallet = WalletInfo.empty;
  List<RideSummary> _rides = const [];
  OnboardingStatus _onboarding = OnboardingStatus.empty;
  bool _hideProfileBanner = false;
  bool _hidePromoBanner = false;
  bool _profileNeedsAttention = false;
  bool _profileCompletionPrompted = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3);
    _bootstrap();
  }

  Future<T?> _soft<T>(Future<T> Function() run, String label) async {
    try {
      return await run();
    } catch (e, st) {
      debugPrint('[Dashboard] $label failed: $e\n$st');
      return null;
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = DashboardPrefs.instance;

      // Required for home — fail the screen only if these fail.
      final me = await UserApiService.instance.getMe();
      final passenger = await UserApiService.instance.getPassengerView();
      final onboarding = await UserApiService.instance.getOnboarding();

      // Optional — don't block the whole dashboard.
      final wallet = await _soft(
        () => UserApiService.instance.getWallet(),
        'wallet',
      );
      final rides = await _soft(
        () => UserApiService.instance.listMyRides(limit: 20),
        'rides',
      );
      final hideProfile =
          await prefs.isProfileBannerHidden;
      final hidePromo = await prefs.isPromoBannerHidden;

      if (!mounted) return;

      final needsEmail = me.email == null || me.email!.isEmpty;
      final needsPlace = !onboarding.locationsSaved &&
          passenger.savedPlaces.isEmpty;
      final incompleteStatus =
          (me.status ?? '').toUpperCase() == 'PROFILE_INCOMPLETE' ||
              !onboarding.profileComplete;

      setState(() {
        _profile = me;
        _passenger = passenger;
        _wallet = (wallet != null &&
                (wallet.balance > 0 || wallet.id.isNotEmpty))
            ? wallet
            : passenger.wallet;
        _rides = rides ?? const [];
        _onboarding = onboarding;
        _hideProfileBanner = hideProfile;
        _hidePromoBanner = hidePromo;
        _profileNeedsAttention =
            needsEmail || needsPlace || incompleteStatus;
        _loading = false;
      });

      // Incomplete signup: prompt once per visit to finish email + location.
      if (!_profileCompletionPrompted &&
          incompleteStatus &&
          (needsEmail || needsPlace)) {
        _profileCompletionPrompted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _openCompleteProfile();
        });
      }
    } on ApiException catch (e, st) {
      debugPrint('[Dashboard] bootstrap ApiException: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[Dashboard] bootstrap error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString().isNotEmpty
            ? e.toString()
            : 'Could not load dashboard';
        _loading = false;
      });
    }
  }

  double get _profileProgress {
    var score = 0.0;
    if (_onboarding.phoneVerified || (_profile?.phone.isNotEmpty ?? false)) {
      score += 0.25;
    }
    if ((_profile?.fullName?.isNotEmpty ?? false) ||
        _passenger.fullName.isNotEmpty) {
      score += 0.25;
    }
    if ((_profile?.email?.isNotEmpty ?? false)) score += 0.25;
    if (_onboarding.locationsSaved || _passenger.savedPlaces.isNotEmpty) {
      score += 0.25;
    }
    return score.clamp(0.0, 1.0);
  }

  void _openTab(int i) => setState(() => _index = i);

  Future<void> _openCompleteProfile() async {
    final result = await Navigator.of(context).pushNamed(
      CompleteProfileScreen.routeName,
      arguments: true,
    );
    if (result == true && mounted) {
      await _bootstrap();
    }
  }

  Future<void> _dismissProfileBanner() async {
    await DashboardPrefs.instance.hideProfileBanner();
    if (!mounted) return;
    setState(() => _hideProfileBanner = true);
  }

  Future<void> _dismissPromoBanner() async {
    await DashboardPrefs.instance.hidePromoBanner();
    if (!mounted) return;
    setState(() => _hidePromoBanner = true);
  }

  Future<void> _openActiveRide(RideSummary ride) async {
    if (!ride.isActive || ride.id.isEmpty) return;
    await Navigator.of(context).pushNamed(
      ActiveRideScreen.routeName,
      arguments: ActiveRideArgs(
        tripId: ride.id,
        role: SessionRole.rider,
      ),
    );
    if (!mounted) return;
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _bootstrap)
              : IndexedStack(
                  index: _index,
                  children: [
                    HomeTab(
                      profile: _profile,
                      passenger: _passenger,
                      onboarding: _onboarding,
                      profileProgress: _profileProgress,
                      hideProfileBanner: _hideProfileBanner,
                      hidePromoBanner: _hidePromoBanner,
                      rides: _rides,
                      onRefresh: _bootstrap,
                      onDismissProfileBanner: _dismissProfileBanner,
                      onDismissPromoBanner: _dismissPromoBanner,
                      onOpenProfile: () => _openTab(3),
                      onOpenWallet: () => _openTab(2),
                      onCompleteProfile: _openCompleteProfile,
                      onSavedPlacesChanged: _bootstrap,
                      onOpenActiveRide: _openActiveRide,
                    ),
                    ActivityTab(
                      rides: _rides,
                      onRefresh: _bootstrap,
                    ),
                    WalletTab(
                      wallet: _wallet,
                      onRefresh: _bootstrap,
                    ),
                    ProfileTab(
                      profile: _profile,
                      passenger: _passenger,
                      onboarding: _onboarding,
                      profileProgress: _profileProgress,
                      onRefresh: _bootstrap,
                      onCompleteProfile: _openCompleteProfile,
                    ),
                  ],
                ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : NavigationBar(
              height: 68,
              selectedIndex: _index,
              backgroundColor: AppColors.surfaceContainerLowest,
              indicatorColor: AppColors.surfaceTint,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: _openTab,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.history_rounded),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: 'Activity',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                  label: 'Wallet',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _profileNeedsAttention,
                    smallSize: 8,
                    child: const Icon(Icons.person_outline_rounded),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _profileNeedsAttention,
                    smallSize: 8,
                    child: const Icon(Icons.person_rounded),
                  ),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
