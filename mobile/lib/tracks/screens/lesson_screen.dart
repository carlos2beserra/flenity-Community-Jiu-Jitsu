import 'package:flutter/material.dart';

import '../../social/widgets/social_ui.dart';
import '../../ui/widgets/common.dart';
import '../tracks_models.dart';
import '../widgets/lesson_video_player.dart';
import '../widgets/track_tiles.dart';

/// Videoaula de um conceito: vídeo, explicação e, para o aluno, "Marcar como aprendido".
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.lesson,
    required this.beltTitle,
    this.beltColor = Colors.white,
    this.onCompletedChanged,
    this.controllerFactory = networkVideo,
  });

  final TrackLesson lesson;
  final String beltTitle;
  final Color beltColor;
  final VideoControllerFactory controllerFactory;

  /// Só o aluno marca como aprendido. Retorna o novo estado confirmado pelo servidor.
  final Future<bool> Function(bool completed)? onCompletedChanged;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late bool _completed = widget.lesson.completed;
  bool _saving = false;

  Future<void> _toggle() async {
    setState(() => _saving = true);
    try {
      final next = await widget.onCompletedChanged!(!_completed);
      if (mounted) setState(() => _completed = next);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onVideoFinished() {
    if (widget.onCompletedChanged == null || _completed || !mounted) return;
    showMessage(context, 'Fim da aula! Quando dominar a técnica, marque como aprendido.');
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final video = lesson.media;
    return Scaffold(
      backgroundColor: SocialColors.bg,
      appBar: AppBar(
        backgroundColor: SocialColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(lesson.category.label, style: socialTitleStyle.copyWith(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: video != null && video.isVideo
                ? LessonVideoPlayer(
                    url: Uri.parse(socialApiOf(context).mediaUrl(video.url)),
                    onFinished: _onVideoFinished,
                    controllerFactory: widget.controllerFactory,
                  )
                : VideoComingSoon(color: widget.beltColor, category: lesson.category),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.beltTitle.toUpperCase()} · ${lesson.category.label.toUpperCase()}',
                  style: const TextStyle(
                    color: SocialColors.ink2,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(lesson.title, style: socialTitleStyle.copyWith(fontSize: 24)),
                const SizedBox(height: 14),
                Text(
                  (lesson.description ?? '').isEmpty
                      ? 'O professor vai explicar este conceito no tatame.'
                      : lesson.description!,
                  style: const TextStyle(fontSize: 16, height: 1.5, color: SocialColors.ink),
                ),
                if (widget.onCompletedChanged != null) ...[
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _completed
                        ? OutlinedButton.icon(
                            key: const Key('lesson-complete'),
                            onPressed: _saving ? null : _toggle,
                            icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
                            label: const Text('Aprendido · desfazer'),
                          )
                        : FilledButton.icon(
                            key: const Key('lesson-complete'),
                            onPressed: _saving ? null : _toggle,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Marcar como aprendido'),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
