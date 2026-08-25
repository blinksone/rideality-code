import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/phone_rules.dart';
import '../../models/api_models.dart';
import '../../models/phone_verification_args.dart';
import '../../services/auth_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/rideality_app_bar.dart';
import 'otp_verification_screen.dart';
import 'welcome_screen.dart';

/// Existing-user login: phone + OTP (Welcome back mock).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  List<Region> _regions = const [];
  Region? _selectedRegion;
  bool _loadingRegions = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    setState(() {
      _loadingRegions = true;
      _error = null;
    });
    try {
      final regions = await AuthApiService.instance.listRegions();
      if (!mounted) return;
      Region? selected;
      for (final r in regions) {
        if (r.code == 'PK') {
          selected = r;
          break;
        }
      }
      setState(() {
        _regions = regions;
        _selectedRegion = selected ?? (regions.isNotEmpty ? regions.first : null);
        _loadingRegions = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRegions = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRegions = false;
        _error = 'Could not load countries. Check your connection.';
      });
    }
  }

  int get _maxInputDigits {
    final range = PhoneRules.lengthFor(_selectedRegion?.code);
    return range.max + 1;
  }

  void _onRegionChanged(Region? region) {
    if (region == null) return;
    final max = PhoneRules.lengthFor(region.code).max + 1;
    final text = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _selectedRegion = region;
      if (text.length > max) {
        _phoneController.text = text.substring(0, max);
        _phoneController.selection =
            TextSelection.collapsed(offset: _phoneController.text.length);
      }
    });
  }

  Future<void> _sendCode() async {
    final region = _selectedRegion;
    if (region == null) {
      _toast('Please select a country');
      return;
    }
    final local = PhoneRules.normalizeLocal(_phoneController.text);
    final error = PhoneRules.validateLocal(local, region.code);
    if (error != null) {
      _toast(error);
      return;
    }

    final phone = AuthApiService.instance.buildPhone(region.phonePrefix, local);
    setState(() => _loading = true);
    try {
      final result = await AuthApiService.instance.sendOtp(
        phone: phone,
        regionCode: region.code,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        OtpVerificationScreen.routeName,
        arguments: PhoneVerificationArgs(
          phone: phone,
          displayPhone: phone,
          regionCode: region.code,
          devBypassCode: result.resolvedDevCode,
          intent: OnboardingIntent.login,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _createAccount() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      WelcomeScreen.routeName,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: const RidealityAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 30,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log in with your phone number to continue',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 32),
                      if (_loadingRegions)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              TextButton(
                                onPressed: _loadRegions,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _FieldShell(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Region>(
                              isExpanded: true,
                              value: _selectedRegion,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.secondary,
                              ),
                              items: _regions
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.public_rounded,
                                            color: AppColors.secondary,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              '${r.name} ${r.phonePrefix}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _onRegionChanged,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FieldShell(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(_maxInputDigits),
                            ],
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                            decoration: InputDecoration(
                              hintText: PhoneRules.hintFor(_selectedRegion?.code),
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                              prefixText: _selectedRegion == null
                                  ? null
                                  : '${_selectedRegion!.phonePrefix} ',
                              prefixStyle: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                              prefixIcon: const Icon(
                                Icons.smartphone_rounded,
                                color: AppColors.secondary,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "We'll text you a one-time code",
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!_loadingRegions && _error == null) ...[
                AppButton(
                  label: 'Send code',
                  icon: Icons.chat_bubble_outline_rounded,
                  isLoading: _loading,
                  borderRadius: 16,
                  onPressed: _sendCode,
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _createAccount,
                  child: Text(
                    'New here? Create an account',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'By continuing you agree to Rideality',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _toast('Terms will open in a browser soon'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Terms',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.secondary,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      ' & ',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    TextButton(
                      onPressed: () =>
                          _toast('Privacy will open in a browser soon'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Privacy',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.secondary,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}
