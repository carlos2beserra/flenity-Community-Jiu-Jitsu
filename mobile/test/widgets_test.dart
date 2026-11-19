import 'dart:convert';

import 'package:flenity_combate/core/api_client.dart';
import 'package:flenity_combate/core/session.dart';
import 'package:flenity_combate/core/token_storage.dart';
import 'package:flenity_combate/screens/chat_screen.dart';
import 'package:flenity_combate/screens/login_screen.dart';
import 'package:flenity_combate/screens/student/student_schedule_tab.dart';
import 'package:flenity_combate/ui/theme.dart';
import 'package:flenity_combate/ui/widgets/activity_feature_card.dart';
import 'package:flenity_combate/ui/widgets/belt_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'api_client_test.dart' show envelope;

Widget wrap(Widget child, {Session? session}) {
  final app = MaterialApp(
    theme: buildTheme(),
    home: Scaffold(body: child),
  );
  return session == null
      ? app
      : ChangeNotifierProvider.value(value: session, child: app);
}

Widget wrapShell(Widget child, {required Session session}) {
  return ChangeNotifierProvider.value(
    value: session,
    child: MaterialApp(theme: buildTheme(), home: child),
  );
}

void main() {
  setUpAll(() => appUseGoogleFonts = false);

  testWidgets('BeltBadge desenha uma listra por grau', (tester) async {
    await tester.pumpWidget(wrap(const BeltBadge(color: '#1e5bd6', degree: 3)));
    final stripes = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('belt-stripe'),
    );
    expect(stripes, findsNWidgets(3));
  });

  testWidgets('faixa preta usa ponteira vermelha', (tester) async {
    await tester.pumpWidget(wrap(const BeltBadge(color: '#111111', degree: 0)));
    final tip = tester.widget<Container>(find.byKey(const Key('belt-tip')));
    expect(tip.color, const Color(0xFFC8361A));
  });

  testWidgets('agenda permite check-in em várias aulas no mesmo dia', (
    tester,
  ) async {
    final today = DateTime.now().weekday % 7;
    final checkedIn = <String>{};
    final checkedInClasses = <String>[];
    final classes = [
      {
        'id': 'class-1',
        'name': 'Jiu-Jitsu fundamentos',
        'startTime': '18:00',
        'endTime': '19:00',
      },
      {
        'id': 'class-2',
        'name': 'Jiu-Jitsu No-Gi',
        'startTime': '19:00',
        'endTime': '20:00',
      },
    ];
    final session = Session(
      api: ApiClient(
        baseUrl: 'http://api',
        httpClient: MockClient((request) async {
          if (request.url.path == '/student/classes' &&
              request.method == 'GET') {
            return envelope(
              classes
                  .map(
                    (slot) => {
                      ...slot,
                      'weekday': today,
                      'capacity': 20,
                      'modality': {'id': 'jiu-jitsu', 'name': 'Jiu-Jitsu'},
                      'instructor': null,
                      'checkInOpen': true,
                      'checkedInToday': checkedIn.contains(slot['id']),
                    },
                  )
                  .toList(),
            );
          }
          if (request.url.path == '/student/check-ins' &&
              request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final classId = body['classId'] as String;
            checkedIn.add(classId);
            checkedInClasses.add(classId);
            return envelope({'id': 'checkin-${checkedInClasses.length}'});
          }
          throw StateError('Unexpected API request: ${request.url}');
        }),
      ),
      storage: MemoryTokenStorage(),
    )..status = SessionStatus.student;

    await tester.pumpWidget(
      wrapShell(const Scaffold(body: StudentScheduleTab()), session: session),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Faça check-in em cada aula de Jiu-Jitsu que participar, respeitando o limite semanal do seu plano. Todas as presenças ficam registradas; para a graduação, conta no máximo uma por dia.',
      ),
      findsOneWidget,
    );
    expect(find.text('CHECK-IN'), findsNWidgets(2));
    await tester.tap(find.text('CHECK-IN').first);
    await tester.pumpAndSettle();

    expect(checkedInClasses, ['class-1']);
    expect(find.text('Presente'), findsOneWidget);
    expect(find.text('CHECK-IN'), findsOneWidget);
    await tester.tap(find.text('CHECK-IN'));
    await tester.pumpAndSettle();

    expect(checkedInClasses, ['class-1', 'class-2']);
    expect(find.text('Presente'), findsNWidgets(2));
  });

  testWidgets('cartão de atividade mostra uma prática e executa a ação', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var started = false;
    var menuOpened = false;
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ActivityFeatureCard(
              height: 540,
              title: 'Jiu-Jitsu ao ar livre',
              eyebrow: 'Detalhes da aula',
              description: 'Treine no seu ritmo.',
              details: 'HOJE · 18:00–19:00 · Jiu-Jitsu',
              host: 'Ana Silva',
              hostLabel: 'Espaço Centro',
              sideNote: 'Vinyasa',
              badge: 'CHECK-IN ABERTO',
              actionLabel: 'FAZER CHECK-IN',
              onAction: () => started = true,
              onMenuTap: () => menuOpened = true,
              icon: Icons.spa_rounded,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Jiu-Jitsu ao ar livre'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu_rounded));
    expect(menuOpened, isTrue);
    await tester.tap(find.text('FAZER CHECK-IN'));
    expect(started, isTrue);
  });

  testWidgets('chat lista os contatos da equipe disponíveis para o aluno', (
    tester,
  ) async {
    final session = Session(
      api: ApiClient(
        baseUrl: 'http://api',
        httpClient: MockClient((request) async {
          if (request.url.path == '/chat/conversations') return envelope([]);
          if (request.url.path == '/chat/contacts') {
            return envelope([
              {'id': 'staff-1', 'name': 'Professora Ana', 'role': 'INSTRUCTOR'},
            ]);
          }
          throw StateError('Unexpected API request: ${request.url}');
        }),
      ),
      storage: MemoryTokenStorage(),
    )..status = SessionStatus.student;

    await tester.pumpWidget(wrap(const ChatScreen(), session: session));
    await tester.pumpAndSettle();

    expect(find.text('CHAT'), findsOneWidget);
    expect(find.text('FALE COM A EQUIPE'), findsOneWidget);
    expect(find.text('Professora Ana'), findsOneWidget);
  });

  testWidgets('login como professor chama a rota da equipe', (tester) async {
    // Arrange
    final paths = <String>[];
    final session = Session(
      api: ApiClient(
        baseUrl: 'http://api',
        httpClient: MockClient((r) async {
          paths.add(r.url.path);
          return r.url.path == '/auth/login'
              ? envelope({'accessToken': 'tok'})
              : envelope({
                  'id': 'u1',
                  'name': 'Mestre',
                  'role': 'INSTRUCTOR',
                  'academy': {'name': 'Centro'},
                });
        }),
      ),
      storage: MemoryTokenStorage(),
    );
    await tester.pumpWidget(wrap(const LoginScreen(), session: session));

    // Act
    await tester.tap(find.byKey(const Key('kind-staff')));
    await tester.pump();
    expect(find.text('Entrar como equipe'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('email')),
      'instrutor1@flenity.com',
    );
    await tester.enterText(find.byKey(const Key('password')), 'combate123');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    // Assert
    expect(paths, ['/auth/login', '/auth/me']);
    expect(session.status, SessionStatus.staff);
  });

  testWidgets('login valida e-mail antes de chamar a API', (tester) async {
    var called = false;
    final session = Session(
      api: ApiClient(
        baseUrl: 'http://api',
        httpClient: MockClient((_) async {
          called = true;
          return envelope({});
        }),
      ),
      storage: MemoryTokenStorage(),
    );
    await tester.pumpWidget(wrap(const LoginScreen(), session: session));

    expect(
      find.text('Sua comunidade de Jiu-Jitsu, sempre com você.'),
      findsOneWidget,
    );
    expect(find.text('Aluno'), findsOneWidget);
    expect(find.text('Professor ou equipe'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('email')), 'sem-arroba');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('erro da API aparece na tela de login', (tester) async {
    final session = Session(
      api: ApiClient(
        baseUrl: 'http://api',
        httpClient: MockClient(
          (_) async => envelope(
            null,
            status: 401,
            error: {
              'code': 'UNAUTHORIZED',
              'message': 'E-mail ou senha inválidos',
            },
          ),
        ),
      ),
      storage: MemoryTokenStorage(),
    );
    await tester.pumpWidget(wrap(const LoginScreen(), session: session));

    await tester.enterText(find.byKey(const Key('email')), 'aluno@flenity.com');
    await tester.enterText(find.byKey(const Key('password')), 'errada');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha inválidos'), findsOneWidget);
  });

  testWidgets('login lembra o último e-mail e tipo de acesso, nunca a senha', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = MemoryTokenStorage();
    await storage.write('flenity.lastEmail', 'instrutor1@flenity.com');
    await storage.write('flenity.lastKind', 'staff');
    final session = Session(api: ApiClient(baseUrl: 'http://api'), storage: storage);

    await tester.pumpWidget(wrap(const LoginScreen(), session: session));
    await tester.pumpAndSettle();

    final email = tester.widget<TextFormField>(find.byKey(const Key('email')));
    expect(email.controller!.text, 'instrutor1@flenity.com');
    expect(find.text('Entrar como equipe'), findsOneWidget);
    final password = tester.widget<TextFormField>(find.byKey(const Key('password')));
    expect(password.controller!.text, isEmpty);
  });

  testWidgets('esqueci minha senha explica como recuperar o acesso', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = Session(api: ApiClient(baseUrl: 'http://api'), storage: MemoryTokenStorage());
    await tester.pumpWidget(wrap(const LoginScreen(), session: session));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Esqueci minha senha'));
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(find.text('Esqueceu a senha?'), findsOneWidget);
    expect(find.textContaining('recepção da sua academia'), findsWidgets);
  });
}
