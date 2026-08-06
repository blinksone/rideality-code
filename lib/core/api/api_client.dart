import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:path/path.dart' as p;

import '../storage/token_storage.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'api_session.dart';

class ApiClient {
  ApiClient({http.Client? client, TokenStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? TokenStorage.instance;

  final http.Client _client;
  final TokenStorage _storage;

  /// Single-flight refresh so concurrent 401s share one /auth/refresh call.
  Future<bool>? _refreshInFlight;

  Future<Map<String, dynamic>> get(
    String path, {
    bool auth = true,
  }) {
    return _send('GET', path, auth: auth);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('POST', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('PATCH', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('DELETE', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> multipartPost(
    String path, {
    required String fieldName,
    required String filePath,
    String? filename,
    bool auth = true,
  }) async {
    Future<Response> once() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final request = http.MultipartRequest('POST', uri);

      if (auth) {
        final token = await _storage.accessToken;
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }

      final name = filename ?? p.basename(filePath);
      final mediaType = _guessMediaType(name);
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          filePath,
          filename: name,
          contentType: mediaType,
        ),
      );

      final streamed = await request.send().timeout(ApiConfig.timeout);
      return http.Response.fromStream(streamed);
    }

    try {
      final response = await once();
      if (auth && _looksLikeAuthFailure(response) && !_isAuthBypassPath(path)) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          final retry = await once();
          return _decode(retry, method: 'POST', path: path);
        }
        await _expireSession();
        return _decode(response, method: 'POST', path: path);
      }
      return _decode(response, method: 'POST', path: path);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error. Please check your connection.');
    }
  }

  /// POST /auth/refresh with stored refresh token. Public for bootstrap.
  Future<bool> refreshAccessToken() {
    if (_refreshInFlight != null) return _refreshInFlight!;
    _refreshInFlight = _refreshAccessTokenImpl().whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<bool> _refreshAccessTokenImpl() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;

    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/refresh');
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      final root = decoded.cast<String, dynamic>();
      final data = (root['data'] as Map?)?.cast<String, dynamic>() ?? root;

      final access = data['accessToken']?.toString() ??
          data['access_token']?.toString() ??
          '';
      if (access.isEmpty) return false;

      final nextRefresh = data['refreshToken']?.toString() ??
          data['refresh_token']?.toString();
      final sessionId = data['sessionId']?.toString() ??
          data['session_id']?.toString();

      await _storage.updateTokens(
        accessToken: access,
        refreshToken: nextRefresh,
        sessionId: sessionId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _expireSession() async {
    await _storage.clear();
    await ApiSession.notifyExpired();
  }

  bool _isAuthBypassPath(String path) {
    final p = path.toLowerCase();
    return p.contains('/auth/otp') ||
        p.contains('/auth/regions') ||
        p.contains('/auth/refresh') ||
        p.contains('/auth/logout');
  }

  bool _looksLikeAuthFailure(Response response) {
    if (response.statusCode == 401) return true;
    // Some stacks return 403 for dead JWTs with an auth message.
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return response.statusCode == 403 &&
            response.body.toLowerCase().contains('token');
      }
      final json = decoded.cast<String, dynamic>();
      final message = (_extractMessage(json) ?? '').toLowerCase();
      final code = (json['code']?.toString() ??
              (json['error'] is Map
                  ? (json['error'] as Map)['code']?.toString()
                  : null) ??
              '')
          .toUpperCase();
      if (code == 'TOKEN_EXPIRED' ||
          code == 'INVALID_TOKEN' ||
          code == 'UNAUTHORIZED' ||
          code == 'SESSION_EXPIRED') {
        return true;
      }
      if (message.contains('invalid or expired token') ||
          message.contains('token expired') ||
          message.contains('jwt expired')) {
        return true;
      }
      return false;
    } catch (_) {
      final body = response.body.toLowerCase();
      return body.contains('invalid or expired token') ||
          body.contains('token expired');
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool allowRefresh = true,
  }) async {
    Future<Response> once() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (auth) {
        final token = await _storage.accessToken;
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }

      final encoded = body == null ? null : jsonEncode(body);

      switch (method) {
        case 'GET':
          return _client.get(uri, headers: headers).timeout(ApiConfig.timeout);
        case 'POST':
          return _client
              .post(uri, headers: headers, body: encoded)
              .timeout(ApiConfig.timeout);
        case 'PATCH':
          return _client
              .patch(uri, headers: headers, body: encoded)
              .timeout(ApiConfig.timeout);
        case 'DELETE':
          return _client
              .delete(uri, headers: headers, body: encoded)
              .timeout(ApiConfig.timeout);
        default:
          throw ApiException('Unsupported method: $method');
      }
    }

    late final Response response;
    try {
      response = await once();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error. Please check your connection.');
    }

    if (auth &&
        allowRefresh &&
        !_isAuthBypassPath(path) &&
        _looksLikeAuthFailure(response)) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        return _send(
          method,
          path,
          body: body,
          auth: auth,
          allowRefresh: false,
        );
      }
      await _expireSession();
    }

    return _decode(response, method: method, path: path);
  }

  Map<String, dynamic> _decode(
    Response response, {
    String method = '',
    String path = '',
  }) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      // Empty body is common on some 401 responses.
      if (response.body.trim().isEmpty && response.statusCode >= 400) {
        throw ApiException(
          response.statusCode == 401
              ? 'Invalid or expired token'
              : 'Request failed (${response.statusCode})',
          statusCode: response.statusCode,
          code: response.statusCode == 401 ? 'UNAUTHORIZED' : null,
        );
      }
      throw ApiException(
        'Invalid server response (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    final message = _extractMessage(json) ??
        'Request failed (${response.statusCode})';
    final code = json['code']?.toString() ??
        (json['error'] is Map
            ? (json['error'] as Map)['code']?.toString()
            : null);

    final hint = code == 'ROUTE_NOT_FOUND' ||
            message.toLowerCase().contains('route not found')
        ? ' ($method $path)'
        : '';

    throw ApiException(
      '$message$hint',
      statusCode: response.statusCode,
      code: code,
    );
  }

  String? _extractMessage(Map<String, dynamic> json) {
    if (json['message'] is String) return json['message'] as String;
    if (json['error'] is String) return json['error'] as String;
    if (json['error'] is Map) {
      final err = json['error'] as Map;
      if (err['message'] is String) return err['message'] as String;
      if (err['details'] is List) {
        final details = err['details'] as List;
        final first = details.whereType<Map>().cast<Map>().isEmpty
            ? null
            : details.whereType<Map>().first;
        if (first != null) {
          final msg = first['message']?.toString() ?? first['msg']?.toString();
          if (msg != null && msg.isNotEmpty) return msg;
        }
      }
    }
    if (json['errors'] is List) {
      final errors = json['errors'] as List;
      final mapped = errors.whereType<Map>().toList();
      if (mapped.isNotEmpty) {
        final msg = mapped.first['message']?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      } else if (errors.isNotEmpty) {
        return errors.first.toString();
      }
    }
    if (json['data'] is Map && (json['data'] as Map)['message'] is String) {
      return (json['data'] as Map)['message'] as String;
    }
    return null;
  }

  MediaType? _guessMediaType(String name) {
    final ext = p.extension(name).toLowerCase();
    return switch (ext) {
      '.png' => MediaType('image', 'png'),
      '.webp' => MediaType('image', 'webp'),
      '.gif' => MediaType('image', 'gif'),
      _ => MediaType('image', 'jpeg'),
    };
  }
}
