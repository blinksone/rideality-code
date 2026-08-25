import 'trip_models.dart';

/// Resolved place returned from [PickupLocationScreen] or pin reverse-geocode.
class SelectedLocation {
  const SelectedLocation({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.googlePlaceId,
    this.databaseId,
    this.type,
    this.city,
    this.area,
    this.distanceKm,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? googlePlaceId;
  final String? databaseId;
  final String? type;
  final String? city;
  final String? area;
  final double? distanceKm;

  String get displayLine =>
      name.trim().isNotEmpty ? name.trim() : address.trim();

  String get subtitleLine {
    if (address.trim().isNotEmpty && address.trim() != displayLine) {
      return address.trim();
    }
    final parts = <String>[
      if (area != null && area!.trim().isNotEmpty) area!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
    ];
    return parts.join(', ');
  }

  DestinationPick toTripDropoff() => DestinationPick(
        address: address.isNotEmpty ? address : name,
        latitude: latitude,
        longitude: longitude,
      );

  factory SelectedLocation.fromJson(Map<String, dynamic> json) {
    double numV(dynamic v, [double d = 0]) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? d;
    }

    return SelectedLocation(
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: numV(json['latitude'] ?? json['lat']),
      longitude: numV(json['longitude'] ?? json['lng']),
      googlePlaceId: json['googlePlaceId']?.toString(),
      databaseId: json['databaseId']?.toString() ?? json['placeId']?.toString(),
      type: json['type']?.toString(),
      city: json['city']?.toString(),
      area: json['area']?.toString(),
      distanceKm: json['distanceKm'] == null
          ? null
          : numV(json['distanceKm']),
    );
  }
}

enum PlaceHitSource { local, google, unknown }

/// Autocomplete row from GET /places/search.
class PlaceSearchHit {
  const PlaceSearchHit({
    required this.name,
    required this.address,
    this.placeId,
    this.googlePlaceId,
    this.latitude,
    this.longitude,
    this.source = PlaceHitSource.unknown,
    this.type,
    this.distanceKm,
  });

  final String name;
  final String address;
  final String? placeId;
  final String? googlePlaceId;
  final double? latitude;
  final double? longitude;
  final PlaceHitSource source;
  final String? type;
  final double? distanceKm;

  factory PlaceSearchHit.fromJson(Map<String, dynamic> json) {
    double? numOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    PlaceHitSource parseSource(String? raw) {
      return switch ((raw ?? '').toUpperCase()) {
        'LOCAL' => PlaceHitSource.local,
        'GOOGLE' => PlaceHitSource.google,
        _ => PlaceHitSource.unknown,
      };
    }

    return PlaceSearchHit(
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      address: json['address']?.toString() ?? json['subtitle']?.toString() ?? '',
      placeId: json['placeId']?.toString() ??
          json['databaseId']?.toString() ??
          json['id']?.toString(),
      googlePlaceId: json['googlePlaceId']?.toString(),
      latitude: numOrNull(json['latitude'] ?? json['lat']),
      longitude: numOrNull(json['longitude'] ?? json['lng']),
      source: parseSource(json['source']?.toString()),
      type: json['type']?.toString(),
      distanceKm: numOrNull(json['distanceKm']),
    );
  }
}

/// List item for recents / nearby / suggestion rows.
class PlaceListItem {
  const PlaceListItem({
    required this.name,
    required this.address,
    this.placeId,
    this.googlePlaceId,
    this.latitude,
    this.longitude,
    this.type,
    this.distanceKm,
    this.source,
  });

  final String name;
  final String address;
  final String? placeId;
  final String? googlePlaceId;
  final double? latitude;
  final double? longitude;
  final String? type;
  final double? distanceKm;
  final PlaceHitSource? source;

  factory PlaceListItem.fromJson(Map<String, dynamic> json) {
    double? numOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    PlaceHitSource? parseSource(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      return switch (raw.toUpperCase()) {
        'LOCAL' => PlaceHitSource.local,
        'GOOGLE' => PlaceHitSource.google,
        _ => PlaceHitSource.unknown,
      };
    }

    return PlaceListItem(
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      placeId: json['placeId']?.toString() ??
          json['databaseId']?.toString() ??
          json['id']?.toString(),
      googlePlaceId: json['googlePlaceId']?.toString(),
      latitude: numOrNull(json['latitude'] ?? json['lat']),
      longitude: numOrNull(json['longitude'] ?? json['lng']),
      type: json['type']?.toString(),
      distanceKm: numOrNull(json['distanceKm']),
      source: parseSource(json['source']?.toString()),
    );
  }
}

/// Saved Home / Work slot from GET /places/suggestions.
class SavedLocationSlot {
  const SavedLocationSlot({
    required this.label,
    this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.placeId,
  });

  final String label;
  final String? name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? placeId;

  bool get isFilled =>
      (address != null && address!.trim().isNotEmpty) ||
      (latitude != null && longitude != null);

  factory SavedLocationSlot.fromJson(Map<String, dynamic> json) {
    double? numOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return SavedLocationSlot(
      label: json['label']?.toString() ?? 'custom',
      name: json['name']?.toString(),
      address: json['address']?.toString(),
      latitude: numOrNull(json['latitude'] ?? json['lat']),
      longitude: numOrNull(json['longitude'] ?? json['lng']),
      placeId: json['placeId']?.toString() ?? json['id']?.toString(),
    );
  }
}

class PlaceSuggestions {
  const PlaceSuggestions({
    this.current,
    this.home,
    this.work,
    this.recents = const [],
    this.nearby = const [],
  });

  final PlaceListItem? current;
  final SavedLocationSlot? home;
  final SavedLocationSlot? work;
  final List<PlaceListItem> recents;
  final List<PlaceListItem> nearby;

  factory PlaceSuggestions.fromJson(Map<String, dynamic> json) {
    List<PlaceListItem> list(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => PlaceListItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    SavedLocationSlot? slot(dynamic raw) {
      if (raw is! Map) return null;
      return SavedLocationSlot.fromJson(raw.cast<String, dynamic>());
    }

    PlaceListItem? item(dynamic raw) {
      if (raw is! Map) return null;
      return PlaceListItem.fromJson(raw.cast<String, dynamic>());
    }

    return PlaceSuggestions(
      current: item(json['current'] ?? json['currentLocation']),
      home: slot(json['home']),
      work: slot(json['work']),
      recents: list(json['recents'] ?? json['recent']),
      nearby: list(json['nearby']),
    );
  }
}
