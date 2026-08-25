import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'realtime_socket_service.dart';

/// Throttled driver GPS → `driver:location_update` (distanceFilter ≥ 15m, ≥ 4s).
class DriverLocationTracker {
  DriverLocationTracker._();
  static final DriverLocationTracker instance = DriverLocationTracker._();

  final RealtimeSocketService _socket = RealtimeSocketService.instance;

  StreamSubscription<Position>? _sub;
  DateTime? _lastEmit;
  String? _vehicleType;
  List<String> _serviceModes = const ['rides'];
  bool _running = false;

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
    String vehicleType = 'sedan',
    List<String>? serviceModes,
  }) async {
    if (serviceModes != null && serviceModes.isNotEmpty) {
      _serviceModes = List<String>.from(serviceModes);
    }
    _vehicleType = vehicleType;
    if (_running) {
      // Modes/vehicle may have changed while already streaming.
      return;
    }
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

    // Immediate first fix so dispatch geo has a point.
    final first = await currentPosition();
    if (first != null) _onPosition(first);
  }

  void updateServiceModes(List<String> modes) {
    if (modes.isNotEmpty) _serviceModes = modes;
  }

  void _onPosition(Position p) {
    final now = DateTime.now();
    if (_lastEmit != null &&
        now.difference(_lastEmit!).inMilliseconds < 4000) {
      return;
    }
    _lastEmit = now;
    _socket.emitDriverLocation(
      lat: p.latitude,
      lng: p.longitude,
      heading: p.heading,
      speed: p.speed,
      vehicleType: _vehicleType,
      serviceModes: _serviceModes,
    );
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    _lastEmit = null;
  }
}
