import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../services/notification_api_service.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import 'complete_profile_screen.dart';

/// Passenger notifications: local inbox + live preference toggles.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static const routeName = '/notifications';

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<AppNotification> _items = const [];
  NotificationPreferences _prefs = NotificationPreferences.empty;
  bool _prefsLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      UserProfileLike? me;
      var profileIncomplete = true;
      var canBook = false;
      String? fullName;
      var rideCount = 0;

      try {
        final profile = await UserApiService.instance.getMe();
        final onboarding = await UserApiService.instance.getOnboarding();
        final rides = await UserApiService.instance.listMyRides(limit: 5);
        me = UserProfileLike(
          fullName: profile.fullName,
          status: profile.status,
          canBook: profile.canBook,
        );
        fullName = profile.fullName;
        profileIncomplete =
            (profile.status ?? '').toUpperCase() == 'PROFILE_INCOMPLETE' ||
                !onboarding.profileComplete;
        canBook = profile.canBook || onboarding.canBook || onboarding.personalInfo;
        rideCount = rides.length;
      } catch (_) {
        // Inbox still works offline from local store.
      }

      final items = await NotificationInbox.instance.ensureSystemMessages(
        profileIncomplete: profileIncomplete,
        canBook: canBook,
        fullName: fullName ?? me?.fullName,
        rideCount: rideCount,
      );

      NotificationPreferences prefs = NotificationPreferences.empty;
      try {
        prefs = await NotificationApiService.instance.getPreferences();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _items = items;
        _prefs = prefs;
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
        _error = 'Could not load notifications';
        _loading = false;
      });
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (!n.read) {
      await NotificationInbox.instance.markRead(n.id);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((e) => e.id == n.id ? e.copyWith(read: true) : e)
            .toList();
      });
    }
    _handleTap(n);
  }

  void _handleTap(AppNotification n) {
    if (n.id == 'sys_profile_incomplete') {
      Navigator.of(context).pushNamed(
        CompleteProfileScreen.routeName,
        arguments: true,
      );
      return;
    }
    if (n.type == NotificationType.ride || n.id == 'sys_ready_to_book') {
      Navigator.of(context).pop(); // back to home for booking
      return;
    }
  }

  Future<void> _markAllRead() async {
    await NotificationInbox.instance.markAllRead();
    if (!mounted) return;
    setState(() {
      _items = _items.map((e) => e.copyWith(read: true)).toList();
    });
  }

  Future<void> _updatePref(
    NotificationPreferences Function(NotificationPreferences) update,
  ) async {
    final next = update(_prefs);
    setState(() {
      _prefs = next;
      _prefsLoading = true;
    });
    try {
      final saved =
          await NotificationApiService.instance.updatePreferences(next);
      if (!mounted) return;
      setState(() {
        _prefs = saved;
        _prefsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _prefsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      await _load();
    }
  }

  int get _unread => _items.where((e) => !e.read).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
        ),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.secondary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Text(
                        _unread == 0
                            ? 'Inbox'
                            : 'Inbox · $_unread unread',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (_items.isEmpty)
                        _EmptyInbox()
                      else
                        ..._items.map(
                          (n) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _NotificationTile(
                              item: n,
                              onTap: () => _markRead(n),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Preferences',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Synced with your Rideality account.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      _PrefsCard(
                        prefs: _prefs,
                        enabled: !_prefsLoading,
                        onChanged: _updatePref,
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// Minimal profile fields for seed (avoids coupling).
class UserProfileLike {
  const UserProfileLike({this.fullName, this.status, this.canBook = false});
  final String? fullName;
  final String? status;
  final bool canBook;
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.ambientShadow,
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 40,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ride updates and offers will show up here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  IconData get _icon => switch (item.type) {
        NotificationType.promo => Icons.local_offer_outlined,
        NotificationType.ride => Icons.directions_car_outlined,
        NotificationType.account => Icons.person_outline_rounded,
        NotificationType.system => Icons.info_outline_rounded,
        NotificationType.other => Icons.notifications_outlined,
      };

  String get _timeLabel {
    final d = DateTime.now().difference(item.createdAt);
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${item.createdAt.day}/${item.createdAt.month}';
  }

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
            color: item.read
                ? AppColors.surfaceContainerLowest
                : AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.ambientShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.read
                      ? AppColors.surfaceTint
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _timeLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrefsCard extends StatelessWidget {
  const _PrefsCard({
    required this.prefs,
    required this.enabled,
    required this.onChanged,
  });

  final NotificationPreferences prefs;
  final bool enabled;
  final void Function(
    NotificationPreferences Function(NotificationPreferences),
  ) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.ambientShadow,
      ),
      child: Column(
        children: [
          _PrefSwitch(
            title: 'Push notifications',
            subtitle: 'Alerts on this device',
            value: prefs.pushEnabled,
            enabled: enabled,
            onChanged: (v) => onChanged((p) => p.copyWith(pushEnabled: v)),
          ),
          const Divider(height: 1),
          _PrefSwitch(
            title: 'Ride updates',
            subtitle: 'Driver ETA, trip status',
            value: prefs.rideUpdates,
            enabled: enabled,
            onChanged: (v) => onChanged((p) => p.copyWith(rideUpdates: v)),
          ),
          const Divider(height: 1),
          _PrefSwitch(
            title: 'SMS',
            subtitle: 'Text messages to your phone',
            value: prefs.smsEnabled,
            enabled: enabled,
            onChanged: (v) => onChanged((p) => p.copyWith(smsEnabled: v)),
          ),
          const Divider(height: 1),
          _PrefSwitch(
            title: 'Email',
            subtitle: 'Receipts and account mail',
            value: prefs.emailEnabled,
            enabled: enabled,
            onChanged: (v) => onChanged((p) => p.copyWith(emailEnabled: v)),
          ),
          const Divider(height: 1),
          _PrefSwitch(
            title: 'Promotions',
            subtitle: 'Deals and special offers',
            value: prefs.promotions,
            enabled: enabled,
            onChanged: (v) => onChanged((p) => p.copyWith(promotions: v)),
          ),
        ],
      ),
    );
  }
}

class _PrefSwitch extends StatelessWidget {
  const _PrefSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: AppColors.secondary,
    );
  }
}
