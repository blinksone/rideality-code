import '../../models/verification_models.dart';
import 'liveness_verification_service.dart';

/// Plug-in point for Jumio / Veriff / Persona / Onfido.
///
/// Credentials stay on the server. This class must not hardcode secrets or
/// production KYC URLs.
class ProductionLivenessVerificationService
    implements LivenessVerificationService {
  @override
  bool get isMock => false;

  @override
  Future<LivenessResult> startVerification({
    required VerificationSession session,
    String? capturedImagePath,
  }) async {
    throw UnimplementedError(
      'Wire an approved KYC SDK here. Do not ship mock liveness to production.',
    );
  }
}
