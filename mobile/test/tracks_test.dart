import 'dart:typed_data';

import 'package:flenity_combate/screens/instructor/instructor_shell.dart';
import 'package:flenity_combate/screens/student/student_shell.dart';
import 'package:flenity_combate/social/media_picker.dart';
import 'package:flenity_combate/tracks/tracks_models.dart';
import 'package:flenity_combate/tracks/widgets/lesson_video_player.dart';
import 'package:flenity_combate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'social_test.dart' show FakeApi, FakePicker, Handler, app, baseRoutes, phoneSize, signedIn, signedInStaff;

Map<String, Object?> beltJson(
  String id,
  String name,
  String color,
  int order, {
  Map<String, Object?> extra = const {},
}) => {'id': id, 'name': name, 'title': 'Faixa $name', 'color': color, 'order': order, ...extra};

Map<String, Object?> lessonJson(
  String id,
  String category, {
  String beltId = 'blue',
  bool completed = false,
  bool published = true,
  bool video = true,
  String? title,
}) => {
  'id': id,
  'beltId': beltId,
  'category': category,
  'title': title ?? 'Conceito $id',
  'description': 'Explicação de $id',
  'position': 0,
  'published': published,
  'updatedAt': '2026-11-18T12:00:00.000Z',
  'media': video ? {'id': 'v-$id', 'kind': 'VIDEO', 'url': '/media/v-$id?exp=1&sig=a'} : null,
  'completed': completed,
};

List<Map<String, Object?>> categoriesJson(List<Map<String, Object?>> lessons, {bool withProgress = true}) => [
  for (final (key, label) in [
    ('GUARD', 'Guarda'),
    ('PASS', 'Passagem'),
    ('CONTROL', 'Controle'),
    ('SUBMISSION', 'Finalizações'),
  ])
    {
      'key': key,
      'label': label,
      'lessons': lessons.where((lesson) => lesson['category'] == key).toList(),
      if (withProgress)
        'progress': {
          'completed': lessons.where((l) => l['category'] == key && l['completed'] == true).length,
          'total': lessons.where((l) => l['category'] == key).length,
          'percent': 0,
        },
    },
];

/// Aluno faixa azul com a branca liberada para revisão.
Map<String, Object?> studentTrackJson({String? beltId, List<Map<String, Object?>>? lessons}) {
  final white = beltJson('white', 'Branca', '#f5f5f5', 0);
  final blue = beltJson('blue', 'Azul', '#1e5bd6', 1);
  final selected = beltId == 'white' ? white : blue;
  final items =
      lessons ??
      (beltId == 'white'
          ? [lessonJson('w1', 'GUARD', beltId: 'white', completed: true, title: 'Fuga de quadril')]
          : [
              lessonJson('b1', 'GUARD', title: 'Meia-guarda'),
              lessonJson('b2', 'SUBMISSION', completed: true, title: 'Triângulo'),
            ]);
  return {
    'current': {...blue, 'degree': 2},
    'belts': [
      {
        ...white,
        'current': false,
        'progress': {'completed': 1, 'total': 1, 'percent': 100},
      },
      {
        ...blue,
        'current': true,
        'progress': {'completed': 1, 'total': 2, 'percent': 50},
      },
    ],
    'belt': selected,
    'progress': {'completed': 1, 'total': items.length, 'percent': 50},
    'categories': categoriesJson(items),
  };
}

Map<String, Object?> staffTrackJson({List<Map<String, Object?>> lessons = const []}) => {
  'belts': [
    beltJson(
      'white',
      'Branca',
      '#f5f5f5',
      0,
      extra: {
        'lessonCount': lessons.length,
        'publishedCount': lessons.where((l) => l['published'] == true).length,
        'studentCount': 12,
      },
    ),
    beltJson('blue', 'Azul', '#1e5bd6', 1, extra: {'lessonCount': 0, 'publishedCount': 0, 'studentCount': 5}),
  ],
  'belt': beltJson('white', 'Branca', '#f5f5f5', 0),
  'categories': categoriesJson(lessons, withProgress: false),
};

Map<String, Handler> staffBase() => {
  ...baseRoutes(),
  'GET /student/community/people/me': (_) => {
    'id': 'm-prof',
    'name': 'Mestre Carlos',
    'avatarUrl': null,
    'isStaff': true,
    'roleLabel': 'Professor',
    'handle': 'mestre.carlos',
    'bio': null,
    'academyName': 'Academia Centro',
    'counts': {'posts': 0, 'followers': 0, 'following': 0},
    'isMe': true,
    'isFollowing': false,
    'followsMe': false,
    'belt': null,
  },
};

void main() {
  setUpAll(() => appUseGoogleFonts = false);

  group('modelos', () {
    test('lê categorias, cor e título da trilha', () {
      expect(TrackCategory.fromApi('SUBMISSION').label, 'Finalizações');
      expect(TrackCategory.fromApi('???'), TrackCategory.guard);
      expect(parseBeltColor('#1e5bd6'), const Color(0xFF1E5BD6));
      expect(parseBeltColor('xyz'), const Color(0xFFF5F5F5));
      expect(formatVideoTime(const Duration(seconds: 75)), '1:15');
      expect(formatVideoTime(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(tracksTitle('Faixa Branca'), 'Descomplicando a Faixa Branca');

      final track = StudentTrack.fromJson(studentTrackJson());
      expect(track.current.degree, 2);
      expect(track.sections.map((s) => s.category.label), ['Guarda', 'Passagem', 'Controle', 'Finalizações']);
      expect(track.sections.last.lessons.single.completed, isTrue);
    });
  });

  group('aluno', () {
    testWidgets('a aba fica entre Rolas e Perfil com o nome da faixa e mostra a trilha', (tester) async {
      phoneSize(tester);
      final api = FakeApi({
        ...baseRoutes(),
        'GET /student/tracks': (request) => studentTrackJson(beltId: request.url.queryParameters['beltId']),
        'POST /student/tracks/lessons/b1/complete': (_) => {'completed': true},
      });
      await tester.pumpWidget(app(await signedIn(api), const StudentShell()));
      await tester.pumpAndSettle();

      final tabs = [
        'Início',
        'Pesquisar',
        'Criar',
        'Rolas',
        'Faixa Azul',
        'Perfil',
      ].map((label) => tester.getCenter(find.byTooltip(label)).dx).toList();
      expect(tabs, orderedEquals([...tabs]..sort()), reason: 'nova aba entre Rolas e Perfil');

      await tester.tap(find.byKey(const Key('tab-tracks')));
      await tester.pumpAndSettle();

      expect(find.text('DESCOMPLICANDO'), findsOneWidget);
      expect(find.text('a Faixa Azul'), findsOneWidget);
      expect(find.text('1 de 2 conceitos aprendidos'), findsOneWidget);
      for (final label in ['Guarda', 'Passagem', 'Controle', 'Finalizações']) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('Meia-guarda'), findsOneWidget);

      await tester.tap(find.byKey(const Key('complete-b1')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /student/tracks/lessons/b1/complete'));

      // Revisão da faixa anterior.
      await tester.tap(find.byKey(const Key('belt-white')));
      await tester.pumpAndSettle();
      expect(find.text('a Faixa Branca'), findsOneWidget);
      expect(find.text('Fuga de quadril'), findsOneWidget);
    });

    testWidgets('abre o conceito e marca como aprendido', (tester) async {
      phoneSize(tester);
      final api = FakeApi({
        ...baseRoutes(),
        'GET /student/tracks': (_) => studentTrackJson(),
        'POST /student/tracks/lessons/b1/complete': (_) => {'completed': true},
      });
      await tester.pumpWidget(app(await signedIn(api), const StudentShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-tracks')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Meia-guarda'));
      await tester.pumpAndSettle();
      expect(find.text('FAIXA AZUL · GUARDA'), findsOneWidget);
      expect(find.text('Explicação de b1'), findsOneWidget);
      final player = tester.widget<LessonVideoPlayer>(find.byType(LessonVideoPlayer));
      expect(player.url.toString(), 'http://api/media/v-b1?exp=1&sig=a', reason: 'toca o vídeo pela URL assinada');

      await tester.tap(find.byKey(const Key('lesson-complete')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /student/tracks/lessons/b1/complete'));
      expect(find.text('Aprendido · desfazer'), findsOneWidget);
    });

    testWidgets('sem conceitos liberados mostra aviso', (tester) async {
      phoneSize(tester);
      final api = FakeApi({...baseRoutes(), 'GET /student/tracks': (_) => studentTrackJson(lessons: const [])});
      await tester.pumpWidget(app(await signedIn(api), const StudentShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-tracks')));
      await tester.pumpAndSettle();

      expect(find.textContaining('ainda não liberou as videoaulas da Faixa Azul'), findsOneWidget);
    });
  });

  group('professor', () {
    testWidgets('faixa vazia: importa a trilha sugerida e libera um conceito', (tester) async {
      phoneSize(tester);
      var lessons = <Map<String, Object?>>[];
      final api = FakeApi({
        ...staffBase(),
        'GET /tracks': (_) => staffTrackJson(lessons: lessons),
        'POST /tracks/starter': (_) {
          lessons = [
            lessonJson('g1', 'GUARD', beltId: 'white', published: false, video: false, title: 'Guarda fechada'),
            lessonJson('g2', 'GUARD', beltId: 'white', published: false, title: 'Raspagem de tesoura'),
          ];
          return {'created': 1};
        },
        'PATCH /tracks/lessons/g2': (_) => lessonJson('g2', 'GUARD', beltId: 'white', title: 'Raspagem de tesoura'),
        'POST /tracks/publish': (_) => {'updated': 1, 'withoutVideo': 1},
      });
      await tester.pumpWidget(app(await signedInStaff(api), const InstructorShell()));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Descomplicando'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tab-tracks')));
      await tester.pumpAndSettle();

      expect(find.text('Monte a trilha da Faixa Branca'), findsOneWidget);
      expect(find.textContaining('12 alunos nesta faixa'), findsOneWidget);
      await tester.tap(find.byKey(const Key('import-starter')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /tracks/starter'));
      expect(api.bodies['POST /tracks/starter'], {'beltId': 'white'});
      expect(find.text('Guarda fechada'), findsOneWidget);

      // Sem vídeo não libera: avisa e abre o editor para enviar o vídeo.
      await tester.tap(find.byKey(const Key('publish-g1')));
      await tester.pumpAndSettle();
      expect(find.text('Envie o vídeo de "Guarda fechada" antes de liberar.'), findsOneWidget);
      expect(api.calls, isNot(contains('PATCH /tracks/lessons/g1')));
      expect(find.text('Editar conceito'), findsOneWidget);
      expect(find.text('Sem vídeo ainda'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('publish-g2')));
      await tester.pumpAndSettle();
      expect(api.bodies['PATCH /tracks/lessons/g2'], {'published': true});

      await tester.tap(find.byKey(const Key('belt-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Liberar tudo desta faixa'));
      await tester.pumpAndSettle();
      expect(find.text('1 videoaula liberada. 1 sem vídeo ficou em rascunho.'), findsOneWidget);
    });

    testWidgets('cria videoaula gravando pela câmera e já libera', (tester) async {
      phoneSize(tester);
      final api = FakeApi({
        ...staffBase(),
        'GET /tracks': (_) => staffTrackJson(lessons: [lessonJson('g1', 'GUARD', beltId: 'white')]),
        'POST /student/community/media': (_) => {'id': 'media-1', 'kind': 'VIDEO', 'url': '/media/media-1'},
        'POST /tracks/lessons': (_) => lessonJson('new', 'SUBMISSION', beltId: 'white'),
      });
      await tester.pumpWidget(app(await signedInStaff(api), const InstructorShell(), picker: VideoPicker()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-tracks')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('new-lesson')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-category-SUBMISSION')));
      await tester.enterText(find.byKey(const Key('lesson-title')), 'Armlock da guarda');
      await tester.enterText(find.byKey(const Key('lesson-description')), 'Gire o quadril.');
      await tester.tap(find.byKey(const Key('lesson-video-record')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Vídeo pronto para enviar'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('lesson-published')));
      await tester.tap(find.byKey(const Key('lesson-published')));
      await tester.tap(find.byKey(const Key('lesson-save')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('POST /student/community/media'));
      expect(api.bodies['POST /tracks/lessons'], {
        'beltId': 'white',
        'category': 'SUBMISSION',
        'title': 'Armlock da guarda',
        'description': 'Gire o quadril.',
        'mediaId': 'media-1',
        'published': true,
      });
      expect(find.text('Conceito salvo e liberado.'), findsOneWidget);
    });

    testWidgets('editor recusa foto e não libera sem vídeo', (tester) async {
      phoneSize(tester);
      final api = FakeApi({
        ...staffBase(),
        'GET /tracks': (_) => staffTrackJson(lessons: [lessonJson('g1', 'GUARD', beltId: 'white')]),
      });
      await tester.pumpWidget(app(await signedInStaff(api), const InstructorShell(), picker: FakePicker()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-tracks')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new-lesson')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('lesson-title')), 'Mata-leão');
      await tester.tap(find.byKey(const Key('lesson-video-gallery')));
      await tester.pumpAndSettle();
      expect(find.text('Escolha um vídeo: o conteúdo da trilha é em vídeo.'), findsOneWidget);
      expect(find.text('Sem vídeo ainda'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // aviso some
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('lesson-published')));
      await tester.tap(find.byKey(const Key('lesson-published')));
      await tester.tap(find.byKey(const Key('lesson-save')));
      await tester.pumpAndSettle();
      expect(find.text('Envie o vídeo da aula antes de liberar para os alunos.'), findsOneWidget);
      expect(api.calls, isNot(contains('POST /tracks/lessons')));
    });

    testWidgets('recepção não vê a aba de trilhas', (tester) async {
      phoneSize(tester);
      final api = FakeApi(staffBase());
      await tester.pumpWidget(app(await signedInStaff(api, role: 'RECEPTION'), const InstructorShell()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tab-tracks')), findsNothing);
      expect(api.calls, isNot(contains('GET /tracks')));
    });
  });
}

/// Câmera/galeria falsa que devolve um vídeo.
class VideoPicker extends FakePicker {
  VideoPicker() {
    picks
      ..clear()
      ..add(PickedMedia(bytes: Uint8List.fromList(List.filled(2048, 1)), name: 'aula.mp4', isVideo: true));
  }
}
