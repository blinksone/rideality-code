import '../../models/verification_models.dart';

/// Guide circle in normalized preview coordinates (0–1).
/// Kept as a square NormalizedRect so overlap math still works.
const kSelfieGuideRect = NormalizedRect(
  left: 0.14,
  top: 0.18,
  width: 0.72,
  height: 0.50,
);

/// Geometric face checks only. This is **not** liveness / anti-spoofing.
class FaceQualityAnalyzer {
  const FaceQualityAnalyzer({
    this.guide = kSelfieGuideRect,
    this.minFill = 0.18,
    this.maxFill = 0.78,
    this.maxCenterOffset = 0.18,
    this.minLuma = 40,
  });

  final NormalizedRect guide;
  final double minFill;
  final double maxFill;
  final double maxCenterOffset;
  final double minLuma;

  FaceQualityResult evaluate({
    required List<DetectedFaceBox> faces,
    double? averageLuma,
  }) {
    if (faces.isEmpty) {
      return const FaceQualityResult(issue: FaceQualityIssue.noFace);
    }
    if (faces.length > 1) {
      return FaceQualityResult(
        issue: FaceQualityIssue.multipleFaces,
        faceCount: faces.length,
      );
    }

    final face = faces.first.bounds;
    final overlap = _intersectionArea(face, guide);
    final faceArea = face.area;
    if (faceArea <= 0) {
      return const FaceQualityResult(
        issue: FaceQualityIssue.outsideGuide,
        faceCount: 1,
      );
    }

    final contained = overlap / faceArea;
    if (contained < 0.72) {
      return const FaceQualityResult(
        issue: FaceQualityIssue.outsideGuide,
        faceCount: 1,
      );
    }

    final fill = faceArea / guide.area;
    if (fill < minFill) {
      return const FaceQualityResult(
        issue: FaceQualityIssue.tooFar,
        faceCount: 1,
      );
    }
    if (fill > maxFill) {
      return const FaceQualityResult(
        issue: FaceQualityIssue.tooClose,
        faceCount: 1,
      );
    }

    final dx = (face.centerX - guide.centerX).abs();
    final dy = (face.centerY - guide.centerY).abs();
    if (dx > maxCenterOffset || dy > maxCenterOffset) {
      return const FaceQualityResult(
        issue: FaceQualityIssue.notCentered,
        faceCount: 1,
      );
    }

    if (averageLuma != null && averageLuma < minLuma) {
      return const FaceQualityResult(
        issue: FaceQualityIssue.poorLight,
        faceCount: 1,
      );
    }

    return FaceQualityResult.ok();
  }

  double _intersectionArea(NormalizedRect a, NormalizedRect b) {
    final left = a.left > b.left ? a.left : b.left;
    final top = a.top > b.top ? a.top : b.top;
    final right = a.right < b.right ? a.right : b.right;
    final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;
    if (right <= left || bottom <= top) return 0;
    return (right - left) * (bottom - top);
  }
}
