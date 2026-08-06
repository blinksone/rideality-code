import '../core/api/api_client.dart';
import '../models/api_models.dart';
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
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => DriverDocument.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => DriverDocument.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<DriverView> getDriverView() async {
    final json = await _client.get('/users/me/driver');
    return DriverView.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// PATCH /users/me/driver/availability — requires approved driver (can_drive).
  Future<DriverView> setAvailability({required bool isOnline}) async {
    final json = await _client.patch(
      '/users/me/driver/availability',
      body: {'isOnline': isOnline},
    );
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Some responses wrap driver / return partial flags.
    if (data.containsKey('onboardingStatus') || data.containsKey('isOnline')) {
      return DriverView.fromJson(data);
    }
    return getDriverView();
  }

  /// PATCH /users/me/mode — activeMode: passenger | driver
  Future<void> switchMode(String activeMode) async {
    await _client.patch(
      '/users/me/mode',
      body: {'activeMode': activeMode},
    );
  }
}
