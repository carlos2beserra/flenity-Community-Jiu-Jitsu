import 'package:flenity_combate/core/api_client.dart';
import 'package:flenity_combate/core/session.dart';
import 'package:flenity_combate/core/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'api_client_test.dart' show envelope;

const staffMe = {
  'id': 'u1',
  'name': 'Mestre Renzo',
  'role': 'INSTRUCTOR',
  'academy': {'name': 'Unidade Centro'},
};

Session buildSession(MockClient client, TokenStorage storage) => Session(
  api: ApiClient(baseUrl: 'http://api', httpClient: client),
  storage: storage,
);

void main() {
  test('login de aluno usa a rota do aluno e persiste o token', () async {
    // Arrange
    final paths = <String>[];
    final storage = MemoryTokenStorage();
    final session = buildSession(
      MockClient((r) async {
        paths.add(r.url.path);
        return envelope({
          'accessToken': 'tok-aluno',
          'student': {'id': 's1'},
        });
      }),
      storage,
    );

    // Act
    await session.login('aluno@flenity.com', 'combate123', LoginKind.student);

    // Assert
    expect(paths, ['/auth/student/login']);
    expect(session.status, SessionStatus.student);
    expect(await storage.read('flenity.token'), 'tok-aluno');
  });

  test('lembra o último e-mail e tipo de acesso após o logout, sem guardar a senha', () async {
    final storage = MemoryTokenStorage();
    final session = buildSession(
      MockClient((r) async => r.url.path == '/auth/login' ? envelope({'accessToken': 'tok'}) : envelope(staffMe)),
      storage,
    );

    expect((await session.lastLogin()).email, isNull);
    await session.login('  instrutor1@flenity.com ', 'combate123', LoginKind.staff);
    await session.logout();

    final last = await session.lastLogin();
    expect(last.email, 'instrutor1@flenity.com');
    expect(last.kind, LoginKind.staff);
    expect(await storage.read('flenity.token'), isNull);
    for (final key in ['flenity.token', 'flenity.kind', 'flenity.lastEmail', 'flenity.lastKind']) {
      expect(await storage.read(key), isNot('combate123'));
    }
  });

  test('trocar de comunidade persiste o token da nova academia', () async {
    final storage = MemoryTokenStorage();
    final session = buildSession(
      MockClient((request) async => envelope({'accessToken': 'tok-crossfit'})),
      storage,
    );
    session.api.token = 'tok-jiu-jitsu';

    await session.switchCommunity('student-crossfit');

    expect(session.api.token, 'tok-crossfit');
    expect(await storage.read('flenity.token'), 'tok-crossfit');
    expect(session.studentContextVersion, 1);
  });

  test('login de professor carrega o perfil da equipe', () async {
    final session = buildSession(
      MockClient((r) async {
        return r.url.path == '/auth/login'
            ? envelope({'accessToken': 'tok'})
            : envelope(staffMe);
      }),
      MemoryTokenStorage(),
    );

    await session.login(
      'instrutor1@flenity.com',
      'combate123',
      LoginKind.staff,
    );

    expect(session.status, SessionStatus.staff);
    expect(session.staff!.roleLabel, 'Professor');
  });

  test('restore volta ao login quando o token salvo é inválido', () async {
    final storage = MemoryTokenStorage();
    await storage.write('flenity.token', 'velho');
    await storage.write('flenity.kind', 'student');
    final session = buildSession(
      MockClient(
        (_) async => envelope(
          null,
          status: 401,
          error: {'code': 'UNAUTHORIZED', 'message': 'expirado'},
        ),
      ),
      storage,
    );

    await session.restore();

    expect(session.status, SessionStatus.signedOut);
    expect(await storage.read('flenity.token'), isNull);
  });

  test('restore mantém a sessão sem rede', () async {
    final storage = MemoryTokenStorage();
    await storage.write('flenity.token', 'tok');
    await storage.write('flenity.kind', 'student');
    final session = buildSession(
      MockClient((_) async => throw Exception('offline')),
      storage,
    );

    await session.restore();

    expect(session.status, SessionStatus.student);
  });
}
