import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../models/trip_models.dart';

class TripsApiService {
  TripsApiService({ApiClient? client}) : _client = client ?? ApiClient();

  static final TripsApiService instance = TripsApiService();

  final ApiClient _client;

  Map<String, dynamic> _data(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) return data.cast<String, dynamic>();
    // Some endpoints return the trip at the root.
    if (json.containsKey('id') || json.containsKey('rideId')) return json;
    return const {};
  }

  Trip _tripFromResponse(Map<String, dynamic> json, String fallbackId) {
    final data = _data(json);
    if (data.isEmpty) {
      // Caller should re-fetch; return placeholder only when needed.
    }
    final nested = data['trip'] ?? data['booking'] ?? data;
    if (nested is Map && nested.isNotEmpty) {
      return Trip.fromJson(nested.cast<String, dynamic>());
    }
    if (data.isNotEmpty) return Trip.fromJson(data);
    return Trip(id: fallbackId, status: TripStatus.unknown);
  }

  Future<Trip> createTrip({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? pickupAddress,
    String? dropoffAddress,
    String? vehicleType,
    String? bookingType,
    double? cargoWeightKg,
    String? cargoDescription,
    String? cargoSizeTier,
    String? dropoffProofType,
    bool? loadingHelp,
  }) async {
    final body = <String, dynamic>{
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
    };
    if (pickupAddress != null && pickupAddress.isNotEmpty) {
      body['pickupAddress'] = pickupAddress;
    }
    if (dropoffAddress != null && dropoffAddress.isNotEmpty) {
      body['dropoffAddress'] = dropoffAddress;
    }
    if (vehicleType != null && vehicleType.isNotEmpty) {
      body['vehicleType'] = vehicleType;
    }
    if (bookingType != null && bookingType.isNotEmpty) {
      body['bookingType'] = bookingType;
    }
    if (cargoWeightKg != null) {
      body['cargoWeightKg'] = cargoWeightKg;
    }
    if (cargoDescription != null && cargoDescription.isNotEmpty) {
      body['cargoDescription'] = cargoDescription;
    }
    if (cargoSizeTier != null && cargoSizeTier.isNotEmpty) {
      body['cargoSizeTier'] = cargoSizeTier;
    }
    if (dropoffProofType != null && dropoffProofType.isNotEmpty) {
      body['dropoffProofType'] = dropoffProofType;
    }
    if (loadingHelp != null) {
      body['loadingHelp'] = loadingHelp;
    }

    final json = await _client.post('/trips', body: body);
    return Trip.fromJson(_data(json));
  }

  /// POST /trips/quote — vehicle options + fares for confirm screen.
  Future<TripQuote> quoteTrip({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? pickupAddress,
    String? dropoffAddress,
    String bookingType = 'ride',
    double? cargoWeightKg,
  }) async {
    final body = <String, dynamic>{
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'bookingType': bookingType,
    };
    if (pickupAddress != null && pickupAddress.isNotEmpty) {
      body['pickupAddress'] = pickupAddress;
    }
    if (dropoffAddress != null && dropoffAddress.isNotEmpty) {
      body['dropoffAddress'] = dropoffAddress;
    }
    if (cargoWeightKg != null) body['cargoWeightKg'] = cargoWeightKg;

    final json = await _client.post('/trips/quote', body: body);
    return TripQuote.fromJson(_data(json));
  }

  Future<Trip> getTrip(String id) async {
    final json = await _client.get('/trips/$id');
    return Trip.fromJson(_data(json));
  }

  Future<Trip> cancelTrip(String id, {String? reason}) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;
    final json = await _client.post('/trips/$id/cancel', body: body);
    return Trip.fromJson(_data(json));
  }

  Future<Trip> updateStatus(String id, TripStatus status) async {
    final json = await _client.post(
      '/trips/$id/status',
      body: {'status': status.apiValue},
    );
    return Trip.fromJson(_data(json));
  }

  /// REST fallback when WebSocket `dispatch:response` fails.
  Future<void> dispatchResponse(String id, {required bool accepted}) async {
    await _client.post(
      '/trips/$id/dispatch-response',
      body: {'accepted': accepted},
    );
  }

  /// POST /bookings/:id/proof/pickup (alias /trips/:id/proof/pickup).
  Future<Trip> submitPickupProof(
    String bookingId, {
    String? photoUrl,
    String? otp,
  }) async {
    final body = <String, dynamic>{};
    if (photoUrl != null && photoUrl.isNotEmpty) body['photoUrl'] = photoUrl;
    if (otp != null && otp.isNotEmpty) body['otp'] = otp;
    return _postProof(bookingId, stage: 'pickup', body: body);
  }

  /// POST /bookings/:id/proof/dropoff (alias /trips/:id/proof/dropoff).
  Future<Trip> submitDropoffProof(
    String bookingId, {
    String? photoUrl,
    String? otp,
  }) async {
    final body = <String, dynamic>{};
    if (photoUrl != null && photoUrl.isNotEmpty) body['photoUrl'] = photoUrl;
    if (otp != null && otp.isNotEmpty) body['otp'] = otp;
    return _postProof(bookingId, stage: 'dropoff', body: body);
  }

  Future<Trip> _postProof(
    String id, {
    required String stage,
    required Map<String, dynamic> body,
  }) async {
    try {
      final json = await _client.post(
        '/bookings/$id/proof/$stage',
        body: body,
      );
      final trip = _tripFromResponse(json, id);
      if (trip.status == TripStatus.unknown && trip.id == id) {
        return getTrip(id);
      }
      return trip.id.isEmpty ? getTrip(id) : trip;
    } on ApiException catch (e) {
      // Alias path for backends that mount proof under /trips.
      if (e.statusCode == 404) {
        final json = await _client.post(
          '/trips/$id/proof/$stage',
          body: body,
        );
        final trip = _tripFromResponse(json, id);
        if (trip.status == TripStatus.unknown) return getTrip(id);
        return trip.id.isEmpty ? getTrip(id) : trip;
      }
      rethrow;
    }
  }
}
