import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// Klien HTTP ke API Gateway. Token JWT & alamat server disimpan di perangkat.
class Api {
  Api._();
  static final Api I = Api._();

  static String get _defaultBase =>
      kIsWeb ? 'http://127.0.0.1:8000' : (defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000');

  String baseUrl = _defaultBase;
  String? token;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    baseUrl = p.getString('base_url') ?? _defaultBase;
    token = p.getString('token');
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    (await SharedPreferences.getInstance()).setString('base_url', baseUrl);
  }

  Future<void> setToken(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    t == null ? await p.remove('token') : await p.setString('token', t);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _u(String path, [Map<String, dynamic>? q]) {
    final qp = <String, String>{};
    q?.forEach((k, v) {
      if (v != null) qp[k] = v.toString();
    });
    return Uri.parse('$baseUrl$path').replace(queryParameters: qp.isEmpty ? null : qp);
  }

  dynamic _handle(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) {
      String msg = 'Terjadi kesalahan (${r.statusCode})';
      if (body is Map && body['detail'] != null) {
        final d = body['detail'];
        msg = d is String ? d : (d is List && d.isNotEmpty ? '${d.first['loc']?.last}: ${d.first['msg']}' : d.toString());
      }
      throw ApiException(r.statusCode, msg);
    }
    return body;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      _handle(await http.get(_u(path, query), headers: _headers).timeout(const Duration(seconds: 30)));

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) async => _handle(await http
      .post(_u(path, query), headers: {..._headers, 'Content-Type': 'application/json'}, body: body == null ? null : jsonEncode(body))
      .timeout(const Duration(seconds: 30)));

  Future<dynamic> put(String path, {Object? body}) async => _handle(await http
      .put(_u(path), headers: {..._headers, 'Content-Type': 'application/json'}, body: body == null ? null : jsonEncode(body))
      .timeout(const Duration(seconds: 30)));

  Future<dynamic> patch(String path, {Object? body, Map<String, dynamic>? query}) async => _handle(await http
      .patch(_u(path, query), headers: {..._headers, 'Content-Type': 'application/json'}, body: body == null ? null : jsonEncode(body))
      .timeout(const Duration(seconds: 30)));

  Future<dynamic> delete(String path) async => _handle(await http.delete(_u(path), headers: _headers).timeout(const Duration(seconds: 30)));

  /// Unggah berkas (multipart). [files] = {fieldName: (bytes, filename)}
  Future<dynamic> multipart(String path, {Map<String, String> fields = const {}, Map<String, (Uint8List, String)> files = const {}}) async {
    final req = http.MultipartRequest('POST', _u(path))..headers.addAll(_headers)..fields.addAll(fields);
    files.forEach((k, v) => req.files.add(http.MultipartFile.fromBytes(k, v.$1, filename: v.$2)));
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    return _handle(await http.Response.fromStream(streamed));
  }

  String fileUrl(String? path) => path == null ? '' : '$baseUrl$path';
}
