import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../models/api_models.dart';

class AuthApiService {
  AuthApiService({ApiClient? client, TokenStorage? storage})
      : _client = client ?? ApiClient(),
        _storage = storage ?? TokenStorage.instance;

  static final AuthApiService instance = AuthApiService();

  final ApiClient _client;
  final TokenStorage _storage;

  /// POST /auth/refresh — returns true when a new access token was stored.
  /// Prefer [ApiClient] auto-refresh; call this from bootstrap on 401.
  Future<bool> tryRefreshSession() async {
    try {
      return await _client.refreshAccessToken();
    } on ApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Region>> listRegions() async {
    final json = await _client.get('/auth/regions', auth: false);
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Region.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  String buildPhone(String phonePrefix, String localNumber) {
    final digits = localNumber.replaceAll(RegExp(r'\D'), '');
    final prefix = phonePrefix.startsWith('+') ? phonePrefix : '+$phonePrefix';
    // Avoid doubling country code if user already typed it.
    if (digits.startsWith(prefix.replaceAll('+', ''))) {
      return '+$digits';
    }
    return '$prefix$digits';
  }

  Future<OtpSendResult> sendOtp({
    required String phone,
    required String regionCode,
  }) async {
    final json = await _client.post(
      '/auth/otp/send',
      auth: false,
      body: {
        'phone': phone,
        'regionCode': regionCode,
      },
    );
    return OtpSendResult.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<AuthSession> verifyOtp({
    required String phone,
    required String code,
    required String regionCode,
  }) async {
    final json = await _client.post(
      '/auth/otp/verify',
      auth: false,
      body: {
        'phone': phone,
        'code': code,
        'regionCode': regionCode,
      },
    );
    final session = AuthSession.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    await _storage.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      sessionId: session.sessionId,
      userId: session.user.id,
      phone: phone,
      regionCode: regionCode,
    );
    return session;
  }

  Future<void> recordConsent({
    bool terms = true,
    bool privacy = true,
    bool marketing = false,
  }) async {
    await _client.post(
      '/users/me/consent',
      body: {
        'consents': [
          {'type': 'terms_of_use', 'version': '1.0', 'accepted': terms},
          {'type': 'privacy_policy', 'version': '1.0', 'accepted': privacy},
          {'type': 'marketing', 'version': '1.0', 'accepted': marketing},
        ],
      },
    );
  }

  Future<void> logout() async {
    final refresh = await _storage.refreshToken;
    try {
      if (refresh != null) {
        await _client.post('/auth/logout', body: {'refreshToken': refresh});
      }
    } finally {
      await _storage.clear();
    }
  }
}
