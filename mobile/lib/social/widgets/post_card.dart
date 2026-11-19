import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/widgets/common.dart';
import '../social_models.dart';
import 'comments_sheet.dart';
import 'social_ui.dart';

/// Publicação no feed: cabeçalho, mídia em carrossel, ações, legenda e comentários recentes.
/// Curtir e salvar são otimistas e voltam ao estado anterior se a API falhar.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onOpenProfile,
    this.onChanged,
    this.onDeleted,
    this.isMine = false,
  });

  final SocialPost post;
  final void Function(SocialAuthor author) onOpenProfile;
  final ValueChanged<SocialPost>? onChanged;
  final VoidCallback? onDeleted;
  final bool isMine;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  late SocialPost _post = widget.post;
  int _page = 0;
  bool _expanded = false;
  late final _heart = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) _post = widget.post;
  }

  @override
  void dispose() {
    _heart.dispose();
    super.dispose();
  }

  void _update(SocialPost next) {
    setState(() => _post = next);
    widget.onChanged?.call(next);
  }

  Future<void> _toggleLike({bool onlyLike = false}) async {
    final before = _post;
    if (onlyLike && before.likedByMe) return;
    final liked = !before.likedByMe;
    _update(before.copyWith(likedByMe: liked, likes: before.likes + (liked ? 1 : -1)));
    try {
      await socialApiOf(context).toggleLike(before.id);
    } catch (error) {
      if (!mounted) return;
      _update(before);
      showMessage(context, errorText(error), error: true);
    }
  }

  void _doubleTapLike() {
    HapticFeedback.lightImpact();
    _heart.forward(from: 0);
    _toggleLike(onlyLike: true);
  }

  Future<void> _toggleSave() async {
    final before = _post;
    _update(before.copyWith(savedByMe: !before.savedByMe));
    try {
      await socialApiOf(context).toggleSave(before.id);
      if (mounted && !before.savedByMe) showMessage(context, 'Salvo na sua coleção.');
    } catch (error) {
      if (!mounted) return;
      _update(before);
      showMessage(context, errorText(error), error: true);
    }
  }

  Future<void> _openComments() async {
    final count = await showCommentsSheet(context, post: _post, onOpenProfile: widget.onOpenProfile);
    if (count != null && mounted) _update(_post.copyWith(comments: count));
  }

  Future<void> _share() async {
    final text = '${_post.author.handle} na comunidade Flenity: ${_post.content}'.trim();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showMessage(context, 'Texto da publicação copiado.');
  }

  Future<void> _openMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SocialColors.bg,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_post.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              title: Text(_post.savedByMe ? 'Remover dos salvos' : 'Salvar'),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Ver perfil'),
              onTap: () => Navigator.pop(context, 'profile'),
            ),
            if (widget.isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: SocialColors.like),
                title: const Text('Apagar', style: TextStyle(color: SocialColors.like, fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'save':
        await _toggleSave();
      case 'profile':
        widget.onOpenProfile(_post.author);
      case 'delete':
        await _delete();
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, 'Apagar publicação', 'Essa ação não pode ser desfeita.', confirm: 'Apagar');
    if (!ok || !mounted) return;
    try {
      await socialApiOf(context).deletePost(_post.id);
      widget.onDeleted?.call();
      if (mounted) showMessage(context, 'Publicação apagada.');
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(post),
        _body(post),
        _actions(post),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.likes > 0)
                Text('${compactCount(post.likes)} ${post.likes == 1 ? 'curtida' : 'curtidas'}', style: socialBold),
              if (post.content.isNotEmpty && post.media.isNotEmpty) _caption(post),
              if (post.comments > 0)
                GestureDetector(
                  onTap: _openComments,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      post.comments == 1 ? 'Ver 1 comentário' : 'Ver todos os ${post.comments} comentários',
                      style: const TextStyle(color: SocialColors.ink2),
                    ),
                  ),
                ),
              for (final comment in post.recentComments.take(2))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${comment.author.handle} ', style: socialBold),
                        TextSpan(text: comment.content),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 18),
                child: Text(
                  relativeTime(post.createdAt),
                  style: const TextStyle(color: SocialColors.ink2, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(SocialPost post) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
    child: Row(
      children: [
        SocialAvatar(author: post.author, size: 34, onTap: () => widget.onOpenProfile(post.author)),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => widget.onOpenProfile(post.author),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthorHandle(author: post.author),
                if (post.isReel)
                  const Text('Rola', style: TextStyle(fontSize: 12, color: SocialColors.ink2)),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Mais opções',
          icon: const Icon(Icons.more_horiz_rounded, color: SocialColors.ink),
          onPressed: _openMenu,
        ),
      ],
    ),
  );

  Widget _body(SocialPost post) {
    final Widget content;
    if (post.media.isEmpty) {
      content = TextPostTile(post: post);
    } else if (post.media.length == 1) {
      content = MediaView(media: post.media.first);
    } else {
      content = PageView.builder(
        itemCount: post.media.length,
        onPageChanged: (page) => setState(() => _page = page),
        itemBuilder: (context, index) => MediaView(media: post.media[index]),
      );
    }
    return GestureDetector(
      key: Key('post-media-${post.id}'),
      onDoubleTap: _doubleTapLike,
      child: AspectRatio(
        aspectRatio: post.isReel ? 4 / 5 : 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (post.media.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    '${_page + 1}/${post.media.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _heart,
                  builder: (context, _) {
                    final t = _heart.value;
                    if (!_heart.isAnimating) return const SizedBox.shrink();
                    final scale = t < 0.3 ? t / 0.3 * 1.2 : (t < 0.45 ? 1.2 - (t - 0.3) : 1.05);
                    return Opacity(
                      opacity: t > 0.75 ? (1 - t) / 0.25 : 1,
                      child: Transform.scale(
                        scale: scale,
                        child: const Icon(
                          Icons.favorite_rounded,
                          key: Key('double-tap-heart'),
                          color: Colors.white,
                          size: 96,
                          shadows: [Shadow(blurRadius: 20, color: Colors.black26)],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(SocialPost post) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        IconButton(
          tooltip: post.likedByMe ? 'Descurtir' : 'Curtir',
          onPressed: _toggleLike,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(
              post.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(post.likedByMe),
              color: post.likedByMe ? SocialColors.like : SocialColors.ink,
              size: 27,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Comentar',
          onPressed: _openComments,
          icon: const Icon(Icons.mode_comment_outlined, color: SocialColors.ink, size: 25),
        ),
        IconButton(
          tooltip: 'Compartilhar',
          onPressed: _share,
          icon: const Icon(Icons.send_outlined, color: SocialColors.ink, size: 24),
        ),
        const Spacer(),
        if (post.media.length > 1)
          Row(
            children: [
              for (var i = 0; i < post.media.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page ? SocialColors.accent : SocialColors.line,
                  ),
                ),
            ],
          ),
        const Spacer(),
        IconButton(
          tooltip: post.savedByMe ? 'Remover dos salvos' : 'Salvar',
          onPressed: _toggleSave,
          icon: Icon(
            post.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: SocialColors.ink,
            size: 27,
          ),
        ),
      ],
    ),
  );

  Widget _caption(SocialPost post) {
    final long = post.content.length > 120 || '\n'.allMatches(post.content).length > 1;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: GestureDetector(
        onTap: long ? () => setState(() => _expanded = !_expanded) : null,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${post.author.handle} ', style: socialBold),
              TextSpan(
                text: long && !_expanded ? '${post.content.split('\n').first.characters.take(110)}… ' : post.content,
              ),
              if (long && !_expanded) const TextSpan(text: 'mais', style: TextStyle(color: SocialColors.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}
