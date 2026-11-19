import 'dart:convert';

import 'package:flenity_combate/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response envelope(Object? data, {int status = 200, Map<String, String>? error}) => http.Response(
      jsonEncode({'success': error == null, 'data': data, 'error': error}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('desembrulha o envelope e envia o token', () async {
    // Arrange
    late http.Request sent;
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((request) async {
        sent = request;
        return envelope({'ok': true});
      }),
    )..token = 'abc';

    // Act
    final data = await api.get('/student/me', query: {'page': '1', 'empty': ''});

    // Assert
    expect(data, {'ok': true});
    expect(sent.headers['Authorization'], 'Bearer abc');
    expect(sent.url.toString(), 'http://api/student/me?page=1');
  });

  test('converte erro da API em ApiException com a mensagem do servidor', () async {
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((_) async => envelope(null, status: 403, error: {'code': 'FORBIDDEN', 'message': 'Mensalidade em atraso há 19 dias'})),
    );

    expect(
      () => api.post('/student/check-ins', {'classId': 'x'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Mensalidade em atraso há 19 dias').having((e) => e.statusCode, 'status', 403)),
    );
  });

  test('avisa sessão expirada em 401 quando havia token', () async {
    var expired = false;
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((_) async => envelope(null, status: 401, error: {'code': 'UNAUTHORIZED', 'message': 'Token inválido'})),
    )
      ..token = 'old'
      ..onUnauthorized = () => expired = true;

    await expectLater(api.get('/student/me'), throwsA(isA<ApiException>()));
    expect(expired, isTrue);
  });

  test('falha de rede vira ApiException com status 0', () async {
    final api = ApiClient(baseUrl: 'http://api', httpClient: MockClient((_) async => throw Exception('offline')));
    await expectLater(api.get('/x'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 0)));
  });
}
