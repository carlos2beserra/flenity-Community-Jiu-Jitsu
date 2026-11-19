import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/widgets/common.dart';
import '../social_models.dart';
import '../social_navigation.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/social_ui.dart';

/// Rolas: vídeos verticais em tela cheia, um por página. Só o rola visível toca, e só com a aba ativa.
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key, this.active = true, this.onCreateReel});

  final bool active;
  final VoidCallback? onCreateReel;

  @override
  State<ReelsScreen> createState() => ReelsScreenState();
}

class ReelsScreenState extends State<ReelsScreen> {
  List<SocialPost> _reels = const [];
  PageResult<SocialPost>? _lastPage;
  int _current = 0;
  bool _loaded = false;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) reload();
  }

  @override
  void didUpdateWidget(covariant ReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_loaded) reload();
  }

  Future<void> reload({bool more = false}) async {
    if (_loading || (more && !(_lastPage?.hasMore ?? false))) return;
    _loading = true;
    try {
      final page = await socialApiOf(context).feed(kind: PostKind.reel, page: more ? _lastPage!.page + 1 : 1, pageSize: 8);
      if (!mounted) return;
      setState(() {
        _reels = more ? [..._reels, ...page.items] : page.items;
        _lastPage = page;
        _loaded = true;
        _error = null;
        if (!more) _current = 0;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _loading = false;
    }
  }

  void _replace(SocialPost next) {
    setState(() => _reels = [for (final reel in _reels) reel.id == next.id ? next : reel]);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_error != null && _reels.isEmpty) {
      body = ErrorView(message: errorText(_error), onRetry: reload);
    } else if (!_loaded) {
      body = widget.active ? const Center(child: CircularProgressIndicator(color: Colors.white)) : const SizedBox.shrink();
    } else if (_reels.isEmpty) {
      body = _empty();
    } else {
      body = PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: _reels.length,
        onPageChanged: (index) {
          setState(() => _current = index);
          if (index >= _reels.length - 2) reload(more: true);
        },
        itemBuilder: (context, index) => _ReelPage(
          key: ValueKey(_reels[index].id),
          reel: _reels[index],
          playing: widget.active && index == _current,
          onChanged: _replace,
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            left: 16,
            right: 4,
            top: 6,
            child: Row(
              children: [
                const Text('Rolas', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (widget.onCreateReel != null)
                  IconButton(
                    tooltip: 'Criar rola',
                    onPressed: widget.onCreateReel,
                    icon: const Icon(Icons.photo_camera_outlined, color: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_outlined, color: Colors.white, size: 56),
          const SizedBox(height: 12),
          const Text(
            'Nenhum rola ainda',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Grave uma técnica, um rola ou a conquista de uma faixa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          if (widget.onCreateReel != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: widget.onCreateReel, child: const Text('Criar rola')),
          ],
        ],
      ),
    ),
  );
}

class _ReelPage extends StatelessWidget {
  const _ReelPage({super.key, required this.reel, required this.playing, required this.onChanged});

  final SocialPost reel;
  final bool playing;
  final ValueChanged<SocialPost> onChanged;

  Future<void> _toggleLike(BuildContext context, {bool onlyLike = false}) async {
    if (onlyLike && reel.likedByMe) return;
    final liked = !reel.likedByMe;
    onChanged(reel.copyWith(likedByMe: liked, likes: reel.likes + (liked ? 1 : -1)));
    try {
      await socialApiOf(context).toggleLike(reel.id);
    } catch (error) {
      onChanged(reel);
      if (context.mounted) showMessage(context, errorText(error), error: true);
    }
  }

  Future<void> _toggleSave(BuildContext context) async {
    onChanged(reel.copyWith(savedByMe: !reel.savedByMe));
    try {
      await socialApiOf(context).toggleSave(reel.id);
    } catch (error) {
      onChanged(reel);
      if (context.mounted) showMessage(context, errorText(error), error: true);
    }
  }

  Future<void> _comments(BuildContext context) async {
    final count = await showCommentsSheet(context, post: reel, onOpenProfile: (author) => openProfile(context, author));
    if (count != null) onChanged(reel.copyWith(comments: count));
  }

  @override
  Widget build(BuildContext context) {
    final media = reel.cover;
    return GestureDetector(
      onDoubleTap: () {
        HapticFeedback.lightImpact();
        _toggleLike(context, onlyLike: true);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media != null) MediaView(media: media, autoplay: playing, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.6, 1],
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 24,
            child: Column(
              children: [
                _RailButton(
                  icon: reel.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: reel.likedByMe ? SocialColors.like : Colors.white,
                  label: compactCount(reel.likes),
                  tooltip: 'Curtir',
                  onTap: () => _toggleLike(context),
                ),
                _RailButton(
                  icon: Icons.mode_comment_outlined,
                  label: compactCount(reel.comments),
                  tooltip: 'Comentários',
                  onTap: () => _comments(context),
                ),
                _RailButton(
                  icon: reel.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  label: '',
                  tooltip: 'Salvar',
                  onTap: () => _toggleSave(context),
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 72,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => openProfile(context, reel.author),
                  child: Row(
                    children: [
                      SocialAvatar(author: reel.author, size: 32),
                      const SizedBox(width: 8),
                      Flexible(child: AuthorHandle(author: reel.author, dark: true)),
                    ],
                  ),
                ),
                if (reel.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      reel.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 30, shadows: const [Shadow(blurRadius: 6)]),
        ),
        if (label.isNotEmpty)
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
