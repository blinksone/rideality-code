/// Parses a license expiry date from OCR text. No image I/O.
class LicenseExpiryParser {
  static final _iso = RegExp(r'\b(20\d{2})[-/.](0?[1-9]|1[0-2])[-/.](0?[1-9]|[12]\d|3[01])\b');
  static final _dmy = RegExp(
    r'\b(0?[1-9]|[12]\d|3[01])[-/.](0?[1-9]|1[0-2])[-/.](20\d{2}|\d{2})\b',
  );
  static final _monthName = RegExp(
    r'\b(0?[1-9]|[12]\d|3[01])\s+'
    r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
    r'jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|'
    r'dec(?:ember)?)\s+(20\d{2})\b',
    caseSensitive: false,
  );

  static const _months = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  /// Returns the most likely future (or latest) expiry date in [text].
  static DateTime? parse(String text) {
    final candidates = <DateTime>[];
    final lower = text.toLowerCase();

    for (final m in _iso.allMatches(text)) {
      final d = _date(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
      if (d != null) candidates.add(d);
    }
    for (final m in _dmy.allMatches(text)) {
      var year = int.parse(m.group(3)!);
      if (year < 100) year += 2000;
      final d = _date(year, int.parse(m.group(2)!), int.parse(m.group(1)!));
      if (d != null) candidates.add(d);
    }
    for (final m in _monthName.allMatches(lower)) {
      final month = _months[m.group(2)!.toLowerCase()];
      if (month == null) continue;
      final d = _date(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
      if (d != null) candidates.add(d);
    }

    if (candidates.isEmpty) return null;

    final today = DateTime.now();
    final floor = DateTime(today.year, today.month, today.day);
    final future = candidates.where((d) => !d.isBefore(floor)).toList()
      ..sort((a, b) => a.compareTo(b));
    if (future.isNotEmpty) return future.last;
    candidates.sort();
    return candidates.last;
  }

  static DateTime? _date(int year, int month, int day) {
    if (year < 2000 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}
