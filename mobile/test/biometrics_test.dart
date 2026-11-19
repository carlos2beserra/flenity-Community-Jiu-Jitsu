import 'dart:convert';

import 'package:flenity_combate/core/api_client.dart';
import 'package:flenity_combate/core/biometrics.dart';
import 'package:flenity_combate/core/session.dart';
import 'package:flenity_combate/core/token_storage.dart';
import 'package:flenity_combate/screens/login_screen.dart';
import 'package:flenity_combate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'api_client_test.dart' show envelope;

/// Biometria controlada pelo teste.
class FakeBiometrics implements BiometricAuth {
  FakeBiometrics({this.available = true, this.approve = true});

  bool available;
  bool approve;
  final reasons = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    return approve;
  }
}

const secret = 'ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12';

class Backend {
  final calls = <String>[];
  final bodies = <String, Object?>{};
  int deviceLoginStatus = 200;

  late final client = MockClient((request) async {
    final key = '${request.method} ${request.url.path}';
    calls.add(key);
    if (request.body.isNotEmpty) bodies[key] = jsonDecode(request.body);
    return switch (key) {
      'POST /auth/student/login' => envelope({'accessToken': 'tok-senha'}),
      'POST /auth/device-credentials' => envelope({'credentialId': 'cred-1', 'secret': secret}),
      'DELETE /auth/device-credentials/cred-1' => envelope({'revoked': true}),
      'POST /auth/device-login' =>
        deviceLoginStatus == 200
            ? envelope({'accessToken': 'tok-bio', 'kind': 'student'})
            : envelope(null, status: 401, error: {'code': 'UNAUTHORIZED', 'message': 'Entrada com biometria expirada.'}),
      _ => http.Response('{}', 404),
    };
  });
}

Session session(Backend backend, TokenStorage storage, FakeBiometrics bio) => Session(
  api: ApiClient(baseUrl: 'http://api', httpClient: backend.client),
  storage: storage,
  biometrics: bio,
);

void main() {
  setUpAll(() => appUseGoogleFonts = false);

  group('sessão', () {
    test('ativar biometria exige confirmar a digital e guarda só a credencial do aparelho', () async {
      final backend = Backend();
      final storage = MemoryTokenStorage();
      final bio = FakeBiometrics();
      final s = session(backend, storage, bio);
      await s.login('aluno@flenity.com', 'combate123', LoginKind.student, enableBiometrics: true);

      expect(bio.reasons, hasLength(1));
      expect(backend.calls, contains('POST /auth/device-credentials'));
      expect(await s.biometricLoginEmail(), 'aluno@flenity.com');
      expect(await storage.read('flenity.bio.secret'), secret);
      for (final key in ['flenity.bio.id', 'flenity.bio.secret', 'flenity.bio.email', 'flenity.bio.kind', 'flenity.lastEmail']) {
        expect(await storage.read(key), isNot('combate123'), reason: 'a senha nunca é guardada');
      }
    });

    test('se a digital for cancelada no login, entra sem ativar a biometria', () async {
      final backend = Backend();
      final s = session(backend, MemoryTokenStorage(), FakeBiometrics(approve: false));

      await s.login('aluno@flenity.com', 'combate123', LoginKind.student, enableBiometrics: true);

      expect(s.status, SessionStatus.student);
      expect(backend.calls, isNot(contains('POST /auth/device-credentials')));
      expect(await s.biometricLoginEmail(), isNull);
    });

    test('depois de sair, entra com a digital trocando a credencial por um novo token', () async {
      final backend = Backend();
      final storage = MemoryTokenStorage();
      final s = session(backend, storage, FakeBiometrics());
      await s.login('aluno@flenity.com', 'combate123', LoginKind.student, enableBiometrics: true);
      await s.logout();
      expect(s.status, SessionStatus.signedOut);

      expect(await s.loginWithBiometrics(), isTrue);

      expect(s.status, SessionStatus.student);
      expect(s.api.token, 'tok-bio');
      expect(backend.bodies['POST /auth/device-login'], {'credentialId': 'cred-1', 'secret': secret});
    });

    test('credencial expirada é apagada do aparelho e o erro é mostrado', () async {
      final backend = Backend();
      final s = session(backend, MemoryTokenStorage(), FakeBiometrics());
      await s.login('aluno@flenity.com', 'combate123', LoginKind.student, enableBiometrics: true);
      await s.logout();
      backend.deviceLoginStatus = 401;

      await expectLater(s.loginWithBiometrics(), throwsA(isA<ApiException>()));
      expect(await s.biometricLoginEmail(), isNull);
      expect(s.status, SessionStatus.signedOut);
    });

    test('desativar revoga a credencial no servidor', () async {
      final backend = Backend();
      final s = session(backend, MemoryTokenStorage(), FakeBiometrics());
      await s.login('aluno@flenity.com', 'combate123', LoginKind.student, enableBiometrics: true);

      await s.disableBiometrics();

      expect(backend.calls, contains('DELETE /auth/device-credentials/cred-1'));
      expect(await s.biometricLoginEmail(), isNull);
    });
  });

  group('tela de login', () {
    Widget app(Session s) => ChangeNotifierProvider.value(
      value: s,
      child: MaterialApp(theme: buildTheme(), home: const LoginScreen()),
    );

    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('mostra a opção de ativar biometria quando o aparelho suporta', (tester) async {
      phone(tester);
      final backend = Backend();
      final s = session(backend, MemoryTokenStorage(), FakeBiometrics());
      await tester.pumpWidget(app(s));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('remember-biometrics')), findsOneWidget);
      expect(find.byKey(const Key('biometric-login')), findsNothing);

      await tester.enterText(find.byKey(const Key('email')), 'aluno@flenity.com');
      await tester.enterText(find.byKey(const Key('password')), 'combate123');
      await tester.ensureVisible(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      expect(backend.calls, contains('POST /auth/device-credentials'));
      expect(s.status, SessionStatus.student);
    });

    testWidgets('sem biometria no aparelho, a opção não aparece', (tester) async {
      phone(tester);
      final s = session(Backend(), MemoryTokenStorage(), FakeBiometrics(available: false));
      await tester.pumpWidget(app(s));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('remember-biometrics')), findsNothing);
      expect(find.byKey(const Key('biometric-login')), findsNothing);
    });

    testWidgets('com biometria ativa, pede a digital ao abrir e entra', (tester) async {
      phone(tester);
      final backend = Backend();
      final storage = MemoryTokenStorage();
      final bio = FakeBiometrics(approve: false);
      final s = session(backend, storage, bio);
      bio.approve = true;
      await s.login('aluno@flenity.com', 'combate123', LoginKind.student, enableBiometrics: true);
      await s.logout();
      bio
        ..approve = false
        ..reasons.clear();

      await tester.pumpWidget(app(s));
      await tester.pumpAndSettle();

      expect(bio.reasons, ['Entrar no Flenity'], reason: 'pede a digital ao abrir a tela');
      expect(find.text('Entrar com biometria'), findsOneWidget);
      expect(find.text('aluno@flenity.com'), findsWidgets);
      expect(find.text('ou use sua senha'), findsOneWidget);
      expect(find.byKey(const Key('remember-biometrics')), findsNothing);

      bio.approve = true;
      await tester.tap(find.byKey(const Key('biometric-login')));
      await tester.pumpAndSettle();
      expect(s.status, SessionStatus.student);
      expect(s.api.token, 'tok-bio');
    });
  });
}
