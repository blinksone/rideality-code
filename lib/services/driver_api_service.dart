import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../models/api_models.dart';
import '../models/trip_models.dart';
import 'user_api_service.dart';

class DriverApiService {
  DriverApiService({ApiClient? client, UserApiService? userApi})
      : _client = client ?? ApiClient(),
        _userApi = userApi ?? UserApiService.instance;

  static final DriverApiService instance = DriverApiService();

  final ApiClient _client;
  final UserApiService _userApi;

  Future<DriverView> registerVehicle({
    required String vehicleType,
    required String model,
    required String numberPlate,
    String? color,
    int? year,
    int availableSeats = 4,
  }) async {
    final body = <String, dynamic>{
      'vehicleType': vehicleType.toLowerCase(),
      'model': model,
      'numberPlate': numberPlate,
      'availableSeats': availableSeats,
    };
    if (color != null && color.isNotEmpty) body['color'] = color;
    if (year != null) body['year'] = year;

    final json = await _client.post('/users/me/driver/vehicle', body: body);
    return DriverView.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Upload image via /users/me/photo then register document with returned URL.
  Future<DriverDocument> uploadAndRegisterDocument({
    required String type,
    required String filePath,
    String? expiresAt,
  }) async {
    final fileUrl = await _userApi.uploadPhoto(filePath);
    return registerDocument(type: type, fileUrl: fileUrl, expiresAt: expiresAt);
  }

  Future<DriverDocument> registerDocument({
    required String type,
    required String fileUrl,
    String? expiresAt,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'fileUrl': fileUrl,
    };
    if (expiresAt != null && expiresAt.isNotEmpty) {
      body['expiresAt'] = expiresAt;
    }
    final json = await _client.post('/users/me/documents', body: body);
    return DriverDocument.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<List<DriverDocument>> listDocuments() async {
    final json = await _client.get('/users/me/documents');
    final data = json['data'];
    List<DriverDocument> parsed;
    if (data is List) {
      parsed = data
          .whereType<Map>()
          .map((e) => DriverDocument.fromJson(e.cast<String, dynamic>()))
          .toList();
    } else if (data is Map && data['items'] is List) {
      parsed = (data['items'] as List)
          .whereType<Map>()
          .map((e) => DriverDocument.fromJson(e.cast<String, dynamic>()))
          .toList();
    } else {
      return const [];
    }
    return DriverDocument.indexByType(parsed).values.toList();
  }

  /// Latest document row per type (rejected overrides approved history).
  Future<Map<String, DriverDocument>> listDocumentsByType() async {
    final docs = await listDocuments();
    return DriverDocument.indexByType(docs);
  }

  Future<DriverView> getDriverView() async {
    final json = await _client.get('/users/me/driver');
    return DriverView.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// PATCH /users/me/driver/availability
  /// Optional [modes] so going online registers service filters in one call.
  Future<DriverView> setAvailability({
    required bool isOnline,
    List<DriverServiceMode>? modes,
  }) async {
    final body = <String, dynamic>{'isOnline': isOnline};
    if (modes != null && modes.isNotEmpty) {
      body['modes'] = DriverServiceMode.toApiList(modes);
    }
    final json = await _client.patch(
      '/users/me/driver/availability',
      body: body,
    );
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Some responses wrap driver / return partial flags.
    if (data.containsKey('onboardingStatus') ||
        data.containsKey('isOnline') ||
        data.containsKey('serviceModes')) {
      return DriverView.fromJson(data);
    }
    return getDriverView();
  }

  /// PATCH /drivers/me/service-modes — body: { modes: ['rides','cargo'] }
  /// Alias: PATCH /users/me/driver/service-modes
  Future<DriverView> setServiceModes(List<DriverServiceMode> modes) async {
    final payload =
        modes.isEmpty ? const [DriverServiceMode.rides] : modes;
    final body = {'modes': DriverServiceMode.toApiList(payload)};
    try {
      final json = await _client.patch(
        '/drivers/me/service-modes',
        body: body,
      );
      return _driverFromModesResponse(json, payload);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        final json = await _client.patch(
          '/users/me/driver/service-modes',
          body: body,
        );
        return _driverFromModesResponse(json, payload);
      }
      rethrow;
    }
  }

  Future<DriverView> _driverFromModesResponse(
    Map<String, dynamic> json,
    List<DriverServiceMode> payload,
  ) async {
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    if (data.isNotEmpty &&
        (data.containsKey('serviceModes') ||
            data.containsKey('onboardingStatus') ||
            data.containsKey('isOnline'))) {
      return DriverView.fromJson(data);
    }
    try {
      final view = await getDriverView();
      return view.copyWith(serviceModes: payload);
    } catch (_) {
      return DriverView.empty.copyWith(serviceModes: payload);
    }
  }

  /// PATCH /users/me/mode — activeMode: passenger | driver
  Future<void> switchMode(String activeMode) async {
    await _client.patch(
      '/users/me/mode',
      body: {'activeMode': activeMode},
    );
  }
}
