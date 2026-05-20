// lib/services/http_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

MediaType _mediaTypeFor(String path) {
  final mime = lookupMimeType(path) ?? 'image/jpeg';
  final parts = mime.split('/');
  return MediaType(parts[0], parts.length > 1 ? parts[1] : 'jpeg');
}

/// HTTP client موحّد مع:
/// - إرفاق access token تلقائياً
/// - refresh token auto-retry عند 401
/// - multipart upload بـ explicit content-type
class HttpClient {
  HttpClient._();
  static final HttpClient instance = HttpClient._();

  // منع طلبات refresh متزامنة
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  // ─── Token management ───────────────────────────────
  Future<String?> _accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.kAccessToken);
  }

  Future<String?> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.kRefreshToken);
  }

  Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.kAccessToken, access);
    await prefs.setString(AppConstants.kRefreshToken, refresh);
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.kAccessToken);
    await prefs.remove(AppConstants.kRefreshToken);
    await prefs.remove(AppConstants.kUserId);
    await prefs.remove(AppConstants.kEmail);
    await prefs.remove(AppConstants.kUserType);
  }

  Map<String, String> _headers({bool json = true, String? token}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  // ─── Response handler ───────────────────────────────
  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String detail = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      detail = body['detail'] ?? body['message'] ?? detail;
    } catch (_) {
      if (res.body.isNotEmpty) detail = res.body;
    }
    throw ApiException(res.statusCode, detail);
  }

  // ─── Refresh token logic ────────────────────────────
  /// Public wrapper للاستخدام من auth_provider
  Future<bool> tryRefresh() => _tryRefresh();

  Future<bool> _tryRefresh() async {
    if (_isRefreshing) {
      // انتظر حتى ينتهي الـ refresh الجاري
      return await _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final refresh = await _refreshToken();
      if (refresh == null) {
        await _clearTokens();
        _refreshCompleter!.complete(false);
        return false;
      }

      final res = await http.post(
        Uri.parse(AppConstants.refreshUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'refresh_token': refresh},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _saveTokens(
          data['access_token'] as String,
          data['refresh_token'] as String,
        );
        _refreshCompleter!.complete(true);
        return true;
      } else {
        await _clearTokens();
        _refreshCompleter!.complete(false);
        return false;
      }
    } on SocketException {
      // خطأ شبكة — لا تمسح الـ tokens، السيرفر قد يكون مؤقتاً غير متاح
      _refreshCompleter!.complete(false);
      return false;
    } catch (_) {
      await _clearTokens();
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  // ─── Core request with auto-refresh ────────────────
  Future<dynamic> _request(
    Future<http.Response> Function(String? token) makeRequest, {
    bool auth = true,
  }) async {
    final token = auth ? await _accessToken() : null;
    http.Response res;

    try {
      res = await makeRequest(token).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ApiException(408, 'Request timed out');
    } on SocketException {
      throw const ApiException(0, 'No internet connection');
    }

    // Token expired → try refresh
    if (res.statusCode == 401 && auth) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newToken = await _accessToken();
        try {
          res = await makeRequest(newToken).timeout(const Duration(seconds: 30));
        } on TimeoutException {
          throw const ApiException(408, 'Request timed out');
        }
      } else {
        throw const ApiException(401, 'Session expired. Please login again.');
      }
    }

    return _handle(res);
  }

  // ─── Public HTTP methods ────────────────────────────
  Future<dynamic> get(String url, {bool auth = true}) => _request(
        (token) => http.get(Uri.parse(url),
            headers: _headers(json: false, token: token)),
        auth: auth,
      );

  Future<dynamic> post(String url, Map<String, dynamic> body,
          {bool auth = true}) =>
      _request(
        (token) => http.post(Uri.parse(url),
            headers: _headers(token: token), body: jsonEncode(body)),
        auth: auth,
      );

  Future<dynamic> put(String url, Map<String, dynamic> body,
          {bool auth = true}) =>
      _request(
        (token) => http.put(Uri.parse(url),
            headers: _headers(token: token), body: jsonEncode(body)),
        auth: auth,
      );

  Future<dynamic> delete(String url, {bool auth = true}) => _request(
        (token) => http.delete(Uri.parse(url),
            headers: _headers(json: false, token: token)),
        auth: auth,
      );

  // ─── Multipart POST ─────────────────────────────────
  Future<dynamic> multipartPost(
    String url, {
    required String fieldName,
    File? file,
    File? proofImage,          // صورة إثبات اختيارية (للملفات غير الصور)
    Map<String, String>? fields,
    bool auth = true,
  }) async {
    final token = auth ? await _accessToken() : null;

    Future<http.MultipartRequest> buildReq(String? tkn) async {
      final req = http.MultipartRequest('POST', Uri.parse(url));
      if (tkn != null) req.headers['Authorization'] = 'Bearer $tkn';
      if (fields != null) req.fields.addAll(fields);
      if (file != null && file.path.isNotEmpty && await file.exists()) {
        req.files.add(await http.MultipartFile.fromPath(
          fieldName, file.path,
          contentType: _mediaTypeFor(file.path),
        ));
      }
      if (proofImage != null && proofImage.path.isNotEmpty && await proofImage.exists()) {
        req.files.add(await http.MultipartFile.fromPath(
          'proof_image', proofImage.path,
          contentType: _mediaTypeFor(proofImage.path),
        ));
      }
      return req;
    }

    final streamed = await (await buildReq(token)).send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 401 && auth) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newToken = await _accessToken();
        final s2 = await (await buildReq(newToken)).send().timeout(const Duration(seconds: 60));
        return _handle(await http.Response.fromStream(s2));
      }
    }
    return _handle(res);
  }

  // ─── Multipart PUT ──────────────────────────────────
  Future<dynamic> multipartPut(
    String url, {
    File? file,
    String? fieldName,
    Map<String, String>? fields,
    bool auth = true,
  }) async {
    final token = auth ? await _accessToken() : null;
    final req = http.MultipartRequest('PUT', Uri.parse(url));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (fields != null) req.fields.addAll(fields);
    if (file != null && fieldName != null &&
        file.path.isNotEmpty && await file.exists()) {
      req.files.add(await http.MultipartFile.fromPath(
        fieldName, file.path,
        contentType: _mediaTypeFor(file.path),
      ));
    }
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  // ─── Form POST (لـ refresh token) ───────────────────
  Future<dynamic> formPost(String url, Map<String, String> fields,
      {bool auth = false}) async {
    final token = auth ? await _accessToken() : null;
    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final res = await http
        .post(Uri.parse(url), headers: headers, body: fields)
        .timeout(const Duration(seconds: 30));
    return _handle(res);
  }
}

final api = HttpClient.instance;
