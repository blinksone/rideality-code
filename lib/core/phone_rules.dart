/// National (local) mobile digit lengths by ISO region code.
/// Lengths are without the country calling code and without a leading trunk `0`.
class PhoneRules {
  const PhoneRules._();

  /// Fallback when the region is unknown.
  static const int defaultMin = 7;
  static const int defaultMax = 15;

  /// Expected national mobile length range for [regionCode] (e.g. `PK`).
  static ({int min, int max}) lengthFor(String? regionCode) {
    final code = (regionCode ?? '').trim().toUpperCase();
    return switch (code) {
      'PK' => (min: 10, max: 10),
      'IN' => (min: 10, max: 10),
      'BD' => (min: 10, max: 10),
      'AE' => (min: 9, max: 9),
      'SA' => (min: 9, max: 9),
      'QA' => (min: 8, max: 8),
      'KW' => (min: 8, max: 8),
      'BH' => (min: 8, max: 8),
      'OM' => (min: 8, max: 8),
      'US' || 'CA' => (min: 10, max: 10),
      'GB' || 'UK' => (min: 10, max: 10),
      'AU' => (min: 9, max: 9),
      'SG' => (min: 8, max: 8),
      'MY' => (min: 9, max: 10),
      'ID' => (min: 9, max: 12),
      'PH' => (min: 10, max: 10),
      'TR' => (min: 10, max: 10),
      'EG' => (min: 10, max: 10),
      'NG' => (min: 10, max: 11),
      'KE' => (min: 9, max: 9),
      'ZA' => (min: 9, max: 9),
      _ => (min: defaultMin, max: defaultMax),
    };
  }

  /// Digits only; strips a leading trunk `0` (e.g. `0300…` → `300…`).
  static String normalizeLocal(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static String? validateLocal(String input, String? regionCode) {
    final digits = normalizeLocal(input);
    final range = lengthFor(regionCode);
    if (digits.isEmpty) {
      return 'Enter a valid phone number';
    }
    if (digits.length < range.min || digits.length > range.max) {
      if (range.min == range.max) {
        return 'Enter a ${range.min}-digit mobile number';
      }
      return 'Enter a ${range.min}–${range.max} digit mobile number';
    }
    return null;
  }

  static String hintFor(String? regionCode) {
    final range = lengthFor(regionCode);
    if (range.min == range.max) {
      return '${range.max} digits (without country code)';
    }
    return '${range.min}–${range.max} digits (without country code)';
  }
}
