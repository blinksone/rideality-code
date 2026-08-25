import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/navigation/app_navigator.dart';
import '../core/storage/token_storage.dart';
import '../models/trip_models.dart';
import '../screens/driver/driver_dashboard_screen.dart';
import '../screens/passenger/passenger_dashboard_screen.dart';
import '../screens/shared/active_ride_screen.dart';
import 'notification_api_service.dart';
import 'realtime_socket_service.dart';

/// Channel id must match backend FCM Android config.
const String kRidealityRidesChannelId = 'rideality_rides';
const String kRidealityRidesChannelName = 'Rideality rides';

/// Firebase Cloud Messaging + local notifications for ride push.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final NotificationApiService _api = NotificationApiService.instance;
  final RealtimeSocketService _socket = RealtimeSocketService.instance;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  bool _started = false;

  final _events = StreamController<PushRideEvent>.broadcast();

  /// App-level stream (driver map / active ride / home can listen).
  Stream<PushRideEvent> get events => _events.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _initLocalNotifications();
    await _requestPermission();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _onMessageSub = FirebaseMessaging.onMessage.listen(_onForeground);
    _onOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
      unawaited(_api.registerFcmTokenSafe(token));
    });

    // Cold start (app was killed, user tapped notification).
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Wait for navigator to exist.
      WidgetsBindingSafe.addPostFrame(() {
        unawaited(_handleMessage(initial, fromUserTap: true));
      });
    }

    // Register token if already logged in (session restore).
    final hasSession = await TokenStorage.instance.hasSession;
    if (hasSession) {
      await registerTokenWithBackend();
    }

    debugPrint('[FCM] PushNotificationService started');
  }

  /// Call after OTP login / whenever access token is available.
  Future<void> registerTokenWithBackend() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] getToken() returned null');
        return;
      }
      debugPrint('[FCM] token length=${token.length}');
      await _api.registerFcmTokenSafe(token);
    } catch (e) {
      debugPrint('[FCM] registerToken failed: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('[FCM] permission=${settings.authorizationStatus}');

    // Android 13+ runtime POST_NOTIFICATIONS is requested via local plugin.
    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const init = InitializationSettings(android: androidInit, iOS: iosInit);

    await _local.initialize(
      settings: init,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          unawaited(_handleDataMap(map, fromUserTap: true));
        } catch (e) {
          debugPrint('[FCM] local tap parse: $e');
        }
      },
    );

    const channel = AndroidNotificationChannel(
      kRidealityRidesChannelId,
      kRidealityRidesChannelName,
      description: 'Ride offers, trip status, and matching updates',
      importance: Importance.high,
      playSound: true,
    );

    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
  }

  Future<void> _onForeground(RemoteMessage message) async {
    debugPrint('[FCM fg] type=${message.data['type']}');
    await _showLocalNotification(message);
    await _handleMessage(message, fromUserTap: false);
  }

  Future<void> _onMessageOpened(RemoteMessage message) async {
    debugPrint('[FCM open] type=${message.data['type']}');
    await _handleMessage(message, fromUserTap: true);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString() ?? '';
    final title = message.notification?.title ??
        _titleForType(type) ??
        'Rideality';
    final body = message.notification?.body ??
        _bodyForType(type, data) ??
        'Open the app for details';

    final androidDetails = AndroidNotificationDetails(
      kRidealityRidesChannelId,
      kRidealityRidesChannelName,
      channelDescription: 'Ride offers, trip status, and matching updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _local.show(
      id: message.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: ios,
      ),
      payload: jsonEncode(data),
    );
  }

  String? _titleForType(String type) {
    return switch (type) {
      'dispatch.offer' => 'New ride request',
      'ride.status_changed' => 'Trip update',
      'dispatch.no_drivers' => 'No drivers nearby',
      _ => null,
    };
  }

  String? _bodyForType(String type, Map<String, dynamic> data) {
    return switch (type) {
      'dispatch.offer' => () {
          final fare = data['fareEstimate'] ?? data['fare'];
          final name = data['riderName'] ?? 'Passenger';
          if (fare != null) return '$name · fare $fare';
          return name.toString();
        }(),
      'ride.status_changed' =>
        'Status: ${data['status'] ?? 'updated'}',
      'dispatch.no_drivers' =>
        'No drivers available. Try again shortly.',
      _ => null,
    };
  }

  Future<void> _handleMessage(
    RemoteMessage message, {
    required bool fromUserTap,
  }) async {
    await _handleDataMap(
      Map<String, dynamic>.from(message.data),
      fromUserTap: fromUserTap,
    );
  }

  Future<void> _handleDataMap(
    Map<String, dynamic> data, {
    required bool fromUserTap,
  }) async {
    final type = data['type']?.toString() ?? '';
    final event = PushRideEvent.fromData(data);
    if (!_events.isClosed) _events.add(event);

    // Feed socket-style streams so UI reacts even without WS.
    switch (type) {
      case 'dispatch.offer':
        final offer = _offerFromData(data);
        if (offer != null) {
          _socket.injectDispatchOffer(offer);
        }
        if (fromUserTap) {
          AppNavigator.state?.pushNamedAndRemoveUntil(
            DriverDashboardScreen.routeName,
            (r) => false,
          );
        }
      case 'ride.status_changed':
        final statusEvent = _statusFromData(data);
        if (statusEvent != null) {
          _socket.injectRideStatus(statusEvent);
        }
        if (fromUserTap) {
          final rideId = data['rideId']?.toString() ?? '';
          if (rideId.isNotEmpty) {
            AppNavigator.state?.pushNamed(
              ActiveRideScreen.routeName,
              arguments: ActiveRideArgs(
                tripId: rideId,
                role: SessionRole.rider, // best-effort; UI refreshes via GET
              ),
            );
          }
        }
      case 'dispatch.no_drivers':
        final rideId = data['rideId']?.toString() ?? '';
        _socket.injectNoDrivers(rideId);
        if (fromUserTap) {
          AppNavigator.state?.pushNamedAndRemoveUntil(
            PassengerDashboardScreen.routeName,
            (r) => false,
          );
        }
      default:
        break;
    }
  }

  DispatchOffer? _offerFromData(Map<String, dynamic> data) {
    final rideId = data['rideId']?.toString() ?? data['id']?.toString() ?? '';
    if (rideId.isEmpty) return null;
    return DispatchOffer.fromJson(data);
  }

  RideStatusChanged? _statusFromData(Map<String, dynamic> data) {
    final rideId = data['rideId']?.toString() ?? '';
    if (rideId.isEmpty) return null;
    return RideStatusChanged.fromJson(data);
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    await _events.close();
    _started = false;
  }
}

/// Normalized push event for listeners.
class PushRideEvent {
  const PushRideEvent({
    required this.type,
    required this.data,
    this.rideId,
    this.status,
  });

  final String type;
  final Map<String, dynamic> data;
  final String? rideId;
  final String? status;

  factory PushRideEvent.fromData(Map<String, dynamic> data) {
    return PushRideEvent(
      type: data['type']?.toString() ?? '',
      data: data,
      rideId: data['rideId']?.toString(),
      status: data['status']?.toString(),
    );
  }
}

/// Avoid importing flutter/widgets in pure util paths incorrectly —
/// use a tiny post-frame helper.
class WidgetsBindingSafe {
  static void addPostFrame(void Function() fn) {
    // Debounce to next event loop if binding not ready.
    scheduleMicrotask(() {
      Future<void>.delayed(const Duration(milliseconds: 300), fn);
    });
  }
}
