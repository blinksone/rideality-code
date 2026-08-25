import '../../models/verification_models.dart';
import 'face_quality_analyzer.dart';

/// Pure UI-state transitions for the selfie screen. Camera I/O stays outside.
class SelfieVerificationStateMachine {
  SelfieVerificationStateMachine({
    FaceQualityAnalyzer analyzer = const FaceQualityAnalyzer(),
  }) : _analyzer = analyzer;

  final FaceQualityAnalyzer _analyzer;

  SelfieVerificationUiState state = SelfieVerificationUiState.initial;
  FaceQualityResult lastQuality = const FaceQualityResult(
    issue: FaceQualityIssue.noFace,
  );
  String? errorMessage;

  final MotionChallengeState motionChallenge = MotionChallengeState();
  bool _motionStarted = false;

  /// Yaw/pitch thresholds (degrees) to count as a deliberate head turn.
  static const double _yawThreshold = 22.0;
  static const double _pitchThreshold = 15.0;

  void requestPermission() {
    state = SelfieVerificationUiState.requestingPermission;
  }

  void permissionDenied() {
    state = SelfieVerificationUiState.permissionDenied;
  }

  void initializingCamera() {
    state = SelfieVerificationUiState.initializingCamera;
  }

  void cameraReady() {
    state = SelfieVerificationUiState.ready;
  }

  void cameraFailed([String? message]) {
    state = SelfieVerificationUiState.error;
    errorMessage = message ?? 'Camera is unavailable.';
  }

  void applyFaces({
    required List<DetectedFaceBox> faces,
    double? averageLuma,
  }) {
    if (_isTerminalOrBusy) return;

    lastQuality = _analyzer.evaluate(faces: faces, averageLuma: averageLuma);

    if (state == SelfieVerificationUiState.motionChallenge) {
      _processMotion(faces);
      return;
    }

    state = switch (lastQuality.issue) {
      FaceQualityIssue.none => SelfieVerificationUiState.detectingFace,
      FaceQualityIssue.noFace => SelfieVerificationUiState.faceNotDetected,
      FaceQualityIssue.multipleFaces =>
        SelfieVerificationUiState.multipleFaces,
      FaceQualityIssue.poorLight ||
      FaceQualityIssue.outsideGuide ||
      FaceQualityIssue.tooFar ||
      FaceQualityIssue.tooClose ||
      FaceQualityIssue.notCentered =>
        SelfieVerificationUiState.poorPosition,
    };
  }

  /// Start the motion challenge flow (face is already detected & centered).
  void startMotionChallenge() {
    if (_isTerminalOrBusy) return;
    _motionStarted = true;
    motionChallenge.reset();
    state = SelfieVerificationUiState.motionChallenge;
  }

  void _processMotion(List<DetectedFaceBox> faces) {
    if (faces.isEmpty || motionChallenge.allDone) return;
    final face = faces.first;
    final yaw = face.headEulerAngleY;
    final pitch = face.headEulerAngleX;
    if (yaw == null || pitch == null) return;

    final current = motionChallenge.current;
    if (current == null) return;

    final matched = switch (current) {
      MotionDirection.left => yaw > _yawThreshold,
      MotionDirection.right => yaw < -_yawThreshold,
      MotionDirection.up => pitch > _pitchThreshold,
      MotionDirection.down => pitch < -_pitchThreshold,
    };

    if (matched) {
      motionChallenge.complete(current);
    }
  }

  bool get motionAllDone => motionChallenge.allDone;
  bool get motionStarted => _motionStarted;

  bool get canCapture {
    if (_isTerminalOrBusy) return false;
    if (state == SelfieVerificationUiState.motionChallenge) {
      return motionChallenge.allDone;
    }
    return state == SelfieVerificationUiState.ready ||
        state == SelfieVerificationUiState.detectingFace ||
        state == SelfieVerificationUiState.faceNotDetected ||
        state == SelfieVerificationUiState.multipleFaces ||
        state == SelfieVerificationUiState.poorPosition;
  }

  /// True when the face is good enough to begin motion challenge.
  bool get canStartMotion {
    if (_motionStarted || _isTerminalOrBusy) return false;
    return lastQuality.isAcceptable;
  }

  void startingLiveness() {
    state = SelfieVerificationUiState.startingLiveness;
  }

  void livenessInProgress() {
    state = SelfieVerificationUiState.livenessInProgress;
  }

  void verificationSuccess() {
    state = SelfieVerificationUiState.verificationSuccess;
  }

  void verificationFailed([String? message]) {
    state = SelfieVerificationUiState.verificationFailed;
    errorMessage = message;
  }

  void retry() {
    errorMessage = null;
    _motionStarted = false;
    motionChallenge.reset();
    lastQuality = const FaceQualityResult(issue: FaceQualityIssue.noFace);
    state = SelfieVerificationUiState.initializingCamera;
  }

  bool get _isTerminalOrBusy {
    return state == SelfieVerificationUiState.startingLiveness ||
        state == SelfieVerificationUiState.livenessInProgress ||
        state == SelfieVerificationUiState.verificationSuccess ||
        state == SelfieVerificationUiState.verificationFailed ||
        state == SelfieVerificationUiState.permissionDenied ||
        state == SelfieVerificationUiState.error ||
        state == SelfieVerificationUiState.requestingPermission ||
        state == SelfieVerificationUiState.initializingCamera;
  }
}
