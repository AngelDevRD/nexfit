import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_exception.dart';
import 'app_config.dart';

class ApiClient {
  static const _tokenKey = 'auth_token';
  String? _cachedToken;

  Future<String?> get token async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> setToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    Map<String, String>? cleanQuery;
    if (query != null) {
      cleanQuery = {
        for (final entry in query.entries)
          if (entry.value != null) entry.key: entry.value.toString(),
      };
    }
    return Uri.parse(
      '${AppConfig.apiBaseUrl}$path',
    ).replace(queryParameters: cleanQuery);
  }

  Future<Map<String, String>> _headers({
    bool auth = true,
    bool form = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': form
          ? 'application/x-www-form-urlencoded'
          : 'application/json',
    };
    if (auth) {
      final t = await token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    String message = 'Error ${response.statusCode}';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['detail'] != null) {
        message = body['detail'].toString();
      }
    } catch (_) {
      // respuesta sin cuerpo JSON parseable, se usa el mensaje genérico
    }
    throw ApiException(response.statusCode, message);
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final response = await http.get(
      _uri(path, query),
      headers: await _headers(auth: auth),
    );
    return _decode(response);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    bool auth = true,
    bool form = false,
  }) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(auth: auth, form: form),
      body: form ? body : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, {Object? body, bool auth = true}) async {
    final response = await http.put(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) async {
    final response = await http.patch(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> delete(String path, {bool auth = true}) async {
    final response = await http.delete(
      _uri(path),
      headers: await _headers(auth: auth),
    );
    _decode(response);
  }
}
