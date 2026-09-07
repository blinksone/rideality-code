import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _session = 'session_id';
  static const _userId = 'user_id';
  static const _phone = 'phone';
  static const _region = 'region_code';
  static const _countryRegionId = 'country_region_id';
  static const _pendingOnboardingIntent = 'pending_onboarding_intent';

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? sessionId,
    String? userId,
    String? phone,
    String? regionCode,
    String? countryRegionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_access, accessToken);
    await prefs.setString(_refresh, refreshToken);
    if (sessionId != null) await prefs.setString(_session, sessionId);
    if (userId != null) await prefs.setString(_userId, userId);
    if (phone != null) await prefs.setString(_phone, phone);
    if (regionCode != null) await prefs.setString(_region, regionCode);
    if (countryRegionId != null && countryRegionId.isNotEmpty) {
      await prefs.setString(_countryRegionId, countryRegionId);
    }
  }

  /// Updates tokens after [POST /auth/refresh] (refresh may be rotated).
  Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
    String? sessionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_access, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refresh, refreshToken);
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      await prefs.setString(_session, sessionId);
    }
  }

  Future<String?> get accessToken async =>
      (await SharedPreferences.getInstance()).getString(_access);

  Future<String?> get refreshToken async =>
      (await SharedPreferences.getInstance()).getString(_refresh);

  Future<String?> get userId async =>
      (await SharedPreferences.getInstance()).getString(_userId);

  Future<String?> get phone async =>
      (await SharedPreferences.getInstance()).getString(_phone);

  Future<String?> get regionCode async =>
      (await SharedPreferences.getInstance()).getString(_region);

  Future<String?> get countryRegionId async =>
      (await SharedPreferences.getInstance()).getString(_countryRegionId);

  /// True when a non-empty access token is stored (session may still be expired).
  Future<bool> get hasSession async {
    final token = await accessToken;
    return token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_access);
    await prefs.remove(_refresh);
    await prefs.remove(_session);
    await prefs.remove(_userId);
    await prefs.remove(_phone);
    await prefs.remove(_region);
    await prefs.remove(_countryRegionId);
    await prefs.remove(_pendingOnboardingIntent);
  }

  /// Used to restore onboarding flow across app relaunches
  /// (e.g. driver OTP → abandon driver steps → next cold start).
  Future<void> setPendingOnboardingIntent(String? intent) async {
    final prefs = await SharedPreferences.getInstance();
    if (intent == null || intent.isEmpty) {
      await prefs.remove(_pendingOnboardingIntent);
      return;
    }
    await prefs.setString(_pendingOnboardingIntent, intent);
  }

  Future<String?> get pendingOnboardingIntent async =>
      (await SharedPreferences.getInstance())
          .getString(_pendingOnboardingIntent);
}

/// Local UI flags for passenger dashboard (banner dismissals, last search).
class DashboardPrefs {
  DashboardPrefs._();
  static final DashboardPrefs instance = DashboardPrefs._();

  static const _profileBanner = 'hide_profile_progress_banner';
  static const _promoBanner = 'hide_promo_banner';
  static const _lastDestination = 'last_destination_query';
  static const _fleetCompanyName = 'fleet_company_name';
  static const _fleetCityName = 'fleet_city_name';
  static const _fleetCompanyId = 'fleet_company_id';
  static const _fleetCityId = 'fleet_city_id';

  Future<bool> get isProfileBannerHidden async =>
      (await SharedPreferences.getInstance()).getBool(_profileBanner) ?? false;

  Future<void> hideProfileBanner() async {
    await (await SharedPreferences.getInstance()).setBool(_profileBanner, true);
  }

  Future<bool> get isPromoBannerHidden async =>
      (await SharedPreferences.getInstance()).getBool(_promoBanner) ?? false;

  Future<void> hidePromoBanner() async {
    await (await SharedPreferences.getInstance()).setBool(_promoBanner, true);
  }

  Future<String?> get lastDestination async =>
      (await SharedPreferences.getInstance()).getString(_lastDestination);

  Future<void> setLastDestination(String value) async {
    await (await SharedPreferences.getInstance())
        .setString(_lastDestination, value);
  }

  Future<void> saveFleetAssignment({
    required String companyId,
    required String companyName,
    required String cityId,
    required String cityName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fleetCompanyId, companyId);
    await prefs.setString(_fleetCompanyName, companyName);
    await prefs.setString(_fleetCityId, cityId);
    await prefs.setString(_fleetCityName, cityName);
  }

  Future<String?> get fleetCompanyName async =>
      (await SharedPreferences.getInstance()).getString(_fleetCompanyName);

  Future<String?> get fleetCityName async =>
      (await SharedPreferences.getInstance()).getString(_fleetCityName);

  /// Geo city UUID saved during fleet onboarding (for Redis supply / hello).
  Future<String?> get fleetCityId async =>
      (await SharedPreferences.getInstance()).getString(_fleetCityId);
}

/// In-app notification inbox (local). Live server has prefs APIs only, no feed.
class NotificationInbox {
  NotificationInbox._();
  static final NotificationInbox instance = NotificationInbox._();

  static const _key = 'passenger_notification_inbox_v1';

  Future<List<AppNotification>> list() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(e.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<AppNotification> items) async {
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await (await SharedPreferences.getInstance()).setString(_key, payload);
  }

  Future<int> unreadCount() async {
    final items = await list();
    return items.where((e) => !e.read).length;
  }

  Future<void> markRead(String id) async {
    final items = await list();
    final next = items
        .map((e) => e.id == id ? e.copyWith(read: true) : e)
        .toList();
    await _save(next);
  }

  Future<void> markAllRead() async {
    final items = await list();
    await _save(items.map((e) => e.copyWith(read: true)).toList());
  }

  Future<void> clearAll() async {
    await (await SharedPreferences.getInstance()).remove(_key);
  }

  /// Inserts missing system messages (idempotent by id).
  Future<List<AppNotification>> ensureSystemMessages({
    required bool profileIncomplete,
    required bool canBook,
    String? fullName,
    int rideCount = 0,
  }) async {
    final items = await list();
    final byId = {for (final n in items) n.id: n};
    final now = DateTime.now();

    void put(AppNotification n) {
      byId.putIfAbsent(n.id, () => n);
    }

    put(
      AppNotification(
        id: 'sys_welcome',
        title: 'Welcome to Rideality',
        body: fullName != null && fullName.isNotEmpty
            ? 'Hi $fullName — you\'re set to explore city rides.'
            : 'You\'re set to explore city rides that feel personal.',
        type: NotificationType.system,
        createdAt: now.subtract(const Duration(days: 1)),
        read: byId['sys_welcome']?.read ?? false,
      ),
    );

    if (profileIncomplete) {
      put(
        AppNotification(
          id: 'sys_profile_incomplete',
          title: 'Finish your profile',
          body:
              'Add your email and a saved place to activate your account.',
          type: NotificationType.account,
          createdAt: now.subtract(const Duration(hours: 2)),
          read: byId['sys_profile_incomplete']?.read ?? false,
        ),
      );
    }

    put(
      AppNotification(
        id: 'sys_promo_50',
        title: '50% off your next 3 rides',
        body: 'Limited promo — valid until Friday. Book a ride anytime.',
        type: NotificationType.promo,
        createdAt: now.subtract(const Duration(hours: 5)),
        read: byId['sys_promo_50']?.read ?? false,
      ),
    );

    if (canBook) {
      put(
        AppNotification(
          id: 'sys_ready_to_book',
          title: 'You can book a ride',
          body: 'Pick a destination on Home to find nearby drivers.',
          type: NotificationType.ride,
          createdAt: now.subtract(const Duration(hours: 1)),
          read: byId['sys_ready_to_book']?.read ?? false,
        ),
      );
    }

    if (rideCount > 0) {
      put(
        AppNotification(
          id: 'sys_rides_summary',
          title: 'Trip history ready',
          body:
              'You have $rideCount trip${rideCount == 1 ? '' : 's'} in Activity.',
          type: NotificationType.ride,
          createdAt: now.subtract(const Duration(minutes: 30)),
          read: byId['sys_rides_summary']?.read ?? false,
        ),
      );
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _save(merged);
    return merged;
  }
}

enum NotificationType { system, account, ride, promo, other }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? 'other';
    final type = NotificationType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => NotificationType.other,
    );
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      type: type,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      read: json['read'] == true,
    );
  }
}
