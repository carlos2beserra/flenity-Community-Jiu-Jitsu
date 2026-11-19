import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../ui/widgets/common.dart';
import '../social_models.dart';
import '../widgets/social_ui.dart';

const _imageDuration = Duration(seconds: 5);

/// Visualizador de flashes em tela cheia: barras de progresso, toque à esquerda/direita para navegar,
/// segurar para pausar e deslizar para baixo para fechar.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({super.key, required this.groups, required this.initialGroup, this.onOpenProfile});

  final List<StoryGroup> groups;
  final int initialGroup;
  final void Function(SocialAuthor author)? onOpenProfile;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with SingleTickerProviderStateMixin {
  late int _group = widget.initialGroup;
  late int _story = _firstUnseen(widget.groups[widget.initialGroup]);
  late final _progress = AnimationController(vsync: this, duration: _imageDuration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
  final _viewed = <String>{};
  bool _deleted = false;

  StoryGroup get _current => widget.groups[_group];
  SocialStory get _currentStory => _current.stories[_story];

  static int _firstUnseen(StoryGroup group) {
    final index = group.stories.indexWhere((story) => !story.seen);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startStory());
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _startStory() {
    if (!mounted) return;
    final story = _currentStory;
    if (!story.media.isVideo) {
      _progress
        ..duration = _imageDuration
        ..forward(from: 0);
    } else {
      _progress.value = 0;
    }
    if (!_current.isMe && _viewed.add(story.id)) {
      socialApiOf(context).markStoryViewed(story.id).catchError((Object error) {
        debugPrint('Falha ao marcar story ${story.id} como visto: $error');
      });
    }
  }

  void _onVideoReady(VideoPlayerController controller) {
    if (!mounted) return;
    controller.setLooping(false);
    _progress
      ..duration = controller.value.duration == Duration.zero ? _imageDuration : controller.value.duration
      ..forward(from: 0);
  }

  void _next() {
    if (_story < _current.stories.length - 1) {
      setState(() => _story++);
    } else if (_group < widget.groups.length - 1) {
      setState(() {
        _group++;
        _story = _firstUnseen(_current);
      });
    } else {
      _close();
      return;
    }
    _startStory();
  }

  void _previous() {
    if (_story > 0) {
      setState(() => _story--);
    } else if (_group > 0) {
      setState(() {
        _group--;
        _story = 0;
      });
    }
    _startStory();
  }

  void _close() {
    if (mounted) Navigator.of(context).pop(_deleted);
  }

  Future<void> _showViewers() async {
    _progress.stop();
    final api = socialApiOf(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: SocialColors.bg,
      builder: (context) => FutureBuilder<List<SocialAuthor>>(
        future: api.storyViewers(_currentStory.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
          }
          final viewers = snapshot.data!;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${viewers.length} visualizações', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (viewers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Ninguém viu ainda.', style: TextStyle(color: SocialColors.ink2)),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final viewer in viewers)
                        ListTile(
                          leading: SocialAvatar(author: viewer, size: 40),
                          title: AuthorHandle(author: viewer),
                          subtitle: Text(viewer.name),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (mounted) _progress.forward();
  }

  Future<void> _delete() async {
    _progress.stop();
    final ok = await confirmDialog(context, 'Apagar flash', 'Este flash será removido.', confirm: 'Apagar');
    if (!mounted) return;
    if (!ok) {
      _progress.forward();
      return;
    }
    try {
      await socialApiOf(context).deleteStory(_currentStory.id);
      _deleted = true;
      _close();
    } catch (error) {
      if (mounted) {
        showMessage(context, errorText(error), error: true);
        _progress.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _currentStory;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) _close();
        },
        onLongPressStart: (_) => _progress.stop(),
        onLongPressEnd: (_) => _progress.forward(),
        onTapUp: (details) {
          final width = MediaQuery.sizeOf(context).width;
          details.globalPosition.dx < width / 3 ? _previous() : _next();
        },
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MediaView(
                  key: ValueKey(story.id),
                  media: story.media,
                  fit: BoxFit.contain,
                  autoplay: story.media.isVideo,
                  showVideoBadge: false,
                  onVideoReady: _onVideoReady,
                ),
              ),
              Positioned(left: 8, right: 8, top: 8, child: _progressBars()),
              Positioned(left: 12, right: 4, top: 20, child: _header(story)),
              if (story.caption != null && story.caption!.isNotEmpty)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: _current.isMe ? 84 : 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      story.caption!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (_current.isMe)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: Center(
                    child: TextButton.icon(
                      onPressed: _showViewers,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Visualizações'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressBars() => Row(
    children: [
      for (var i = 0; i < _current.stories.length; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => LinearProgressIndicator(
                  minHeight: 2.5,
                  value: i < _story ? 1 : (i == _story ? _progress.value : 0),
                  backgroundColor: Colors.white30,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _header(SocialStory story) => Row(
    children: [
      SocialAvatar(
        author: _current.author,
        size: 32,
        onTap: widget.onOpenProfile == null
            ? null
            : () {
                Navigator.of(context).pop(_deleted);
                widget.onOpenProfile!(_current.author);
              },
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          _current.isMe ? 'Seu flash' : _current.author.handle,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 8),
      Text(relativeTime(story.createdAt), style: const TextStyle(color: Colors.white70, fontSize: 13)),
      const Spacer(),
      if (_current.isMe)
        IconButton(
          tooltip: 'Apagar flash',
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
      IconButton(
        tooltip: 'Fechar',
        onPressed: _close,
        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
      ),
    ],
  );
}
