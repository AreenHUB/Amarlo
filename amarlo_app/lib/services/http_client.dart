// lib/services/http_client.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// خطأ موحّد من الـ API
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// يُحدد الـ MIME type الصحيح بناءً على امتداد الملف
MediaType _mediaTypeFor(String path) {
  final mime = lookupMimeType(path) ?? 'image/jpeg';
  final parts = mime.split('/');
  return MediaType(parts[0], parts.length > 1 ? parts[1] : 'jpeg');
}

/// HTTP client مع إرفاق التوكن تلقائياً
class HttpClient {
  HttpClient._();
  static final HttpClient instance = HttpClient._();

  // ─── Token ───────────────────────────────────────────
  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.kAccessToken);
  }

  Map<String, String> _headers({bool json = true, String? token}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  // ─── Response handler ────────────────────────────────
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

  // ─── REST methods ────────────────────────────────────

  Future<dynamic> get(String url, {bool auth = true}) async {
    final token = auth ? await _token() : null;
    final res = await http
        .get(Uri.parse(url), headers: _headers(json: false, token: token))
        .timeout(const Duration(seconds: 30));
    return _handle(res);
  }

  Future<dynamic> post(String url, Map<String, dynamic> body,
      {bool auth = true}) async {
    final token = auth ? await _token() : null;
    final res = await http
        .post(Uri.parse(url),
            headers: _headers(token: token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return _handle(res);
  }

  Future<dynamic> put(String url, Map<String, dynamic> body,
      {bool auth = true}) async {
    final token = auth ? await _token() : null;
    final res = await http
        .put(Uri.parse(url),
            headers: _headers(token: token), body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return _handle(res);
  }

  Future<dynamic> delete(String url, {bool auth = true}) async {
    final token = auth ? await _token() : null;
    final res = await http
        .delete(Uri.parse(url), headers: _headers(json: false, token: token))
        .timeout(const Duration(seconds: 30));
    return _handle(res);
  }

  // ─── Multipart POST (صور / ملفات) ───────────────────
  Future<dynamic> multipartPost(
    String url, {
    required String fieldName,
    File? file,
    Map<String, String>? fields,
    bool auth = true,
  }) async {
    final token = auth ? await _token() : null;
    final req = http.MultipartRequest('POST', Uri.parse(url));

    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (fields != null) req.fields.addAll(fields);

    if (file != null && file.path.isNotEmpty && await file.exists()) {
      // تحديد الـ content_type بشكل صريح لتجنب إرسال octet-stream
      req.files.add(await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        contentType: _mediaTypeFor(file.path),
      ));
    }

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  // ─── Multipart PUT ───────────────────────────────────
  Future<dynamic> multipartPut(
    String url, {
    File? file,
    String? fieldName,
    Map<String, String>? fields,
    bool auth = true,
  }) async {
    final token = auth ? await _token() : null;
    final req = http.MultipartRequest('PUT', Uri.parse(url));

    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (fields != null) req.fields.addAll(fields);

    if (file != null &&
        fieldName != null &&
        file.path.isNotEmpty &&
        await file.exists()) {
      req.files.add(await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        contentType: _mediaTypeFor(file.path),
      ));
    }

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }
}

final api = HttpClient.instance;
