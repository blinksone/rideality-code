/// Catalog vehicle / product codes used by quote, map supply, and Redis GPS.
abstract final class VehicleCatalog {
  static const bike = 'bike';
  static const rickshaw = 'rickshaw';
  static const economy = 'economy';
  static const ac = 'ac';
  static const cargo = 'cargo';

  static const all = [bike, rickshaw, economy, ac, cargo];

  /// Map legacy / display aliases to catalog codes Redis + quote use.
  static String normalize(String? raw, {String fallback = economy}) {
    final t = (raw ?? '').trim().toLowerCase();
    if (t.isEmpty) return fallback;
    return switch (t) {
      'sedan' || 'car' || 'standard' || 'suv' => economy,
      'lux' || 'luxury' || 'premium' => ac,
      'motorcycle' || 'motorbike' => bike,
      'auto' || 'autorickshaw' => rickshaw,
      'bike' || 'rickshaw' || 'economy' || 'ac' || 'cargo' => t,
      _ => t,
    };
  }
}
