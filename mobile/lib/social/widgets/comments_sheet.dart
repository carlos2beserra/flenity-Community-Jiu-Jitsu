import 'package:flutter/material.dart';

import '../../ui/widgets/common.dart';
import '../social_models.dart';
import 'social_ui.dart';

/// Abre os comentários em uma folha inferior. Retorna o novo total de comentários (ou null).
Future<int?> showCommentsSheet(
  BuildContext context, {
  required SocialPost post,
  required void Function(SocialAuthor author) onOpenProfile,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: SocialColors.bg,
  showDragHandle: true,
  builder: (context) => _CommentsSheet(post: post, onOpenProfile: onOpenProfile),
);

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post, required this.onOpenProfile});

  final SocialPost post;
  final void Function(SocialAuthor author) onOpenProfile;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _input = TextEditingController();
  List<SocialComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  Object? _error;
  late int _total = widget.post.comments;
  SocialProfile? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = socialApiOf(context);
    try {
      final results = await Future.wait([api.comments(widget.post.id), api.profile(null)]);
      if (!mounted) return;
      final page = results[0] as PageResult<SocialComment>;
      setState(() {
        _comments = page.items;
        _total = page.total;
        _me = results[1] as SocialProfile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await socialApiOf(context).addComment(widget.post.id, text);
      _input.clear();
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _total++;
      });
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(SocialComment comment) async {
    final ok = await confirmDialog(context, 'Apagar comentário', 'Remover este comentário?', confirm: 'Apagar');
    if (!ok || !mounted) return;
    try {
      await socialApiOf(context).deleteComment(widget.post.id, comment.id);
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((c) => c.id != comment.id).toList();
        _total--;
      });
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    }
  }

  bool _canDelete(SocialComment comment) =>
      _me != null && (comment.author.id == _me!.author.id || widget.post.author.id == _me!.author.id);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _total);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              const Text('Comentários', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              const Divider(height: 1, color: SocialColors.line),
              Expanded(child: _list()),
              const Divider(height: 1, color: SocialColors.line),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                  child: Row(
                    children: [
                      if (_me != null) SocialAvatar(author: _me!.author, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('comment-input'),
                          controller: _input,
                          maxLength: 1000,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Adicione um comentário para ${widget.post.author.handle}…',
                            counterText: '',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('comment-send'),
                        onPressed: _sending ? null : _send,
                        child: const Text('Publicar', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorView(
        message: errorText(_error),
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load();
        },
      );
    }
    if (_comments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ainda não há comentários', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Inicie a conversa.', style: TextStyle(color: SocialColors.ink2)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return ListTile(
          onLongPress: _canDelete(comment) ? () => _delete(comment) : null,
          leading: SocialAvatar(
            author: comment.author,
            size: 34,
            onTap: () {
              Navigator.pop(context, _total);
              widget.onOpenProfile(comment.author);
            },
          ),
          title: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${comment.author.handle}  ', style: socialBold.copyWith(fontSize: 13)),
                TextSpan(
                  text: relativeTime(comment.createdAt),
                  style: const TextStyle(color: SocialColors.ink2, fontSize: 12),
                ),
              ],
            ),
          ),
          subtitle: Text(comment.content, style: const TextStyle(color: SocialColors.ink, fontSize: 14)),
        );
      },
    );
  }
}
