import '../../models/verification_models.dart';

/// Contract for an approved KYC / liveness SDK (Jumio, Veriff, Persona, Onfido, …).
///
/// Do **not** put provider API secrets in Flutter source. Sessions/tokens must
/// come from the backend over HTTPS and be short-lived.
abstract class LivenessVerificationService {
  /// True when this implementation is a development stub, not anti-spoofing.
  bool get isMock;

  Future<LivenessResult> startVerification({
    required VerificationSession session,
    String? capturedImagePath,
  });
}
