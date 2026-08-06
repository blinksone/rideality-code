import '../core/api/api_client.dart';
import '../core/api/api_config.dart';
import '../core/api/api_exception.dart';
import '../models/api_models.dart';
import 'onboarding_api_service.dart';

class UserApiService {
  UserApiService({ApiClient? client, OnboardingApiService? onboardingApi})
      : _client = client ?? ApiClient(),
        _onboardingApi = onboardingApi ?? OnboardingApiService.instance;

  static final UserApiService instance = UserApiService();

  final ApiClient _client;
  final OnboardingApiService _onboardingApi;

  Future<UserProfile> getMe() async {
    final json = await _client.get('/users/me');
    return UserProfile.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<OnboardingStatus> getOnboarding() async {
    return _onboardingApi.getStatus();
  }

  Future<PassengerView> getPassengerView() async {
    final json = await _client.get('/users/me/passenger');
    return PassengerView.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<WalletInfo> getWallet() async {
    final json = await _client.get('/users/me/wallet');
    return WalletInfo.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<List<WalletTransaction>> listWalletTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _client.get(
      '/users/me/wallet/transactions?page=$page&limit=$limit',
    );
    final data = json['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => WalletTransaction.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => WalletTransaction.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<List<RideSummary>> listMyRides({
    int page = 1,
    int limit = 20,
    String status = 'all',
  }) async {
    final json = await _client.get(
      '/users/me/rides?page=$page&limit=$limit&status=$status',
    );
    final data = json['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => RideSummary.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => RideSummary.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  /// PATCH /users/me — fullName, email, optional DOB / gender / language.
  /// Always reloads [GET /users/me] so clients see canonical server state.
  Future<UserProfile> updateProfile({
    String? fullName,
    String? email,
    String? preferredLanguage,
    String? dateOfBirth,
    String? gender,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null && fullName.trim().isNotEmpty) {
      body['fullName'] = fullName.trim();
    }
    if (email != null) {
      final e = email.trim();
      if (e.isNotEmpty) body['email'] = e;
    }
    if (preferredLanguage != null && preferredLanguage.trim().isNotEmpty) {
      body['preferredLanguage'] = preferredLanguage.trim();
    }
    if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty) {
      body['dateOfBirth'] = dateOfBirth.trim();
    }
    final normalizedGender = UserProfile.normalizeGender(gender);
    if (normalizedGender != null) {
      body['gender'] = normalizedGender;
    }

    if (body.isEmpty) return getMe();

    try {
      await _client.patch('/users/me', body: body);
    } on ApiException catch (e) {
      // Some backends only accept core fields on PATCH — retry without extras.
      final extrasOnlyFailure = e.statusCode == 400 || e.statusCode == 422;
      final hasExtras = body.containsKey('dateOfBirth') ||
          body.containsKey('gender') ||
          body.containsKey('preferredLanguage');
      if (extrasOnlyFailure && hasExtras) {
        final core = <String, dynamic>{};
        if (body['fullName'] != null) core['fullName'] = body['fullName'];
        if (body['email'] != null) core['email'] = body['email'];
        if (core.isEmpty) rethrow;
        await _client.patch('/users/me', body: core);
        // Keep going — DOB/gender may not be persisted by this API version.
      } else {
        rethrow;
      }
    }

    return getMe();
  }

  /// POST /users/me/photo (multipart field `photo`).
  /// Returns absolute URL; falls back to GET /users/me when response omits URL.
  Future<String> uploadPhoto(String filePath) async {
    String? raw;
    try {
      final json = await _client.multipartPost(
        '/users/me/photo',
        fieldName: 'photo',
        filePath: filePath,
      );
      final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final profile = (data['profile'] as Map?)?.cast<String, dynamic>() ?? {};
      raw = data['photoUrl']?.toString() ??
          data['url']?.toString() ??
          data['path']?.toString() ??
          profile['photoUrl']?.toString() ??
          json['photoUrl']?.toString();
    } on ApiException {
      rethrow;
    }

    final resolved = ApiConfig.resolveMediaUrl(raw);
    if (resolved != null && resolved.isNotEmpty) return resolved;

    final me = await getMe();
    return me.photoUrl ?? '';
  }

  Future<void> saveLocations({
    required String label,
    required String address,
    required double latitude,
    required double longitude,
    bool isDefault = true,
  }) async {
    await _client.post(
      '/users/me/locations',
      body: {
        'locations': [
          {
            'label': label,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
            'isDefault': isDefault,
          },
        ],
      },
    );
  }
}
