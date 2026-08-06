import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../models/api_models.dart';
import '../../services/auth_api_service.dart';
import '../../services/driver_api_service.dart';
import '../../services/notification_api_service.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/network_avatar.dart';
import '../passenger/notifications_screen.dart';
import '../passenger/welcome_screen.dart';
import 'chat_inbox_tab.dart';
import 'driver_online_map_screen.dart';
import 'under_review_screen.dart';
import 'update_profile_screen.dart';
import 'vehicle_details_screen.dart';

/// Driver shell — bottom tabs: Home / Trips / Chat / Earnings / Profile.
/// Home always hosts the map (online/offline controlled on the map).
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key, this.initialIndex = 0});

  static const routeName = '/driver-home';

  final int initialIndex;

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  static const int tabHome = 0;
  static const int tabProfile = 4;

  /// Default for hot reload; `initState` still applies [initialIndex].
  int _tab = tabHome;

  bool _loading = true;
  String? _error;

  UserProfile? _me;
  DriverView _driver = DriverView.empty;
  WalletInfo _wallet = WalletInfo.empty;
  List<RideSummary> _rides = const [];
  bool _canDrive = false;
  String _period = 'Today';

  @override
  void initState() {
    super.initState();
    _tab = widget.initialIndex.clamp(0, tabProfile);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        UserApiService.instance.getMe(),
        UserApiService.instance.getOnboarding(),
        UserApiService.instance.getWallet(),
        UserApiService.instance.listMyRides(limit: 50),
      ]);
      final me = results[0] as UserProfile;
      final onboarding = results[1] as OnboardingStatus;
      final wallet = results[2] as WalletInfo;
      final rides = results[3] as List<RideSummary>;

      DriverView driver = DriverView.empty;
      try {
        driver = await DriverApiService.instance.getDriverView();
      } on ApiException catch (e) {
        if (e.statusCode != 404 && e.code != 'NOT_FOUND') rethrow;
      }

      final canDrive = me.canDrive ||
          onboarding.canDrive ||
          onboarding.driverApproved ||
          driver.isApproved;

      if (canDrive && me.activeMode?.toLowerCase() != 'driver') {
        try {
          await DriverApiService.instance.switchMode('driver');
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _me = me;
        _driver = driver;
        _wallet = wallet;
        _rides = rides;
        _canDrive = canDrive;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load driver dashboard';
        _loading = false;
      });
    }
  }

  List<RideSummary> get _periodRides {
    final now = DateTime.now();
    DateTime start;
    switch (_period) {
      case 'Week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
      case 'Month':
        start = DateTime(now.year, now.month, 1);
      default:
        start = DateTime(now.year, now.month, now.day);
    }
    return _rides.where((r) {
      final raw = r.createdAt;
      if (raw == null || raw.isEmpty) return _period == 'Today';
      final dt = DateTime.tryParse(raw);
      if (dt == null) return false;
      return !dt.isBefore(start);
    }).toList();
  }

  int get _tripsCount {
    final filtered = _periodRides;
    if (filtered.isNotEmpty) return filtered.length;
    if (_period == 'Today' && _rides.isEmpty) return _driver.totalRides;
    return 0;
  }

  double get _periodEarnings {
    final rides = _periodRides;
    final sum = rides.fold<double>(0, (a, r) => a + (r.fare ?? 0));
    if (sum > 0) return sum;
    if (_period == 'Today') return _wallet.balance;
    return 0;
  }

  String get _timeLabel {
    final hours = _driver.activeHours;
    if (hours <= 0) return '0h 0m';
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m}m';
  }

  String _money(double v) {
    final c = _wallet.currency.toUpperCase() == 'PKR' ? 'Rs.' : _wallet.currency;
    return '$c ${v.toStringAsFixed(2)}';
  }

  /// Open Profile bottom tab (map avatar).
  void _openProfileTab() {
    setState(() => _tab = tabProfile);
  }

  void _openNotifications() {
    Navigator.of(context).pushNamed(NotificationsScreen.routeName);
  }

  void _onMapDriverUpdated(DriverView driver) {
    setState(() => _driver = driver);
    if (!driver.isOnline) {
      _toast('You\'re offline');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openProfile() async {
    // MaterialPageRoute survives hot-reload better than named routes alone.
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: UpdateProfileScreen.routeName),
        builder: (_) => UpdateProfileScreen(initialProfile: _me),
      ),
    );
    if (result == true && mounted) {
      await _bootstrap();
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to verify your phone again to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AuthApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      WelcomeScreen.routeName,
      (_) => false,
    );
  }

  void _openVehicles() {
    Navigator.of(context)
        .pushNamed(VehicleDetailsScreen.routeName, arguments: true)
        .then((_) => _bootstrap());
  }

  Future<void> _openEarnings() async {
    List<WalletTransaction> txs = const [];
    var loading = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            if (loading) {
              UserApiService.instance.listWalletTransactions(limit: 30).then((list) {
                if (!ctx.mounted) return;
                setSheet(() {
                  txs = list;
                  loading = false;
                });
              }).catchError((_) {
                if (!ctx.mounted) return;
                setSheet(() => loading = false);
              });
            }
            final bal = _wallet;
            final symbol =
                bal.currency.toUpperCase() == 'PKR' ? 'Rs.' : bal.currency;
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (ctx, scroll) {
                return ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Text(
                      'Earnings',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$symbol ${bal.balance.toStringAsFixed(2)}',
                        style: Theme.of(ctx).textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (txs.isEmpty)
                      Text(
                        'No transactions yet.',
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      )
                    else
                      ...txs.map(
                        (t) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            t.description?.isNotEmpty == true
                                ? t.description!
                                : t.type.replaceAll('_', ' '),
                          ),
                          subtitle: Text(t.createdAt ?? ''),
                          trailing: Text(
                            '$symbol ${t.amount.toStringAsFixed(2)}',
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: t.amount >= 0
                                      ? AppColors.success
                                      : AppColors.onSurface,
                                ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openPayouts() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final symbol = _wallet.currency.toUpperCase() == 'PKR'
            ? 'Rs.'
            : _wallet.currency;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Payouts',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Wallet balance ready: $symbol ${_wallet.balance.toStringAsFixed(2)}',
                  style: Theme.of(ctx).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Payout methods and schedules are managed by Rideality finance. '
                  'Cashouts appear in Earnings when processed.',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'View earnings',
                  borderRadius: 14,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openEarnings();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & Support'),
        content: const SingleChildScrollView(
          child: Text(
            '• Go online from the Home toggle to receive requests.\n'
            '• Profile opens account menu; notifications are the bell.\n'
            '• Email support@rideality.com for account help.\n'
            '• Finish vehicle + documents + approval to unlock driving.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openRatings() {
    final r = _driver.ratingAvg ?? 0;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ratings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              r > 0 ? r.toStringAsFixed(1) : '—',
              style: Theme.of(ctx).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text('${_driver.totalRides} trips · ${_driver.incentiveTier} tier'),
            const SizedBox(height: 4),
            Text(
              '${_driver.totalDistanceKm.toStringAsFixed(1)} km · '
              '${_driver.activeHours.toStringAsFixed(1)} h active',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    NotificationPreferences prefs = NotificationPreferences.empty;
    try {
      prefs = await NotificationApiService.instance.getPreferences();
    } catch (_) {}
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> update(
              NotificationPreferences Function(NotificationPreferences) fn,
            ) async {
              final next = fn(prefs);
              setSheet(() => prefs = next);
              try {
                prefs =
                    await NotificationApiService.instance.updatePreferences(next);
                setSheet(() {});
              } on ApiException catch (e) {
                if (mounted) _toast(e.message);
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    SwitchListTile(
                      title: const Text('Push notifications'),
                      value: prefs.pushEnabled,
                      onChanged: (v) =>
                          update((p) => p.copyWith(pushEnabled: v)),
                    ),
                    SwitchListTile(
                      title: const Text('Ride updates'),
                      value: prefs.rideUpdates,
                      onChanged: (v) =>
                          update((p) => p.copyWith(rideUpdates: v)),
                    ),
                    SwitchListTile(
                      title: const Text('Promotions'),
                      value: prefs.promotions,
                      onChanged: (v) =>
                          update((p) => p.copyWith(promotions: v)),
                    ),
                    ListTile(
                      title: const Text('Full notification center'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushNamed(
                          NotificationsScreen.routeName,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          ),
        ),
      );
    }

    if (_error != null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.onSurface,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _bootstrap,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final me = _me!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _tab,
          children: [
            // 0 — Home (map only)
            DriverOnlineMapScreen(
              key: const ValueKey('driver-online-map'),
              embedded: true,
              driver: _driver,
              me: me,
              wallet: _wallet,
              canDrive: _canDrive,
              onDriverUpdated: _onMapDriverUpdated,
              onOpenDashboard: _openProfileTab,
            ),
            // 1 — Trips
            _DriverTripsTab(
              rides: _rides,
              onRefresh: _bootstrap,
              onNotifications: _openNotifications,
            ),
            // 2 — Chat inbox
            const ChatInboxTab(),
            // 3 — Earnings / Overview
            _DriverEarningsTab(
              me: me,
              period: _period,
              trips: _tripsCount,
              earningsLabel: _money(_periodEarnings),
              timeLabel: _timeLabel,
              onPeriod: (p) => setState(() => _period = p),
              onNotifications: _openNotifications,
            ),
            // 4 — Profile (menu)
            _DriverMenuTab(
              me: me,
              driver: _driver,
              canDrive: _canDrive,
              onProfile: _openProfile,
              onVehicles: _openVehicles,
              onEarnings: _openEarnings,
              onPayouts: _openPayouts,
              onHelp: _openHelp,
              onRatings: _openRatings,
              onSettings: _openSettings,
              onApplicationStatus: () {
                Navigator.of(context).pushNamed(UnderReviewScreen.routeName);
              },
              onLogout: _confirmLogout,
              onNotifications: _openNotifications,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 68,
          selectedIndex: _tab,
          backgroundColor: AppColors.surfaceContainerLowest,
          indicatorColor: AppColors.surfaceTint,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route_rounded),
              label: 'Trips',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments_rounded),
              label: 'Earnings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuListItem extends StatelessWidget {
  const _MenuListItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceTint,
        child: Icon(icon, color: AppColors.secondary, size: 22),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

/// Avatar with initial fallback (never an empty tint circle).
class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({
    required this.name,
    this.photoUrl,
    this.radius = 26,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return NetworkAvatar(
      name: name,
      photoUrl: photoUrl,
      radius: radius,
    );
  }
}

class _NotifIconButton extends StatelessWidget {
  const _NotifIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: NotificationInbox.instance.unreadCount(),
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return IconButton(
          onPressed: onTap,
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: n > 0,
            smallSize: 8,
            backgroundColor: const Color(0xFFE53935),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.onSurface,
              size: 26,
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen Profile / Menu tab.
class _DriverMenuTab extends StatelessWidget {
  const _DriverMenuTab({
    required this.me,
    required this.driver,
    required this.canDrive,
    required this.onProfile,
    required this.onVehicles,
    required this.onEarnings,
    required this.onPayouts,
    required this.onHelp,
    required this.onRatings,
    required this.onSettings,
    required this.onApplicationStatus,
    required this.onLogout,
    required this.onNotifications,
  });

  final UserProfile me;
  final DriverView driver;
  final bool canDrive;
  final VoidCallback onProfile;
  final VoidCallback onVehicles;
  final VoidCallback onEarnings;
  final VoidCallback onPayouts;
  final VoidCallback onHelp;
  final VoidCallback onRatings;
  final VoidCallback onSettings;
  final VoidCallback onApplicationStatus;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final name = me.fullName ?? 'Driver';
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Menu',
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _NotifIconButton(onTap: onNotifications),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
              boxShadow: AppColors.ambientShadow,
            ),
            child: Row(
              children: [
                _DriverAvatar(
                  name: name,
                  photoUrl: me.photoUrl,
                  radius: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(me.phone, style: tt.bodySmall),
                      if (driver.totalRides > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${driver.totalRides} trips',
                          style: tt.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _MenuListItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            onTap: onProfile,
          ),
          _MenuListItem(
            icon: Icons.directions_car_outlined,
            label: 'Vehicles',
            onTap: onVehicles,
          ),
          _MenuListItem(
            icon: Icons.payments_outlined,
            label: 'Earnings',
            onTap: onEarnings,
          ),
          _MenuListItem(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Payouts',
            onTap: onPayouts,
          ),
          _MenuListItem(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: onHelp,
          ),
          _MenuListItem(
            icon: Icons.star_outline_rounded,
            label: 'Ratings',
            onTap: onRatings,
          ),
          _MenuListItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: onSettings,
          ),
          if (!canDrive)
            _MenuListItem(
              icon: Icons.fact_check_outlined,
              label: 'Application status',
              onTap: onApplicationStatus,
            ),
          const Divider(height: 28),
          _MenuListItem(
            icon: Icons.logout_rounded,
            label: 'Log out',
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

/// Earnings tab — Overview stats (no decorative grid).
class _DriverEarningsTab extends StatelessWidget {
  const _DriverEarningsTab({
    required this.me,
    required this.period,
    required this.trips,
    required this.earningsLabel,
    required this.timeLabel,
    required this.onPeriod,
    required this.onNotifications,
  });

  final UserProfile me;
  final String period;
  final int trips;
  final String earningsLabel;
  final String timeLabel;
  final ValueChanged<String> onPeriod;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final name = me.fullName ?? 'Driver';
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
            child: Row(
              children: [
                _DriverAvatar(name: name, photoUrl: me.photoUrl, radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _NotifIconButton(onTap: onNotifications),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Overview',
                              style: tt.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            initialValue: period,
                            color: AppColors.surfaceContainerLowest,
                            onSelected: onPeriod,
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'Today',
                                child: Text('Today', style: tt.bodyMedium),
                              ),
                              PopupMenuItem(
                                value: 'Week',
                                child: Text('Week', style: tt.bodyMedium),
                              ),
                              PopupMenuItem(
                                value: 'Month',
                                child: Text('Month', style: tt.bodyMedium),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceTint,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    period,
                                    style: tt.labelMedium?.copyWith(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.secondary,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCol(
                              label: 'Trips',
                              value: '$trips',
                            ),
                          ),
                          Expanded(
                            child: _StatCol(
                              label: 'Earnings',
                              value: earningsLabel,
                            ),
                          ),
                          Expanded(
                            child: _StatCol(
                              label: 'Total Time',
                              value: timeLabel,
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
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _DriverTripsTab extends StatelessWidget {
  const _DriverTripsTab({
    required this.rides,
    required this.onRefresh,
    required this.onNotifications,
  });

  final List<RideSummary> rides;
  final Future<void> Function() onRefresh;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Trips',
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _NotifIconButton(onTap: onNotifications),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.secondary,
              onRefresh: onRefresh,
              child: rides.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        const Icon(
                          Icons.route_outlined,
                          size: 48,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No trips yet',
                          textAlign: TextAlign.center,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Accepted rides will show here.',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: rides.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final r = rides[i];
                        final fare = r.fare;
                        final c = r.currency.toUpperCase() == 'PKR'
                            ? 'Rs.'
                            : r.currency;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: AppColors.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.status.replaceAll('_', ' '),
                                      style: tt.labelSmall?.copyWith(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  if (fare != null)
                                    Text(
                                      '$c ${fare.toStringAsFixed(0)}',
                                      style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                r.pickupAddress ?? 'Pickup',
                                style: tt.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r.dropoffAddress ?? 'Drop-off',
                                style: tt.bodyMedium,
                              ),
                              if (r.createdAt != null) ...[
                                const SizedBox(height: 6),
                                Text(r.createdAt!, style: tt.labelSmall),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
