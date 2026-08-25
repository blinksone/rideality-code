import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../models/api_models.dart';
import '../../models/verification_models.dart';
import '../../services/driver_api_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/verification/license_ocr_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/rideality_app_bar.dart';
import 'selfie_verification_screen.dart';
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
  Map<String, DriverDocument> _serverDocs = const {};

  static const _labels = ['Phone', 'OTP', 'Identity', 'Vehicle', 'Docs'];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final map = await DriverApiService.instance.listDocumentsByType();
      if (!mounted) return;
      final license = map['driver_license'];
      final selfie = map['selfie'];
      final id = map['national_id'];
      setState(() {
        _serverDocs = map;
        _licenseRegistered = license != null && !license.needsResubmission;
        _selfieRegistered = selfie != null && !selfie.needsResubmission;
        _idRegistered = id != null && !id.needsResubmission;
      });
    } catch (_) {}
  }

  bool get _hasRejectedDocs =>
      _serverDocs.values.any((d) => d.needsResubmission);

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

  Future<void> _pickLicense() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;
    await _pickAndRegister(
      key: 'license',
      type: 'driver_license',
      useCamera: source == ImageSource.camera,
      runOcr: true,
    );
  }

  Future<void> _pickSelfie() async {
    final result = await Navigator.of(context).pushNamed(
      SelfieVerificationScreen.routeName,
    );
    if (result is! SelfieCaptureResult || !mounted) return;
    try {
      await _registerPickedFile(
        key: 'selfie',
        type: 'selfie',
        picked: PickedImageFile(
          file: XFile(result.imagePath),
          name: 'selfie.jpg',
        ),
        deleteAfter: true,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickAndRegister({
    required String key,
    required String type,
    required bool useCamera,
    String? expiresAt,
    bool runOcr = false,
  }) async {
    setState(() => _uploadingKey = key);
    try {
      final picked = await ImagePickerService.instance.pickDocument(
        useCamera: useCamera,
      );
      if (picked == null || !mounted) return;

      if (runOcr && key == 'license') {
        final expiry =
            await LicenseOcrService.instance.extractExpiry(picked.file.path);
        if (expiry != null && mounted) {
          setState(() => _licenseExpiry = expiry);
        }
      }

      await _registerPickedFile(
        key: key,
        type: type,
        picked: picked,
        expiresAt: expiresAt ??
            (_licenseExpiry == null ? null : _fmt(_licenseExpiry!)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploadingKey = null);
    }
  }

  Future<void> _registerPickedFile({
    required String key,
    required String type,
    required PickedImageFile picked,
    String? expiresAt,
    bool deleteAfter = false,
  }) async {
    setState(() {
      _uploadingKey = key;
      switch (key) {
        case 'license':
          _license = picked;
        case 'selfie':
          _selfie = picked;
        case 'id':
          _nationalId = picked;
      }
    });
    try {
      await DriverApiService.instance.uploadAndRegisterDocument(
        type: type,
        filePath: picked.file.path,
        expiresAt: expiresAt,
      );
      await _loadExisting();
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
    } finally {
      if (deleteAfter) {
        try {
          final file = File(picked.file.path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
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
                      _hasRejectedDocs
                          ? 'Re-upload rejected documents'
                          : 'Upload documents',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasRejectedDocs
                          ? 'Only the items marked Re-upload need a new photo. Approved documents stay on file.'
                          : 'Driver license is required. Selfie is recommended for faster review.',
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
                          labelText: 'License expiry (from photo or picker)',
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
                          'Required — photo of the front. Expiry is read with OCR when possible.',
                      badge: 'Required',
                      badgeColor: AppColors.errorContainer,
                      badgeTextColor: AppColors.onErrorContainer,
                      accent: true,
                      image: _license,
                      registered: _licenseRegistered,
                      serverDoc: _serverDocs['driver_license'],
                      actionLabel: _licenseRegistered ? 'Uploaded' : 'Upload',
                      actionIcon: Icons.upload_rounded,
                      filledAction: true,
                      isLoading: _uploadingKey == 'license',
                      onAction: _pickLicense,
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
                          'Front camera. Keep your face inside the circle.',
                      badge: _serverDocs['selfie']?.needsResubmission == true
                          ? 'Re-upload'
                          : 'Recommended',
                      badgeColor:
                          _serverDocs['selfie']?.needsResubmission == true
                              ? AppColors.errorContainer
                              : AppColors.surfaceContainer,
                      badgeTextColor:
                          _serverDocs['selfie']?.needsResubmission == true
                              ? AppColors.onErrorContainer
                              : AppColors.onSurfaceVariant,
                      image: _selfie,
                      registered: _selfieRegistered,
                      serverDoc: _serverDocs['selfie'],
                      actionLabel: _serverDocs['selfie']?.needsResubmission ==
                              true
                          ? 'Re-upload selfie'
                          : _selfieRegistered
                              ? 'Uploaded'
                              : 'Take photo',
                      actionIcon: Icons.camera_alt_rounded,
                      isLoading: _uploadingKey == 'selfie',
                      onAction: _pickSelfie,
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
                      serverDoc: _serverDocs['national_id'],
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
    this.serverDoc,
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
  final DriverDocument? serverDoc;
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
    final needsReupload = serverDoc?.needsResubmission ?? false;
    final actionEnabled = !registered || needsReupload;
    final label = needsReupload
        ? (title.toLowerCase().contains('selfie')
            ? 'Re-upload selfie'
            : 'Re-upload')
        : actionLabel;

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
                      if (serverDoc != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          serverDoc!.needsResubmission
                              ? 'Rejected${serverDoc!.rejectionReason != null && serverDoc!.rejectionReason!.isNotEmpty ? ' — ${serverDoc!.rejectionReason}' : ''}'
                              : serverDoc!.isApproved
                                  ? 'Approved by city fleet'
                                  : 'Pending city review',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: serverDoc!.needsResubmission
                                    ? AppColors.error
                                    : serverDoc!.isApproved
                                        ? AppColors.success
                                        : AppColors.amber,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
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
                          onPressed: actionEnabled ? onAction : null,
                          child: Text(
                            label,
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
                              onPressed: actionEnabled ? onAction : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: needsReupload
                                    ? AppColors.error
                                    : AppColors.secondary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(actionIcon, size: 18),
                              label: Text(label),
                            )
                          : OutlinedButton.icon(
                              onPressed: actionEnabled ? onAction : null,
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
                              label: Text(label),
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
