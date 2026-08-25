import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';

/// User notification toggles (GET/PATCH /me/notification-preferences).
class NotificationPreferences {
  const NotificationPreferences({
    this.pushEnabled = true,
    this.rideUpdates = true,
    this.smsEnabled = true,
    this.emailEnabled = true,
    this.promotions = true,
  });

  final bool pushEnabled;
  final bool rideUpdates;
  final bool smsEnabled;
  final bool emailEnabled;
  final bool promotions;

  static const empty = NotificationPreferences();

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? rideUpdates,
    bool? smsEnabled,
    bool? emailEnabled,
    bool? promotions,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      rideUpdates: rideUpdates ?? this.rideUpdates,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      promotions: promotions ?? this.promotions,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        'rideUpdates': rideUpdates,
        'smsEnabled': smsEnabled,
        'emailEnabled': emailEnabled,
        'promotions': promotions,
        // Aliases some backends use
        'marketing': promotions,
      };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    bool read(String a, [String? b]) {
      if (json[a] == true || json[a] == false) return json[a] as bool;
      if (b != null && (json[b] == true || json[b] == false)) {
        return json[b] as bool;
      }
      // Nested data keys
      return true;
    }

    return NotificationPreferences(
      pushEnabled: read('pushEnabled', 'push_enabled'),
      rideUpdates: read('rideUpdates', 'ride_updates'),
      smsEnabled: read('smsEnabled', 'sms_enabled'),
      emailEnabled: read('emailEnabled', 'email_enabled'),
      promotions: () {
        if (json['promotions'] == true || json['promotions'] == false) {
          return json['promotions'] as bool;
        }
        if (json['marketing'] == true || json['marketing'] == false) {
          return json['marketing'] as bool;
        }
        return true;
      }(),
    );
  }
}

/// REST APIs for device push registration and preferences.
class NotificationApiService {
  NotificationApiService({ApiClient? client}) : _client = client ?? ApiClient();

  static final NotificationApiService instance = NotificationApiService();

  final ApiClient _client;

  /// POST /me/fcm-token — register FCM token after login / on refresh.
  Future<void> registerFcmToken({
    required String fcmToken,
    String? deviceName,
    String? platform,
  }) async {
    final body = <String, dynamic>{
      'fcmToken': fcmToken,
      'platform': platform ??
          (Platform.isIOS
              ? 'ios'
              : Platform.isAndroid
                  ? 'android'
                  : 'other'),
    };
    if (deviceName != null && deviceName.isNotEmpty) {
      body['deviceName'] = deviceName;
    }
    await _client.post('/me/fcm-token', body: body);
  }

  /// Best-effort: ignore failures so push never blocks auth.
  Future<void> registerFcmTokenSafe(String fcmToken) async {
    try {
      final hasSession = await TokenStorage.instance.hasSession;
      if (!hasSession || fcmToken.isEmpty) return;
      await registerFcmToken(
        fcmToken: fcmToken,
        deviceName: await _deviceName(),
      );
    } catch (_) {}
  }

  /// GET /me/notification-preferences
  Future<NotificationPreferences> getPreferences() async {
    final json = await _client.get('/me/notification-preferences');
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ??
        (json.containsKey('pushEnabled') || json.containsKey('rideUpdates')
            ? json
            : const <String, dynamic>{});
    if (data.isEmpty) return NotificationPreferences.empty;
    return NotificationPreferences.fromJson(data);
  }

  /// PATCH /me/notification-preferences
  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences prefs,
  ) async {
    final json = await _client.patch(
      '/me/notification-preferences',
      body: prefs.toJson(),
    );
    final data = (json['data'] as Map?)?.cast<String, dynamic>();
    if (data != null && data.isNotEmpty) {
      return NotificationPreferences.fromJson(data);
    }
    return prefs;
  }

  /// Convenience partial patch (optional).
  Future<void> patchNotificationPreferences({
    bool? pushEnabled,
    bool? rideUpdates,
    bool? marketing,
  }) async {
    final body = <String, dynamic>{};
    if (pushEnabled != null) body['pushEnabled'] = pushEnabled;
    if (rideUpdates != null) body['rideUpdates'] = rideUpdates;
    if (marketing != null) {
      body['marketing'] = marketing;
      body['promotions'] = marketing;
    }
    if (body.isEmpty) return;
    await _client.patch('/me/notification-preferences', body: body);
  }

  Future<String?> _deviceName() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        return '${a.manufacturer} ${a.model}';
      }
      if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        return i.name;
      }
    } catch (_) {}
    return null;
  }
}
