import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../social/widgets/social_ui.dart';
import '../../ui/widgets/common.dart';
import '../tracks_api.dart';
import '../tracks_models.dart';
import '../widgets/track_tiles.dart';
import 'lesson_editor_screen.dart';

/// Professor monta a trilha de cada faixa e decide o que fica liberado para os alunos.
class StaffTracksScreen extends StatefulWidget {
  const StaffTracksScreen({super.key});

  @override
  State<StaffTracksScreen> createState() => StaffTracksScreenState();
}

class StaffTracksScreenState extends State<StaffTracksScreen> {
  StaffTrack? _track;
  Object? _error;
  String? _beltId;
  bool _busy = false;

  TracksApi get _api => TracksApi(context.read<Session>().api);

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final track = await _api.staffTrack(beltId: _beltId);
      if (!mounted) return;
      setState(() {
        _track = track;
        _beltId = track.belt?.id;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// Executa uma ação, mostra a mensagem (fixa ou devolvida pela ação) e recarrega a trilha.
  Future<void> _run(Future<Object?> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      final message = success ?? (result is String ? result : null);
      if (mounted && message != null) showMessage(context, message);
      await reload();
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectBelt(TrackBelt belt) {
    if (belt.id == _beltId) return;
    setState(() => _beltId = belt.id);
    reload();
  }

  Future<void> _edit({TrackLesson? lesson, TrackCategory? category}) async {
    final belt = _track?.belt;
    if (belt == null) return;
    final saved = await Navigator.of(context).push<TrackLesson>(
      MaterialPageRoute(
        fullscreenDialog: lesson == null,
        builder: (_) => LessonEditorScreen(api: _api, belt: belt, lesson: lesson, initialCategory: category),
      ),
    );
    if (saved == null || !mounted) return;
    showMessage(context, saved.published ? 'Conceito salvo e liberado.' : 'Conceito salvo como rascunho.');
    reload();
  }

  Future<void> _togglePublished(TrackLesson lesson, bool published) async {
    if (published && !(lesson.media?.isVideo ?? false)) {
      showMessage(context, 'Envie o vídeo de "${lesson.title}" antes de liberar.', error: true);
      return _edit(lesson: lesson);
    }
    return _run(
      () => _api.updateLesson(lesson.id, published: published),
      success: published ? '"${lesson.title}" liberado para os alunos.' : '"${lesson.title}" voltou para rascunho.',
    );
  }

  Future<void> _delete(TrackLesson lesson) async {
    final ok = await confirmDialog(
      context,
      'Apagar conceito',
      'Apagar "${lesson.title}"? O progresso dos alunos nele também é apagado.',
      confirm: 'Apagar',
    );
    if (ok) await _run(() => _api.deleteLesson(lesson.id), success: 'Conceito apagado.');
  }

  Future<void> _publishAll(bool published, {TrackCategory? category}) {
    final belt = _track!.belt!;
    final scope = category == null ? 'da ${belt.title}' : 'de ${category.label}';
    return _run(() async {
      final result = await _api.publishAll(belt.id, published: published, category: category);
      if (!published) return 'Conceitos $scope recolhidos para rascunho.';
      final released = '${result.updated} ${result.updated == 1 ? 'videoaula liberada' : 'videoaulas liberadas'}';
      return result.withoutVideo == 0
          ? '$released $scope.'
          : '$released. ${result.withoutVideo} sem vídeo ${result.withoutVideo == 1 ? 'ficou' : 'ficaram'} em rascunho.';
    });
  }

  Future<void> _importStarter() => _run(
    () => _api.importStarter(_track!.belt!.id),
    success: 'Trilha sugerida adicionada como rascunho. Grave os vídeos e libere quando quiser.',
  );

  @override
  Widget build(BuildContext context) {
    final track = _track;
    if (track == null) {
      return ColoredBox(
        color: SocialColors.bg,
        child: _error != null
            ? ErrorView(message: errorText(_error), onRetry: reload)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final belt = track.belt;
    if (belt == null) {
      return const ColoredBox(
        color: SocialColors.bg,
        child: TrackEmpty(
          title: 'Sem faixas',
          message: 'Cadastre as faixas da modalidade no painel para montar as trilhas.',
        ),
      );
    }
    final summary = track.belts.firstWhere((item) => item.id == belt.id, orElse: () => belt);
    final empty = track.sections.every((section) => section.lessons.isEmpty);
    return Scaffold(
      backgroundColor: SocialColors.bg,
      floatingActionButton: empty
          ? null
          : FloatingActionButton.extended(
              key: const Key('new-lesson'),
              heroTag: 'new-lesson',
              backgroundColor: SocialColors.ink,
              foregroundColor: Colors.white,
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Conceito'),
            ),
      body: RefreshIndicator(
        onRefresh: reload,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  TrackHeader(
                    belt: belt,
                    subtitle:
                        '${summary.publishedCount} de ${summary.lessonCount} liberados · '
                        '${summary.studentCount} ${summary.studentCount == 1 ? 'aluno' : 'alunos'} nesta faixa',
                  ),
                  if (!empty) Positioned(top: 4, right: 4, child: _beltMenu()),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: BeltSelector(
                belts: track.belts,
                selectedId: belt.id,
                onSelected: _selectBelt,
                caption: (item) =>
                    item.lessonCount == 0 ? 'Vazia' : '${item.publishedCount}/${item.lessonCount} liberados',
              ),
            ),
            if (_busy) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
            if (empty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: TrackEmpty(
                  title: 'Monte a trilha da ${belt.title}',
                  message:
                      'Grave as videoaulas do que o aluno precisa aprender em Guarda, Passagem, Controle e Finalizações. '
                      'Comece pela nossa lista sugerida: só aparece para os alunos o que tiver vídeo e for liberado.',
                  actions: [
                    FilledButton.icon(
                      key: const Key('import-starter'),
                      onPressed: _busy ? null : _importStarter,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Usar trilha sugerida'),
                    ),
                    OutlinedButton(onPressed: () => _edit(), child: const Text('Criar do zero')),
                  ],
                ),
              )
            else ...[
              for (final section in track.sections) ..._section(section),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _beltMenu() => PopupMenuButton<bool>(
    key: const Key('belt-menu'),
    tooltip: 'Liberar ou recolher a faixa',
    icon: const Icon(Icons.more_horiz_rounded, color: SocialColors.ink),
    onSelected: (published) => _publishAll(published),
    itemBuilder: (_) => const [
      PopupMenuItem(value: true, child: Text('Liberar tudo desta faixa')),
      PopupMenuItem(value: false, child: Text('Recolher tudo (rascunho)')),
    ],
  );

  List<Widget> _section(TrackSection section) {
    final published = section.lessons.where((lesson) => lesson.published).length;
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          category: section.category,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$published/${section.lessons.length}',
                style: const TextStyle(color: SocialColors.ink2, fontWeight: FontWeight.w700),
              ),
              PopupMenuButton<String>(
                key: Key('section-menu-${section.category.apiName}'),
                icon: const Icon(Icons.more_vert_rounded, color: SocialColors.ink2),
                onSelected: (value) => switch (value) {
                  'add' => _edit(category: section.category),
                  'publish' => _publishAll(true, category: section.category),
                  _ => _publishAll(false, category: section.category),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'add', child: Text('Adicionar conceito')),
                  if (section.lessons.isNotEmpty) ...[
                    PopupMenuItem(value: 'publish', child: Text('Liberar ${section.category.label}')),
                    PopupMenuItem(value: 'hide', child: Text('Recolher ${section.category.label}')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      if (section.lessons.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: OutlinedButton.icon(
              onPressed: () => _edit(category: section.category),
              icon: const Icon(Icons.add_rounded),
              label: Text('Adicionar em ${section.category.label}'),
            ),
          ),
        )
      else
        SliverList.list(
          children: [
            for (var i = 0; i < section.lessons.length; i++)
              _lessonTile(section.lessons[i], first: i == 0, last: i == section.lessons.length - 1),
          ],
        ),
    ];
  }

  Widget _lessonTile(TrackLesson lesson, {required bool first, required bool last}) => LessonTile(
    key: Key('lesson-${lesson.id}'),
    lesson: lesson,
    beltColor: _track?.belt?.color ?? Colors.white,
    dimmed: !lesson.published,
    onTap: () => _edit(lesson: lesson),
    leading: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Switch(
        key: Key('publish-${lesson.id}'),
        value: lesson.published,
        onChanged: _busy ? null : (value) => _togglePublished(lesson, value),
      ),
    ),
    trailing: PopupMenuButton<String>(
      key: Key('lesson-menu-${lesson.id}'),
      icon: const Icon(Icons.more_vert_rounded, color: SocialColors.ink2),
      onSelected: (value) => switch (value) {
        'edit' => _edit(lesson: lesson),
        'up' => _run(() => _api.moveLesson(lesson.id, up: true)),
        'down' => _run(() => _api.moveLesson(lesson.id, up: false)),
        _ => _delete(lesson),
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Editar')),
        if (!first) const PopupMenuItem(value: 'up', child: Text('Mover para cima')),
        if (!last) const PopupMenuItem(value: 'down', child: Text('Mover para baixo')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Apagar', style: TextStyle(color: SocialColors.like)),
        ),
      ],
    ),
  );
}
