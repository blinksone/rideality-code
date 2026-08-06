/// Hook for global auth failure (access + refresh tokens both unusable).
abstract final class ApiSession {
  /// Called once after storage is cleared. Wire in [main] to pop to welcome.
  static Future<void> Function()? onSessionExpired;

  static bool _notifying = false;

  static Future<void> notifyExpired() async {
    if (_notifying) return;
    _notifying = true;
    try {
      final cb = onSessionExpired;
      if (cb != null) await cb();
    } finally {
      _notifying = false;
    }
  }
}
