import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/vehicle_catalog.dart';
import 'realtime_socket_service.dart';

/// Throttled driver GPS → `driver:location_update`
/// (every 4–5s **or** ≥15m move). Stop when going offline.
class DriverLocationTracker {
  DriverLocationTracker._();
  static final DriverLocationTracker instance = DriverLocationTracker._();

  final RealtimeSocketService _socket = RealtimeSocketService.instance;

  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  DateTime? _lastEmit;
  Position? _lastPosition;
  String? _vehicleType;
  String? _cityId;
  List<String> _serviceModes = const ['rides'];
  bool _running = false;

  static const _minEmitGap = Duration(milliseconds: 4000);
  static const _heartbeatEvery = Duration(seconds: 5);

  bool get isRunning => _running;

  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled;
  }

  Future<Position?> currentPosition() async {
    final ok = await ensurePermission();
    if (!ok) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> start({
    String vehicleType = VehicleCatalog.economy,
    String? cityId,
    List<String>? serviceModes,
  }) async {
    if (serviceModes != null && serviceModes.isNotEmpty) {
      _serviceModes = List<String>.from(serviceModes);
    }
    _vehicleType = VehicleCatalog.normalize(vehicleType);
    if (cityId != null && cityId.isNotEmpty) _cityId = cityId;
    if (_running) return;

    final ok = await ensurePermission();
    if (!ok) {
      throw StateError('Location permission or service unavailable');
    }

    _running = true;
    _lastEmit = null;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (_) {},
    );

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatEvery, (_) {
      final p = _lastPosition;
      if (p != null) _emit(p, force: true);
    });

    final first = await currentPosition();
    if (first != null) _onPosition(first);
  }

  void updateServiceModes(List<String> modes) {
    if (modes.isNotEmpty) _serviceModes = modes;
  }

  void updateMeta({String? vehicleType, String? cityId}) {
    if (vehicleType != null && vehicleType.isNotEmpty) {
      _vehicleType = VehicleCatalog.normalize(vehicleType);
    }
    if (cityId != null && cityId.isNotEmpty) _cityId = cityId;
  }

  void _onPosition(Position p) {
    _lastPosition = p;
    _emit(p, force: false);
  }

  void _emit(Position p, {required bool force}) {
    final now = DateTime.now();
    if (!force &&
        _lastEmit != null &&
        now.difference(_lastEmit!) < _minEmitGap) {
      return;
    }
    _lastEmit = now;
    _socket.emitDriverLocation(
      lat: p.latitude,
      lng: p.longitude,
      heading: p.heading,
      speed: p.speed,
      vehicleType: _vehicleType,
      cityId: _cityId,
      serviceModes: _serviceModes,
    );
  }

  Future<void> stop() async {
    _running = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    await _sub?.cancel();
    _sub = null;
    _lastEmit = null;
    _lastPosition = null;
  }
}
