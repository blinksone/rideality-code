// KYC / selfie verification models.
// Face detection is not liveness. Mock liveness is not anti-spoofing.

enum SelfieVerificationUiState {
  initial,
  requestingPermission,
  initializingCamera,
  ready,
  detectingFace,
  faceNotDetected,
  multipleFaces,
  poorPosition,
  motionChallenge,
  startingLiveness,
  livenessInProgress,
  verificationSuccess,
  verificationFailed,
  permissionDenied,
  error,
}

enum FaceQualityIssue {
  none,
  noFace,
  multipleFaces,
  outsideGuide,
  tooFar,
  tooClose,
  notCentered,
  poorLight,
}

class FaceQualityResult {
  const FaceQualityResult({
    required this.issue,
    this.faceCount = 0,
  });

  final FaceQualityIssue issue;
  final int faceCount;

  bool get isAcceptable => issue == FaceQualityIssue.none && faceCount == 1;

  factory FaceQualityResult.ok() =>
      const FaceQualityResult(issue: FaceQualityIssue.none, faceCount: 1);
}

class NormalizedRect {
  const NormalizedRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
  double get area => width * height;
}

class DetectedFaceBox {
  const DetectedFaceBox(
    this.bounds, {
    this.headEulerAngleY,
    this.headEulerAngleX,
    this.headEulerAngleZ,
  });

  final NormalizedRect bounds;

  /// Yaw: negative = face turned right (from user POV), positive = left.
  final double? headEulerAngleY;

  /// Pitch: negative = looking down, positive = looking up.
  final double? headEulerAngleX;

  /// Roll.
  final double? headEulerAngleZ;
}

/// A motion challenge direction the user must perform.
enum MotionDirection { left, right, up, down }

/// Tracks which motion challenges have been completed.
class MotionChallengeState {
  MotionChallengeState({
    List<MotionDirection>? sequence,
  }) : sequence = sequence ?? _defaultSequence();

  final List<MotionDirection> sequence;
  final Set<MotionDirection> completed = {};
  int _currentIndex = 0;

  static List<MotionDirection> _defaultSequence() {
    final list = List<MotionDirection>.from(MotionDirection.values);
    list.shuffle();
    return list;
  }

  MotionDirection? get current =>
      _currentIndex < sequence.length ? sequence[_currentIndex] : null;

  bool get allDone => _currentIndex >= sequence.length;

  void complete(MotionDirection dir) {
    if (dir == current) {
      completed.add(dir);
      _currentIndex++;
    }
  }

  void reset() {
    completed.clear();
    _currentIndex = 0;
    final list = List<MotionDirection>.from(MotionDirection.values);
    list.shuffle();
    sequence
      ..clear()
      ..addAll(list);
  }

  int get totalSteps => sequence.length;
  int get completedCount => completed.length;
}

class VerificationSession {
  const VerificationSession({
    required this.id,
    required this.isMock,
  });

  final String id;
  final bool isMock;

  /// Local placeholder until the backend exposes a KYC session API.
  factory VerificationSession.localMock() => VerificationSession(
        id: 'local-mock-${DateTime.now().millisecondsSinceEpoch}',
        isMock: true,
      );
}

enum LivenessOutcome { passed, failed, cancelled }

class LivenessResult {
  const LivenessResult({
    required this.outcome,
    required this.usedMockProvider,
    this.message,
    this.providerName = 'mock',
  });

  final LivenessOutcome outcome;
  final bool usedMockProvider;
  final String? message;
  final String providerName;

  bool get isSuccess => outcome == LivenessOutcome.passed;

  factory LivenessResult.mockPassed() => const LivenessResult(
        outcome: LivenessOutcome.passed,
        usedMockProvider: true,
        providerName: 'mock',
        message:
            'Development check only. This is not production anti-spoofing.',
      );

  factory LivenessResult.mockFailed([String? message]) => LivenessResult(
        outcome: LivenessOutcome.failed,
        usedMockProvider: true,
        providerName: 'mock',
        message: message ??
            'Development check failed. This is not production anti-spoofing.',
      );
}

enum VerificationStatus { pending, passed, failed, expired }

class SelfieCaptureResult {
  const SelfieCaptureResult({
    required this.imagePath,
    required this.liveness,
    required this.session,
  });

  final String imagePath;
  final LivenessResult liveness;
  final VerificationSession session;
}
