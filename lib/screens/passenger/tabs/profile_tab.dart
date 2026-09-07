import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../models/api_models.dart';
import '../../../services/auth_api_service.dart';
import '../../../services/driver_api_service.dart';
import '../../../services/user_api_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/network_avatar.dart';
import '../../driver/documents_upload_screen.dart';
import '../../driver/become_driver_screen.dart';
import '../../driver/driver_dashboard_screen.dart';
import '../../driver/under_review_screen.dart';
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
  DriverView? _driver;
  List<DriverDocument> _rejectedDocs = const [];
  late final TextEditingController _name;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.profile?.fullName ?? widget.passenger.fullName,
    );
    _email = TextEditingController(text: widget.profile?.email ?? '');
    _loadDriver();
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

  bool get _driverRejected =>
      (_driver?.isRejected ?? false) || (_driver?.isSuspended ?? false);

  bool get _needsDocReupload => _rejectedDocs.isNotEmpty;

  Future<void> _loadDriver() async {
    if (!widget.onboarding.isDriver) {
      if (_driver != null || _rejectedDocs.isNotEmpty) {
        setState(() {
          _driver = null;
          _rejectedDocs = const [];
        });
      }
      return;
    }
    try {
      final driver = await DriverApiService.instance.getDriverView();
      var rejected = const <DriverDocument>[];
      try {
        final docs = await DriverApiService.instance.listDocuments();
        rejected = docs.where((d) => d.needsResubmission).toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _driver = driver;
        _rejectedDocs = rejected;
      });
    } catch (_) {}
  }

  Future<void> _refresh() async {
    await widget.onRefresh();
    await _loadDriver();
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

  String _driverApplicationSubtitle() {
    if (_needsDocReupload) {
      final labels = _rejectedDocs
          .map((d) => switch (d.type) {
                'selfie' => 'Selfie',
                'driver_license' => 'License',
                'national_id' => 'National ID',
                _ => d.type.replaceAll('_', ' '),
              })
          .toSet()
          .join(', ');
      final reason = _rejectedDocs.first.rejectionReason?.trim();
      if (reason != null && reason.isNotEmpty) {
        return 'Re-upload $labels — $reason';
      }
      return 'Re-upload rejected: $labels';
    }
    final driver = _driver;
    if (driver == null) {
      return 'Waiting for your city fleet to approve you.';
    }
    if (driver.isRejected) {
      final reason = driver.rejectionReason?.trim();
      if (reason != null && reason.isNotEmpty) {
        return 'Rejected — $reason';
      }
      return 'Rejected by your city fleet';
    }
    if (driver.isSuspended) {
      final reason = driver.rejectionReason?.trim();
      if (reason != null && reason.isNotEmpty) {
        return 'Suspended — $reason';
      }
      return 'Driver account suspended';
    }
    if (driver.isApproved) return 'Approved — open driver dashboard';
    return 'Waiting for your city fleet to approve you.';
  }

  String _accountStatusSubtitle(UserProfile? me) {
    final riderStatus = (me?.status ?? '').trim();
    final parts = <String>[];
    if (_driver?.isRejected ?? false) {
      parts.add('Driver rejected');
    } else if (_driver?.isSuspended ?? false) {
      parts.add('Driver suspended');
    }
    if (riderStatus.isNotEmpty) {
      parts.add('Rider ${riderStatus.replaceAll('_', ' ')}');
    }
    if (widget.onboarding.phoneVerified) parts.add('Phone verified');
    if (widget.onboarding.canBook || (me?.canBook ?? false)) {
      parts.add('Can book');
    }
    if (widget.onboarding.profileComplete) parts.add('Profile complete');
    return parts.join(' · ').ifEmpty('In progress');
  }

  Future<void> _logout() async {
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
        onRefresh: _refresh,
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
              if (!widget.onboarding.isDriver)
                _Tile(
                  icon: Icons.local_taxi_outlined,
                  title: 'Become a driver',
                  subtitle: 'Earn with Rideality',
                  onTap: () {
                    Navigator.of(context)
                        .pushNamed(BecomeDriverScreen.routeName);
                  },
                ),
              if (!_driverRejected &&
                  (widget.onboarding.canDrive ||
                      widget.onboarding.driverApproved ||
                      (me?.canDrive ?? false)))
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
                )
              else if (widget.onboarding.isDriver)
                _Tile(
                  icon: _needsDocReupload
                      ? Icons.upload_rounded
                      : (_driver?.isRejected ?? false) ||
                              (_driver?.isSuspended ?? false)
                          ? Icons.gpp_bad_rounded
                          : Icons.hourglass_top_rounded,
                  title: _needsDocReupload
                      ? 'Re-upload documents'
                      : 'Driver application',
                  subtitle: _driverApplicationSubtitle(),
                  onTap: () {
                    if (_needsDocReupload) {
                      Navigator.of(context).pushNamed(
                        DocumentsUploadScreen.routeName,
                      ).then((_) => _loadDriver());
                      return;
                    }
                    Navigator.of(context)
                        .pushNamed(UnderReviewScreen.routeName)
                        .then((_) => _loadDriver());
                  },
                ),
              _Tile(
                icon: Icons.verified_user_outlined,
                title: 'Account status',
                subtitle: _accountStatusSubtitle(me),
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
