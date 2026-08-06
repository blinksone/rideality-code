import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../models/api_models.dart';
import '../../models/phone_verification_args.dart';
import '../../services/auth_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import 'otp_verification_screen.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({
    super.key,
    this.intent = OnboardingIntent.passenger,
  });

  static const routeName = '/phone';

  final OnboardingIntent intent;

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final _phoneController = TextEditingController();
  List<Region> _regions = const [];
  Region? _selectedRegion;
  bool _loadingRegions = true;
  bool _loading = false;
  String? _error;

  bool get _isDriver => widget.intent == OnboardingIntent.driver;

  static const _passengerLabels = ['Phone', 'OTP', 'Profile', 'Place'];
  static const _driverLabels = ['Phone', 'OTP', 'Identity', 'Vehicle', 'Docs'];

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
      setState(() {
        _regions = regions;
        Region? selected;
        for (final r in regions) {
          if (r.code == 'PK') {
            selected = r;
            break;
          }
        }
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
        _error = 'Could not load regions. Check your connection.';
      });
    }
  }

  Future<void> _continue() async {
    final region = _selectedRegion;
    final local = _phoneController.text.trim();
    if (region == null) {
      _toast('Please select a region');
      return;
    }
    if (local.replaceAll(RegExp(r'\D'), '').length < 7) {
      _toast('Enter a valid phone number');
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
          intent: widget.intent,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const RidealityAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProgressStepper(
                currentStep: 1,
                totalSteps: _isDriver ? 5 : 4,
                labels: _isDriver ? _driverLabels : _passengerLabels,
              ),
              const SizedBox(height: 32),
              Text(
                "What's your number?",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _isDriver
                    ? "We'll text a one-time code to verify you as a driver."
                    : "We'll text a one-time code so we know it's really you.",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 28),
              if (_loadingRegions)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 40,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(onPressed: _loadRegions, child: const Text('Retry')),
                    ],
                  ),
                )
              else ...[
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Country / region',
                    prefixIcon: Icon(Icons.public_rounded),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Region>(
                      isExpanded: true,
                      isDense: true,
                      value: _selectedRegion,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.onSurfaceVariant,
                      ),
                      items: _regions
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                '${r.name} ${r.phonePrefix}',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRegion = v),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Use your WhatsApp / SMS number for ${_selectedRegion?.name ?? 'your region'}.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                AppButton(
                  label: 'Send code',
                  icon: Icons.sms_outlined,
                  isLoading: _loading,
                  onPressed: _continue,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
