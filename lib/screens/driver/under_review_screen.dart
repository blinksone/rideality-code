import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../models/api_models.dart';
import '../../services/driver_api_service.dart';
import '../../services/onboarding_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import '../passenger/passenger_dashboard_screen.dart';
import 'driver_dashboard_screen.dart';

class UnderReviewScreen extends StatefulWidget {
  const UnderReviewScreen({super.key});

  static const routeName = '/under-review';

  @override
  State<UnderReviewScreen> createState() => _UnderReviewScreenState();
}

class _UnderReviewScreenState extends State<UnderReviewScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  OnboardingStatus _onboarding = OnboardingStatus.empty;
  DriverView? _driver;
  String? _error;

  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        OnboardingApiService.instance.getStatus(),
        DriverApiService.instance.getDriverView(),
      ]);
      if (!mounted) return;
      setState(() {
        _onboarding = results[0] as OnboardingStatus;
        _driver = results[1] as DriverView;
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
        _error = 'Failed to load application status';
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    return switch (status) {
      'approved' => AppColors.success,
      'rejected' || 'suspended' => AppColors.error,
      'pending_review' => AppColors.amber,
      _ => AppColors.secondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _driver?.onboardingStatus ?? 'pending_review';
    final color = _statusColor(status);
    final approved = status == 'approved';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const RidealityAppBar(showBack: true),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: AppColors.secondary,
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                  child: FadeTransition(
                    opacity:
                        CurvedAnimation(parent: _anim, curve: Curves.easeOut),
                    child: Column(
                      children: [
                        const ProgressStepper(
                          currentStep: 5,
                          totalSteps: 5,
                          labels: [
                            'Phone',
                            'OTP',
                            'Identity',
                            'Vehicle',
                            'Docs',
                          ],
                        ),
                        const SizedBox(height: 28),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ScaleTransition(
                          scale: Tween<double>(begin: 0.7, end: 1).animate(
                            CurvedAnimation(
                              parent: _anim,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.32),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              approved
                                  ? Icons.verified_rounded
                                  : Icons.hourglass_top_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            status.replaceAll('_', ' ').toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          approved
                              ? "You're approved!"
                              : 'Application submitted',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          approved
                              ? "Switch to driver mode and go online when you're ready."
                              : 'We usually review documents within 24–48 hours. Pull down to refresh.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _StatusRow(
                                title: 'Phone verified',
                                subtitle: _onboarding.phoneVerified
                                    ? 'Linked'
                                    : 'Pending',
                                done: _onboarding.phoneVerified,
                              ),
                              const Divider(height: 1),
                              _StatusRow(
                                title: 'Identity',
                                subtitle: _onboarding.personalInfo
                                    ? 'Saved'
                                    : 'Pending',
                                done: _onboarding.personalInfo,
                              ),
                              const Divider(height: 1),
                              _StatusRow(
                                title: 'Vehicle',
                                subtitle: _driver?.vehicleModel != null
                                    ? '${_driver!.vehicleModel} · ${_driver!.numberPlate ?? ''}'
                                    : 'Pending',
                                done: _onboarding.vehicleInfo ||
                                    (_driver?.vehicleModel?.isNotEmpty ??
                                        false),
                              ),
                              const Divider(height: 1),
                              _StatusRow(
                                title: 'Documents',
                                subtitle: _onboarding.documentsUploaded
                                    ? (approved
                                        ? 'Approved'
                                        : 'Under review')
                                    : 'Upload required',
                                done: _onboarding.documentsUploaded && approved,
                                pending: _onboarding.documentsUploaded &&
                                    !approved,
                              ),
                              const Divider(height: 1),
                              _StatusRow(
                                title: 'Final approval',
                                subtitle: approved || _onboarding.driverApproved
                                    ? 'Driver approved'
                                    : 'Awaiting admin validation',
                                done: approved || _onboarding.driverApproved,
                                locked: !_onboarding.documentsUploaded,
                              ),
                            ],
                          ),
                        ),
                        if (_onboarding.pendingSteps.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Pending: ${_onboarding.pendingSteps.join(', ')}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                        const SizedBox(height: 28),
                        if (approved || _onboarding.driverApproved ||
                            _onboarding.canDrive)
                          AppButton(
                            label: 'Open driver dashboard',
                            icon: Icons.speed_rounded,
                            borderRadius: 14,
                            onPressed: () {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                DriverDashboardScreen.routeName,
                                (route) => false,
                              );
                            },
                          )
                        else
                          AppButton(
                            label: 'Back to home',
                            icon: Icons.home_rounded,
                            borderRadius: 14,
                            onPressed: () {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                PassengerDashboardScreen.routeName,
                                (route) => false,
                              );
                            },
                          ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Refresh status',
                          variant: AppButtonVariant.secondary,
                          icon: Icons.refresh_rounded,
                          borderRadius: 14,
                          onPressed: _load,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.title,
    required this.subtitle,
    required this.done,
    this.pending = false,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool pending;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final Color iconBg;
    final Color iconColor;
    final IconData icon;

    if (locked && !done) {
      icon = Icons.lock_rounded;
      iconBg = AppColors.surfaceContainerLow;
      iconColor = AppColors.onSurfaceVariant;
    } else if (pending) {
      icon = Icons.sync_rounded;
      iconBg = AppColors.amber.withValues(alpha: 0.15);
      iconColor = AppColors.amber;
    } else if (done) {
      icon = Icons.check_rounded;
      iconBg = AppColors.successSoft;
      iconColor = AppColors.success;
    } else {
      icon = Icons.radio_button_unchecked;
      iconBg = AppColors.surfaceContainerLow;
      iconColor = AppColors.onSurfaceVariant;
    }

    return Opacity(
      opacity: locked && !done ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
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
            Text(
              done
                  ? 'Done'
                  : pending
                      ? 'Review'
                      : locked
                          ? 'Locked'
                          : 'Pending',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: done
                        ? AppColors.success
                        : pending
                            ? AppColors.amber
                            : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
