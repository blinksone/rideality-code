abstract final class ApiConfig {
  static const String baseHost = 'http://65.21.177.122:3000';
  static const String baseUrl = '$baseHost/api/v1';

  /// Socket.IO host (path `/socket.io`). Defaults to same machine, port 3100.
  static const String wsHost = 'http://65.21.177.122:3100';

  static const Duration timeout = Duration(seconds: 30);

  /// Turns API-relative media paths into absolute URLs.
  /// e.g. `/uploads/x.jpg` → `http://host:3000/uploads/x.jpg`
  /// Returns only `http`/`https` with a host; never a bare path.
  static String? resolveMediaUrl(String? url) {
    if (url == null) return null;
    var value = url.trim();
    if (value.isEmpty) return null;

    // Strip mis-parsed local schemes: file:///uploads/...
    if (value.startsWith('file:')) {
      final parsed = Uri.tryParse(value);
      value = (parsed?.path.isNotEmpty == true)
          ? parsed!.path
          : value.replaceFirst(RegExp(r'^file:/*'), '/');
    }

    String absolute;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      absolute = value;
    } else if (value.startsWith('//')) {
      final rest = value.substring(2);
      if (rest.contains('.') && !rest.startsWith('uploads/')) {
        absolute = 'http:$value';
      } else {
        absolute = '$baseHost/${rest.replaceFirst(RegExp(r'^/'), '')}';
      }
    } else if (value.startsWith('/')) {
      absolute = '$baseHost$value';
    } else if (value.startsWith('uploads/')) {
      absolute = '$baseHost/$value';
    } else {
      absolute = '$baseHost/$value';
    }

    final uri = Uri.tryParse(absolute);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return absolute;
  }
}
