import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../models/api_models.dart';

/// Mobile onboarding against the **live** API surface.
///
/// Live backend:
/// - POST /users/me/profile  (role: passenger | driver | both)
/// - GET  /users/me/onboarding
/// - POST /users/me/locations
///
/// Postman also documents `/onboarding/*` — those still 404 on the current server.
class OnboardingApiService {
  OnboardingApiService({ApiClient? client}) : _client = client ?? ApiClient();

  static final OnboardingApiService instance = OnboardingApiService();

  final ApiClient _client;

  Future<OnboardingResult> completePassenger({
    required String fullName,
    String? email,
    String? dateOfBirth,
    String? gender,
    String? profession,
    String preferredLanguage = 'en',
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool acceptTerms = true,
    bool acceptPrivacy = true,
    bool acceptMarketing = false,
    bool promoOptIn = false,
    String consentVersion = '1.0',
    SavedLocationInput? location,
  }) async {
    final body = <String, dynamic>{
      'fullName': fullName.trim(),
      'role': 'passenger',
      'preferredLanguage': preferredLanguage,
      'acceptTerms': acceptTerms,
      'acceptPrivacy': acceptPrivacy,
      'acceptMarketing': acceptMarketing,
      'promoOptIn': promoOptIn,
      'consentVersion': consentVersion,
    };
    _putIfNotEmpty(body, 'email', email);
    _putIfNotEmpty(body, 'dateOfBirth', dateOfBirth);
    _putIfNotEmpty(body, 'gender', gender);
    _putIfNotEmpty(body, 'profession', profession);
    _putIfNotEmpty(body, 'emergencyContactName', emergencyContactName);
    _putIfNotEmpty(body, 'emergencyContactPhone', emergencyContactPhone);

    final result = await _completeProfile(body);

    if (location != null) {
      try {
        await _client.post(
          '/users/me/locations',
          body: {
            'locations': [location.toJson()],
          },
        );
        final status = await getStatus();
        return OnboardingResult(
          onboarding: status,
          type: 'passenger',
          canBook: status.canBook || result.canBook,
          canDrive: status.canDrive || result.canDrive,
          nextSteps: status.pendingSteps,
          fullName: result.fullName ?? fullName.trim(),
        );
      } catch (_) {
        // Location can be finished on the next screen.
      }
    }

    return result;
  }

  Future<OnboardingResult> completeDriver({
    required String fullName,
    required String dateOfBirth,
    required String companyId,
    required String fleetRegionId,
    String? email,
    String? gender,
    String? profession,
    String preferredLanguage = 'en',
    String? licenseNumber,
    String? licenseExpiry,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool acceptTerms = true,
    bool acceptPrivacy = true,
    String consentVersion = '1.0',
    SavedLocationInput? location,
  }) async {
    final body = <String, dynamic>{
      'fullName': fullName.trim(),
      'dateOfBirth': dateOfBirth.trim(),
      'companyId': companyId,
      // Ops city (company.fleetRegionId) — not geo city id from /fleet/cities.
      'regionId': fleetRegionId,
      'preferredLanguage': preferredLanguage,
      'acceptTerms': acceptTerms,
      'acceptPrivacy': acceptPrivacy,
      'consentVersion': consentVersion,
    };
    _putIfNotEmpty(body, 'email', email);
    _putIfNotEmpty(body, 'gender', gender);
    _putIfNotEmpty(body, 'profession', profession);
    _putIfNotEmpty(body, 'licenseNumber', licenseNumber);
    _putIfNotEmpty(body, 'licenseExpiry', licenseExpiry);
    _putIfNotEmpty(body, 'emergencyContactName', emergencyContactName);
    _putIfNotEmpty(body, 'emergencyContactPhone', emergencyContactPhone);
    if (location != null) {
      body['location'] = location.toJson();
    }

    try {
      final json = await _client.post('/onboarding/driver', body: body);
      return OnboardingResult.fromJson(
        (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    } on ApiException catch (e) {
      if (!_isRouteMissing(e) && e.statusCode != 405) rethrow;
    }

    body['role'] = 'driver';
    return _completeProfile(body);
  }

  Future<OnboardingStatus> getStatus() async {
    try {
      final json = await _client.get('/onboarding/status');
      return OnboardingStatus.fromApiPayload(
        (json['data'] as Map?)?.cast<String, dynamic>(),
      );
    } on ApiException catch (e) {
      if (!_isRouteMissing(e)) rethrow;
      final json = await _client.get('/users/me/onboarding');
      return OnboardingStatus.fromApiPayload(
        (json['data'] as Map?)?.cast<String, dynamic>(),
      );
    }
  }

  Future<OnboardingResult> _completeProfile(Map<String, dynamic> body) async {
    // 1) Live path (verified working).
    try {
      final json = await _client.post('/users/me/profile', body: body);
      return OnboardingResult.fromJson(
        (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    } on ApiException catch (e) {
      if (!_isRouteMissing(e) && e.statusCode != 405) {
        // Profile may already exist — try partial update then read back status.
        if (e.statusCode == 409 ||
            e.statusCode == 400 ||
            (e.message.toLowerCase().contains('already'))) {
          return _patchThenStatus(body);
        }
        rethrow;
      }
    }

    // 2) Documented Postman path (may be deployed later).
    try {
      final json = await _client.post('/onboarding/passenger', body: body);
      return OnboardingResult.fromJson(
        (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    } on ApiException catch (e) {
      if (!_isRouteMissing(e)) rethrow;
    }

    // 3) Last resort: PATCH name/email + load me.
    try {
      return await _patchThenStatus(body);
    } on ApiException catch (e) {
      throw ApiException(
        'Could not save profile. ${e.message}',
        statusCode: e.statusCode,
        code: e.code,
      );
    }
  }

  Future<OnboardingResult> _patchThenStatus(Map<String, dynamic> body) async {
    final patch = <String, dynamic>{};
    if (body['fullName'] != null) patch['fullName'] = body['fullName'];
    if (body['email'] != null) patch['email'] = body['email'];
    if (body['preferredLanguage'] != null) {
      patch['preferredLanguage'] = body['preferredLanguage'];
    }
    if (patch.isNotEmpty) {
      await _client.patch('/users/me', body: patch);
    }
    final me = await _client.get('/users/me');
    final data = (me['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OnboardingResult.fromJson(data);
  }

  bool _isRouteMissing(ApiException e) {
    final m = e.message.toLowerCase();
    return e.code == 'ROUTE_NOT_FOUND' ||
        e.statusCode == 404 ||
        m.contains('route not found') ||
        m.contains('cannot post') ||
        m.contains('not found');
  }
}

void _putIfNotEmpty(Map<String, dynamic> body, String key, String? value) {
  if (value != null && value.trim().isNotEmpty) {
    body[key] = value.trim();
  }
}

class SavedLocationInput {
  const SavedLocationInput({
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isDefault = true,
  });

  final String label;
  final String address;
  final double latitude;
  final double longitude;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'isDefault': isDefault,
      };
}

class OnboardingResult {
  const OnboardingResult({
    required this.onboarding,
    this.type,
    this.canBook = false,
    this.canDrive = false,
    this.nextSteps = const [],
    this.fullName,
  });

  final OnboardingStatus onboarding;
  final String? type;
  final bool canBook;
  final bool canDrive;
  final List<String> nextSteps;
  final String? fullName;

  factory OnboardingResult.fromJson(Map<String, dynamic> json) {
    final nested = json['onboarding'];
    final obMap = nested is Map ? nested.cast<String, dynamic>() : json;
    final caps = (json['capabilities'] as Map?)?.cast<String, dynamic>() ?? {};
    final profile = (json['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final userProfile =
        (user['profile'] as Map?)?.cast<String, dynamic>() ?? profile;

    final next = json['next_steps'] ??
        json['nextSteps'] ??
        obMap['pending_steps'] ??
        json['pending_steps'];

    List<String> nextSteps;
    if (next is List) {
      nextSteps = next.map((e) => e.toString()).toList();
    } else if (next is String && next.isNotEmpty) {
      nextSteps = [next];
    } else {
      nextSteps = const [];
    }

    return OnboardingResult(
      type: json['type']?.toString() ?? json['activeMode']?.toString(),
      onboarding: OnboardingStatus.fromApiPayload({
        ...json,
        if (nested is Map) 'onboarding': nested,
      }),
      canBook: caps['can_book'] == true,
      canDrive: caps['can_drive'] == true,
      nextSteps: nextSteps,
      fullName: userProfile['fullName']?.toString() ??
          profile['fullName']?.toString() ??
          json['fullName']?.toString(),
    );
  }
}
