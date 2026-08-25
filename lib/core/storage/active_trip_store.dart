import 'package:shared_preferences/shared_preferences.dart';

import '../../models/trip_models.dart';

/// Local cache of an in-progress trip for socket reconnect / app resume.
class ActiveTripStore {
  ActiveTripStore._();
  static final ActiveTripStore instance = ActiveTripStore._();

  static const _rideId = 'active_trip_ride_id';
  static const _role = 'active_trip_role';
  static const _vehicle = 'active_trip_vehicle';

  Future<void> save({
    required String rideId,
    required SessionRole role,
    String? vehicleType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rideId, rideId);
    await prefs.setString(_role, role.name);
    if (vehicleType != null && vehicleType.isNotEmpty) {
      await prefs.setString(_vehicle, vehicleType);
    }
  }

  Future<String?> get rideId async =>
      (await SharedPreferences.getInstance()).getString(_rideId);

  Future<SessionRole?> get role async {
    final raw = (await SharedPreferences.getInstance()).getString(_role);
    if (raw == null) return null;
    for (final e in SessionRole.values) {
      if (e.name == raw) return e;
    }
    return null;
  }

  Future<String?> get vehicleType async =>
      (await SharedPreferences.getInstance()).getString(_vehicle);

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rideId);
    await prefs.remove(_role);
    await prefs.remove(_vehicle);
  }
}
