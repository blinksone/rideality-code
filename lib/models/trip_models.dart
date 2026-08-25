// Server-authoritative trip FSM + Socket.IO payloads (mobile real-time contract).

enum SessionRole { driver, rider }

/// Driver accepts rides, cargo, or both (dispatch filters on this set).
enum DriverServiceMode {
  rides,
  cargo;

  String get apiValue => name;

  static DriverServiceMode? parse(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    return switch (s) {
      'rides' || 'ride' || 'taxi' || 'passenger' => DriverServiceMode.rides,
      'cargo' || 'delivery' => DriverServiceMode.cargo,
      _ => null,
    };
  }

  static List<DriverServiceMode> parseList(dynamic raw) {
    if (raw is List) {
      final out = <DriverServiceMode>{};
      for (final e in raw) {
        final m = parse(e?.toString());
        if (m != null) out.add(m);
      }
      if (out.isNotEmpty) return out.toList();
    }
    if (raw is String) {
      final lower = raw.toLowerCase().trim();
      if (lower == 'both' || lower == 'all') {
        return const [DriverServiceMode.rides, DriverServiceMode.cargo];
      }
      final one = parse(lower);
      if (one != null) return [one];
    }
    return const [DriverServiceMode.rides];
  }

  static List<String> toApiList(List<DriverServiceMode> modes) =>
      modes.map((m) => m.apiValue).toList();
}

/// Booking kind on the shared trip / ride model.
enum BookingType {
  ride,
  cargo;

  static BookingType parse(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    return switch (s) {
      'cargo' || 'delivery' => BookingType.cargo,
      _ => BookingType.ride,
    };
  }

  String get apiValue => name;
}

enum CargoProofKind {
  photo,
  otp,
  both;

  static CargoProofKind parse(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    return switch (s) {
      'otp' => CargoProofKind.otp,
      'both' || 'photo_and_otp' || 'photo+otp' => CargoProofKind.both,
      _ => CargoProofKind.photo,
    };
  }
}

class CargoProof {
  const CargoProof({
    this.pickupPhotoUrl,
    this.pickupConfirmedAt,
    this.dropoffConfirmationType = CargoProofKind.otp,
    this.dropoffOtpVerified = false,
    this.dropoffPhotoUrl,
    this.dropoffConfirmedAt,
  });

  final String? pickupPhotoUrl;
  final DateTime? pickupConfirmedAt;
  final CargoProofKind dropoffConfirmationType;
  final bool dropoffOtpVerified;
  final String? dropoffPhotoUrl;
  final DateTime? dropoffConfirmedAt;

  bool get pickupReady =>
      (pickupPhotoUrl != null && pickupPhotoUrl!.isNotEmpty) ||
      pickupConfirmedAt != null;

  bool get dropoffReady =>
      dropoffConfirmedAt != null ||
      dropoffOtpVerified ||
      (dropoffPhotoUrl != null && dropoffPhotoUrl!.isNotEmpty);

  factory CargoProof.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const CargoProof();
    DateTime? dt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return CargoProof(
      pickupPhotoUrl: json['pickupPhotoUrl']?.toString() ??
          json['pickup_photo_url']?.toString(),
      pickupConfirmedAt: dt(
        json['pickupConfirmedAt'] ?? json['pickup_confirmed_at'],
      ),
      dropoffConfirmationType: CargoProofKind.parse(
        json['dropoffConfirmationType']?.toString() ??
            json['dropoff_confirmation_type']?.toString(),
      ),
      dropoffOtpVerified: json['dropoffOtpVerified'] == true ||
          json['dropoff_otp_verified'] == true,
      dropoffPhotoUrl: json['dropoffPhotoUrl']?.toString() ??
          json['dropoff_photo_url']?.toString(),
      dropoffConfirmedAt: dt(
        json['dropoffConfirmedAt'] ?? json['dropoff_confirmed_at'],
      ),
    );
  }
}

enum TripStatus {
  requested,
  accepted,
  driverEnRoute,
  arrived,
  pickedUp,
  completed,
  cancelled,
  unknown;

  static TripStatus parse(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    return switch (s) {
      'requested' => TripStatus.requested,
      'accepted' || 'assigned' => TripStatus.accepted,
      'driver_en_route' || 'driverenroute' => TripStatus.driverEnRoute,
      'arrived' => TripStatus.arrived,
      'picked_up' || 'pickedup' || 'in_progress' => TripStatus.pickedUp,
      'completed' || 'complete' => TripStatus.completed,
      'cancelled' || 'canceled' => TripStatus.cancelled,
      _ => TripStatus.unknown,
    };
  }

  String get apiValue => switch (this) {
        TripStatus.requested => 'requested',
        TripStatus.accepted => 'accepted',
        TripStatus.driverEnRoute => 'driver_en_route',
        TripStatus.arrived => 'arrived',
        TripStatus.pickedUp => 'picked_up',
        TripStatus.completed => 'completed',
        TripStatus.cancelled => 'cancelled',
        TripStatus.unknown => 'unknown',
      };

  String get label => switch (this) {
        TripStatus.requested => 'Finding a driver',
        TripStatus.accepted => 'Driver assigned',
        TripStatus.driverEnRoute => 'Driver en route',
        TripStatus.arrived => 'Driver arrived',
        TripStatus.pickedUp => 'Trip in progress',
        TripStatus.completed => 'Completed',
        TripStatus.cancelled => 'Cancelled',
        TripStatus.unknown => 'Updating…',
      };

  bool get isTerminal =>
      this == TripStatus.completed || this == TripStatus.cancelled;

  bool get isActive => !isTerminal && this != TripStatus.unknown;

  /// Next status a driver may push via POST /trips/:id/status.
  TripStatus? get nextDriverStatus => switch (this) {
        TripStatus.accepted => TripStatus.driverEnRoute,
        TripStatus.driverEnRoute => TripStatus.arrived,
        TripStatus.arrived => TripStatus.pickedUp,
        TripStatus.pickedUp => TripStatus.completed,
        _ => null,
      };

  String? get nextDriverActionLabel => switch (nextDriverStatus) {
        TripStatus.driverEnRoute => 'Start en route',
        TripStatus.arrived => "I've arrived",
        TripStatus.pickedUp => 'Start trip',
        TripStatus.completed => 'Complete trip',
        _ => null,
      };

  /// Cargo: pickup / dropoff need proof actions labeled for the driver.
  String? nextDriverActionLabelFor(BookingType bookingType) {
    if (bookingType != BookingType.cargo) return nextDriverActionLabel;
    return switch (nextDriverStatus) {
      TripStatus.driverEnRoute => 'Start en route',
      TripStatus.arrived => "I've arrived",
      TripStatus.pickedUp => 'Confirm pickup',
      TripStatus.completed => 'Confirm delivery',
      _ => null,
    };
  }
}

class Trip {
  const Trip({
    required this.id,
    required this.status,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.pickupAddress,
    this.dropoffAddress,
    this.driverUserId,
    this.passengerUserId,
    this.vehicleType,
    this.fareEstimate,
    this.currency = 'PKR',
    this.bookingType = BookingType.ride,
    this.cargoWeightKg,
    this.cargoDescription,
    this.cargoSizeTier,
    this.dropoffProofType = CargoProofKind.otp,
    this.dropoffOtp,
    this.proof,
  });

  final String id;
  final TripStatus status;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? driverUserId;
  final String? passengerUserId;
  final String? vehicleType;
  final double? fareEstimate;
  final String currency;
  final BookingType bookingType;
  final double? cargoWeightKg;
  final String? cargoDescription;
  final String? cargoSizeTier;
  /// `otp` | `photo` — how the driver must confirm dropoff.
  final CargoProofKind dropoffProofType;
  /// Shown once to the passenger at create time for recipient handover.
  final String? dropoffOtp;
  final CargoProof? proof;

  bool get isCargo => bookingType == BookingType.cargo;

  /// True when current next transition requires proof capture first.
  bool get needsPickupProof =>
      isCargo && status == TripStatus.arrived && !(proof?.pickupReady ?? false);

  bool get needsDropoffProof =>
      isCargo &&
      status == TripStatus.pickedUp &&
      !(proof?.dropoffReady ?? false);

  bool get needsCargoProofBeforeAdvance =>
      needsPickupProof || needsDropoffProof;

  Trip copyWith({
    TripStatus? status,
    String? driverUserId,
    String? passengerUserId,
    CargoProof? proof,
    BookingType? bookingType,
    String? dropoffOtp,
  }) {
    return Trip(
      id: id,
      status: status ?? this.status,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      driverUserId: driverUserId ?? this.driverUserId,
      passengerUserId: passengerUserId ?? this.passengerUserId,
      vehicleType: vehicleType,
      fareEstimate: fareEstimate,
      currency: currency,
      bookingType: bookingType ?? this.bookingType,
      cargoWeightKg: cargoWeightKg,
      cargoDescription: cargoDescription,
      cargoSizeTier: cargoSizeTier,
      dropoffProofType: dropoffProofType,
      dropoffOtp: dropoffOtp ?? this.dropoffOtp,
      proof: proof ?? this.proof,
    );
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> asMap(dynamic v) =>
        v is Map ? v.cast<String, dynamic>() : const {};

    final pickup = asMap(json['pickup']);
    final dropoff = asMap(json['dropoff'] ?? json['destination']);
    final fare = asMap(json['fare']);
    final cargo = asMap(json['cargo'] ?? json['cargoDetails']);
    final proofMap = asMap(
      json['proof'] ?? json['cargoProof'] ?? json['cargo_proof'],
    );

    double? numOrNull(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    }

    final id = json['id']?.toString() ??
        json['rideId']?.toString() ??
        json['ride_id']?.toString() ??
        json['bookingId']?.toString() ??
        '';

    final bookingRaw = json['bookingType']?.toString() ??
        json['booking_type']?.toString() ??
        (json['vehicleType']?.toString().toLowerCase() == 'cargo'
            ? 'cargo'
            : null);

    final proofTypeRaw = json['dropoffProofType']?.toString() ??
        json['dropoff_proof_type']?.toString() ??
        cargo['dropoffProofType']?.toString() ??
        cargo['dropoff_proof_type']?.toString() ??
        proofMap['dropoffConfirmationType']?.toString() ??
        proofMap['dropoff_confirmation_type']?.toString();

    final otpOnce = json['dropoffOtp']?.toString() ??
        cargo['dropoffOtp']?.toString() ??
        cargo['otp']?.toString();

    return Trip(
      id: id,
      status: TripStatus.parse(json['status']?.toString()),
      pickupLat: numOrNull(json['pickupLat'] ?? pickup['lat'] ?? pickup['latitude']),
      pickupLng: numOrNull(json['pickupLng'] ?? pickup['lng'] ?? pickup['longitude']),
      dropoffLat:
          numOrNull(json['dropoffLat'] ?? dropoff['lat'] ?? dropoff['latitude']),
      dropoffLng: numOrNull(
        json['dropoffLng'] ?? dropoff['lng'] ?? dropoff['longitude'],
      ),
      pickupAddress:
          json['pickupAddress']?.toString() ?? pickup['address']?.toString(),
      dropoffAddress: json['dropoffAddress']?.toString() ??
          dropoff['address']?.toString(),
      driverUserId: json['driverUserId']?.toString() ??
          json['driverId']?.toString() ??
          json['driver_user_id']?.toString(),
      passengerUserId: json['passengerUserId']?.toString() ??
          json['riderId']?.toString() ??
          json['passenger_user_id']?.toString(),
      vehicleType: json['vehicleType']?.toString(),
      fareEstimate: numOrNull(
        fare['estimate'] ??
            fare['total'] ??
            json['fareEstimate'] ??
            json['fare'],
      ),
      currency: fare['currency']?.toString() ??
          json['currency']?.toString() ??
          'PKR',
      bookingType: BookingType.parse(bookingRaw),
      cargoWeightKg: numOrNull(
        json['cargoWeightKg'] ??
            json['cargo_weight_kg'] ??
            cargo['weightKg'] ??
            cargo['weight'],
      ),
      cargoDescription: json['cargoDescription']?.toString() ??
          json['cargo_description']?.toString() ??
          cargo['description']?.toString(),
      cargoSizeTier: json['cargoSizeTier']?.toString() ??
          json['sizeTier']?.toString() ??
          cargo['size']?.toString() ??
          cargo['sizeTier']?.toString(),
      dropoffProofType: CargoProofKind.parse(proofTypeRaw),
      dropoffOtp: otpOnce,
      proof: proofMap.isEmpty
          ? (CargoProof.fromJson(cargo).pickupConfirmedAt != null ||
                  CargoProof.fromJson(cargo).pickupPhotoUrl != null
              ? CargoProof.fromJson(cargo)
              : null)
          : CargoProof.fromJson(proofMap),
    );
  }
}

class DispatchOffer {
  const DispatchOffer({
    required this.rideId,
    required this.pickupLat,
    required this.pickupLng,
    this.riderName,
    this.fareEstimate,
    this.distanceMeters,
    this.timeoutMs = 18000,
    this.dropoffLabel,
    this.bookingType = BookingType.ride,
    this.cargoWeightKg,
    this.cargoDescription,
    this.cargoSizeTier,
    this.dropoffDistanceMeters,
  });

  final String rideId;
  final double pickupLat;
  final double pickupLng;
  final String? riderName;
  final double? fareEstimate;
  final double? distanceMeters;
  final int timeoutMs;
  final String? dropoffLabel;
  final BookingType bookingType;
  final double? cargoWeightKg;
  final String? cargoDescription;
  final String? cargoSizeTier;
  final double? dropoffDistanceMeters;

  bool get isCargo => bookingType == BookingType.cargo;

  int get timeoutSeconds =>
      ((timeoutMs > 0 ? timeoutMs : 18000) / 1000).round().clamp(5, 120);

  int get etaMinutes {
    if (distanceMeters == null || distanceMeters! <= 0) return 3;
    return (distanceMeters! / 500).round().clamp(1, 45);
  }

  String fareLabel({String currency = 'PKR'}) {
    final f = fareEstimate;
    if (f == null) return '—';
    final symbol = currency.toUpperCase() == 'PKR' ? 'Rs.' : currency;
    return '$symbol ${f.toStringAsFixed(0)}';
  }

  String get weightLabel {
    final w = cargoWeightKg;
    if (w == null) return '—';
    return w == w.roundToDouble()
        ? '${w.toInt()} kg'
        : '${w.toStringAsFixed(1)} kg';
  }

  factory DispatchOffer.fromJson(Map<String, dynamic> json) {
    double numV(dynamic v, [double d = 0]) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? d;
    }

    double? numOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int intV(dynamic v, [int d = 18000]) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse(v?.toString() ?? '') ?? d;
    }

    double? fare;
    final fareRaw = json['fareEstimate'] ?? json['fare'];
    if (fareRaw is num) {
      fare = fareRaw.toDouble();
    } else if (fareRaw != null) {
      fare = double.tryParse(fareRaw.toString());
    }

    final dist = numOrNull(json['distanceMeters'] ?? json['distance_meters']);
    final bookingRaw = json['bookingType']?.toString() ??
        json['booking_type']?.toString() ??
        (json['vehicleType']?.toString().toLowerCase() == 'cargo'
            ? 'cargo'
            : null);

    return DispatchOffer(
      rideId: json['rideId']?.toString() ??
          json['id']?.toString() ??
          json['bookingId']?.toString() ??
          '',
      pickupLat: numV(json['pickupLat'] ?? json['pickup_lat']),
      pickupLng: numV(json['pickupLng'] ?? json['pickup_lng']),
      riderName:
          json['riderName']?.toString() ?? json['passengerName']?.toString(),
      fareEstimate: fare,
      distanceMeters: dist,
      timeoutMs: intV(json['timeoutMs'] ?? json['timeout_ms']),
      dropoffLabel: json['dropoffAddress']?.toString() ??
          json['dropoff']?.toString(),
      bookingType: () {
        final parsed = BookingType.parse(bookingRaw);
        // Backend sometimes omits cargo on offer while cargo weight is present.
        final weight = numOrNull(
          json['cargoWeightKg'] ??
              json['cargo_weight_kg'] ??
              json['weightKg'],
        );
        if (parsed == BookingType.ride && weight != null && weight > 0) {
          return BookingType.cargo;
        }
        return parsed;
      }(),
      cargoWeightKg: numOrNull(
        json['cargoWeightKg'] ??
            json['cargo_weight_kg'] ??
            json['weightKg'],
      ),
      cargoDescription: json['cargoDescription']?.toString() ??
          json['cargo_description']?.toString(),
      cargoSizeTier: json['cargoSizeTier']?.toString() ??
          json['sizeTier']?.toString() ??
          json['size']?.toString(),
      dropoffDistanceMeters: numOrNull(
        json['dropoffDistanceMeters'] ??
            json['dropoff_distance_meters'] ??
            json['tripDistanceMeters'],
      ),
    );
  }
}

class RideLocationUpdate {
  const RideLocationUpdate({
    required this.rideId,
    required this.lat,
    required this.lng,
    this.heading,
    this.etaSeconds,
    this.driverId,
  });

  final String rideId;
  final double lat;
  final double lng;
  final double? heading;
  final int? etaSeconds;
  final String? driverId;

  factory RideLocationUpdate.fromJson(Map<String, dynamic> json) {
    double numV(dynamic v, [double d = 0]) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? d;
    }

    return RideLocationUpdate(
      rideId: json['rideId']?.toString() ?? '',
      lat: numV(json['lat']),
      lng: numV(json['lng']),
      heading: json['heading'] == null ? null : numV(json['heading']),
      etaSeconds: (json['etaSeconds'] as num?)?.round() ??
          int.tryParse(json['etaSeconds']?.toString() ?? ''),
      driverId: json['driverId']?.toString(),
    );
  }
}

class RideStatusChanged {
  const RideStatusChanged({
    required this.rideId,
    required this.status,
    this.from,
    this.driverUserId,
    this.passengerUserId,
  });

  final String rideId;
  final TripStatus status;
  final TripStatus? from;
  final String? driverUserId;
  final String? passengerUserId;

  factory RideStatusChanged.fromJson(Map<String, dynamic> json) {
    return RideStatusChanged(
      rideId: json['rideId']?.toString() ?? '',
      status: TripStatus.parse(json['status']?.toString()),
      from: json['from'] != null
          ? TripStatus.parse(json['from']?.toString())
          : null,
      driverUserId:
          json['driverUserId']?.toString() ?? json['driverId']?.toString(),
      passengerUserId: json['passengerUserId']?.toString() ??
          json['passengerId']?.toString(),
    );
  }
}

/// Result of passenger destination selection (booking).
class DestinationPick {
  const DestinationPick({
    required this.address,
    this.latitude,
    this.longitude,
    this.vehicleType = 'sedan',
  });

  final String address;
  final double? latitude;
  final double? longitude;
  final String vehicleType;
}

/// One row from POST /trips/quote `data.options`.
class TripQuoteOption {
  const TripQuoteOption({
    required this.vehicleType,
    required this.label,
    required this.fare,
    this.family,
    this.currency = 'PKR',
    this.etaMin,
    this.available = true,
    this.badge,
  });

  final String vehicleType;
  final String label;
  final String? family;
  final double fare;
  final String currency;
  final int? etaMin;
  final bool available;
  final String? badge;

  String get etaLabel =>
      etaMin == null ? '—' : '$etaMin min';

  String get fareLabel {
    final sym = currency.toUpperCase() == 'PKR' ? 'Rs' : currency;
    final amount = fare == fare.roundToDouble()
        ? fare.round().toString()
        : fare.toStringAsFixed(0);
    return '$sym $amount';
  }

  factory TripQuoteOption.fromJson(Map<String, dynamic> json) {
    double numV(dynamic v, [double d = 0]) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? d;
    }

    int? intOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.round();
      return int.tryParse(v.toString());
    }

    return TripQuoteOption(
      vehicleType: json['vehicleType']?.toString() ??
          json['code']?.toString() ??
          '',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '',
      family: json['family']?.toString(),
      fare: numV(json['fare'] ?? json['estimate'] ?? json['total']),
      currency: json['currency']?.toString() ?? 'PKR',
      etaMin: intOrNull(json['etaMin'] ?? json['etaMinutes'] ?? json['eta']),
      available: json['available'] != false,
      badge: json['badge']?.toString(),
    );
  }
}

/// POST /trips/quote response `data`.
class TripQuote {
  const TripQuote({
    this.currency = 'PKR',
    this.distanceKm,
    this.durationMin,
    this.bookingType = 'ride',
    this.options = const [],
  });

  final String currency;
  final double? distanceKm;
  final int? durationMin;
  final String bookingType;
  final List<TripQuoteOption> options;

  List<TripQuoteOption> get availableOptions =>
      options.where((o) => o.available).toList();

  factory TripQuote.fromJson(Map<String, dynamic> json) {
    double? numOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? intOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.round();
      return int.tryParse(v.toString());
    }

    final raw = json['options'] ?? json['vehicles'] ?? json['products'];
    final options = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => TripQuoteOption.fromJson(e.cast<String, dynamic>()))
            .where((o) => o.vehicleType.isNotEmpty)
            .toList()
        : const <TripQuoteOption>[];

    return TripQuote(
      currency: json['currency']?.toString() ?? 'PKR',
      distanceKm: numOrNull(json['distanceKm'] ?? json['distance_km']),
      durationMin: intOrNull(json['durationMin'] ?? json['duration_min']),
      bookingType: json['bookingType']?.toString() ?? 'ride',
      options: options,
    );
  }
}
