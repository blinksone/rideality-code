import '../../models/verification_models.dart';
import 'liveness_verification_service.dart';

/// Development stub so the selfie UI can be tested.
///
/// **NOT production anti-spoofing.** Blink/head-movement heuristics are not
/// implemented and would not be a real liveness check. Replace with an
/// approved KYC SDK via [LivenessVerificationService].
class MockLivenessVerificationService implements LivenessVerificationService {
  MockLivenessVerificationService({this.shouldSucceed = true});

  final bool shouldSucceed;

  @override
  bool get isMock => true;

  @override
  Future<LivenessResult> startVerification({
    required VerificationSession session,
    String? capturedImagePath,
  }) async {
    // Image bytes are never logged. Path is unused by the mock.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!shouldSucceed) {
      return LivenessResult.mockFailed();
    }
    return LivenessResult.mockPassed();
  }
}
