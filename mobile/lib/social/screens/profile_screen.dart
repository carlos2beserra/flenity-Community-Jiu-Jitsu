import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/widgets/belt_badge.dart';
import '../../ui/widgets/common.dart';
import '../social_models.dart';
import '../social_navigation.dart';
import '../widgets/social_ui.dart';
import 'edit_profile_screen.dart';
import 'follow_list_screen.dart';

/// Perfil de um aluno na comunidade: cabeçalho com contadores, bio e faixa, e grade de
/// publicações, rolas e (no próprio perfil) itens salvos.
/// `studentId == null` abre o perfil do próprio aluno.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.studentId,
    this.title,
    this.embedded = false,
    this.onOpenMenu,
    this.onCreate,
    this.onTitleTap,
    this.shortcuts,
  });

  final String? studentId;
  final String? title;

  /// Aba "Perfil" do app (sem botão voltar, com menu e botão de criar).
  final bool embedded;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onCreate;

  /// Toque no @usuário do topo (no app: trocar de academia).
  final VoidCallback? onTitleTap;

  /// Atalhos extras abaixo dos botões do próprio perfil (ex.: painel do professor).
  final Widget? shortcuts;

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  SocialProfile? _profile;
  Object? _error;
  bool _followBusy = false;
  final Map<int, List<SocialPost>> _tabs = {};
  final Map<int, PageResult<SocialPost>> _lastPage = {};
  final Set<int> _loadingTabs = {};
  TabController? _tabController;

  int get _tabCount => _profile?.isMe == true ? 3 : 2;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final profile = await socialApiOf(context).profile(widget.studentId);
      if (!mounted) return;
      final needsController = _tabController == null || _tabController!.length != (profile.isMe ? 3 : 2);
      setState(() {
        _profile = profile;
        _error = null;
        if (needsController) {
          _tabController?.dispose();
          _tabController = TabController(length: profile.isMe ? 3 : 2, vsync: this)
            ..addListener(() {
              if (!_tabController!.indexIsChanging) _loadTab(_tabController!.index);
            });
        }
        _tabs.clear();
        _lastPage.clear();
      });
      await _loadTab(_tabController!.index);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _loadTab(int tab, {bool more = false}) async {
    final profile = _profile;
    if (profile == null || _loadingTabs.contains(tab)) return;
    if (!more && _tabs.containsKey(tab)) return;
    if (more && !(_lastPage[tab]?.hasMore ?? false)) return;
    final page = more ? (_lastPage[tab]!.page + 1) : 1;
    _loadingTabs.add(tab);
    try {
      final api = socialApiOf(context);
      final result = switch (tab) {
        0 => await api.feed(authorId: profile.author.id, kind: PostKind.post, page: page, pageSize: 21),
        1 => await api.feed(authorId: profile.author.id, kind: PostKind.reel, page: page, pageSize: 21),
        _ => await api.saved(page: page),
      };
      if (!mounted) return;
      setState(() {
        _tabs[tab] = [...?(more ? _tabs[tab] : null), ...result.items];
        _lastPage[tab] = result;
      });
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      _loadingTabs.remove(tab);
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile!;
    setState(() => _followBusy = true);
    try {
      final following = await socialApiOf(context).toggleFollow(profile.author.id);
      if (!mounted) return;
      setState(() {
        _profile = profile.copyWith(
          isFollowing: following,
          followers: profile.followers + (following == profile.isFollowing ? 0 : (following ? 1 : -1)),
        );
      });
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _openTabPost(int tab, int index) async {
    final posts = _tabs[tab] ?? const <SocialPost>[];
    final updated = await openPostList(
      context,
      title: tab == 2 ? 'Salvos' : (tab == 1 ? 'Rolas' : 'Publicações'),
      posts: posts,
      initialIndex: index,
    );
    if (updated == null || !mounted) return;
    final removed = posts.length - updated.length;
    setState(() {
      _tabs[tab] = tab == 2 ? updated.where((post) => post.savedByMe).toList() : updated;
      if (removed > 0 && _profile != null) reload();
    });
  }

  Future<void> _editProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: _profile!)),
    );
    if (changed == true) await reload();
  }

  void _openFollows(FollowTab tab) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FollowListScreen(profile: _profile!, initialTab: tab)),
  );

  Future<void> _shareProfile() async {
    await Clipboard.setData(ClipboardData(text: '@${_profile!.author.handle} na comunidade ${_profile!.academyName}'));
    if (mounted) showMessage(context, 'Perfil copiado para compartilhar.');
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final title = profile?.author.handle ?? widget.title ?? '';
    return Scaffold(
      backgroundColor: SocialColors.bg,
      appBar: AppBar(
        backgroundColor: SocialColors.bg,
        automaticallyImplyLeading: !widget.embedded,
        titleSpacing: widget.embedded ? 16 : null,
        title: GestureDetector(
          key: const Key('profile-title'),
          onTap: widget.onTitleTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: socialTitleStyle.copyWith(fontSize: 20))),
              if (widget.onTitleTap != null)
                const Icon(Icons.keyboard_arrow_down_rounded, color: SocialColors.ink, semanticLabel: 'Trocar de academia'),
            ],
          ),
        ),
        actions: [
          if (widget.onCreate != null)
            IconButton(
              tooltip: 'Criar',
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add_box_outlined, color: SocialColors.ink),
            ),
          if (widget.onOpenMenu != null)
            IconButton(
              tooltip: 'Menu',
              onPressed: widget.onOpenMenu,
              icon: const Icon(Icons.menu_rounded, color: SocialColors.ink),
            ),
        ],
      ),
      body: _body(profile),
    );
  }

  Widget _body(SocialProfile? profile) {
    if (_error != null && profile == null) return ErrorView(message: errorText(_error), onRetry: reload);
    if (profile == null || _tabController == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            loadMoreWhenNearEnd(notification, () => _loadTab(_tabController!.index, more: true)),
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: _header(profile)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: SocialColors.ink,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: SocialColors.ink,
                  unselectedLabelColor: SocialColors.ink2,
                  dividerColor: SocialColors.line,
                  tabs: [
                    const Tab(icon: Icon(Icons.grid_on_rounded, semanticLabel: 'Publicações')),
                    const Tab(icon: Icon(Icons.movie_outlined, semanticLabel: 'Rolas')),
                    if (_tabCount == 3) const Tab(icon: Icon(Icons.bookmark_border_rounded, semanticLabel: 'Salvos')),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [for (var tab = 0; tab < _tabCount; tab++) _grid(tab)],
          ),
        ),
      ),
    );
  }

  Widget _grid(int tab) {
    final posts = _tabs[tab];
    if (posts == null) return const Center(child: CircularProgressIndicator());
    if (posts.isEmpty) {
      final (icon, title, subtitle) = switch (tab) {
        0 => (Icons.photo_camera_outlined, 'Nenhuma publicação ainda', 'Fotos e textos aparecem aqui.'),
        1 => (Icons.movie_outlined, 'Nenhum rola ainda', 'Vídeos curtos aparecem aqui.'),
        _ => (Icons.bookmark_border_rounded, 'Nada salvo', 'Salve publicações para ver depois. Só você vê seus salvos.'),
      };
      return ListView(
        padding: const EdgeInsets.all(40),
        children: [
          Icon(icon, size: 56, color: SocialColors.ink),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: SocialColors.ink2)),
        ],
      );
    }
    return CustomScrollView(
      key: PageStorageKey('profile-tab-$tab'),
      slivers: [PostGrid(posts: posts, reelAspect: tab == 1, onTap: (index) => _openTabPost(tab, index))],
    );
  }

  Widget _header(SocialProfile profile) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SocialAvatar(author: profile.author, size: 84),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  for (final count in [
                    _Count(value: profile.posts, label: 'publicações'),
                    _Count(value: profile.followers, label: 'seguidores', onTap: () => _openFollows(FollowTab.followers)),
                    _Count(value: profile.following, label: 'seguindo', onTap: () => _openFollows(FollowTab.following)),
                  ])
                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: count)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Flexible(child: Text(profile.author.name, style: socialBold.copyWith(fontSize: 15))),
            RoleBadge(author: profile.author),
          ],
        ),
        if (profile.belt != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                BeltBadge(color: profile.belt!.color, degree: profile.belt!.degree, width: 54, height: 10),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Faixa ${profile.belt!.name.toLowerCase()}'
                    '${profile.belt!.degree > 0 ? ' · ${profile.belt!.degree}º grau' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: SocialColors.ink2, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (profile.academyName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(profile.academyName, style: const TextStyle(color: SocialColors.ink2, fontSize: 13)),
          ),
        if (profile.bio.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(profile.bio)),
        const SizedBox(height: 12),
        Row(
          children: profile.isMe
              ? [
                  Expanded(child: SocialSecondaryButton(label: 'Editar perfil', onPressed: _editProfile)),
                  const SizedBox(width: 6),
                  Expanded(child: SocialSecondaryButton(label: 'Compartilhar perfil', onPressed: _shareProfile)),
                ]
              : [
                  Expanded(
                    child: FollowButton(
                      key: const Key('profile-follow'),
                      following: profile.isFollowing,
                      busy: _followBusy,
                      onPressed: _toggleFollow,
                    ),
                  ),
                  if (profile.followsMe && !profile.isFollowing) ...[
                    const SizedBox(width: 8),
                    const Text('Segue você', style: TextStyle(color: SocialColors.ink2, fontSize: 12)),
                  ],
                ],
        ),
        if (profile.isMe && widget.shortcuts != null) ...[const SizedBox(height: 12), widget.shortcuts!],
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: [
          Text(compactCount(value), style: socialBold.copyWith(fontSize: 17)),
          Text(label, style: const TextStyle(fontSize: 13, color: SocialColors.ink)),
        ],
      ),
    ),
  );
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: SocialColors.bg, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => oldDelegate.tabBar != tabBar;
}
