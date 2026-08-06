import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../services/onboarding_api_service.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import 'vehicle_details_screen.dart';

class BecomeDriverScreen extends StatefulWidget {
  const BecomeDriverScreen({super.key});

  static const routeName = '/become-driver';

  @override
  State<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

class _BecomeDriverScreenState extends State<BecomeDriverScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseController = TextEditingController();
  DateTime? _dob;
  DateTime? _licenseExpiry;
  bool _loading = false;
  bool _acceptTerms = true;

  static const _labels = ['Phone', 'OTP', 'Identity', 'Vehicle', 'Docs'];

  @override
  void initState() {
    super.initState();
    _prefillName();
  }

  Future<void> _prefillName() async {
    try {
      final me = await UserApiService.instance.getMe();
      if (!mounted) return;
      if (me.fullName != null && me.fullName!.isNotEmpty) {
        _nameController.text = me.fullName!;
      }
      if (me.email != null && me.email!.isNotEmpty) {
        _emailController.text = me.email!;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isAdult(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of birth (must be 18+)',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiry ?? DateTime(now.year + 2),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
      helpText: 'License expiry',
    );
    if (picked != null) setState(() => _licenseExpiry = picked);
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _toast('Full name is required');
      return;
    }
    if (_dob == null) {
      _toast('Date of birth is required for drivers (18+)');
      return;
    }
    if (!_isAdult(_dob!)) {
      _toast('You must be at least 18 years old');
      return;
    }
    if (!_acceptTerms) {
      _toast('Please accept Terms & Privacy to continue');
      return;
    }

    setState(() => _loading = true);
    try {
      await OnboardingApiService.instance.completeDriver(
        fullName: name,
        dateOfBirth: _fmt(_dob!),
        email: _emailController.text.trim(),
        licenseNumber: _licenseController.text.trim().isEmpty
            ? null
            : _licenseController.text.trim(),
        licenseExpiry: _licenseExpiry == null ? null : _fmt(_licenseExpiry!),
        profession: 'driver',
        acceptTerms: true,
        acceptPrivacy: true,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed(VehicleDetailsScreen.routeName);
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ProgressStepper(
                      currentStep: 3,
                      totalSteps: 5,
                      labels: _labels,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Driver identity',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Full name and date of birth (18+) are required to drive with Rideality.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.route_rounded,
                              color: AppColors.secondary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Next: vehicle details → documents → admin approval.',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      label: 'Full name',
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      prefixIcon: Icons.person_outline_rounded,
                      required: true,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of birth *',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        child: Text(
                          _dob == null ? 'Select date (18+)' : _fmt(_dob!),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _dob == null
                                        ? AppColors.onSurfaceVariant
                                        : AppColors.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Email (optional)',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'License number (optional)',
                      controller: _licenseController,
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickExpiry,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'License expiry (optional)',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                        child: Text(
                          _licenseExpiry == null
                              ? 'Select date'
                              : _fmt(_licenseExpiry!),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _licenseExpiry == null
                                        ? AppColors.onSurfaceVariant
                                        : AppColors.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _acceptTerms,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.secondary,
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: Text(
                        'I accept Terms of Service & Privacy Policy',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      onChanged: (v) =>
                          setState(() => _acceptTerms = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: AppButton(
                label: 'Continue to vehicle',
                icon: Icons.arrow_forward_rounded,
                isLoading: _loading,
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
