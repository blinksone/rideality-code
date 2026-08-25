import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../models/verification_models.dart';
import '../../services/verification/selfie_verification_repository.dart';
import '../../services/verification/selfie_verification_state_machine.dart';
import 'selfie_verification_view.dart';

class SelfieVerificationScreen extends StatefulWidget {
  const SelfieVerificationScreen({super.key});

  static const routeName = '/selfie-verification';

  @override
  State<SelfieVerificationScreen> createState() =>
      _SelfieVerificationScreenState();
}

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen>
    with WidgetsBindingObserver {
  final _machine = SelfieVerificationStateMachine();
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: false,
      enableLandmarks: false,
      enableClassification: true,
      enableTracking: true,
    ),
  );
  final _repo = SelfieVerificationRepository.instance;

  CameraController? _camera;
  bool _streamBusy = false;
  DateTime _lastDetect = DateTime.fromMillisecondsSinceEpoch(0);
  String? _pendingPath;
  bool _starting = false;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopCamera());
    unawaited(_detector.close());
    unawaited(_deletePending());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_stopCamera());
    } else if (state == AppLifecycleState.resumed &&
        _machine.state != SelfieVerificationUiState.permissionDenied &&
        _machine.state != SelfieVerificationUiState.verificationSuccess) {
      unawaited(_bootstrap());
    }
  }

  Future<void> _bootstrap() async {
    if (_starting) return;
    _starting = true;
    _machine.requestPermission();
    _emit();
    try {
      _machine.initializingCamera();
      _emit();
      await _openFrontCamera();
      _machine.cameraReady();
      _emit();
    } on CameraException catch (e) {
      final denied = e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.description?.toLowerCase().contains('permission') == true;
      if (denied) {
        _machine.permissionDenied();
      } else {
        _machine.cameraFailed();
      }
      _emit();
    } catch (e) {
      _machine.cameraFailed();
      _emit();
    } finally {
      _starting = false;
    }
  }

  Future<void> _openFrontCamera() async {
    await _stopCamera();
    final cameras = await availableCameras();
    CameraDescription? front;
    for (final c in cameras) {
      if (c.lensDirection == CameraLensDirection.front) {
        front = c;
        break;
      }
    }
    if (front == null) {
      throw StateError('Front camera unavailable');
    }
    final controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    _camera = controller;
    await controller.startImageStream(_onFrame);
  }

  Future<void> _stopCamera() async {
    final camera = _camera;
    _camera = null;
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
    } catch (_) {}
    await camera.dispose();
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_streamBusy) return;
    final now = DateTime.now();
    if (now.difference(_lastDetect) < const Duration(milliseconds: 420)) {
      return;
    }
    _lastDetect = now;
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    final input = _toInputImage(image, camera);
    if (input == null) return;
    _streamBusy = true;
    try {
      final faces = await _detector.processImage(input);
      if (!mounted) return;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      final boxes = faces
          .map((f) => DetectedFaceBox(
                _normalize(f.boundingBox, size, true),
                headEulerAngleY: f.headEulerAngleY,
                headEulerAngleX: f.headEulerAngleX,
                headEulerAngleZ: f.headEulerAngleZ,
              ))
          .toList();
      _machine.applyFaces(
        faces: boxes,
        averageLuma: _averageLuma(image),
      );
      if (_machine.canStartMotion) {
        _machine.startMotionChallenge();
      }
      if (_machine.motionAllDone && _machine.motionStarted) {
        unawaited(_capture());
      }
      _emit();
    } catch (_) {
      // Live detection is assistive only; capture still re-checks the still.
    } finally {
      _streamBusy = false;
    }
  }

  NormalizedRect _normalize(Rect box, Size imageSize, bool mirror) {
    var left = box.left / imageSize.width;
    final top = box.top / imageSize.height;
    final width = box.width / imageSize.width;
    final height = box.height / imageSize.height;
    if (mirror) {
      left = 1.0 - left - width;
    }
    return NormalizedRect(
      left: left.clamp(0, 1),
      top: top.clamp(0, 1),
      width: width.clamp(0, 1),
      height: height.clamp(0, 1),
    );
  }

  double? _averageLuma(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return null;
    var sum = 0;
    const step = 16;
    var n = 0;
    for (var i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
      n++;
    }
    if (n == 0) return null;
    return sum / n;
  }

  InputImage? _toInputImage(CameraImage image, CameraController camera) {
    try {
      final plane = image.planes.first;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      final rotation = _rotation(camera.description);
      if (format == null || rotation == null) return null;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  InputImageRotation? _rotation(CameraDescription camera) {
    final sensor = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensor);
    }
    var compensation = _orientations[DeviceOrientation.portraitUp] ?? 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      compensation = (sensor + compensation) % 360;
    } else {
      compensation = (sensor - compensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(compensation);
  }

  Future<void> _capture() async {
    if (!_machine.canCapture) return;
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    try {
      if (camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
      final shot = await camera.takePicture();
      _pendingPath = shot.path;
      final still = InputImage.fromFilePath(shot.path);
      final faces = await _detector.processImage(still);
      final decoded = await decodeImageFromList(await shot.readAsBytes());
      final size = Size(decoded.width.toDouble(), decoded.height.toDouble());
      decoded.dispose();
      final boxes = faces
          .map((f) => DetectedFaceBox(_normalize(f.boundingBox, size, false)))
          .toList();
      _machine.applyFaces(faces: boxes);
      if (!_machine.lastQuality.isAcceptable) {
        await _deletePending();
        await camera.startImageStream(_onFrame);
        _emit();
        return;
      }
      _machine.startingLiveness();
      _emit();
      _machine.livenessInProgress();
      _emit();
      final session = await _repo.createVerificationSession();
      final liveness = await _repo.verifyLiveness(
        session: session,
        capturedImagePath: shot.path,
      );
      if (!liveness.isSuccess) {
        await _deletePending();
        _machine.verificationFailed(liveness.message);
        _emit();
        return;
      }
      _machine.verificationSuccess();
      _emit();
      if (!mounted) return;
      Navigator.of(context).pop(
        SelfieCaptureResult(
          imagePath: shot.path,
          liveness: liveness,
          session: session,
        ),
      );
    } catch (_) {
      await _deletePending();
      _machine.verificationFailed('Could not capture selfie.');
      _emit();
    }
  }

  Future<void> _retry() async {
    await _deletePending();
    _machine.retry();
    _emit();
    await _bootstrap();
  }

  Future<void> _deletePending() async {
    final path = _pendingPath;
    _pendingPath = null;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void _cancel() {
    unawaited(_deletePending());
    Navigator.of(context).maybePop();
  }

  void _emit() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    Widget? preview;
    if (camera != null && camera.value.isInitialized) {
      preview = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: camera.value.previewSize?.height ?? 1,
          height: camera.value.previewSize?.width ?? 1,
          child: CameraPreview(camera),
        ),
      );
    }
    return SelfieVerificationView(
      state: _machine.state,
      preview: preview,
      errorMessage: _machine.errorMessage,
      qualityOk: _machine.lastQuality.isAcceptable,
      showMockBanner: true,
      onCapture: _machine.canCapture ? _capture : null,
      onRetry: _retry,
      onCancel: _cancel,
      currentMotionDir: _machine.motionChallenge.current,
      completedMotions: Set<MotionDirection>.from(
        _machine.motionChallenge.completed,
      ),
    );
  }
}
