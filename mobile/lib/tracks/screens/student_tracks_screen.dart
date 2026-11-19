import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../social/widgets/social_ui.dart';
import '../../ui/widgets/common.dart';
import '../tracks_api.dart';
import '../tracks_models.dart';
import '../widgets/track_tiles.dart';
import 'lesson_screen.dart';

/// "Descomplicando a Faixa X": o que o aluno precisa aprender na faixa dele, liberado pelo professor.
class StudentTracksScreen extends StatefulWidget {
  const StudentTracksScreen({super.key, this.onBeltLoaded});

  /// Avisa o app da faixa atual (nome e cor da aba).
  final ValueChanged<TrackBelt>? onBeltLoaded;

  @override
  State<StudentTracksScreen> createState() => StudentTracksScreenState();
}

class StudentTracksScreenState extends State<StudentTracksScreen> {
  StudentTrack? _track;
  Object? _error;
  String? _beltId;
  final _sectionKeys = {for (final category in TrackCategory.values) category: GlobalKey()};

  TracksApi get _api => TracksApi(context.read<Session>().api);

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final track = await _api.studentTrack(beltId: _beltId);
      if (!mounted) return;
      setState(() {
        _track = track;
        _error = null;
      });
      widget.onBeltLoaded?.call(track.current);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _selectBelt(TrackBelt belt) {
    if (belt.id == _track?.belt.id) return;
    _beltId = belt.current ? null : belt.id;
    reload();
  }

  Future<bool> _setCompleted(TrackLesson lesson, bool completed) async {
    try {
      await _api.setCompleted(lesson.id, completed);
      if (mounted) {
        if (completed) showMessage(context, 'Boa! "${lesson.title}" marcado como aprendido.');
        reload();
      }
      return completed;
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
      return !completed;
    }
  }

  Future<void> _open(TrackLesson lesson) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LessonScreen(
        lesson: lesson,
        beltTitle: _track!.belt.title,
        beltColor: _track!.belt.color,
        onCompletedChanged: (completed) => _setCompleted(lesson, completed),
      ),
    ),
  );

  void _jumpTo(TrackCategory category) {
    final target = _sectionKeys[category]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

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
    final empty = track.sections.every((section) => section.lessons.isEmpty);
    return ColoredBox(
      color: SocialColors.bg,
      child: RefreshIndicator(
        onRefresh: reload,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: TrackHeader(
                belt: track.belt,
                degree: track.belt.id == track.current.id ? track.current.degree : 0,
                progress: track.progress,
              ),
            ),
            if (track.belts.length > 1)
              SliverToBoxAdapter(
                child: BeltSelector(
                  belts: track.belts,
                  selectedId: track.belt.id,
                  onSelected: _selectBelt,
                  caption: (belt) => belt.current ? 'Atual' : '${belt.progress.percent}%',
                ),
              ),
            if (empty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: TrackEmpty(
                  title: 'Em breve',
                  message: 'Seu professor ainda não liberou as videoaulas da ${track.belt.title}. Fique de olho!',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: CategoryGrid(sections: track.sections, onTap: _jumpTo),
                ),
              ),
              for (final section in track.sections)
                if (section.lessons.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      key: _sectionKeys[section.category],
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          category: section.category,
                          trailing: Text(
                            '${section.progress.completed}/${section.progress.total}',
                            style: const TextStyle(color: SocialColors.ink2, fontWeight: FontWeight.w700),
                          ),
                        ),
                        for (final lesson in section.lessons)
                          LessonTile(
                            key: Key('lesson-${lesson.id}'),
                            lesson: lesson,
                            beltColor: track.belt.color,
                            onTap: () => _open(lesson),
                            leading: IconButton(
                              key: Key('complete-${lesson.id}'),
                              tooltip: lesson.completed ? 'Desmarcar' : 'Marcar como aprendido',
                              onPressed: () => _setCompleted(lesson, !lesson.completed),
                              icon: Icon(
                                lesson.completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: lesson.completed ? const Color(0xFF16A34A) : SocialColors.ink2,
                                size: 28,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }
}
