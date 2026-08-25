import 'package:flutter/material.dart';

import '../../models/verification_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/face_guide_overlay.dart';

HeadDirection _toHeadDir(MotionDirection? d) {
  if (d == null) return HeadDirection.none;
  return switch (d) {
    MotionDirection.left => HeadDirection.left,
    MotionDirection.right => HeadDirection.right,
    MotionDirection.up => HeadDirection.up,
    MotionDirection.down => HeadDirection.down,
  };
}

String selfieInstructionFor(
  SelfieVerificationUiState state, {
  MotionDirection? motionDir,
}) {
  return switch (state) {
    SelfieVerificationUiState.initial ||
    SelfieVerificationUiState.requestingPermission =>
      'Allow camera access to continue.',
    SelfieVerificationUiState.initializingCamera =>
      'Starting the front camera\u2026',
    SelfieVerificationUiState.ready =>
      'Position your face inside the circle',
    SelfieVerificationUiState.detectingFace => 'Keep your face visible',
    SelfieVerificationUiState.faceNotDetected =>
      'We can\u2019t see your face. Position your face inside the circle.',
    SelfieVerificationUiState.multipleFaces =>
      'Only one person should be in the frame.',
    SelfieVerificationUiState.poorPosition =>
      'Center your face in the circle. Move to a well-lit area.',
    SelfieVerificationUiState.motionChallenge =>
      motionDir != null
          ? 'Turn your head ${motionDir.name}'
          : 'Motion check complete!',
    SelfieVerificationUiState.startingLiveness ||
    SelfieVerificationUiState.livenessInProgress =>
      'Checking your selfie\u2026',
    SelfieVerificationUiState.verificationSuccess => 'Selfie captured.',
    SelfieVerificationUiState.verificationFailed =>
      'Verification didn\u2019t complete. You can try again.',
    SelfieVerificationUiState.permissionDenied =>
      'Camera permission is required for selfie verification.',
    SelfieVerificationUiState.error =>
      'The camera could not be started. Try again.',
  };
}

/// Presentation-only selfie KYC UI. Camera is supplied by [preview].
class SelfieVerificationView extends StatelessWidget {
  const SelfieVerificationView({
    super.key,
    required this.state,
    required this.onCapture,
    required this.onRetry,
    required this.onCancel,
    this.preview,
    this.errorMessage,
    this.qualityOk = false,
    this.showMockBanner = true,
    this.currentMotionDir,
    this.completedMotions = const {},
  });

  final SelfieVerificationUiState state;
  final Widget? preview;
  final String? errorMessage;
  final bool qualityOk;
  final bool showMockBanner;
  final VoidCallback? onCapture;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final MotionDirection? currentMotionDir;
  final Set<MotionDirection> completedMotions;

  bool get _showRetry =>
      state == SelfieVerificationUiState.permissionDenied ||
      state == SelfieVerificationUiState.error ||
      state == SelfieVerificationUiState.verificationFailed;

  bool get _busy =>
      state == SelfieVerificationUiState.startingLiveness ||
      state == SelfieVerificationUiState.livenessInProgress ||
      state == SelfieVerificationUiState.initializingCamera ||
      state == SelfieVerificationUiState.requestingPermission;

  bool get _inMotion =>
      state == SelfieVerificationUiState.motionChallenge;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.canvasDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Selfie verification',
                      style: tt.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showMockBanner)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.devBadge,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Development check \u2014 not production anti-spoofing.',
                  style: tt.labelSmall?.copyWith(
                    color: AppColors.devBadgeText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (_inMotion)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    MotionDirection.values.length,
                    (i) {
                      final done = i < completedMotions.length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: CircleAvatar(
                          radius: 6,
                          backgroundColor: done
                              ? AppColors.success
                              : Colors.white24,
                        ),
                      );
                    },
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: const Color(0xFF0F172A),
                        child: preview ??
                            const Center(
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 72,
                                color: Colors.white24,
                              ),
                            ),
                      ),
                      FaceGuideOverlay(
                        ok: qualityOk,
                        activeDirection: _toHeadDir(currentMotionDir),
                        completedDirections: completedMotions
                            .map(_toHeadDir)
                            .where((d) => d != HeadDirection.none)
                            .toSet(),
                      ),
                      if (_busy)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
              child: Column(
                children: [
                  Text(
                    selfieInstructionFor(state, motionDir: currentMotionDir),
                    textAlign: TextAlign.center,
                    style: tt.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(color: AppColors.amber),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_showRetry)
                    AppButton(
                      label: 'Retry',
                      icon: Icons.refresh_rounded,
                      onPressed: onRetry,
                    )
                  else if (_inMotion && !qualityOk)
                    Text(
                      'Follow the prompts above',
                      style: tt.bodySmall?.copyWith(color: Colors.white54),
                    )
                  else
                    AppButton(
                      label: _busy ? 'Please wait' : 'Capture selfie',
                      icon: Icons.camera_alt_rounded,
                      onPressed: onCapture,
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
