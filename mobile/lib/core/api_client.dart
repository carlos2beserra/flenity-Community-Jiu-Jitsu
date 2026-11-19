import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Cliente da API Flenity: envia o token e desembrulha o envelope `{ success, data, error }`.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? token;

  /// Chamado quando a API responde 401 com um token presente (sessão expirada).
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, String?>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body ?? const {});
  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Envia um arquivo (multipart/form-data, campo `file`).
  Future<dynamic> upload(String path, List<int> bytes, String filename) {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    return _dispatch(request, timeout: const Duration(minutes: 3));
  }

  /// URLs de mídia chegam relativas à API (`/media/...`); URLs absolutas são mantidas.
  String resolveUrl(String url) => url.startsWith('http') ? url : '$baseUrl$url';

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String?>? query}) {
    final params = {for (final e in (query ?? {}).entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value!};
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params.isEmpty ? null : params);
    final request = http.Request(method, uri)
      ..headers.addAll({if (body != null) 'Content-Type': 'application/json'});
    if (body != null) request.body = jsonEncode(body);
    return _dispatch(request);
  }

  Future<dynamic> _dispatch(http.BaseRequest request, {Duration timeout = const Duration(seconds: 20)}) async {
    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } catch (_) {
      throw ApiException(0, 'NETWORK', 'Sem conexão com o servidor');
    }

    Map<String, dynamic>? envelope;
    try {
      envelope = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      envelope = null;
    }

    if (response.statusCode >= 400 || envelope?['success'] != true) {
      if (response.statusCode == 401 && token != null) onUnauthorized?.call();
      final error = envelope?['error'] as Map<String, dynamic>?;
      throw ApiException(
        response.statusCode,
        error?['code'] as String? ?? 'ERROR',
        error?['message'] as String? ?? 'Erro inesperado (${response.statusCode})',
      );
    }
    return envelope!['data'];
  }
}
