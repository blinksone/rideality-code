import '../core/api/api_client.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.pushEnabled = true,
    this.smsEnabled = true,
    this.emailEnabled = true,
    this.rideUpdates = true,
    this.promotions = false,
  });

  final bool pushEnabled;
  final bool smsEnabled;
  final bool emailEnabled;
  final bool rideUpdates;
  final bool promotions;

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? smsEnabled,
    bool? emailEnabled,
    bool? rideUpdates,
    bool? promotions,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      rideUpdates: rideUpdates ?? this.rideUpdates,
      promotions: promotions ?? this.promotions,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        'smsEnabled': smsEnabled,
        'emailEnabled': emailEnabled,
        'rideUpdates': rideUpdates,
        'promotions': promotions,
      };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushEnabled: json['pushEnabled'] != false,
      smsEnabled: json['smsEnabled'] != false,
      emailEnabled: json['emailEnabled'] != false,
      rideUpdates: json['rideUpdates'] != false,
      promotions: json['promotions'] == true,
    );
  }

  static const empty = NotificationPreferences();
}

class NotificationApiService {
  NotificationApiService({ApiClient? client}) : _client = client ?? ApiClient();

  static final NotificationApiService instance = NotificationApiService();

  final ApiClient _client;

  Future<NotificationPreferences> getPreferences() async {
    final json = await _client.get('/users/me/notification-preferences');
    return NotificationPreferences.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences prefs,
  ) async {
    final json = await _client.patch(
      '/users/me/notification-preferences',
      body: prefs.toJson(),
    );
    return NotificationPreferences.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? prefs.toJson(),
    );
  }
}
