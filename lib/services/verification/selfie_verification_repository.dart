import '../../models/verification_models.dart';
import 'liveness_verification_service.dart';
import 'mock_liveness_verification_service.dart';

/// Backend KYC session/status.
///
/// Existing Rideality APIs register a selfie with `POST /users/me/documents`.
/// There is **no** dedicated liveness endpoint yet — methods below are
/// marked TODO and must not invent fake production URLs.
class SelfieVerificationRepository {
  SelfieVerificationRepository({
    LivenessVerificationService? liveness,
  }) : _liveness = liveness ?? MockLivenessVerificationService();

  static final SelfieVerificationRepository instance =
      SelfieVerificationRepository();

  final LivenessVerificationService _liveness;

  /// TODO: POST a short-lived session when the backend adds KYC.
  Future<VerificationSession> createVerificationSession() async {
    return VerificationSession.localMock();
  }

  Future<LivenessResult> verifyLiveness({
    required VerificationSession session,
    String? capturedImagePath,
  }) {
    return _liveness.startVerification(
      session: session,
      capturedImagePath: capturedImagePath,
    );
  }

  /// TODO: GET status from backend when a verification id exists.
  Future<VerificationStatus> getVerificationStatus(String verificationId) async {
    if (verificationId.isEmpty) return VerificationStatus.failed;
    if (verificationId.startsWith('local-mock-')) {
      return VerificationStatus.passed;
    }
    return VerificationStatus.pending;
  }
}
