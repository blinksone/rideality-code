import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../models/api_models.dart';
import '../../services/driver_api_service.dart';
import '../../services/driver_location_tracker.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import 'passenger_dashboard_screen.dart';

/// Finishes a passenger after signup when status is [PROFILE_INCOMPLETE].
///
/// Backend completes the profile once ≥1 location is saved; email is saved via
/// PATCH /users/me. This screen collects both so the DB moves to ACTIVE.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, this.fromDashboard = false});

  static const routeName = '/complete-profile';

  final bool fromDashboard;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  bool _loadingMe = true;
  bool _saving = false;
  bool _locating = false;
  String? _loadError;
  String _fullName = '';
  String _label = 'home';
  bool _hasEmail = false;
  bool _hasLocation = false;
  UserProfile? _me;
  DriverView? _driver;
  double? _lat;
  double? _lng;

  static const _labels = [
    ('home', Icons.home_rounded),
    ('work', Icons.work_rounded),
    ('university', Icons.school_rounded),
    ('custom', Icons.place_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadingMe = true;
      _loadError = null;
    });
    try {
      // Typed sequential calls (avoid cast map that breaks after hot-reload).
      final me = await UserApiService.instance.getMe();
      final onboarding = await UserApiService.instance.getOnboarding();
      List<SavedPlace> places = const [];
      try {
        places = (await UserApiService.instance.getPassengerView()).savedPlaces;
      } catch (_) {
        // Place list is optional for prefilling; onboarding flags still apply.
      }
      DriverView? driver;
      if (onboarding.isDriver ||
          me.activeMode?.toLowerCase() == 'driver' ||
          me.canDrive) {
        try {
          driver = await DriverApiService.instance.getDriverView();
        } catch (_) {}
      }
      if (!mounted) return;

      final email = me.email?.trim() ?? '';
      SavedPlace? seed;
      for (final p in places) {
        if (p.label.toLowerCase() == 'home') {
          seed = p;
          break;
        }
      }
      seed ??= places.isNotEmpty ? places.first : null;

      setState(() {
        _me = me;
        _driver = driver;
        _fullName = me.fullName ?? '';
        _hasEmail = email.isNotEmpty;
        _hasLocation = onboarding.locationsSaved || places.isNotEmpty;
        if (email.isNotEmpty) _emailController.text = email;
        if (seed != null) {
          _label = seed.label.toLowerCase();
          _addressController.text = seed.address;
          _lat = seed.latitude;
          _lng = seed.longitude;
        }
        _loadingMe = false;
      });
      if (seed == null) {
        await _fetchCurrentLocation(silent: true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingMe = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load profile';
        _loadingMe = false;
      });
    }
  }

  Future<void> _fetchCurrentLocation({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      final pos = await DriverLocationTracker.instance.currentPosition();
      if (!mounted) return;
      if (pos == null) {
        if (!silent) {
          _toast('Turn on location and allow access to save this place.');
        }
        return;
      }
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (_addressController.text.trim().isEmpty) {
          _addressController.text =
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        }
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  bool _looksLikeEmail(String value) {
    final v = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    final address = _addressController.text.trim();
    final lat = _lat;
    final lng = _lng;

    if (!_hasEmail || email != (_me?.email ?? '')) {
      if (email.isEmpty) {
        _toast('Email is required for ride receipts');
        return;
      }
      if (!_looksLikeEmail(email)) {
        _toast('Enter a valid email address');
        return;
      }
    }

    if (!_hasLocation) {
      if (address.isEmpty || lat == null || lng == null) {
        _toast('Add an address and tap Use current location');
        return;
      }
    } else if (address.isNotEmpty && (lat == null || lng == null)) {
      _toast('Tap Use current location to set coordinates');
      return;
    }

    setState(() => _saving = true);
    try {
      // 1) Email — PATCH /users/me (status stays PROFILE_INCOMPLETE until place)
      final currentEmail = _me?.email?.trim() ?? '';
      if (email.isNotEmpty && email != currentEmail) {
        await UserApiService.instance.updateProfile(
          fullName: _fullName.isNotEmpty ? _fullName : null,
          email: email,
        );
      }

      // 2) Location — POST /users/me/locations → ACTIVE + profile_complete
      if (!_hasLocation || address.isNotEmpty) {
        if (address.isEmpty || lat == null || lng == null) {
          _toast('Add an address and tap Use current location');
          setState(() => _saving = false);
          return;
        }
        await UserApiService.instance.saveLocations(
          label: _label,
          address: address,
          latitude: lat,
          longitude: lng,
          isDefault: true,
        );
      }

      if (!mounted) return;
      _toast('Profile updated');
      _goNext();
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goNext() {
    if (widget.fromDashboard) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      PassengerDashboardScreen.routeName,
      (_) => false,
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: RidealityAppBar(
        showBack: widget.fromDashboard,
      ),
      body: SafeArea(
        child: _loadingMe
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _ErrorBody(message: _loadError!, onRetry: _load)
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!widget.fromDashboard) ...[
                                const ProgressStepper(
                                  currentStep: 4,
                                  totalSteps: 4,
                                  labels: ['Phone', 'OTP', 'Profile', 'Place'],
                                ),
                                const SizedBox(height: 28),
                              ] else
                                const SizedBox(height: 8),
                              Text(
                                'Finish your profile',
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _fullName.isNotEmpty
                                    ? 'Hi $_fullName — add email and a saved place to activate your account.'
                                    : 'Add email and a saved place to activate your account.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              _StatusChip(
                                status: _me?.status ?? 'PROFILE_INCOMPLETE',
                                complete:
                                    _me?.status?.toUpperCase() == 'ACTIVE' &&
                                        !(_driver?.isRejected ?? false) &&
                                        !(_driver?.isSuspended ?? false),
                                driverRejected: _driver?.isRejected ?? false,
                                driverSuspended: _driver?.isSuspended ?? false,
                                reason: _driver?.rejectionReason,
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Email',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              AppTextField(
                                label: 'Email',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.mail_outline_rounded,
                                required: true,
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Saved place',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Required to mark your profile complete (home / work).',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _labels.map((item) {
                                  final selected = _label == item.$1;
                                  return ChoiceChip(
                                    avatar: Icon(
                                      item.$2,
                                      size: 16,
                                      color: selected
                                          ? Colors.white
                                          : AppColors.secondary,
                                    ),
                                    label: Text(item.$1),
                                    selected: selected,
                                    onSelected: (_) =>
                                        setState(() => _label = item.$1),
                                    selectedColor: AppColors.secondary,
                                    labelStyle: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: selected
                                              ? Colors.white
                                              : AppColors.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    backgroundColor:
                                        AppColors.surfaceContainerLow,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 14),
                              AppTextField(
                                label: 'Address',
                                controller: _addressController,
                                required: true,
                                prefixIcon: Icons.location_on_outlined,
                              ),
                              const SizedBox(height: 14),
                              AppButton(
                                label: _lat == null
                                    ? 'Use current location'
                                    : 'Update current location',
                                icon: Icons.my_location_rounded,
                                variant: AppButtonVariant.secondary,
                                isLoading: _locating,
                                borderRadius: 14,
                                onPressed: _locating
                                    ? null
                                    : () => _fetchCurrentLocation(),
                              ),
                              if (_lat != null && _lng != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Location set · ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ] else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'We’ll use your GPS — no need to type coordinates.',
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                        child: Column(
                          children: [
                            AppButton(
                              label: 'Save & continue',
                              icon: Icons.check_rounded,
                              isLoading: _saving,
                              onPressed: _save,
                            ),
                            if (widget.fromDashboard) ...[
                              const SizedBox(height: 10),
                              AppButton(
                                label: 'Not now',
                                variant: AppButtonVariant.ghost,
                                borderRadius: 14,
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.complete,
    this.driverRejected = false,
    this.driverSuspended = false,
    this.reason,
  });

  final String status;
  final bool complete;
  final bool driverRejected;
  final bool driverSuspended;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final rejected = driverRejected ||
        status.toUpperCase() == 'REJECTED' ||
        status.toUpperCase() == 'DECLINED';
    final suspended =
        driverSuspended || status.toUpperCase() == 'SUSPENDED';
    final color = rejected || suspended
        ? AppColors.error
        : complete
            ? AppColors.success
            : const Color(0xFFE65100);
    final title = rejected
        ? 'Driver application rejected'
        : suspended
            ? 'Driver account suspended'
            : complete
                ? 'Account active'
                : 'Status: ${status.replaceAll('_', ' ')} — finish email & place';
    final detail = (rejected || suspended) &&
            reason != null &&
            reason!.trim().isNotEmpty
        ? reason!.trim()
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected || suspended
                ? Icons.gpp_bad_rounded
                : complete
                    ? Icons.verified_rounded
                    : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          height: 1.35,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
