class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  /// Access/refresh session is unusable — re-auth required.
  bool get isAuthFailure {
    if (statusCode == 401) return true;
    final c = (code ?? '').toUpperCase();
    if (c == 'UNAUTHORIZED' ||
        c == 'TOKEN_EXPIRED' ||
        c == 'INVALID_TOKEN' ||
        c == 'AUTH_REQUIRED' ||
        c == 'SESSION_EXPIRED') {
      return true;
    }
    final m = message.toLowerCase();
    return m.contains('invalid or expired token') ||
        m.contains('token expired') ||
        m.contains('token is invalid') ||
        m.contains('jwt expired') ||
        m.contains('unauthorized') ||
        m.contains('authentication required') ||
        m.contains('not authenticated');
  }

  @override
  String toString() => message;
}
