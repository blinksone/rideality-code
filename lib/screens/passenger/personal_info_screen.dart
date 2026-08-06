import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../services/image_picker_service.dart';
import '../../services/onboarding_api_service.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/profile_photo_picker.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import 'complete_profile_screen.dart';
import 'passenger_dashboard_screen.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  static const routeName = '/personal-info';

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _dob;
  String? _gender;
  bool _loading = false;
  bool _uploadingPhoto = false;
  PickedImageFile? _profilePhoto;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 22),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSourceChoice>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _ImageSourceSheet(),
    );
    if (source == null || !mounted) return;

    final picked = source == ImageSourceChoice.camera
        ? await ImagePickerService.instance.pickFromCamera()
        : await ImagePickerService.instance.pickFromGallery();
    if (picked == null || !mounted) return;

    setState(() {
      _profilePhoto = picked;
      _uploadingPhoto = true;
    });

    try {
      await UserApiService.instance.uploadPhoto(picked.file.path);
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _toast('Full name is required (min 2 characters)');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await OnboardingApiService.instance.completePassenger(
        fullName: name,
        email: _emailController.text.trim(),
        dateOfBirth: _dob == null ? null : _formatDate(_dob!),
        gender: _gender,
        acceptTerms: true,
        acceptPrivacy: true,
      );
      if (!mounted) return;

      // Always finish email + place after name (PROFILE_INCOMPLETE).
      final needsFinish = !result.onboarding.profileComplete ||
          !result.onboarding.locationsSaved ||
          result.onboarding.pendingSteps.contains('locations_saved') ||
          _emailController.text.trim().isEmpty;

      // MaterialPageRoute avoids named-route misses after hot-reload.
      final next = needsFinish
          ? const CompleteProfileScreen()
          : const PassengerDashboardScreen();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // Friendlier toast if backend path is wrong/stale.
      final msg = e.message.toLowerCase().contains('route not found')
          ? 'Could not save profile. Pull to stop app and run a full restart (not hot reload).'
          : e.message;
      _toast(msg);
    } catch (e) {
      if (!mounted) return;
      _toast('Could not continue: $e');
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
                      totalSteps: 4,
                      labels: ['Phone', 'OTP', 'Profile', 'Place'],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Tell us about you',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your name unlocks booking. Next you’ll add email and a place to activate the account.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: ProfilePhotoPicker(
                        image: _profilePhoto,
                        isUploading: _uploadingPhoto,
                        onPick: _pickProfilePhoto,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      label: 'Full name',
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      prefixIcon: Icons.person_outline_rounded,
                      required: true,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Email (optional)',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of birth (optional)',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        child: Text(
                          _dob == null ? 'Select date' : _formatDate(_dob!),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: _dob == null
                                    ? AppColors.onSurfaceVariant
                                    : AppColors.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Gender (optional)',
                        prefixIcon: Icon(Icons.people_outline_rounded),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          isDense: true,
                          value: _gender,
                          hint: Text(
                            'Prefer not to say',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.onSurfaceVariant,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: AppButton(
                label: 'Continue',
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

enum ImageSourceChoice { gallery, camera }

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSourceChoice.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSourceChoice.camera),
            ),
          ],
        ),
      ),
    );
  }
}
