import 'dart:convert';

import 'package:flenity_combate/core/api_client.dart';
import 'package:flenity_combate/core/session.dart';
import 'package:flenity_combate/core/token_storage.dart';
import 'package:flenity_combate/screens/community_screen.dart';
import 'package:flenity_combate/screens/instructor/instructor_shell.dart';
import 'package:flenity_combate/screens/student/student_shell.dart';
import 'package:flenity_combate/social/media_picker.dart';
import 'package:flenity_combate/social/screens/notifications_screen.dart';
import 'package:flenity_combate/social/screens/profile_screen.dart';
import 'package:flenity_combate/social/screens/story_viewer_screen.dart';
import 'package:flenity_combate/social/social_models.dart';
import 'package:flenity_combate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'api_client_test.dart' show envelope;

typedef Handler = Object? Function(http.Request request);

/// API falsa: responde por "MÉTODO /caminho" e registra cada chamada.
class FakeApi {
  FakeApi(this.routes);

  final Map<String, Handler> routes;
  final calls = <String>[];
  final bodies = <String, Object?>{};

  late final client = MockClient((request) async {
    final key = '${request.method} ${request.url.path}';
    calls.add(key);
    if (request.headers['content-type']?.startsWith('application/json') == true && request.body.isNotEmpty) {
      bodies[key] = jsonDecode(request.body);
    }
    final handler = routes[key];
    if (handler == null) throw StateError('Rota não esperada: $key');
    return envelope(handler(request));
  });

  int count(String key) => calls.where((call) => call == key).length;
}

Map<String, Object?> author(String id, String name) => {'id': id, 'name': name, 'avatarUrl': null};

Map<String, Object?> postJson({
  String id = 'p1',
  String authorId = 'other',
  String authorName = 'Bruno Lima',
  String content = 'Treino de raspagem hoje!',
  int likes = 3,
  int comments = 0,
  bool liked = false,
  bool saved = false,
  String kind = 'POST',
  List<Map<String, Object?>> media = const [],
}) => {
  'id': id,
  'kind': kind,
  'content': content,
  'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
  'author': author(authorId, authorName),
  'media': media,
  '_count': {'likes': likes, 'comments': comments},
  'likedByMe': liked,
  'savedByMe': saved,
  'comments': <Object?>[],
};

Map<String, Object?> page(List<Object?> items) => {'items': items, 'total': items.length, 'page': 1, 'pageSize': 20};

Map<String, Object?> profileJson({
  String id = 'me',
  String name = 'Ana Silva',
  bool isMe = true,
  bool following = false,
  int followers = 4,
}) => {
  ...author(id, name),
  'handle': handleFromName(name),
  'bio': 'Faixa azul · Oss!',
  'academyName': 'Academia Centro',
  'belt': {'name': 'Azul', 'color': '#1e5bd6', 'degree': 2},
  'counts': {'posts': 1, 'followers': followers, 'following': 2},
  'isMe': isMe,
  'isFollowing': following,
  'followsMe': false,
};

Map<String, Handler> baseRoutes({List<Object?>? posts, List<Object?>? stories}) => {
  'POST /auth/student/login': (_) => {'accessToken': 'tok'},
  'GET /student/community/posts': (request) =>
      page(request.url.queryParameters['kind'] == 'REEL' ? const [] : (posts ?? [postJson()])),
  'GET /student/community/stories': (_) => stories ?? const [],
  'GET /student/community/people/me': (_) => profileJson(),
  'GET /student/community/notifications/unread-count': (_) => {'count': 2},
};

Future<Session> signedIn(FakeApi api) async {
  final session = Session(
    api: ApiClient(baseUrl: 'http://api', httpClient: api.client),
    storage: MemoryTokenStorage(),
  );
  await session.login('aluna@flenity.com', 'senha', LoginKind.student);
  return session;
}

Future<Session> signedInStaff(FakeApi api, {String role = 'INSTRUCTOR', String name = 'Mestre Carlos'}) async {
  api.routes['POST /auth/login'] = (_) => {'accessToken': 'staff-tok'};
  api.routes['GET /auth/me'] = (_) => {
    'id': 'u-1',
    'name': name,
    'role': role,
    'academy': {'name': 'Academia Centro'},
  };
  final session = Session(
    api: ApiClient(baseUrl: 'http://api', httpClient: api.client),
    storage: MemoryTokenStorage(),
  );
  await session.login('prof@flenity.com', 'senha', LoginKind.staff);
  return session;
}

Map<String, Object?> staffAuthor(String id, String name) =>
    {...author(id, name), 'isStaff': true, 'roleLabel': 'Professor'};

Widget app(Session session, Widget home, {MediaPickerService? picker}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: session),
    Provider<MediaPickerService?>.value(value: picker),
  ],
  child: MaterialApp(theme: buildTheme(), home: home),
);

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

class FakePicker implements MediaPickerService {
  final picks = <PickedMedia>[
    PickedMedia(bytes: base64Decode(_onePixelPng), name: 'treino.png', isVideo: false),
  ];

  @override
  Future<List<PickedMedia>> pickFromGallery({required bool multiple, required bool allowVideo, required bool videoOnly}) async =>
      picks;

  @override
  Future<PickedMedia?> capture({required bool video}) async => picks.first;
}

void main() {
  setUpAll(() => appUseGoogleFonts = false);

  group('modelos sociais', () {
    test('lê publicação com mídia e contadores', () {
      final post = SocialPost.fromJson(
        postJson(media: [
          {'id': 'm1', 'kind': 'VIDEO', 'url': '/media/m1?exp=1&sig=a'},
        ], likes: 12, liked: true),
      );
      expect(post.author.handle, 'bruno.lima');
      expect(post.cover!.isVideo, isTrue);
      expect(post.likes, 12);
      expect(post.likedByMe, isTrue);
    });

    test('formata contadores e tempo relativo', () {
      expect(compactCount(999), '999');
      expect(compactCount(1234), '1.234');
      expect(compactCount(12500), '12,5 mil');
      expect(compactCount(3000000), '3 mi');
      final now = DateTime(2026, 11, 17, 12);
      expect(relativeTime(now.subtract(const Duration(seconds: 20)), now: now), 'agora');
      expect(relativeTime(now.subtract(const Duration(hours: 5)), now: now), '5 h');
      expect(relativeTime(now.subtract(const Duration(days: 15)), now: now), '2 sem');
    });

    test('@usuário segue o mesmo critério da API', () {
      expect(handleFromName('João Conceição'), 'joao.conceicao');
      expect(handleFromName('***'), 'aluno');
    });

    test('ApiClient resolve URLs de mídia relativas à API', () {
      final client = ApiClient(baseUrl: 'http://api');
      expect(client.resolveUrl('/media/x?sig=1'), 'http://api/media/x?sig=1');
      expect(client.resolveUrl('https://cdn/x.jpg'), 'https://cdn/x.jpg');
    });
  });

  testWidgets('início mostra stories, feed e badge de notificações; curtir chama a API', (tester) async {
    phoneSize(tester);
    final api = FakeApi({
      ...baseRoutes(
        stories: [
          {
            'author': author('other', 'Bruno Lima'),
            'isMe': false,
            'hasUnseen': true,
            'stories': [
              {
                'id': 's1',
                'media': {'id': 'm1', 'kind': 'IMAGE', 'url': '/media/m1'},
                'createdAt': DateTime.now().toUtc().toIso8601String(),
                'seen': false,
              },
            ],
          },
        ],
      ),
      'POST /student/community/posts/p1/like': (_) => {'liked': true},
      'POST /student/community/posts/p1/save': (_) => {'saved': true},
    });
    await tester.pumpWidget(app(await signedIn(api), const StudentShell()));
    await tester.pumpAndSettle();

    expect(find.text('Flenity'), findsOneWidget);
    expect(find.text('Seu flash'), findsOneWidget);
    expect(find.text('bruno.lima'), findsWidgets);
    expect(find.text('Treino de raspagem hoje!'), findsOneWidget);
    expect(find.text('3 curtidas'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byTooltip('Curtir'));
    await tester.pumpAndSettle();
    expect(api.count('POST /student/community/posts/p1/like'), 1);
    expect(find.text('4 curtidas'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Salvar'));
    await tester.pumpAndSettle();
    expect(api.count('POST /student/community/posts/p1/save'), 1);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
  });

  testWidgets('duplo toque na publicação curte (e não descurte)', (tester) async {
    phoneSize(tester);
    final api = FakeApi({
      ...baseRoutes(posts: [postJson(content: '', media: [{'id': 'm1', 'kind': 'IMAGE', 'url': '/media/m1'}])]),
      'POST /student/community/posts/p1/like': (_) => {'liked': true},
    });
    await tester.pumpWidget(app(await signedIn(api), const StudentShell()));
    await tester.pumpAndSettle();

    final media = find.byKey(const Key('post-media-p1'));
    await tester.tap(media);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(media);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('double-tap-heart')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(api.count('POST /student/community/posts/p1/like'), 1);
    expect(find.text('4 curtidas'), findsOneWidget);

    await tester.tap(media);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(media);
    await tester.pumpAndSettle();
    expect(api.count('POST /student/community/posts/p1/like'), 1);
  });

  testWidgets('cria publicação com foto: envia a mídia e mostra no topo do feed', (tester) async {
    phoneSize(tester);
    late http.Request upload;
    final api = FakeApi({
      ...baseRoutes(posts: const []),
      'POST /student/community/media': (request) {
        upload = request;
        return {'id': 'media-1', 'kind': 'IMAGE', 'url': '/media/media-1'};
      },
      'POST /student/community/posts': (_) => postJson(
        id: 'new',
        authorId: 'me',
        authorName: 'Ana Silva',
        content: 'Primeiro treino da semana',
        likes: 0,
        media: [{'id': 'media-1', 'kind': 'IMAGE', 'url': '/media/media-1'}],
      ),
    });
    final picker = FakePicker();
    await tester.pumpWidget(app(await signedIn(api), const StudentShell(), picker: picker));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo à comunidade'), findsOneWidget);

    await tester.tap(find.byTooltip('Criar'));
    await tester.pumpAndSettle();
    expect(find.text('Nova publicação'), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-pick-gallery')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('create-caption')), 'Primeiro treino da semana');
    await tester.tap(find.byKey(const Key('create-share')));
    await tester.pumpAndSettle();

    expect(upload.headers['content-type'], startsWith('multipart/form-data'));
    expect(api.bodies['POST /student/community/posts'], {
      'content': 'Primeiro treino da semana',
      'mediaIds': ['media-1'],
      'kind': 'POST',
    });
    expect(find.text('Publicação compartilhada.'), findsOneWidget);
    expect(find.text('ana.silva'), findsWidgets);
  });

  testWidgets('flash exige mídia e é publicado pelo botão "Seu flash"', (tester) async {
    phoneSize(tester);
    final api = FakeApi({
      ...baseRoutes(),
      'POST /student/community/media': (_) => {'id': 'media-2', 'kind': 'IMAGE', 'url': '/media/media-2'},
      'POST /student/community/stories': (_) => {'id': 'st1'},
    });
    await tester.pumpWidget(app(await signedIn(api), const StudentShell(), picker: FakePicker()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my-story')));
    await tester.pumpAndSettle();
    expect(find.text('Novo flash'), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-share')));
    await tester.pump();
    expect(find.text('Escolha uma foto ou vídeo para o flash.'), findsOneWidget);
    expect(api.count('POST /student/community/stories'), 0);

    await tester.tap(find.byKey(const Key('create-pick-gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-share')));
    await tester.pumpAndSettle();
    expect(api.bodies['POST /student/community/stories'], {'mediaId': 'media-2'});
    expect(find.text('Flash publicado por 24 horas.'), findsOneWidget);
  });

  testWidgets('perfil de outro aluno: seguir atualiza botão e contador', (tester) async {
    phoneSize(tester);
    final api = FakeApi({
      ...baseRoutes(),
      'GET /student/community/people/other': (_) => profileJson(id: 'other', name: 'Bruno Lima', isMe: false),
      'POST /student/community/people/other/follow': (_) => {'following': true},
    });
    await tester.pumpWidget(app(await signedIn(api), const ProfileScreen(studentId: 'other')));
    await tester.pumpAndSettle();

    expect(find.text('bruno.lima'), findsOneWidget);
    expect(find.text('Faixa azul · 2º grau'), findsOneWidget);
    expect(find.text('Faixa azul · Oss!'), findsOneWidget);
    expect(find.text('seguidores'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Treino de raspagem hoje!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-follow')));
    await tester.pumpAndSettle();
    expect(api.count('POST /student/community/people/other/follow'), 1);
    expect(find.text('Seguindo'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('meu perfil tem editar perfil, aba de salvos e menu com as ferramentas do aluno', (tester) async {
    phoneSize(tester);
    final api = FakeApi({
      ...baseRoutes(),
      'GET /student/community/saved': (_) => page([postJson(id: 'saved-1', content: 'Post salvo', saved: true)]),
      'PATCH /student/community/profile': (_) => profileJson(),
      'GET /student/me': (_) => {
        'id': 'me',
        'name': 'Ana Silva',
        'academy': {'name': 'Academia Centro'},
        'ranks': [],
        'classesThisMonth': 0,
        'overdueCount': 0,
        'overdueCents': 0,
        'memberships': [],
        'nextInvoice': null,
      },
      'GET /student/check-ins': (_) => {'items': []},
      'GET /student/classes': (_) => [],
    });
    await tester.pumpWidget(app(await signedIn(api), const StudentShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.text('publicações'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded).last);
    await tester.pumpAndSettle();
    expect(api.count('GET /student/community/saved'), 1);

    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-profile-bio')), 'Guardeiro');
    await tester.tap(find.byKey(const Key('edit-profile-save')));
    await tester.pumpAndSettle();
    expect(api.bodies['PATCH /student/community/profile'], {'bio': 'Guardeiro'});

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Agenda e check-in'), findsOneWidget);
    expect(find.text('Planos e mensalidades'), findsOneWidget);
    await tester.tap(find.text('Minha evolução'));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing, reason: 'Minha evolução abre sem a barra Resumo/Agenda/Planos');
    expect(find.text('Resumo'), findsNothing);
    expect(find.text('Próxima aula'), findsOneWidget);
  });

  testWidgets('perfil do aluno tem atalhos como o do professor: agenda, evolução e mensalidades', (tester) async {
    phoneSize(tester);
    final api = FakeApi({
      ...baseRoutes(),
      'GET /student/community/saved': (_) => page(const []),
      'GET /student/classes': (_) => const [],
      'GET /student/invoices': (_) => const [],
      'GET /student/me': (_) => {
        'id': 'me',
        'name': 'Ana Silva',
        'academy': {'name': 'Academia Centro'},
        'ranks': [],
        'classesThisMonth': 0,
        'overdueCount': 0,
        'overdueCents': 0,
        'memberships': [
          {'plan': {'name': 'Plano Jiu-Jitsu'}},
        ],
        'nextInvoice': null,
      },
    });
    await tester.pumpWidget(app(await signedIn(api), const StudentShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Perfil'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shortcut-schedule')), findsOneWidget);
    expect(find.byKey(const Key('shortcut-evolution')), findsOneWidget);
    expect(find.byKey(const Key('shortcut-plans')), findsOneWidget);

    await tester.tap(find.byKey(const Key('shortcut-schedule')));
    await tester.pumpAndSettle();
    expect(find.text('Agenda e check-in'), findsOneWidget);
    expect(find.text('AGENDA DA SEMANA'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing, reason: 'Agenda abre sem a barra Resumo/Agenda/Planos');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shortcut-plans')));
    await tester.pumpAndSettle();
    expect(find.text('Planos e mensalidades'), findsOneWidget);
    expect(find.text('Plano Jiu-Jitsu'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing, reason: 'sem os botões Resumo/Agenda/Planos no topo');
    expect(find.text('Resumo'), findsNothing);
  });

  testWidgets('pesquisar encontra pessoas da academia', (tester) async {
    phoneSize(tester);
    final api = FakeApi({
      ...baseRoutes(),
      'GET /student/community/explore': (_) => page(const []),
      'GET /student/community/people': (request) => page([
        if ((request.url.queryParameters['search'] ?? '').toLowerCase().startsWith('car'))
          {...author('c1', 'Carla Souza'), 'isMe': false, 'isFollowing': false},
      ]),
    });
    await tester.pumpWidget(app(await signedIn(api), const StudentShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pesquisar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('explore-search')));
    await tester.enterText(find.byKey(const Key('explore-search')), 'Car');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('carla.souza'), findsOneWidget);
    expect(find.text('Seguir'), findsOneWidget);
  });

  testWidgets('notificações agrupam por período e marcam como lidas', (tester) async {
    final api = FakeApi({
      ...baseRoutes(),
      'GET /student/community/notifications': (_) => page([
        {
          'id': 'n1',
          'type': 'FOLLOW',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'read': false,
          'actor': author('c1', 'Carla Souza'),
          'followingActor': false,
          'post': null,
        },
        {
          'id': 'n2',
          'type': 'LIKE',
          'createdAt': DateTime.now().subtract(const Duration(days: 3)).toUtc().toIso8601String(),
          'read': true,
          'actor': author('b1', 'Bruno Lima'),
          'followingActor': true,
          'post': {'id': 'p1', 'kind': 'POST', 'thumbnail': null},
        },
      ]),
      'POST /student/community/notifications/read': (_) => {'updated': 1},
    });
    await tester.pumpWidget(app(await signedIn(api), const NotificationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Últimos 7 dias'), findsOneWidget);
    expect(find.textContaining('começou a seguir você', findRichText: true), findsOneWidget);
    expect(find.textContaining('curtiu sua publicação', findRichText: true), findsOneWidget);
    expect(api.count('POST /student/community/notifications/read'), 1);
  });

  testWidgets('visualizador de flash marca como visto, avança e fecha no fim', (tester) async {
    final api = FakeApi({
      ...baseRoutes(),
      'POST /student/community/stories/s1/view': (_) => {'viewed': true},
      'POST /student/community/stories/s2/view': (_) => {'viewed': true},
    });
    Map<String, Object?> story(String id) => {
      'id': id,
      'media': {'id': 'm-$id', 'kind': 'IMAGE', 'url': '/media/m-$id'},
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'seen': false,
      'caption': id == 's1' ? 'Oss!' : null,
    };
    final groups = [
      StoryGroup.fromJson({
        'author': author('b1', 'Bruno Lima'),
        'isMe': false,
        'hasUnseen': true,
        'stories': [story('s1'), story('s2')],
      }),
    ];
    final session = await signedIn(api);
    await tester.pumpWidget(
      app(
        session,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(builder: (_) => StoryViewerScreen(groups: groups, initialGroup: 0)),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('bruno.lima'), findsOneWidget);
    expect(find.text('Oss!'), findsOneWidget);
    expect(api.count('POST /student/community/stories/s1/view'), 1);

    await tester.pump(const Duration(milliseconds: 5100));
    await tester.pump();
    expect(api.count('POST /student/community/stories/s2/view'), 1);
    expect(find.text('Oss!'), findsNothing);

    await tester.pump(const Duration(milliseconds: 5100));
    await tester.pumpAndSettle();
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('comentários: abre a folha, publica e atualiza o total', (tester) async {
    phoneSize(tester);
    final api = FakeApi({
      ...baseRoutes(posts: [postJson(comments: 0)]),
      'GET /student/community/posts/p1/comments': (_) => page(const []),
      'POST /student/community/posts/p1/comments': (_) => {
        'id': 'c1',
        'postId': 'p1',
        'content': 'Boa, Bruno!',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'author': author('me', 'Ana Silva'),
      },
    });
    await tester.pumpWidget(app(await signedIn(api), const StudentShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Comentar'));
    await tester.pumpAndSettle();
    expect(find.text('Ainda não há comentários'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('comment-input')), 'Boa, Bruno!');
    await tester.tap(find.byKey(const Key('comment-send')));
    await tester.pumpAndSettle();
    expect(find.text('Boa, Bruno!'), findsOneWidget);
    expect(api.bodies['POST /student/community/posts/p1/comments'], {'content': 'Boa, Bruno!'});

    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.text('Ver 1 comentário'), findsOneWidget);
  });

  group('comunidades', () {
    final token = 'ab' * 32;

    Map<String, Object?> community(String id, String name, {bool current = false}) => {
      'id': id,
      'academyId': 'academy-$id',
      'name': name,
      'plans': current ? ['Jiu-Jitsu Adulto'] : <String>[],
      'isCurrent': current,
      'memberCount': current ? 42 : 18,
      'postsThisWeek': current ? 7 : 1,
    };

    Map<String, Handler> communityRoutes({void Function(http.Request)? onAccept}) => {
      ...baseRoutes(),
      'GET /student/communities': (_) => [
        community('me', 'Academia Centro', current: true),
        community('s2', 'Equipe Norte'),
      ],
      'GET /student/community/people': (_) => page([
        {...author('c1', 'Carla Souza'), 'isMe': false, 'isFollowing': false},
        {...author('b1', 'Bruno Lima'), 'isMe': false, 'isFollowing': true},
      ]),
      'POST /student/community/people/c1/follow': (_) => {'following': true},
      'POST /student/communities/invitations/accept': (request) {
        onAccept?.call(request);
        return {'accepted': true, 'academyId': 'a3'};
      },
      'POST /student/communities/s2/switch': (_) => {'accessToken': 'tok-2', 'student': {'id': 's2'}},
    };

    test('lê o código do convite a partir do link ou do código puro', () {
      expect(parseInviteToken('https://app.flenity.com/convite?token=${token.toUpperCase()}&x=1'), token);
      expect(parseInviteToken('  $token  '), token);
      expect(parseInviteToken('convite-seguro'), isNull);
      expect(parseInviteToken('https://app/convite?token=abc'), isNull);
    });

    testWidgets('mostra a academia atual, contadores e sugestões para seguir', (tester) async {
      phoneSize(tester);
      final api = FakeApi(communityRoutes());
      await tester.pumpWidget(app(await signedIn(api), const Scaffold(body: CommunityScreen())));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('current-community-name')), findsOneWidget);
      expect(find.text('Academia Centro'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('publicações na semana'), findsOneWidget);
      expect(find.text('Jiu-Jitsu Adulto'), findsOneWidget);
      expect(find.text('carla.souza'), findsOneWidget);
      expect(find.text('bruno.lima'), findsNothing, reason: 'quem já é seguido não aparece nas sugestões');

      await tester.tap(find.byKey(const ValueKey('suggest-follow-c1')));
      await tester.pumpAndSettle();
      expect(api.count('POST /student/community/people/c1/follow'), 1);
      expect(find.text('Seguindo'), findsOneWidget);
    });

    testWidgets('convite inválido mostra erro sem chamar a API; link válido entra', (tester) async {
      phoneSize(tester);
      Object? sent;
      final api = FakeApi(communityRoutes(onAccept: (request) => sent = jsonDecode(request.body)));
      await tester.pumpWidget(app(await signedIn(api), const Scaffold(body: CommunityScreen())));
      await tester.pumpAndSettle();

      final field = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Link ou código do convite');
      await tester.enterText(field, 'convite-seguro');
      await tester.ensureVisible(find.text('Entrar na comunidade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar na comunidade'));
      await tester.pumpAndSettle();
      expect(find.textContaining('não parece um convite válido'), findsOneWidget);
      expect(api.count('POST /student/communities/invitations/accept'), 0);

      await tester.enterText(field, 'https://app.flenity.com/convite?token=$token');
      await tester.ensureVisible(find.text('Entrar na comunidade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar na comunidade'));
      await tester.pumpAndSettle();
      expect(sent, {'token': token});
      expect(find.text('Você entrou na comunidade!'), findsOneWidget);
    });

    testWidgets('trocar de academia pede confirmação e troca a sessão', (tester) async {
      phoneSize(tester);
      final api = FakeApi(communityRoutes());
      final session = await signedIn(api);
      await tester.pumpWidget(app(session, const Scaffold(body: CommunityScreen())));
      await tester.pumpAndSettle();
      final version = session.studentContextVersion;

      await tester.ensureVisible(find.byKey(const ValueKey('community-s2')));
      await tester.tap(find.byKey(const ValueKey('community-s2')));
      await tester.pumpAndSettle();
      expect(find.text('Trocar para Equipe Norte?'), findsOneWidget);
      expect(api.count('POST /student/communities/s2/switch'), 0);

      await tester.tap(find.byKey(const Key('confirm-switch')));
      await tester.pumpAndSettle();
      expect(api.count('POST /student/communities/s2/switch'), 1);
      expect(session.studentContextVersion, version + 1);
      expect(find.text('Agora você está em Equipe Norte.'), findsOneWidget);
    });

    testWidgets('tocar no @usuário do perfil abre o seletor de academias', (tester) async {
      phoneSize(tester);
      final api = FakeApi({...communityRoutes(), 'GET /student/community/saved': (_) => page(const [])});
      await tester.pumpWidget(app(await signedIn(api), const StudentShell()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-title')));
      await tester.pumpAndSettle();
      expect(find.text('Suas academias'), findsOneWidget);
      expect(find.text('Equipe Norte'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('switch-s2')));
      await tester.pumpAndSettle();
      expect(api.count('POST /student/communities/s2/switch'), 1);
    });
  });

  group('professor', () {
    Map<String, Handler> staffRoutes() => {
      ...baseRoutes(
        posts: [
          postJson(id: 'p-prof', authorId: 'm-prof', authorName: 'Mestre Carlos', content: 'Aula de hoje: passagem de guarda'),
        ],
      ),
      'GET /student/community/people/me': (_) => {
        ...profileJson(id: 'm-prof', name: 'Mestre Carlos'),
        'isStaff': true,
        'roleLabel': 'Professor',
        'belt': null,
      },
      'GET /classes/today': (_) => const [],
    };

    testWidgets('professor usa o feed real, com as mesmas abas do aluno', (tester) async {
      phoneSize(tester);
      final api = FakeApi(staffRoutes());
      api.routes['GET /student/community/posts'] = (request) => page(
        request.url.queryParameters['kind'] == 'REEL'
            ? const []
            : [
                {
                  ...postJson(id: 'p-prof', content: 'Aula de hoje: passagem de guarda'),
                  'author': staffAuthor('m-prof', 'Mestre Carlos'),
                },
              ],
      );
      await tester.pumpWidget(app(await signedInStaff(api), const InstructorShell()));
      await tester.pumpAndSettle();

      expect(find.text('Flenity'), findsOneWidget);
      expect(find.text('Seu flash'), findsOneWidget);
      expect(find.text('Aula de hoje: passagem de guarda'), findsOneWidget);
      expect(find.text('Professor'), findsOneWidget, reason: 'selo ao lado do @ do professor');
      for (final tab in ['Início', 'Pesquisar', 'Criar', 'Rolas', 'Perfil']) {
        expect(find.byTooltip(tab), findsOneWidget);
      }
      expect(api.calls, contains('GET /student/community/posts'));
    });

    testWidgets('perfil do professor tem atalhos para aulas, graduações e alunos', (tester) async {
      phoneSize(tester);
      final api = FakeApi({...staffRoutes(), 'GET /student/community/saved': (_) => page(const [])});
      await tester.pumpWidget(app(await signedInStaff(api), const InstructorShell()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Mestre Carlos'), findsOneWidget);
      expect(find.text('Professor'), findsOneWidget);
      expect(find.byKey(const Key('profile-title')), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing, reason: 'professor não troca de academia');

      await tester.tap(find.byKey(const Key('shortcut-classes')));
      await tester.pumpAndSettle();
      expect(find.text('Aulas de hoje'), findsWidgets);
      expect(api.calls, contains('GET /classes/today'));
    });

    testWidgets('menu do professor: só administrador vê "Adicionar professor"', (tester) async {
      phoneSize(tester);
      final api = FakeApi({...staffRoutes(), 'GET /student/community/saved': (_) => page(const [])});
      await tester.pumpWidget(app(await signedInStaff(api), const InstructorShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Aulas de hoje e chamada'), findsOneWidget);
      expect(find.text('Quem está apto a graduar'), findsOneWidget);
      expect(find.text('Adicionar professor'), findsNothing);
      expect(find.text('Minha academia'), findsNothing);
    });

    testWidgets('administrador cria acesso de professor pelo menu do perfil', (tester) async {
      phoneSize(tester);
      final api = FakeApi({
        ...staffRoutes(),
        'GET /student/community/saved': (_) => page(const []),
        'POST /users': (request) => {'id': 'teacher-1', ...jsonDecode(request.body) as Map<String, dynamic>},
      });
      await tester.pumpWidget(app(await signedInStaff(api, role: 'ADMIN', name: 'Ana Admin'), const InstructorShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar professor'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('instructor-name')), 'Carlos Professor');
      await tester.enterText(find.byKey(const Key('instructor-email')), 'carlos@flenity.com');
      await tester.enterText(find.byKey(const Key('instructor-password')), 'senha-inicial');
      await tester.tap(find.text('Criar acesso'));
      await tester.pumpAndSettle();

      expect(api.bodies['POST /users'], {
        'name': 'Carlos Professor',
        'email': 'carlos@flenity.com',
        'password': 'senha-inicial',
        'role': 'INSTRUCTOR',
      });
      expect(find.text('Acesso de professor criado.'), findsOneWidget);
    });
  });
}
