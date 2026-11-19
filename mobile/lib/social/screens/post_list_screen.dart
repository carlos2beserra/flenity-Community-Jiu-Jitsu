import 'package:flutter/material.dart';

import '../social_models.dart';
import '../social_navigation.dart';
import '../widgets/post_card.dart';
import '../widgets/social_ui.dart';

/// Feed vertical a partir de uma grade: começa na publicação tocada e segue com as demais.
class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key, required this.title, required this.posts, required this.initialIndex});

  final String title;
  final List<SocialPost> posts;
  final int initialIndex;

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  late final List<SocialPost> _posts = List.of(widget.posts);
  String? _myId;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await socialApiOf(context).profile(null);
      if (mounted) setState(() => _myId = me.author.id);
    } catch (error) {
      debugPrint('Falha ao carregar perfil: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.initialIndex.clamp(0, _posts.isEmpty ? 0 : _posts.length - 1);
    final ordered = [..._posts.skip(start), ..._posts.take(start)];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_posts);
      },
      child: Scaffold(
        backgroundColor: SocialColors.bg,
        appBar: AppBar(
          backgroundColor: SocialColors.bg,
          title: Text(widget.title, style: socialTitleStyle.copyWith(fontSize: 18)),
        ),
        body: ListView.builder(
          itemCount: ordered.length,
          itemBuilder: (context, index) {
            final post = ordered[index];
            return PostCard(
              key: ValueKey(post.id),
              post: post,
              isMine: post.author.id == _myId,
              onOpenProfile: (author) => openProfile(context, author),
              onChanged: (next) => _replace(next),
              onDeleted: () => setState(() => _posts.removeWhere((p) => p.id == post.id)),
            );
          },
        ),
      ),
    );
  }

  void _replace(SocialPost next) {
    final index = _posts.indexWhere((p) => p.id == next.id);
    if (index >= 0) _posts[index] = next;
  }
}
