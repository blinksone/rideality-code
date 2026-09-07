import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/api/api_client.dart';
import '../core/api/api_config.dart';
import '../core/storage/active_trip_store.dart';
import '../core/storage/token_storage.dart';
import '../core/vehicle_catalog.dart';
import '../models/trip_models.dart';

/// Socket.IO client for rider/driver real-time trips (JWT handshake).
class RealtimeSocketService {
  RealtimeSocketService._();
  static final RealtimeSocketService instance = RealtimeSocketService._();

  final TokenStorage _storage = TokenStorage.instance;
  final ActiveTripStore _tripStore = ActiveTripStore.instance;
  final ApiClient _api = ApiClient();

  io.Socket? _socket;
  SessionRole? _role;
  String? _rideId;
  String? _vehicleType;
  String? _cityId;
  List<String> _serviceModes = const ['rides'];
  bool _connecting = false;

  final _dispatchOfferController = StreamController<DispatchOffer>.broadcast();
  final _statusController = StreamController<RideStatusChanged>.broadcast();
  final _locationController = StreamController<RideLocationUpdate>.broadcast();
  final _noDriversController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _sessionReadyController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<DispatchOffer> get dispatchOffers => _dispatchOfferController.stream;
  Stream<RideStatusChanged> get statusChanges => _statusController.stream;
  Stream<RideLocationUpdate> get locationUpdates => _locationController.stream;
  Stream<String> get noDrivers => _noDriversController.stream;
  Stream<bool> get connectionChanges => _connectionController.stream;
  Stream<Map<String, dynamic>> get sessionReady =>
      _sessionReadyController.stream;

  bool get isConnected => _socket?.connected == true;
  SessionRole? get role => _role;
  String? get activeRideId => _rideId;

  /// Push (FCM) can feed the same UI streams when WS is offline.
  void injectDispatchOffer(DispatchOffer offer) {
    if (offer.rideId.isEmpty) return;
    if (!_dispatchOfferController.isClosed) {
      _dispatchOfferController.add(offer);
    }
  }

  void injectRideStatus(RideStatusChanged event) {
    if (event.rideId.isEmpty) return;
    if (!_statusController.isClosed) _statusController.add(event);
  }

  void injectNoDrivers(String rideId) {
    if (!_noDriversController.isClosed) {
      _noDriversController.add(rideId);
    }
  }

  Future<void> connectAsDriver({
    String? vehicleType,
    String? rideId,
    String? cityId,
    List<String>? serviceModes,
  }) async {
    _role = SessionRole.driver;
    // Preserve existing session fields unless explicitly overridden.
    if (vehicleType != null && vehicleType.isNotEmpty) {
      _vehicleType = VehicleCatalog.normalize(vehicleType);
    } else {
      _vehicleType ??= VehicleCatalog.economy;
    }
    if (cityId != null && cityId.isNotEmpty) {
      _cityId = cityId;
    } else {
      _cityId ??= await DashboardPrefs.instance.fleetCityId;
    }
    if (rideId != null && rideId.isNotEmpty) {
      _rideId = rideId;
    }
    if (serviceModes != null && serviceModes.isNotEmpty) {
      _serviceModes = List<String>.from(serviceModes);
    } else if (_serviceModes.isEmpty) {
      _serviceModes = const ['rides'];
    }
    await _ensureConnected();
  }

  Future<void> connectAsRider({String? rideId}) async {
    _role = SessionRole.rider;
    if (rideId != null && rideId.isNotEmpty) {
      _rideId = rideId;
    }
    await _ensureConnected();
  }

  Future<void> _ensureConnected() async {
    if (_connecting) return;
    if (_socket?.connected == true) {
      _sendHello();
      return;
    }

    _connecting = true;
    try {
      var token = await _storage.accessToken;
      if (token == null || token.isEmpty) {
        final refreshed = await _api.refreshAccessToken();
        if (refreshed) token = await _storage.accessToken;
      }
      if (token == null || token.isEmpty) {
        throw StateError('No access token for socket auth');
      }

      await _disposeSocketOnly();

      final socket = io.io(
        ApiConfig.wsHost,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(20)
            .setReconnectionDelay(1500)
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );

      _socket = socket;
      _bindSocket(socket);
      socket.connect();
    } finally {
      _connecting = false;
    }
  }

  void _bindSocket(io.Socket socket) {
    socket.onConnect((_) {
      debugPrint('[ws] connected');
      _connectionController.add(true);
      _sendHello();
    });

    socket.onDisconnect((_) {
      debugPrint('[ws] disconnected');
      _connectionController.add(false);
    });

    socket.onConnectError((err) {
      debugPrint('[ws] connect_error: $err');
      _connectionController.add(false);
      // Token may be expired — try refresh once then rebuild.
      unawaited(_tryRefreshAndReconnect());
    });

    socket.on('session:ready', (data) {
      final map = _asMap(data);
      if (map != null) _sessionReadyController.add(map);
    });

    socket.on('ride:joined', (data) {
      final map = _asMap(data);
      final id = map?['rideId']?.toString();
      if (id != null && id.isNotEmpty) _rideId = id;
    });

    socket.on('dispatch:offer', (data) {
      final map = _asMap(data);
      if (map == null) return;
      final offer = DispatchOffer.fromJson(map);
      if (offer.rideId.isEmpty) return;
      _dispatchOfferController.add(offer);
    });

    socket.on('dispatch:response_ack', (data) {
      debugPrint('[ws] dispatch:response_ack $data');
    });

    socket.on('dispatch:no_drivers', (data) {
      final map = _asMap(data);
      final id = map?['rideId']?.toString() ?? _rideId ?? '';
      _noDriversController.add(id);
    });

    socket.on('ride:status_changed', (data) {
      final map = _asMap(data);
      if (map == null) return;
      final event = RideStatusChanged.fromJson(map);
      if (event.rideId.isEmpty) return;
      if (event.status.isTerminal) {
        unawaited(_tripStore.clear());
      } else if (event.rideId.isNotEmpty && _role != null) {
        unawaited(
          _tripStore.save(
            rideId: event.rideId,
            role: _role!,
            vehicleType: _vehicleType,
          ),
        );
      }
      _statusController.add(event);
    });

    socket.on('ride:location_broadcast', (data) {
      final map = _asMap(data);
      if (map == null) return;
      final update = RideLocationUpdate.fromJson(map);
      if (update.rideId.isEmpty) return;
      _locationController.add(update);
    });
  }

  Future<void> _tryRefreshAndReconnect() async {
    final ok = await _api.refreshAccessToken();
    if (!ok || _role == null) return;
    final rideId = _rideId ?? await _tripStore.rideId;
    final vehicle = _vehicleType ?? await _tripStore.vehicleType;
    final modes = List<String>.from(_serviceModes);
    final role = _role;
    await disconnect();
    if (role == SessionRole.driver) {
      await connectAsDriver(
        vehicleType: vehicle,
        rideId: rideId,
        cityId: _cityId,
        serviceModes: modes,
      );
    } else {
      await connectAsRider(rideId: rideId);
    }
  }

  void _sendHello() {
    final role = _role;
    if (role == null || _socket == null) return;
    final payload = <String, dynamic>{
      'role': role == SessionRole.driver ? 'driver' : 'rider',
    };
    if (_rideId != null && _rideId!.isNotEmpty) {
      payload['rideId'] = _rideId;
    }
    if (role == SessionRole.driver) {
      payload['vehicleType'] = VehicleCatalog.normalize(_vehicleType);
      if (_cityId != null && _cityId!.isNotEmpty) {
        payload['cityId'] = _cityId;
      }
      // Always include serviceModes so dispatch filters stay warm while online.
      payload['serviceModes'] =
          _serviceModes.isNotEmpty ? _serviceModes : const ['rides'];
    }
    _socket!.emit('session:hello', payload);
  }

  /// Re-send hello (and optional ride join) after local state update.
  Future<void> updateSession({
    String? rideId,
    String? vehicleType,
    String? cityId,
    SessionRole? role,
    List<String>? serviceModes,
  }) async {
    if (role != null) _role = role;
    if (rideId != null) _rideId = rideId;
    if (vehicleType != null) {
      _vehicleType = VehicleCatalog.normalize(vehicleType);
    }
    if (cityId != null && cityId.isNotEmpty) _cityId = cityId;
    if (serviceModes != null && serviceModes.isNotEmpty) {
      _serviceModes = serviceModes;
    }
    if (_role == null) return;
    await _ensureConnected();
    _sendHello();
  }

  void joinRide(String rideId) {
    _rideId = rideId;
    _socket?.emit('ride:join', {'rideId': rideId});
    if (_role != null) {
      unawaited(
        _tripStore.save(
          rideId: rideId,
          role: _role!,
          vehicleType: _vehicleType,
        ),
      );
    }
  }

  void leaveRide(String rideId) {
    _socket?.emit('ride:leave', {'rideId': rideId});
    if (_rideId == rideId) _rideId = null;
    unawaited(_tripStore.clear());
  }

  void emitDriverLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    String? vehicleType,
    String? cityId,
    List<String>? serviceModes,
  }) {
    if (_socket?.connected != true) return;
    final product = VehicleCatalog.normalize(
      vehicleType ?? _vehicleType,
    );
    final city = (cityId != null && cityId.isNotEmpty) ? cityId : _cityId;
    final payload = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'vehicleType': product,
      'serviceModes': (serviceModes != null && serviceModes.isNotEmpty)
          ? serviceModes
          : (_serviceModes.isNotEmpty ? _serviceModes : const ['rides']),
    };
    if (heading != null) payload['heading'] = heading;
    if (speed != null) payload['speed'] = speed;
    if (city != null && city.isNotEmpty) payload['cityId'] = city;
    // Active ride id helps server scope broadcasts and skip completed rooms.
    if (_rideId != null && _rideId!.isNotEmpty) {
      payload['rideId'] = _rideId;
    }
    _socket!.emit('driver:location_update', payload);
  }

  void emitDispatchResponse({
    required String rideId,
    required bool accepted,
  }) {
    _socket?.emit('dispatch:response', {
      'rideId': rideId,
      'accepted': accepted,
    });
    if (accepted) {
      _rideId = rideId;
      // Join once here — callers must not join again for the same accept.
      joinRide(rideId);
      _sendHello();
    }
  }

  /// Resume from [ActiveTripStore] after app cold start.
  Future<void> resumeIfNeeded() async {
    final rideId = await _tripStore.rideId;
    final role = await _tripStore.role;
    if (rideId == null || role == null) return;
    final vehicle = await _tripStore.vehicleType;
    if (role == SessionRole.driver) {
      await connectAsDriver(vehicleType: vehicle, rideId: rideId);
    } else {
      await connectAsRider(rideId: rideId);
      joinRide(rideId);
    }
  }

  Future<void> disconnect() async {
    _role = null;
    _rideId = null;
    await _disposeSocketOnly();
  }

  Future<void> _disposeSocketOnly() async {
    final s = _socket;
    _socket = null;
    if (s == null) return;
    try {
      s.disconnect();
      s.dispose();
    } catch (_) {}
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return data.cast<String, dynamic>();
    if (data is List && data.isNotEmpty && data.first is Map) {
      return (data.first as Map).cast<String, dynamic>();
    }
    return null;
  }
}
