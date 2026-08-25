import '../core/api/api_client.dart';
import '../models/place_models.dart';

class PlacesApiService {
  PlacesApiService({ApiClient? client}) : _client = client ?? ApiClient();

  static final PlacesApiService instance = PlacesApiService();

  final ApiClient _client;

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) return data.cast<String, dynamic>();
    return json;
  }

  List<T> _list<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) map,
  ) {
    final data = _unwrap(json);
    final raw = data['items'] ?? data['places'] ?? data['results'] ?? data;
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => map(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  /// GET /places/suggestions — open the location sheet.
  Future<PlaceSuggestions> getSuggestions({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _client.get(
      '/places/suggestions'
      '?latitude=$latitude&longitude=$longitude',
    );
    return PlaceSuggestions.fromJson(_unwrap(json));
  }

  /// GET /places/nearby — our DB only.
  Future<List<PlaceListItem>> getNearby({
    required double latitude,
    required double longitude,
    double radius = 8,
    int limit = 20,
  }) async {
    final json = await _client.get(
      '/places/nearby'
      '?latitude=$latitude&longitude=$longitude'
      '&radius=$radius&limit=$limit',
    );
    return _list(json, PlaceListItem.fromJson);
  }

  /// GET /places/search — local catalog + Google autocomplete.
  Future<List<PlaceSearchHit>> search({
    required String query,
    required double latitude,
    required double longitude,
    required String sessionToken,
  }) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final json = await _client.get(
      '/places/search'
      '?query=$q&latitude=$latitude&longitude=$longitude'
      '&sessionToken=${Uri.encodeQueryComponent(sessionToken)}',
    );
    return _list(json, PlaceSearchHit.fromJson);
  }

  /// GET /places/google/:placeId — preview only.
  Future<SelectedLocation> getGooglePlace({
    required String placeId,
    required String sessionToken,
  }) async {
    final json = await _client.get(
      '/places/google/${Uri.encodeComponent(placeId)}'
      '?sessionToken=${Uri.encodeQueryComponent(sessionToken)}',
    );
    return SelectedLocation.fromJson(_unwrap(json));
  }

  /// POST /places/select — tap a result (details + upsert + usage).
  Future<SelectedLocation> selectPlace({
    String? placeId,
    String? googlePlaceId,
    String? sessionToken,
    double? latitude,
    double? longitude,
    String? source,
  }) async {
    final body = <String, dynamic>{};
    if (placeId != null && placeId.isNotEmpty) body['placeId'] = placeId;
    if (googlePlaceId != null && googlePlaceId.isNotEmpty) {
      body['googlePlaceId'] = googlePlaceId;
    }
    if (sessionToken != null && sessionToken.isNotEmpty) {
      body['sessionToken'] = sessionToken;
    }
    if (latitude != null && longitude != null) {
      body['latitude'] = latitude;
      body['longitude'] = longitude;
      if (source != null && source.isNotEmpty) body['source'] = source;
    }

    final json = await _client.post('/places/select', body: body);
    return SelectedLocation.fromJson(_unwrap(json));
  }

  /// GET /places/reverse — map pin / GPS address (no catalog insert).
  Future<SelectedLocation> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _client.get(
      '/places/reverse?latitude=$latitude&longitude=$longitude',
    );
    return SelectedLocation.fromJson(_unwrap(json));
  }

  /// GET /places/recents
  Future<List<PlaceListItem>> getRecents() async {
    final json = await _client.get('/places/recents');
    return _list(json, PlaceListItem.fromJson);
  }

  /// POST /places — upsert when the app already has full place details.
  Future<SelectedLocation> upsertPlace({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? googlePlaceId,
    String? type,
    String? city,
    String? area,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (googlePlaceId != null && googlePlaceId.isNotEmpty) {
      body['googlePlaceId'] = googlePlaceId;
    }
    if (type != null && type.isNotEmpty) body['type'] = type;
    if (city != null && city.isNotEmpty) body['city'] = city;
    if (area != null && area.isNotEmpty) body['area'] = area;

    final json = await _client.post('/places', body: body);
    return SelectedLocation.fromJson(_unwrap(json));
  }
}
