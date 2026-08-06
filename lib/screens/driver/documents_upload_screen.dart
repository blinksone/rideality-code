import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../services/driver_api_service.dart';
import '../../services/image_picker_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import 'under_review_screen.dart';

class DocumentsUploadScreen extends StatefulWidget {
  const DocumentsUploadScreen({super.key});

  static const routeName = '/documents';

  @override
  State<DocumentsUploadScreen> createState() => _DocumentsUploadScreenState();
}

class _DocumentsUploadScreenState extends State<DocumentsUploadScreen> {
  PickedImageFile? _license;
  PickedImageFile? _selfie;
  PickedImageFile? _nationalId;
  DateTime? _licenseExpiry;
  bool _loading = false;
  String? _uploadingKey;
  bool _licenseRegistered = false;
  bool _selfieRegistered = false;
  bool _idRegistered = false;

  static const _labels = ['Phone', 'OTP', 'Identity', 'Vehicle', 'Docs'];

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiry ?? DateTime(now.year + 3),
      firstDate: now,
      lastDate: DateTime(now.year + 40),
      helpText: 'License expiry date',
    );
    if (picked != null) setState(() => _licenseExpiry = picked);
  }

  Future<void> _pickAndRegister({
    required String key,
    required String type,
    required bool useCamera,
    String? expiresAt,
  }) async {
    setState(() => _uploadingKey = key);
    try {
      final picked =
          await ImagePickerService.instance.pickDocument(useCamera: useCamera);
      if (picked == null || !mounted) return;

      setState(() {
        switch (key) {
          case 'license':
            _license = picked;
          case 'selfie':
            _selfie = picked;
          case 'id':
            _nationalId = picked;
        }
      });

      await DriverApiService.instance.uploadAndRegisterDocument(
        type: type,
        filePath: picked.file.path,
        expiresAt: expiresAt,
      );

      if (!mounted) return;
      setState(() {
        switch (key) {
          case 'license':
            _licenseRegistered = true;
          case 'selfie':
            _selfieRegistered = true;
          case 'id':
            _idRegistered = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type.replaceAll('_', ' ')} uploaded')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploadingKey = null);
    }
  }

  Future<void> _submit() async {
    if (!_licenseRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver license is required')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (!mounted) return;
      Navigator.of(context).pushNamed(UnderReviewScreen.routeName);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                      currentStep: 5,
                      totalSteps: 5,
                      labels: _labels,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Upload documents',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Driver license is required. Selfie is recommended for faster review.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: _pickExpiry,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'License expiry (recommended)',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                        child: Text(
                          _licenseExpiry == null
                              ? 'Select expiry date'
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
                    const SizedBox(height: 16),
                    _DocumentCard(
                      icon: Icons.badge_outlined,
                      title: 'Driver license',
                      description:
                          'Required — front of your license, clearly visible.',
                      badge: 'Required',
                      badgeColor: AppColors.errorContainer,
                      badgeTextColor: AppColors.onErrorContainer,
                      accent: true,
                      image: _license,
                      registered: _licenseRegistered,
                      actionLabel: _licenseRegistered ? 'Uploaded' : 'Upload',
                      actionIcon: Icons.upload_rounded,
                      filledAction: true,
                      isLoading: _uploadingKey == 'license',
                      onAction: () => _pickAndRegister(
                        key: 'license',
                        type: 'driver_license',
                        useCamera: false,
                        expiresAt: _licenseExpiry == null
                            ? null
                            : _fmt(_licenseExpiry!),
                      ),
                      onRemove: () => setState(() {
                        _license = null;
                        _licenseRegistered = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _DocumentCard(
                      icon: Icons.photo_camera_outlined,
                      title: 'Selfie',
                      description:
                          'Recommended for KYC. Hold phone at eye level.',
                      badge: 'Recommended',
                      badgeColor: AppColors.surfaceContainer,
                      badgeTextColor: AppColors.onSurfaceVariant,
                      image: _selfie,
                      registered: _selfieRegistered,
                      actionLabel:
                          _selfieRegistered ? 'Uploaded' : 'Take photo',
                      actionIcon: Icons.camera_alt_rounded,
                      isLoading: _uploadingKey == 'selfie',
                      onAction: () => _pickAndRegister(
                        key: 'selfie',
                        type: 'selfie',
                        useCamera: true,
                      ),
                      onRemove: () => setState(() {
                        _selfie = null;
                        _selfieRegistered = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _DocumentCard(
                      icon: Icons.credit_card_outlined,
                      title: 'National ID',
                      description: 'Optional — can speed up review.',
                      badge: 'Optional',
                      badgeColor: null,
                      badgeTextColor: AppColors.onSurfaceVariant,
                      image: _nationalId,
                      registered: _idRegistered,
                      actionLabel: _idRegistered ? 'Uploaded' : 'Add',
                      actionIcon: Icons.add_rounded,
                      textOnlyAction: true,
                      isLoading: _uploadingKey == 'id',
                      onAction: () => _pickAndRegister(
                        key: 'id',
                        type: 'national_id',
                        useCamera: false,
                      ),
                      onRemove: () => setState(() {
                        _nationalId = null;
                        _idRegistered = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _licenseRegistered
                            ? 'License registered — ready for review'
                            : 'Upload your driver license to continue',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _licenseRegistered
                                  ? AppColors.success
                                  : AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
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
                label: 'Submit for review',
                icon:
                    _licenseRegistered ? Icons.send_rounded : Icons.lock_rounded,
                isLoading: _loading,
                onPressed: _licenseRegistered ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.image,
    required this.registered,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.onRemove,
    this.accent = false,
    this.filledAction = false,
    this.textOnlyAction = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String badge;
  final Color? badgeColor;
  final Color badgeTextColor;
  final PickedImageFile? image;
  final bool registered;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final VoidCallback onRemove;
  final bool accent;
  final bool filledAction;
  final bool textOnlyAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final uploaded = image != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent
              ? AppColors.secondary.withValues(alpha: 0.3)
              : AppColors.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent
                        ? AppColors.secondary.withValues(alpha: 0.1)
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color:
                        accent ? AppColors.secondary : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (badgeColor != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                badge.toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: badgeTextColor,
                                      letterSpacing: 0.3,
                                    ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 8),
                            Text(
                              badge.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: badgeTextColor.withValues(alpha: 0.7),
                                    letterSpacing: 0.3,
                                  ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : textOnlyAction
                      ? TextButton(
                          onPressed: registered ? null : onAction,
                          child: Text(
                            actionLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        )
                      : filledAction
                          ? FilledButton.icon(
                              onPressed: registered ? null : onAction,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(actionIcon, size: 18),
                              label: Text(actionLabel),
                            )
                          : OutlinedButton.icon(
                              onPressed: registered ? null : onAction,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.secondary,
                                side: const BorderSide(
                                  color: AppColors.secondary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(actionIcon, size: 18),
                              label: Text(actionLabel),
                            ),
            ),
            if (uploaded) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      registered
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_top_rounded,
                      color: registered ? AppColors.success : AppColors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        registered
                            ? '${image!.name} registered'
                            : '${image!.name} selected',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
