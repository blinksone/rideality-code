import '../core/api/api_client.dart';
import '../models/api_models.dart';

/// Public fleet directory + authenticated driver invites.
class FleetApiService {
  FleetApiService({ApiClient? client}) : _client = client ?? ApiClient();

  static final FleetApiService instance = FleetApiService();

  final ApiClient _client;

  List<T> _list<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final data = json['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => parse(e.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => parse(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  /// GET /fleet/cities?regionId={countryRegionId} — public geo cities.
  Future<List<GeoCityOption>> listCities({required String regionId}) async {
    final json = await _client.get(
      '/fleet/cities?regionId=${Uri.encodeQueryComponent(regionId)}',
      auth: false,
    );
    return _list(json, GeoCityOption.fromJson);
  }

  /// GET /fleet/companies?cityId={geoCityId}&search= — public.
  Future<List<FleetCompanyOption>> listCompanies({
    required String cityId,
    String? search,
    int limit = 20,
  }) async {
    final qs = <String>[
      'cityId=${Uri.encodeQueryComponent(cityId)}',
      'sort=top',
      'limit=$limit',
    ];
    final q = search?.trim();
    if (q != null && q.isNotEmpty) {
      qs.add('search=${Uri.encodeQueryComponent(q)}');
    }
    final json = await _client.get(
      '/fleet/companies?${qs.join('&')}',
      auth: false,
    );
    return _list(json, FleetCompanyOption.fromJson);
  }

  /// GET /fleet/companies/{companyId}/public?cityId={geoCityId} — public.
  Future<FleetCompanyOption> getCompanyPublic({
    required String companyId,
    required String cityId,
  }) async {
    final json = await _client.get(
      '/fleet/companies/$companyId/public?cityId=${Uri.encodeQueryComponent(cityId)}',
      auth: false,
    );
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return FleetCompanyOption.fromJson(data);
    }
    if (data is Map) {
      return FleetCompanyOption.fromJson(data.cast<String, dynamic>());
    }
    return const FleetCompanyOption(
      id: '',
      legalName: '',
      regionId: '',
    );
  }

  /// GET /fleet/me/invites — auth. Driver invites only.
  Future<List<FleetDriverInvite>> listMyInvites() async {
    final json = await _client.get('/fleet/me/invites');
    return _list(json, FleetDriverInvite.fromJson)
        .where((e) => e.isPendingDriver)
        .toList();
  }

  Future<void> acceptInvite(String token) async {
    await _client.post('/fleet/invites/$token/accept');
  }

  Future<void> rejectInvite(String token) async {
    await _client.post('/fleet/invites/$token/reject');
  }
}
