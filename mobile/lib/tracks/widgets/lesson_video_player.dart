import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Cria o controlador do vídeo. Os testes trocam por um falso (sem plataforma de vídeo).
typedef VideoControllerFactory = VideoPlayerController Function(Uri url);

VideoPlayerController networkVideo(Uri url) => VideoPlayerController.networkUrl(url);

/// Player da videoaula: com som, pausar, voltar 10 s, câmera lenta e tela cheia.
class LessonVideoPlayer extends StatefulWidget {
  const LessonVideoPlayer({
    super.key,
    required this.url,
    this.onFinished,
    this.controllerFactory = networkVideo,
    this.autoplay = true,
  });

  final Uri url;
  final VoidCallback? onFinished;
  final VideoControllerFactory controllerFactory;
  final bool autoplay;

  @override
  State<LessonVideoPlayer> createState() => _LessonVideoPlayerState();
}

class _LessonVideoPlayerState extends State<LessonVideoPlayer> {
  late final VideoPlayerController _video = widget.controllerFactory(widget.url);
  bool _failed = false;
  bool _finishedNotified = false;

  @override
  void initState() {
    super.initState();
    _video.addListener(_onTick);
    _start();
  }

  Future<void> _start() async {
    try {
      await _video.initialize();
      if (mounted && widget.autoplay) await _video.play();
    } catch (error) {
      debugPrint('Falha ao carregar a videoaula: $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onTick() {
    final value = _video.value;
    final finished = value.isInitialized && value.duration > Duration.zero && value.position >= value.duration;
    if (finished && !_finishedNotified) {
      _finishedNotified = true;
      widget.onFinished?.call();
    } else if (!finished) {
      _finishedNotified = false;
    }
  }

  @override
  void dispose() {
    _video
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  Future<void> _openFullscreen() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, _, _) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: VideoControls(video: _video, fullscreen: true)),
        ),
      ),
    );
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('Não foi possível carregar o vídeo.', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: VideoControls(video: _video, onFullscreen: _openFullscreen),
    );
  }
}

/// Vídeo + controles. Os controles somem sozinhos durante a reprodução; toque mostra de novo.
class VideoControls extends StatefulWidget {
  const VideoControls({super.key, required this.video, this.onFullscreen, this.fullscreen = false});

  final VideoPlayerController video;
  final VoidCallback? onFullscreen;
  final bool fullscreen;

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  bool _visible = true;
  Timer? _hide;

  VideoPlayerController get _video => widget.video;

  @override
  void initState() {
    super.initState();
    _video.addListener(_refresh);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _video.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && _video.value.isPlaying) setState(() => _visible = false);
    });
  }

  void _show() {
    setState(() => _visible = true);
    _scheduleHide();
  }

  Future<void> _togglePlay() async {
    final value = _video.value;
    if (value.isPlaying) {
      await _video.pause();
    } else {
      if (value.duration > Duration.zero && value.position >= value.duration) await _video.seekTo(Duration.zero);
      await _video.play();
    }
    _show();
  }

  Future<void> _rewind() async {
    final target = _video.value.position - const Duration(seconds: 10);
    await _video.seekTo(target < Duration.zero ? Duration.zero : target);
    _show();
  }

  Future<void> _toggleSpeed() async {
    await _video.setPlaybackSpeed(_video.value.playbackSpeed < 1 ? 1 : 0.5);
    _show();
  }

  @override
  Widget build(BuildContext context) {
    final value = _video.value;
    final ready = value.isInitialized;
    final slow = value.playbackSpeed < 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _visible ? () => setState(() => _visible = false) : _show,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            Center(
              child: AspectRatio(aspectRatio: value.aspectRatio, child: VideoPlayer(_video)),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (ready)
            AnimatedOpacity(
              opacity: _visible || !value.isPlaying ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !(_visible || !value.isPlaying),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.black38),
                  child: Stack(
                    children: [
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ControlButton(
                              key: const Key('video-rewind'),
                              icon: Icons.replay_10_rounded,
                              tooltip: 'Voltar 10 segundos',
                              onTap: _rewind,
                            ),
                            const SizedBox(width: 24),
                            _ControlButton(
                              key: const Key('video-play'),
                              icon: value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              tooltip: value.isPlaying ? 'Pausar' : 'Assistir',
                              size: 56,
                              onTap: _togglePlay,
                            ),
                            const SizedBox(width: 24),
                            _ControlButton(
                              key: const Key('video-speed'),
                              icon: slow ? Icons.slow_motion_video_rounded : Icons.speed_rounded,
                              tooltip: slow ? 'Velocidade normal' : 'Câmera lenta (0,5x)',
                              label: slow ? '0,5x' : '1x',
                              onTap: _toggleSpeed,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 4,
                        bottom: 4,
                        child: Row(
                          children: [
                            Text(
                              '${formatVideoTime(value.position)} / ${formatVideoTime(value.duration)}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: VideoProgressIndicator(
                                _video,
                                allowScrubbing: true,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                colors: const VideoProgressColors(
                                  playedColor: Colors.white,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                            ),
                            IconButton(
                              key: const Key('video-fullscreen'),
                              tooltip: widget.fullscreen ? 'Sair da tela cheia' : 'Tela cheia',
                              color: Colors.white,
                              onPressed: widget.fullscreen ? () => Navigator.of(context).pop() : widget.onFullscreen,
                              icon: Icon(widget.fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 34,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkResponse(
      onTap: onTap,
      radius: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: size),
          if (label != null)
            Text(
              label!,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    ),
  );
}

/// 75 s → "1:15"; 1 h 2 min 3 s → "1:02:03".
String formatVideoTime(Duration duration) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return hours > 0 ? '$hours:${two(minutes)}:${two(seconds)}' : '$minutes:${two(seconds)}';
}
