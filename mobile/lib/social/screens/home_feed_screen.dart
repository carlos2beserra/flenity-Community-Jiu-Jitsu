import 'package:flutter/material.dart';

import '../../screens/chat_screen.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/flenity_logo.dart';
import '../social_api.dart';
import '../social_models.dart';
import '../social_navigation.dart';
import '../widgets/post_card.dart';
import '../widgets/social_ui.dart';
import '../widgets/story_bar.dart';
import 'notifications_screen.dart';
import 'story_viewer_screen.dart';

/// Início: stories no topo e o feed da academia ("Para você") ou só de quem o aluno segue.
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key, required this.onCreateStory, required this.onCreatePost});

  final VoidCallback onCreateStory;
  final VoidCallback onCreatePost;

  @override
  State<HomeFeedScreen> createState() => HomeFeedScreenState();
}

class HomeFeedScreenState extends State<HomeFeedScreen> {
  final _scroll = ScrollController();
  FeedScope _scope = FeedScope.all;
  List<SocialPost> _posts = const [];
  PageResult<SocialPost>? _lastPage;
  List<StoryGroup> _stories = const [];
  SocialProfile? _me;
  int _unread = 0;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final api = socialApiOf(context);
    _loading = true;
    try {
      final results = await Future.wait([
        api.feed(scope: _scope),
        api.stories(),
        api.profile(null),
        api.unreadNotifications(),
      ]);
      if (!mounted) return;
      setState(() {
        _lastPage = results[0] as PageResult<SocialPost>;
        _posts = _lastPage!.items;
        _stories = results[1] as List<StoryGroup>;
        _me = results[2] as SocialProfile;
        _unread = results[3] as int;
        _loaded = true;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _loading = false;
    }
  }

  Future<void> _loadMore() async {
    final last = _lastPage;
    if (_loading || last == null || !last.hasMore) return;
    _loading = true;
    try {
      final page = await socialApiOf(context).feed(scope: _scope, page: last.page + 1);
      if (!mounted) return;
      setState(() {
        _lastPage = page;
        final known = _posts.map((post) => post.id).toSet();
        _posts = [..._posts, ...page.items.where((post) => !known.contains(post.id))];
      });
    } catch (error) {
      debugPrint('Falha ao carregar mais publicações: $error');
    } finally {
      _loading = false;
    }
  }

  /// Rola para o topo (toque na aba Início já selecionada).
  void scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  void addPost(SocialPost post) {
    setState(() => _posts = [post, ..._posts]);
    scrollToTop();
  }

  void _setScope(FeedScope scope) {
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      _loaded = false;
    });
    reload();
  }

  Future<void> _openStories(int index) async {
    await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => StoryViewerScreen(
          groups: _stories,
          initialGroup: index,
          onOpenProfile: (author) => openProfile(context, author),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(animation), child: child)),
      ),
    );
    if (!mounted) return;
    try {
      final stories = await socialApiOf(context).stories();
      if (mounted) setState(() => _stories = stories);
    } catch (error) {
      debugPrint('Falha ao atualizar stories: $error');
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
    if (mounted) setState(() => _unread = 0);
  }

  void _openMessages() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Palette.mat,
        appBar: AppBar(backgroundColor: SocialColors.bg, title: Text('Mensagens', style: socialTitleStyle.copyWith(fontSize: 18))),
        body: const SafeArea(top: false, child: ChatScreen()),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SocialColors.bg,
    child: RefreshIndicator(
      onRefresh: reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) => loadMoreWhenNearEnd(notification, _loadMore),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: SocialColors.bg,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 16,
              title: _scopeMenu(),
              actions: [
                IconButton(
                  tooltip: 'Notificações',
                  onPressed: _openNotifications,
                  icon: Badge(
                    isLabelVisible: _unread > 0,
                    label: Text(_unread > 9 ? '9+' : '$_unread'),
                    backgroundColor: SocialColors.like,
                    child: const Icon(Icons.favorite_border_rounded, color: SocialColors.ink, size: 27),
                  ),
                ),
                IconButton(
                  tooltip: 'Mensagens',
                  onPressed: _openMessages,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: SocialColors.ink, size: 25),
                ),
                const SizedBox(width: 4),
              ],
            ),
            if (_error != null && !_loaded)
              SliverFillRemaining(child: ErrorView(message: errorText(_error), onRetry: reload))
            else if (!_loaded)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else ...[
              SliverToBoxAdapter(
                child: StoryBar(
                  me: _me?.author,
                  groups: _stories,
                  onAddStory: widget.onCreateStory,
                  onOpen: _openStories,
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1, color: SocialColors.line)),
              if (_posts.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _empty())
              else
                SliverList.builder(
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return PostCard(
                      key: ValueKey(post.id),
                      post: post,
                      isMine: post.author.id == _me?.author.id,
                      onOpenProfile: (author) => openProfile(context, author),
                      onChanged: (next) => _posts = [for (final p in _posts) p.id == next.id ? next : p],
                      onDeleted: () => setState(() => _posts = _posts.where((p) => p.id != post.id).toList()),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _scopeMenu() => PopupMenuButton<FeedScope>(
    tooltip: 'Escolher feed',
    onSelected: _setScope,
    position: PopupMenuPosition.under,
    itemBuilder: (_) => [
      CheckedPopupMenuItem(value: FeedScope.all, checked: _scope == FeedScope.all, child: const Text('Para você')),
      CheckedPopupMenuItem(
        value: FeedScope.following,
        checked: _scope == FeedScope.following,
        child: const Text('Seguindo'),
      ),
    ],
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FlenityLogo(size: 28),
        const SizedBox(width: 8),
        Text(_scope == FeedScope.all ? 'Flenity' : 'Seguindo', style: displayStyle(26, color: SocialColors.ink)),
        const SizedBox(width: 2),
        const Icon(Icons.keyboard_arrow_down_rounded, color: SocialColors.ink),
      ],
    ),
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.sports_martial_arts_rounded, size: 56, color: SocialColors.ink),
        const SizedBox(height: 12),
        Text(
          _scope == FeedScope.following ? 'Siga colegas de treino' : 'Bem-vindo à comunidade',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          _scope == FeedScope.following
              ? 'Publicações de quem você segue aparecem aqui. Encontre pessoas na busca.'
              : 'Seja o primeiro a compartilhar um treino, uma técnica ou uma conquista.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: SocialColors.ink2),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: widget.onCreatePost, child: const Text('Criar publicação')),
      ],
    ),
  );
}
