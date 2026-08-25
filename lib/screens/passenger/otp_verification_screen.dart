import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../models/phone_verification_args.dart';
import '../../services/auth_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/otp_input.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.args});

  static const routeName = '/otp';

  final PhoneVerificationArgs args;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  bool _loading = false;
  bool _resending = false;
  String _otp = '';
  String? _devHint;

  bool get _isDriver => widget.args.intent == OnboardingIntent.driver;
  bool get _isLogin => widget.args.intent == OnboardingIntent.login;

  @override
  void initState() {
    super.initState();
    _devHint = widget.args.devBypassCode;
  }

  Future<void> _verify() async {
    if (_otp.length < 4) {
      _toast('Enter the verification code');
      return;
    }

    setState(() => _loading = true);
    try {
      final session = await AuthApiService.instance.verifyOtp(
        phone: widget.args.phone,
        code: _otp,
        regionCode: widget.args.regionCode,
        countryRegionId: widget.args.countryRegionId,
      );
      if (!mounted) return;

      try {
        await AuthApiService.instance.recordConsent();
      } catch (_) {}

      if (!mounted) return;

      // Persist onboarding intent so cold-start restoration keeps the right flow
      // even if user abandons before completing onboarding.
      await TokenStorage.instance.setPendingOnboardingIntent(
        widget.args.intent == OnboardingIntent.login ? null : widget.args.intent.name,
      );
      if (!mounted) return;

      final route = nextRouteAfterOtp(
        session.user.onboarding,
        isNewUser: session.isNewUser,
        intent: widget.args.intent,
        activeMode: session.user.activeMode,
        userStatus: session.user.status,
      );
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      final result = await AuthApiService.instance.sendOtp(
        phone: widget.args.phone,
        regionCode: widget.args.regionCode,
      );
      if (!mounted) return;
      setState(() => _devHint = result.resolvedDevCode);
      _toast(
        result.resolvedDevCode != null
            ? 'Code resent (dev: ${result.resolvedDevCode})'
            : 'Code resent',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const RidealityAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
          child: Column(
            children: [
              if (!_isLogin)
                ProgressStepper(
                  currentStep: 2,
                  totalSteps: _isDriver ? 5 : 4,
                  labels: _isDriver
                      ? const ['Phone', 'OTP', 'Identity', 'Vehicle', 'Docs']
                      : const ['Phone', 'OTP', 'Profile', 'Place'],
                )
              else
                const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: _isLogin ? 20 : 36,
                    bottom: 16,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          color: AppColors.secondary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _isLogin ? 'Verify it’s you' : 'Enter verification code',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sent to ${widget.args.displayPhone}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                      if (_devHint != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.devBadge,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Dev OTP: $_devHint',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.devBadgeText,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      OtpInput(
                        length: 6,
                        onChanged: (value) => _otp = value,
                        onCompleted: (_) => _verify(),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: _resending ? null : _resend,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: _resending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Resend code',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              AppButton(
                label: 'Verify & continue',
                icon: Icons.verified_rounded,
                isLoading: _loading,
                borderRadius: 14,
                onPressed: _verify,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Change number',
                variant: AppButtonVariant.ghost,
                borderRadius: 14,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
