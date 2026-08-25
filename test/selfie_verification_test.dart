import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideality_app/models/verification_models.dart';
import 'package:rideality_app/screens/driver/selfie_verification_view.dart';
import 'package:rideality_app/services/verification/face_quality_analyzer.dart';
import 'package:rideality_app/services/verification/license_expiry_parser.dart';
import 'package:rideality_app/services/verification/mock_liveness_verification_service.dart';
import 'package:rideality_app/services/verification/selfie_verification_repository.dart';
import 'package:rideality_app/services/verification/selfie_verification_state_machine.dart';
import 'package:rideality_app/theme/app_theme.dart';

void main() {
  const analyzer = FaceQualityAnalyzer();

  DetectedFaceBox _box({
    double left = 0.22,
    double top = 0.22,
    double width = 0.56,
    double height = 0.42,
  }) {
    return DetectedFaceBox(
      NormalizedRect(left: left, top: top, width: width, height: height),
    );
  }

  group('FaceQualityAnalyzer', () {
    test('no face', () {
      final r = analyzer.evaluate(faces: const []);
      expect(r.issue, FaceQualityIssue.noFace);
    });

    test('multiple faces', () {
      final r = analyzer.evaluate(faces: [_box(), _box(left: 0.1)]);
      expect(r.issue, FaceQualityIssue.multipleFaces);
      expect(r.faceCount, 2);
    });

    test('invalid position — too far', () {
      final r = analyzer.evaluate(
        faces: [
          _box(left: 0.40, top: 0.32, width: 0.18, height: 0.16),
        ],
      );
      expect(r.issue, FaceQualityIssue.tooFar);
    });

    test('invalid position — outside guide', () {
      final r = analyzer.evaluate(
        faces: [
          _box(left: 0.0, top: 0.0, width: 0.2, height: 0.2),
        ],
      );
      expect(r.issue, FaceQualityIssue.outsideGuide);
    });

    test('acceptable centered face', () {
      final r = analyzer.evaluate(faces: [_box()]);
      expect(r.isAcceptable, isTrue);
    });
  });

  group('SelfieVerificationStateMachine', () {
    test('permission denied', () {
      final m = SelfieVerificationStateMachine();
      m.requestPermission();
      m.permissionDenied();
      expect(m.state, SelfieVerificationUiState.permissionDenied);
    });

    test('camera initialization failure', () {
      final m = SelfieVerificationStateMachine();
      m.initializingCamera();
      m.cameraFailed('lens error');
      expect(m.state, SelfieVerificationUiState.error);
      expect(m.errorMessage, 'lens error');
    });

    test('no face', () {
      final m = SelfieVerificationStateMachine();
      m.cameraReady();
      m.applyFaces(faces: const []);
      expect(m.state, SelfieVerificationUiState.faceNotDetected);
    });

    test('multiple faces', () {
      final m = SelfieVerificationStateMachine();
      m.cameraReady();
      m.applyFaces(faces: [_box(), _box(left: 0.1)]);
      expect(m.state, SelfieVerificationUiState.multipleFaces);
    });

    test('invalid face position', () {
      final m = SelfieVerificationStateMachine();
      m.cameraReady();
      m.applyFaces(
        faces: [_box(left: 0.0, top: 0.0, width: 0.2, height: 0.2)],
      );
      expect(m.state, SelfieVerificationUiState.poorPosition);
    });

    test('retry from failed', () {
      final m = SelfieVerificationStateMachine();
      m.verificationFailed('nope');
      m.retry();
      expect(m.state, SelfieVerificationUiState.initializingCamera);
      expect(m.errorMessage, isNull);
    });
  });

  group('Mock liveness', () {
    test('successful mock verification', () async {
      final svc = MockLivenessVerificationService();
      expect(svc.isMock, isTrue);
      final result = await svc.startVerification(
        session: VerificationSession.localMock(),
      );
      expect(result.isSuccess, isTrue);
      expect(result.usedMockProvider, isTrue);
    });

    test('failed mock verification', () async {
      final svc = MockLivenessVerificationService(shouldSucceed: false);
      final result = await svc.startVerification(
        session: VerificationSession.localMock(),
      );
      expect(result.outcome, LivenessOutcome.failed);
      expect(result.usedMockProvider, isTrue);
    });
  });

  group('SelfieVerificationRepository', () {
    test('mock session then pass', () async {
      final repo = SelfieVerificationRepository(
        liveness: MockLivenessVerificationService(),
      );
      final session = await repo.createVerificationSession();
      expect(session.isMock, isTrue);
      final live = await repo.verifyLiveness(session: session);
      expect(live.isSuccess, isTrue);
      final status = await repo.getVerificationStatus(session.id);
      expect(status, VerificationStatus.passed);
    });
  });

  group('LicenseExpiryParser', () {
    test('reads DD/MM/YYYY', () {
      final d = LicenseExpiryParser.parse('EXP 12/01/2028');
      expect(d, DateTime(2028, 1, 12));
    });

    test('reads ISO date', () {
      final d = LicenseExpiryParser.parse('valid until 2029-06-30');
      expect(d, DateTime(2029, 6, 30));
    });
  });

  group('SelfieVerificationView', () {
    Widget wrap(SelfieVerificationUiState state, {VoidCallback? onRetry}) {
      return MaterialApp(
        theme: AppTheme.light,
        home: SelfieVerificationView(
          state: state,
          onCapture: () {},
          onRetry: onRetry ?? () {},
          onCancel: () {},
        ),
      );
    }

    testWidgets('permission denied shows retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        wrap(
          SelfieVerificationUiState.permissionDenied,
          onRetry: () => retried = true,
        ),
      );
      expect(find.textContaining('Camera permission'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('no face instruction', (tester) async {
      await tester.pumpWidget(
        wrap(SelfieVerificationUiState.faceNotDetected),
      );
      expect(find.textContaining('can’t see your face'), findsOneWidget);
    });

    testWidgets('multiple faces instruction', (tester) async {
      await tester.pumpWidget(wrap(SelfieVerificationUiState.multipleFaces));
      expect(find.textContaining('Only one person'), findsOneWidget);
    });

    testWidgets('invalid position instruction', (tester) async {
      await tester.pumpWidget(wrap(SelfieVerificationUiState.poorPosition));
      expect(find.textContaining('well-lit'), findsOneWidget);
    });

    testWidgets('mock banner is visible', (tester) async {
      await tester.pumpWidget(
        wrap(SelfieVerificationUiState.ready),
      );
      expect(find.textContaining('not production anti-spoofing'), findsOneWidget);
    });
  });
}
