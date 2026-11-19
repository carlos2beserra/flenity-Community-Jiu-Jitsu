import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../social/media_picker.dart';
import '../../social/social_models.dart';
import '../../social/widgets/social_ui.dart';
import '../../ui/widgets/common.dart';
import '../tracks_api.dart';
import '../tracks_models.dart';
import '../widgets/track_tiles.dart';

/// Mesmo limite da API para vídeos (60 MB).
const maxLessonVideoBytes = 60 * 1024 * 1024;

/// Professor cria ou edita uma videoaula da trilha: categoria, título, vídeo, explicação e liberação.
class LessonEditorScreen extends StatefulWidget {
  const LessonEditorScreen({super.key, required this.api, required this.belt, this.lesson, this.initialCategory});

  final TracksApi api;
  final TrackBelt belt;
  final TrackLesson? lesson;
  final TrackCategory? initialCategory;

  @override
  State<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends State<LessonEditorScreen> {
  late final _title = TextEditingController(text: widget.lesson?.title);
  late final _description = TextEditingController(text: widget.lesson?.description);
  late TrackCategory _category = widget.lesson?.category ?? widget.initialCategory ?? TrackCategory.guard;
  late bool _published = widget.lesson?.published ?? false;
  late SocialMedia? _currentMedia = widget.lesson?.media;
  PickedMedia? _newMedia;
  bool _saving = false;
  String? _status;

  bool get _editing => widget.lesson != null;

  MediaPickerService get _picker => Provider.of<MediaPickerService?>(context, listen: false) ?? DeviceMediaPicker();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  /// A trilha é feita de videoaulas: escolhe um vídeo da galeria ou grava na hora.
  Future<void> _pickVideo({required bool record}) async {
    final PickedMedia? picked;
    try {
      picked = record
          ? await _picker.capture(video: true)
          : (await _picker.pickFromGallery(multiple: false, allowVideo: true, videoOnly: true)).firstOrNull;
    } catch (error) {
      if (mounted) showMessage(context, 'Não foi possível abrir ${record ? 'a câmera' : 'a galeria'}.', error: true);
      debugPrint('Falha ao escolher vídeo: $error');
      return;
    }
    if (picked == null || !mounted) return;
    if (!picked.isVideo) {
      showMessage(context, 'Escolha um vídeo: o conteúdo da trilha é em vídeo.', error: true);
      return;
    }
    if (picked.bytes.length > maxLessonVideoBytes) {
      showMessage(context, 'O vídeo passa de 60 MB. Grave um trecho menor ou com qualidade mais baixa.', error: true);
      return;
    }
    setState(() => _newMedia = picked);
  }

  void _removeMedia() => setState(() {
    _newMedia = null;
    _currentMedia = null;
  });

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 2) {
      showMessage(context, 'Dê um nome ao conceito.', error: true);
      return;
    }
    if (_published && _newMedia == null && !(_currentMedia?.isVideo ?? false)) {
      showMessage(context, 'Envie o vídeo da aula antes de liberar para os alunos.', error: true);
      return;
    }
    final social = socialApiOf(context);
    setState(() => _saving = true);
    try {
      String? mediaId;
      if (_newMedia != null) {
        setState(() => _status = 'Enviando vídeo…');
        mediaId = (await social.upload(_newMedia!.bytes, _newMedia!.name)).id;
      }
      setState(() => _status = 'Salvando…');
      final description = _description.text.trim();
      final TrackLesson saved;
      if (_editing) {
        saved = await widget.api.updateLesson(
          widget.lesson!.id,
          category: _category,
          title: title,
          description: description,
          mediaId: mediaId,
          removeMedia: _currentMedia == null && widget.lesson!.media != null && mediaId == null,
          published: _published,
        );
      } else {
        saved = await widget.api.createLesson(
          beltId: widget.belt.id,
          category: _category,
          title: title,
          description: description,
          mediaId: mediaId,
          published: _published,
        );
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SocialColors.bg,
    appBar: AppBar(
      backgroundColor: SocialColors.bg,
      surfaceTintColor: Colors.transparent,
      title: Text(_editing ? 'Editar conceito' : 'Novo conceito', style: socialTitleStyle.copyWith(fontSize: 18)),
      actions: [
        TextButton(
          key: const Key('lesson-save'),
          onPressed: _saving ? null : _save,
          child: Text(_status ?? 'Salvar', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.belt.title,
          style: const TextStyle(color: SocialColors.ink2, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in TrackCategory.values)
              ChoiceChip(
                key: Key('editor-category-${category.apiName}'),
                avatar: Icon(category.icon, size: 18),
                label: Text(category.label),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('lesson-title'),
          controller: _title,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome do conceito', hintText: 'Ex.: Raspagem de tesoura'),
        ),
        const SizedBox(height: 4),
        _mediaCard(),
        const SizedBox(height: 16),
        TextField(
          key: const Key('lesson-description'),
          controller: _description,
          maxLength: 4000,
          minLines: 4,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Resumo da aula (opcional)',
            hintText: 'Pontos-chave do vídeo, detalhes e erros comuns',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          key: const Key('lesson-published'),
          contentPadding: EdgeInsets.zero,
          value: _published,
          onChanged: (value) => setState(() => _published = value),
          title: const Text('Liberado para os alunos', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            _published
                ? 'Alunos da ${widget.belt.title} (e das faixas acima) já veem este conceito.'
                : 'Rascunho: só a equipe vê até você liberar. Para liberar, envie o vídeo.',
          ),
        ),
      ],
    ),
  );

  Widget _mediaCard() {
    final picked = _newMedia;
    final hasVideo = picked != null || (_currentMedia?.isVideo ?? false);
    final status = picked != null
        ? 'Vídeo pronto para enviar (${(picked.bytes.length / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB)'
        : hasVideo
        ? 'Vídeo da aula anexado'
        : 'Sem vídeo ainda';
    return Container(
      decoration: BoxDecoration(color: SocialColors.surface, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              VideoThumb(color: widget.belt.color, category: _category, hasVideo: hasVideo, width: 80),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Videoaula', style: socialBold),
                    Text(
                      status,
                      key: const Key('lesson-video-status'),
                      style: const TextStyle(color: SocialColors.ink2),
                    ),
                  ],
                ),
              ),
              if (hasVideo)
                IconButton(
                  key: const Key('lesson-video-remove'),
                  tooltip: 'Remover vídeo',
                  onPressed: _saving ? null : _removeMedia,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('lesson-video-gallery'),
                  onPressed: _saving ? null : () => _pickVideo(record: false),
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text(hasVideo ? 'Trocar vídeo' : 'Da galeria'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('lesson-video-record'),
                  onPressed: _saving ? null : () => _pickVideo(record: true),
                  icon: const Icon(Icons.videocam_rounded),
                  label: const Text('Gravar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Até 60 MB (cerca de 90 s gravando pelo celular). Mostre a técnica de mais de um ângulo.',
            style: TextStyle(color: SocialColors.ink2, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
