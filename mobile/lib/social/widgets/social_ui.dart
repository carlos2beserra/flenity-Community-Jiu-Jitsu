import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../social_api.dart';
import '../social_models.dart';

/// Cores da área social: fundo branco, tinta escura e o azul da Flenity como destaque.
abstract final class SocialColors {
  static const bg = Colors.white;
  static const ink = Color(0xFF111418);
  static const ink2 = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF3F4F6);
  static const like = Color(0xFFE5374A);
  static const accent = Color(0xFF1689EF);

  /// Anel de story da marca Flenity: azul → turquesa → verde.
  static const storyRing = SweepGradient(
    colors: [Color(0xFF1689EF), Color(0xFF22C1C3), Color(0xFF6EDC9F), Color(0xFF22C1C3), Color(0xFF1689EF)],
  );
}

SocialApi socialApiOf(BuildContext context) => SocialApi(context.read<Session>().api);

const socialTitleStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SocialColors.ink, letterSpacing: -0.6);
const socialBold = TextStyle(fontWeight: FontWeight.w700, color: SocialColors.ink);

enum StoryRing { none, unseen, seen }

class SocialAvatar extends StatelessWidget {
  const SocialAvatar({super.key, required this.author, this.size = 36, this.ring = StoryRing.none, this.onTap});

  final SocialAuthor author;
  final double size;
  final StoryRing ring;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = author.avatarUrl;
    Widget avatar = ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? _Initials(name: author.name, size: size)
            : Image.network(
                socialApiOf(context).mediaUrl(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Initials(name: author.name, size: size),
              ),
      ),
    );
    if (ring != StoryRing.none) {
      final gap = size * 0.06 + 1.5;
      avatar = Container(
        padding: EdgeInsets.all(ring == StoryRing.unseen ? 2.5 : 1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ring == StoryRing.unseen ? SocialColors.storyRing : null,
          color: ring == StoryRing.seen ? SocialColors.line : null,
        ),
        child: Container(
          padding: EdgeInsets.all(gap),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: SocialColors.bg),
          child: avatar,
        ),
      );
    }
    return Semantics(
      label: 'Foto de ${author.name}',
      button: onTap != null,
      child: GestureDetector(onTap: onTap, child: avatar),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDCEBFA), Color(0xFFB9D8F5)],
      ),
    ),
    child: Text(
      initials(name),
      style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: const Color(0xFF1D4F7A)),
    ),
  );
}

/// Imagem ou vídeo de uma publicação. Vídeos só criam o player quando vão tocar.
class MediaView extends StatefulWidget {
  const MediaView({
    super.key,
    required this.media,
    this.fit = BoxFit.cover,
    this.autoplay = false,
    this.showVideoBadge = true,
    this.onVideoReady,
  });

  final SocialMedia media;
  final BoxFit fit;
  final bool autoplay;
  final bool showVideoBadge;
  final ValueChanged<VideoPlayerController>? onVideoReady;

  @override
  State<MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends State<MediaView> {
  VideoPlayerController? _video;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    if (widget.media.isVideo && widget.autoplay) _startVideo();
  }

  @override
  void didUpdateWidget(covariant MediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.media.isVideo) return;
    if (widget.autoplay && _video == null) _startVideo();
    if (widget.autoplay && _video != null) _video!.play();
    if (!widget.autoplay && oldWidget.autoplay) _video?.pause();
  }

  Future<void> _startVideo() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(socialApiOf(context).mediaUrl(widget.media.url)));
    _video = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted) return;
      await controller.play();
      widget.onVideoReady?.call(controller);
      setState(() {});
    } catch (error) {
      debugPrint('Falha ao carregar vídeo ${widget.media.id}: $error');
      if (mounted) setState(() {});
    }
  }

  void _toggleVideo() {
    final video = _video;
    if (video == null) {
      _startVideo();
      return;
    }
    setState(() => video.value.isPlaying ? video.pause() : video.play());
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _video?.setVolume(_muted ? 0 : 1);
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = socialApiOf(context).mediaUrl(widget.media.url);
    if (!widget.media.isVideo) {
      return Image.network(
        url,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const ColoredBox(color: SocialColors.surface),
        errorBuilder: (_, _, _) => const _MediaError(),
      );
    }
    final video = _video;
    final ready = video != null && video.value.isInitialized;
    return GestureDetector(
      onTap: _toggleVideo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (ready)
            FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(width: video.value.size.width, height: video.value.size.height, child: VideoPlayer(video)),
            ),
          if (!ready || !video.value.isPlaying)
            const Center(child: Icon(Icons.play_arrow_rounded, size: 64, color: Colors.white70)),
          if (ready && widget.showVideoBadge)
            Positioned(
              right: 10,
              bottom: 10,
              child: _RoundIcon(
                icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                tooltip: _muted ? 'Ativar som' : 'Silenciar',
                onTap: _toggleMute,
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 16, color: Colors.white)),
      ),
    ),
  );
}

class _MediaError extends StatelessWidget {
  const _MediaError();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: SocialColors.surface,
    child: Center(child: Icon(Icons.broken_image_outlined, color: SocialColors.ink2)),
  );
}

/// Publicação só de texto exibida como cartão quadrado colorido (grade e feed).
class TextPostTile extends StatelessWidget {
  const TextPostTile({super.key, required this.post, this.compact = false});

  final SocialPost post;
  final bool compact;

  static const _palettes = [
    [Color(0xFF1689EF), Color(0xFF0B5CAD)],
    [Color(0xFF1F2937), Color(0xFF111827)],
    [Color(0xFF16A394), Color(0xFF0E7468)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
    [Color(0xFF7C3AED), Color(0xFF5B21B6)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[post.id.hashCode.abs() % _palettes.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      padding: EdgeInsets.all(compact ? 8 : 28),
      alignment: Alignment.center,
      child: Text(
        post.content,
        textAlign: TextAlign.center,
        maxLines: compact ? 5 : 9,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 10.5 : (post.content.length > 140 ? 18 : 24),
          height: 1.25,
        ),
      ),
    );
  }
}

/// Grade de 3 colunas de publicações (perfil, explorar, salvos).
class PostGrid extends StatelessWidget {
  const PostGrid({super.key, required this.posts, required this.onTap, this.reelAspect = false});

  final List<SocialPost> posts;
  final void Function(int index) onTap;
  final bool reelAspect;

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 1.5,
      mainAxisSpacing: 1.5,
      childAspectRatio: reelAspect ? 9 / 16 : 1,
    ),
    itemCount: posts.length,
    itemBuilder: (context, index) => PostThumbnail(
      key: ValueKey('grid-${posts[index].id}'),
      post: posts[index],
      onTap: () => onTap(index),
    ),
  );
}

class PostThumbnail extends StatelessWidget {
  const PostThumbnail({super.key, required this.post, required this.onTap});

  final SocialPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = post.cover;
    final badge = post.isReel
        ? Icons.movie_outlined
        : post.media.length > 1
        ? Icons.collections_outlined
        : cover?.isVideo == true
        ? Icons.videocam_outlined
        : null;
    return Semantics(
      button: true,
      label: 'Publicação de ${post.author.name}',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover == null)
              TextPostTile(post: post, compact: true)
            else if (cover.isVideo)
              const ColoredBox(
                color: Color(0xFF1F2937),
                child: Center(child: Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 34)),
              )
            else
              MediaView(media: cover),
            if (badge != null)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(badge, color: Colors.white, size: 18, shadows: const [Shadow(blurRadius: 4)]),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botão "Seguir" / "Seguindo" com o visual das redes sociais.
class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.following, required this.onPressed, this.dense = false, this.busy = false});

  final bool following;
  final VoidCallback? onPressed;
  final bool dense;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final label = following ? 'Seguindo' : 'Seguir';
    final style = FilledButton.styleFrom(
      backgroundColor: following ? SocialColors.surface : SocialColors.accent,
      foregroundColor: following ? SocialColors.ink : Colors.white,
      padding: EdgeInsets.symmetric(horizontal: dense ? 16 : 20, vertical: dense ? 6 : 10),
      minimumSize: Size(dense ? 88 : 0, dense ? 32 : 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    );
    return FilledButton(
      style: style,
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    );
  }
}

/// Botão cinza secundário ("Editar perfil", "Compartilhar perfil").
class SocialSecondaryButton extends StatelessWidget {
  const SocialSecondaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: SocialColors.surface,
      foregroundColor: SocialColors.ink,
      padding: const EdgeInsets.symmetric(vertical: 10),
      minimumSize: const Size(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

/// Carrega a próxima página quando a rolagem chega perto do fim.
bool loadMoreWhenNearEnd(ScrollNotification notification, VoidCallback loadMore) {
  if (notification.metrics.axis == Axis.vertical &&
      notification.metrics.pixels >= notification.metrics.maxScrollExtent - 600) {
    loadMore();
  }
  return false;
}

/// Selo ao lado do @usuário de quem é da equipe ("Professor", "Equipe").
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.author, this.dark = false});

  final SocialAuthor author;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final label = author.roleLabel;
    if (!author.isStaff || label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: dark ? Colors.white24 : SocialColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 12, color: dark ? Colors.white : SocialColors.accent),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : SocialColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// @usuário em negrito seguido do selo de equipe, quando houver.
class AuthorHandle extends StatelessWidget {
  const AuthorHandle({super.key, required this.author, this.style, this.dark = false});

  final SocialAuthor author;
  final TextStyle? style;
  final bool dark;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          author.handle,
          overflow: TextOverflow.ellipsis,
          style: style ?? socialBold.copyWith(fontSize: 14, color: dark ? Colors.white : SocialColors.ink),
        ),
      ),
      RoleBadge(author: author, dark: dark),
    ],
  );
}

/// Atalho do painel do perfil (ex.: Aulas, Agenda, Mensalidades).
class ProfileShortcut {
  const ProfileShortcut({required this.key, required this.icon, required this.label, required this.onTap});

  final Key key;
  final IconData icon;
  final String label;
  final void Function(BuildContext context) onTap;
}

/// Linha de atalhos exibida abaixo dos botões do próprio perfil, igual para aluno e equipe.
class ProfileShortcutsRow extends StatelessWidget {
  const ProfileShortcutsRow({super.key, required this.shortcuts});

  final List<ProfileShortcut> shortcuts;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < shortcuts.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Material(
            key: shortcuts[i].key,
            color: SocialColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => shortcuts[i].onTap(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Icon(shortcuts[i].icon, color: SocialColors.accent),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(shortcuts[i].label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
