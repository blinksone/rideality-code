import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../models/api_models.dart';
import '../../../services/auth_api_service.dart';
import '../../../services/user_api_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/network_avatar.dart';
import '../../driver/become_driver_screen.dart';
import '../../driver/driver_dashboard_screen.dart';
import '../notifications_screen.dart';
import '../save_location_screen.dart';
import '../welcome_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.profile,
    required this.passenger,
    required this.onboarding,
    required this.profileProgress,
    required this.onRefresh,
    required this.onCompleteProfile,
  });

  final UserProfile? profile;
  final PassengerView passenger;
  final OnboardingStatus onboarding;
  final double profileProgress;
  final Future<void> Function() onRefresh;
  final VoidCallback onCompleteProfile;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _editing = false;
  bool _saving = false;
  late final TextEditingController _name;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.profile?.fullName ?? widget.passenger.fullName,
    );
    _email = TextEditingController(text: widget.profile?.email ?? '');
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing) {
      _name.text = widget.profile?.fullName ?? widget.passenger.fullName;
      _email.text = widget.profile?.email ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserApiService.instance.updateProfile(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
      );
      if (!mounted) return;
      setState(() => _editing = false);
      await widget.onRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await AuthApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      WelcomeScreen.routeName,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.profile;
    final p = widget.passenger;
    final pct = (widget.profileProgress * 100).round();
    final name = p.fullName.isNotEmpty
        ? p.fullName
        : (me?.fullName ?? 'Rider');

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Profile',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.ambientShadow,
              ),
              child: Row(
                children: [
                  NetworkAvatar(
                    name: name,
                    photoUrl: me?.photoUrl ?? p.photoUrl,
                    radius: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullName.isNotEmpty
                              ? p.fullName
                              : (me?.fullName ?? 'Rider'),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          me?.phone ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Profile $pct% complete',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_editing) ...[
              AppTextField(
                label: 'Full name',
                controller: _name,
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Save changes',
                isLoading: _saving,
                borderRadius: 16,
                onPressed: _save,
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.ghost,
                borderRadius: 16,
                onPressed: () => setState(() => _editing = false),
              ),
            ] else ...[
              if ((me?.status ?? '').toUpperCase() == 'PROFILE_INCOMPLETE' ||
                  !widget.onboarding.profileComplete ||
                  (me?.email == null || me!.email!.isEmpty) ||
                  (!widget.onboarding.locationsSaved && p.savedPlaces.isEmpty))
                _Tile(
                  icon: Icons.task_alt_rounded,
                  title: 'Finish setup',
                  subtitle: 'Update email and save a place',
                  onTap: widget.onCompleteProfile,
                ),
              _Tile(
                icon: Icons.edit_outlined,
                title: 'Edit profile',
                subtitle: me?.email?.isNotEmpty == true
                    ? me!.email!
                    : 'Add email for receipts',
                onTap: () => setState(() => _editing = true),
              ),
              _Tile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Alerts and preferences',
                onTap: () {
                  Navigator.of(context).pushNamed(
                    NotificationsScreen.routeName,
                  );
                },
              ),
              _Tile(
                icon: Icons.place_outlined,
                title: 'Saved places',
                subtitle: p.savedPlaces.isEmpty
                    ? 'Add home or work'
                    : '${p.savedPlaces.length} saved',
                onTap: () {
                  Navigator.of(context)
                      .pushNamed(
                        SaveLocationScreen.routeName,
                        arguments: true,
                      )
                      .then((_) => widget.onRefresh());
                },
              ),
              _Tile(
                icon: Icons.local_taxi_outlined,
                title: 'Become a driver',
                subtitle: 'Earn with Rideality',
                onTap: () {
                  Navigator.of(context)
                      .pushNamed(BecomeDriverScreen.routeName);
                },
              ),
              if (widget.onboarding.canDrive ||
                  widget.onboarding.driverApproved ||
                  (me?.canDrive ?? false))
                _Tile(
                  icon: Icons.speed_rounded,
                  title: 'Driver dashboard',
                  subtitle: 'Go online and accept rides',
                  onTap: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      DriverDashboardScreen.routeName,
                      (_) => false,
                    );
                  },
                ),
              _Tile(
                icon: Icons.verified_user_outlined,
                title: 'Account status',
                subtitle: [
                  if (me?.status != null && me!.status!.isNotEmpty)
                    me.status!.replaceAll('_', ' '),
                  if (widget.onboarding.phoneVerified) 'Phone verified',
                  if (widget.onboarding.canBook || (me?.canBook ?? false))
                    'Can book',
                  if (widget.onboarding.profileComplete) 'Profile complete',
                ].join(' · ').ifEmpty('In progress'),
                onTap: null,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Log out',
                variant: AppButtonVariant.ghost,
                borderRadius: 16,
                icon: Icons.logout_rounded,
                onPressed: _logout,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.ambientShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceTint,
          child: Icon(icon, color: AppColors.secondary, size: 20),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: onTap == null
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
      ),
    );
  }
}
