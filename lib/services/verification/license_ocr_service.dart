import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'license_expiry_parser.dart';

/// On-device OCR for driver-license expiry. Does not upload the image.
class LicenseOcrService {
  LicenseOcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer();

  static final LicenseOcrService instance = LicenseOcrService();

  final TextRecognizer _recognizer;

  Future<DateTime?> extractExpiry(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    try {
      final result = await _recognizer.processImage(input);
      return LicenseExpiryParser.parse(result.text);
    } catch (_) {
      return null;
    }
  }

  Future<void> close() => _recognizer.close();
}
