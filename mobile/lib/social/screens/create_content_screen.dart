import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ui/widgets/common.dart';
import '../media_picker.dart';
import '../social_models.dart';
import '../widgets/social_ui.dart';

enum CreateMode { post, story, reel }

/// Resultado devolvido ao fechar a tela de criação.
class CreatedContent {
  const CreatedContent({required this.mode, this.post});

  final CreateMode mode;
  final SocialPost? post;
}

/// Criação de publicação (texto e/ou carrossel), flash (foto ou vídeo, 24 h) ou rola (um vídeo).
class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key, this.initialMode = CreateMode.post});

  final CreateMode initialMode;

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  late CreateMode _mode = widget.initialMode;
  final _caption = TextEditingController();
  final List<PickedMedia> _media = [];
  bool _publishing = false;
  String? _status;

  MediaPickerService get _picker =>
      Provider.of<MediaPickerService?>(context, listen: false) ?? DeviceMediaPicker();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _setMode(CreateMode mode) {
    setState(() {
      _mode = mode;
      if (mode != CreateMode.post && _media.length > 1) _media.removeRange(1, _media.length);
      if (mode == CreateMode.reel) _media.removeWhere((media) => !media.isVideo);
    });
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickFromGallery(
        multiple: _mode == CreateMode.post,
        allowVideo: _mode != CreateMode.reel,
        videoOnly: _mode == CreateMode.reel,
      );
      if (!mounted || picked.isEmpty) return;
      setState(() {
        if (_mode == CreateMode.post) {
          _media
            ..addAll(picked)
            ..removeRange(0, (_media.length - 10).clamp(0, _media.length));
        } else {
          _media
            ..clear()
            ..add(picked.first);
        }
      });
    } catch (error) {
      if (mounted) showMessage(context, 'Não foi possível abrir a galeria: ${errorText(error)}', error: true);
    }
  }

  Future<void> _capture() async {
    try {
      final picked = await _picker.capture(video: _mode == CreateMode.reel);
      if (!mounted || picked == null) return;
      setState(() {
        if (_mode != CreateMode.post) _media.clear();
        if (_media.length < 10) _media.add(picked);
      });
    } catch (error) {
      if (mounted) showMessage(context, 'Não foi possível abrir a câmera: ${errorText(error)}', error: true);
    }
  }

  String? get _problem => switch (_mode) {
    CreateMode.post when _media.isEmpty && _caption.text.trim().isEmpty => 'Escreva algo ou adicione uma foto.',
    CreateMode.story when _media.isEmpty => 'Escolha uma foto ou vídeo para o flash.',
    CreateMode.reel when _media.length != 1 || !_media.first.isVideo => 'Escolha um vídeo para o rola.',
    _ => null,
  };

  Future<void> _publish() async {
    final problem = _problem;
    if (problem != null) {
      showMessage(context, problem, error: true);
      return;
    }
    final api = socialApiOf(context);
    setState(() => _publishing = true);
    try {
      final ids = <String>[];
      for (var i = 0; i < _media.length; i++) {
        setState(() => _status = _media.length == 1 ? 'Enviando…' : 'Enviando ${i + 1} de ${_media.length}…');
        final uploaded = await api.upload(_media[i].bytes, _media[i].name);
        ids.add(uploaded.id);
      }
      setState(() => _status = 'Publicando…');
      final caption = _caption.text.trim();
      SocialPost? post;
      if (_mode == CreateMode.story) {
        await api.createStory(ids.first, caption: caption);
      } else {
        post = await api.createPost(
          content: caption,
          mediaIds: ids,
          kind: _mode == CreateMode.reel ? PostKind.reel : PostKind.post,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(CreatedContent(mode: _mode, post: post));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _status = null;
      });
      showMessage(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      CreateMode.post => 'Nova publicação',
      CreateMode.story => 'Novo flash',
      CreateMode.reel => 'Novo rola',
    };
    return Scaffold(
      backgroundColor: SocialColors.bg,
      appBar: AppBar(
        backgroundColor: SocialColors.bg,
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close_rounded, color: SocialColors.ink),
          onPressed: _publishing ? null : () => Navigator.pop(context),
        ),
        title: Text(title, style: socialTitleStyle.copyWith(fontSize: 18)),
        actions: [
          TextButton(
            key: const Key('create-share'),
            onPressed: _publishing ? null : _publish,
            child: const Text('Compartilhar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _publishing,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            if (_publishing) LinearProgressIndicator(minHeight: 2, color: SocialColors.accent, semanticsLabel: _status),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<CreateMode>(
                segments: const [
                  ButtonSegment(value: CreateMode.post, label: Text('Publicação'), icon: Icon(Icons.grid_on_rounded)),
                  ButtonSegment(value: CreateMode.story, label: Text('Flash'), icon: Icon(Icons.history_toggle_off_rounded)),
                  ButtonSegment(value: CreateMode.reel, label: Text('Rola'), icon: Icon(Icons.movie_outlined)),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => _setMode(selection.first),
              ),
            ),
            _preview(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('create-pick-gallery'),
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(_mode == CreateMode.reel ? 'Vídeo da galeria' : 'Galeria'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _capture,
                      icon: Icon(_mode == CreateMode.reel ? Icons.videocam_outlined : Icons.photo_camera_outlined),
                      label: const Text('Câmera'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                key: const Key('create-caption'),
                controller: _caption,
                onChanged: (_) => setState(() {}),
                minLines: _mode == CreateMode.post && _media.isEmpty ? 5 : 2,
                maxLines: 8,
                maxLength: _mode == CreateMode.story ? 200 : 2200,
                decoration: InputDecoration(
                  hintText: switch (_mode) {
                    CreateMode.post => 'Escreva uma legenda ou compartilhe uma conquista do tatame…',
                    CreateMode.story => 'Texto sobre o flash (opcional)',
                    CreateMode.reel => 'Legenda do rola…',
                  },
                ),
              ),
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status!, textAlign: TextAlign.center, style: const TextStyle(color: SocialColors.ink2)),
              ),
            if (_mode == CreateMode.story)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Flashes ficam visíveis por 24 horas para quem segue você.',
                  style: TextStyle(color: SocialColors.ink2, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    if (_media.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: AspectRatio(
          aspectRatio: _mode == CreateMode.post ? 2.2 : 1.4,
          child: Material(
            color: SocialColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickFromGallery,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _mode == CreateMode.reel ? Icons.video_library_outlined : Icons.add_photo_alternate_outlined,
                    size: 38,
                    color: SocialColors.ink2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (_mode) {
                      CreateMode.post => 'Adicionar fotos ou vídeos (até 10)',
                      CreateMode.story => 'Escolher foto ou vídeo',
                      CreateMode.reel => 'Escolher um vídeo',
                    },
                    style: const TextStyle(color: SocialColors.ink2, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        scrollDirection: Axis.horizontal,
        itemCount: _media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final media = _media[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 160,
                  height: 198,
                  child: media.isVideo
                      ? const ColoredBox(
                          color: Color(0xFF1F2937),
                          child: Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white70, size: 40)),
                        )
                      : Image.memory(media.bytes, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _media.removeAt(index)),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.white, semanticLabel: 'Remover'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
