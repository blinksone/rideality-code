import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../models/api_models.dart';
import '../../services/driver_api_service.dart';
import '../../services/onboarding_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import '../passenger/passenger_dashboard_screen.dart';
import 'documents_upload_screen.dart';
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
  List<DriverDocument> _documents = const [];
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
      final status = OnboardingApiService.instance.getStatus();
      final driver = DriverApiService.instance.getDriverView();
      List<DriverDocument> docs = const [];
      try {
        docs = await DriverApiService.instance.listDocuments();
      } catch (_) {}
      final results = await Future.wait([status, driver]);
      if (!mounted) return;
      setState(() {
        _onboarding = results[0] as OnboardingStatus;
        _driver = results[1] as DriverView;
        _documents = docs;
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

  String _docLabel(String type) {
    return switch (type) {
      'driver_license' => 'Driver license',
      'national_id' => 'National ID',
      'selfie' => 'Selfie',
      'vehicle_registration' => 'Registration',
      'vehicle_insurance' => 'Insurance',
      _ => type.replaceAll('_', ' '),
    };
  }

  String _friendlyPending(List<String> steps) {
    const labels = {
      'vehicle_info': 'vehicle',
      'documents_uploaded': 'documents',
      'driver_approved': 'city fleet approval',
      'personal_info': 'identity',
    };
    final names = steps
        .map((s) => labels[s] ?? s.replaceAll('_', ' '))
        .toSet()
        .toList();
    if (names.isEmpty) return '';
    return 'Still needed: ${names.join(', ')}';
  }

  Color _statusColor(String status) {
    return switch (status) {
      'approved' || 'active' => AppColors.success,
      'rejected' || 'suspended' || 'declined' || 'denied' => AppColors.error,
      'pending_review' => AppColors.amber,
      _ => AppColors.secondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = (_driver?.onboardingStatus ?? 'pending_review').toLowerCase();
    final color = _statusColor(status);
    final approved = status == 'approved' || status == 'active';
    final rejected = status == 'rejected' ||
        status == 'declined' ||
        status == 'denied' ||
        (_driver?.isRejected ?? false);
    final suspended = status == 'suspended' || (_driver?.isSuspended ?? false);
    final rejectedDocs =
        _documents.where((d) => d.needsResubmission).toList();
    final needsDocReupload = rejectedDocs.isNotEmpty;
    final reasons = <String>[
      if (_driver?.rejectionReason != null &&
          _driver!.rejectionReason!.trim().isNotEmpty)
        _driver!.rejectionReason!.trim(),
      for (final d in rejectedDocs)
        if (d.rejectionReason != null && d.rejectionReason!.trim().isNotEmpty)
          '${_docLabel(d.type)}: ${d.rejectionReason!.trim()}',
    ];
    final reason = reasons.toSet().join('\n');
    final headline = approved
        ? "You're approved!"
        : rejected
            ? 'Your application was rejected'
            : needsDocReupload
                ? 'Some documents were rejected'
            : suspended
                ? 'Your driver account is suspended'
                : 'Waiting for your city fleet to approve you.';
    final subtitle = approved
        ? "Switch to driver mode and go online when you're ready."
        : rejected || needsDocReupload
            ? 'Fix the issues below and re-upload your documents.'
            : suspended
                ? 'Contact your city fleet if you think this is a mistake.'
                : 'Regional fleet reviews your documents. Pull down to refresh.';

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
                                  : rejected || suspended
                                      ? Icons.gpp_bad_rounded
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
                          headline,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                        ),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reason',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: AppColors.onErrorContainer,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reason,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.onErrorContainer,
                                        height: 1.4,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (rejectedDocs.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppColors.ambientShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Re-upload required',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                ...rejectedDocs.map(
                                  (d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _docLabel(d.type),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              if (d.rejectionReason != null &&
                                                  d.rejectionReason!
                                                      .trim()
                                                      .isNotEmpty)
                                                Text(
                                                  d.rejectionReason!.trim(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: AppColors.error,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pushNamed(
                                              DocumentsUploadScreen.routeName,
                                            );
                                          },
                                          child: const Text('Re-upload'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        FutureBuilder<List<String?>>(
                          future: Future.wait([
                            DashboardPrefs.instance.fleetCompanyName,
                            DashboardPrefs.instance.fleetCityName,
                          ]),
                          builder: (context, snap) {
                            final company = snap.data?[0];
                            final city = snap.data?[1];
                            if ((company == null || company.isEmpty) &&
                                (city == null || city.isEmpty)) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                [
                                  if (company != null && company.isNotEmpty)
                                    company,
                                  if (city != null && city.isNotEmpty) city,
                                ].join(' · '),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            );
                          },
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
                                subtitle: _driver?.vehicleModel != null &&
                                        _driver!.vehicleModel!.isNotEmpty
                                    ? '${_driver!.vehicleModel} · ${_driver!.numberPlate ?? ''}'
                                    : 'Optional — add later',
                                done: _onboarding.vehicleInfo ||
                                    (_driver?.vehicleModel?.isNotEmpty ??
                                        false),
                              ),
                              const Divider(height: 1),
                              _StatusRow(
                                title: 'Documents',
                                subtitle: rejectedDocs.isNotEmpty
                                    ? (reason.isNotEmpty
                                        ? 'Rejected — $reason'
                                        : 'Reupload')
                                    : _onboarding.documentStatusLabel,
                                done: _onboarding.documentsApproved &&
                                    rejectedDocs.isEmpty,
                                pending: _onboarding.documentsPendingReview &&
                                    rejectedDocs.isEmpty,
                                rejected: _onboarding.documentsNeedReupload ||
                                    rejectedDocs.isNotEmpty,
                              ),
                              const Divider(height: 1),
                              _StatusRow(
                                title: 'Final approval',
                                subtitle: approved || _onboarding.driverApproved
                                    ? 'Driver approved'
                                    : rejected || suspended
                                        ? (reason.isNotEmpty
                                            ? reason
                                            : 'Rejected by your city fleet')
                                        : needsDocReupload
                                            ? 'Waiting — re-upload rejected documents first'
                                        : 'Waiting for your city fleet to approve you.',
                                done: approved || _onboarding.driverApproved,
                                rejected: rejected || suspended,
                                pending: needsDocReupload && !rejected && !suspended,
                                locked: !_onboarding.documentsUploaded &&
                                    !_onboarding.documentsApproved &&
                                    !rejected &&
                                    !suspended &&
                                    !needsDocReupload,
                              ),
                            ],
                          ),
                        ),
                        if (!rejected &&
                            !suspended &&
                            _onboarding.pendingSteps.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            _friendlyPending(_onboarding.pendingSteps),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                        const SizedBox(height: 28),
                        if (rejected || needsDocReupload) ...[
                          AppButton(
                            label: needsDocReupload && !rejected
                                ? 'Re-upload rejected documents'
                                : 'Re-upload documents',
                            icon: Icons.upload_rounded,
                            borderRadius: 14,
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                DocumentsUploadScreen.routeName,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (approved ||
                            (!rejected &&
                                !suspended &&
                                (_onboarding.driverApproved ||
                                    _onboarding.canDrive)))
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
    this.rejected = false,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool pending;
  final bool locked;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final Color iconBg;
    final Color iconColor;
    final IconData icon;

    if (rejected) {
      icon = Icons.close_rounded;
      iconBg = AppColors.errorContainer;
      iconColor = AppColors.error;
    } else if (locked && !done) {
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
              rejected
                  ? 'Rejected'
                  : done
                      ? 'Done'
                      : pending
                          ? 'Review'
                          : locked
                              ? 'Locked'
                              : 'Pending',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: rejected
                        ? AppColors.error
                        : done
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
