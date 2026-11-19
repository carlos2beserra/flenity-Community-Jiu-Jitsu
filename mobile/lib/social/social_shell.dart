import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import 'screens/create_content_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/home_feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reels_screen.dart';
import 'widgets/social_ui.dart';

/// Abas do app. "Criar" não é uma aba: abre a tela de criação por cima.
/// `tracks` é a aba própria de cada perfil (trilhas da faixa), entre Rolas e Perfil.
enum SocialTab { home, explore, create, reels, tracks, profile }

/// Aba extra entre Rolas e Perfil. A página só é criada na primeira visita.
class SocialExtraTab {
  const SocialExtraTab({required this.label, required this.icon, required this.builder});

  final String label;

  /// Ícone conforme a aba está selecionada e se a barra está escura (Rolas).
  final Widget Function(bool selected, bool dark) icon;
  final WidgetBuilder builder;
}

/// Item do menu do perfil (☰). `onSelected` recebe o contexto do shell.
class SocialMenuItem {
  const SocialMenuItem({required this.icon, required this.title, required this.onSelected, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final void Function(BuildContext context) onSelected;
}

/// Abre uma ferramenta (agenda, chamada, graduações…) como página com barra de título.
void openToolPage(BuildContext context, String title, Widget body, {Color background = Palette.mat}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            backgroundColor: SocialColors.bg,
            title: Text(title, style: socialTitleStyle.copyWith(fontSize: 18)),
          ),
          body: SafeArea(top: false, child: body),
        ),
      ),
    );

/// Estrutura comum do app para alunos e equipe: Início, Pesquisar, Criar, Rolas e Perfil.
/// Cada perfil acrescenta seus próprios itens de menu e atalhos no perfil.
class SocialShell extends StatefulWidget {
  const SocialShell({super.key, required this.menuItems, this.profileShortcuts, this.onProfileTitleTap, this.extraTab});

  final List<SocialMenuItem> Function(BuildContext context) menuItems;
  final Widget? profileShortcuts;
  final void Function(BuildContext context)? onProfileTitleTap;
  final SocialExtraTab? extraTab;

  @override
  State<SocialShell> createState() => _SocialShellState();
}

class _SocialShellState extends State<SocialShell> with WidgetsBindingObserver {
  SocialTab _tab = SocialTab.home;
  final _homeKey = GlobalKey<HomeFeedScreenState>();
  final _reelsKey = GlobalKey<ReelsScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();
  bool _extraVisited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _tab != SocialTab.home && mounted) {
      setState(() => _tab = SocialTab.home);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _select(SocialTab tab) {
    if (tab == SocialTab.create) {
      _create(CreateMode.post);
      return;
    }
    if (tab == _tab && tab == SocialTab.home) _homeKey.currentState?.scrollToTop();
    setState(() {
      _tab = tab;
      if (tab == SocialTab.tracks) _extraVisited = true;
    });
  }

  Future<void> _create(CreateMode mode) async {
    final result = await Navigator.of(context).push<CreatedContent>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => CreateContentScreen(initialMode: mode)),
    );
    if (result == null || !mounted) return;
    switch (result.mode) {
      case CreateMode.post:
        if (result.post != null) _homeKey.currentState?.addPost(result.post!);
        setState(() => _tab = SocialTab.home);
        showMessage(context, 'Publicação compartilhada.');
      case CreateMode.story:
        await _homeKey.currentState?.reload();
        if (mounted) showMessage(context, 'Flash publicado por 24 horas.');
      case CreateMode.reel:
        await _reelsKey.currentState?.reload();
        if (mounted) {
          setState(() => _tab = SocialTab.reels);
          showMessage(context, 'Rola publicado.');
        }
    }
    await _profileKey.currentState?.reload();
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    final session = context.read<Session>();
    try {
      if (enabled) {
        await session.disableBiometrics();
        if (mounted) showMessage(context, 'Entrada com biometria desativada neste aparelho.');
      } else {
        await session.enableBiometrics();
        if (mounted) showMessage(context, 'Pronto! Na próxima vez, entre com sua digital ou Face ID.');
      }
    } on BiometricCancelled {
      if (mounted) showMessage(context, 'Biometria não confirmada. Nada foi alterado.', error: true);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    }
  }

  Future<void> _openMenu() async {
    final session = context.read<Session>();
    final items = widget.menuItems(context);
    final biometricsAvailable = await session.canUseBiometrics();
    final biometricsEnabled = biometricsAvailable && await session.biometricLoginEmail() != null;
    if (!mounted) return;
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: SocialColors.bg,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                ListTile(
                  leading: Icon(items[i].icon, color: SocialColors.ink),
                  title: Text(items[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: items[i].subtitle == null ? null : Text(items[i].subtitle!),
                  onTap: () => Navigator.pop(context, i),
                ),
              if (biometricsAvailable)
                ListTile(
                  key: const Key('menu-biometrics'),
                  leading: const Icon(Icons.fingerprint_rounded, color: SocialColors.ink),
                  title: const Text('Entrar com biometria', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    biometricsEnabled ? 'Ativada neste aparelho' : 'Digital ou Face ID, sem digitar a senha',
                  ),
                  trailing: Switch(value: biometricsEnabled, onChanged: (_) => Navigator.pop(context, -2)),
                  onTap: () => Navigator.pop(context, -2),
                ),
              const Divider(color: SocialColors.line),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: SocialColors.like),
                title: const Text(
                  'Sair',
                  style: TextStyle(color: SocialColors.like, fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(context, -1),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == -1) {
      await session.logout();
      return;
    }
    if (choice == -2) {
      await _toggleBiometrics(biometricsEnabled);
      return;
    }
    items[choice].onSelected(context);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final dark = _tab == SocialTab.reels;
    final extraTab = widget.extraTab;
    return Scaffold(
      backgroundColor: dark ? Colors.black : SocialColors.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          key: ValueKey(session.studentContextVersion),
          index: switch (_tab) {
            SocialTab.home || SocialTab.create => 0,
            SocialTab.explore => 1,
            SocialTab.reels => 2,
            SocialTab.tracks => 3,
            SocialTab.profile => 4,
          },
          children: [
            HomeFeedScreen(
              key: _homeKey,
              onCreateStory: () => _create(CreateMode.story),
              onCreatePost: () => _create(CreateMode.post),
            ),
            ExploreScreen(active: _tab == SocialTab.explore),
            ReelsScreen(key: _reelsKey, active: _tab == SocialTab.reels, onCreateReel: () => _create(CreateMode.reel)),
            if (extraTab != null && _extraVisited) Builder(builder: extraTab.builder) else const SizedBox.shrink(),
            // O perfil só carrega na primeira visita à aba.
            if (_tab == SocialTab.profile || _profileKey.currentState != null)
              ProfileScreen(
                key: _profileKey,
                embedded: true,
                onOpenMenu: _openMenu,
                onCreate: () => _create(CreateMode.post),
                onTitleTap: widget.onProfileTitleTap == null ? null : () => widget.onProfileTitleTap!(context),
                shortcuts: widget.profileShortcuts,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(selected: _tab, dark: dark, onSelect: _select, extraTab: extraTab),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.selected, required this.dark, required this.onSelect, this.extraTab});

  final SocialTab selected;
  final bool dark;
  final ValueChanged<SocialTab> onSelect;
  final SocialExtraTab? extraTab;

  static const _items = [
    (SocialTab.home, Icons.home_outlined, Icons.home_rounded, 'Início'),
    (SocialTab.explore, Icons.search_rounded, Icons.saved_search_rounded, 'Pesquisar'),
    (SocialTab.create, Icons.add_box_outlined, Icons.add_box_outlined, 'Criar'),
    (SocialTab.reels, Icons.movie_outlined, Icons.movie_rounded, 'Rolas'),
  ];
  static const _profile = (SocialTab.profile, Icons.person_outline, Icons.person_rounded, 'Perfil');

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : SocialColors.ink;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? Colors.black : SocialColors.bg,
        border: Border(top: BorderSide(color: dark ? Colors.white12 : SocialColors.line, width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              for (final item in _items) _button(item, fg),
              if (extraTab case final tab?)
                Expanded(
                  child: IconButton(
                    key: const Key('tab-tracks'),
                    tooltip: tab.label,
                    onPressed: () => onSelect(SocialTab.tracks),
                    icon: tab.icon(selected == SocialTab.tracks, dark),
                  ),
                ),
              _button(_profile, fg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button((SocialTab, IconData, IconData, String) item, Color fg) {
    final (tab, icon, selectedIcon, label) = item;
    return Expanded(
      child: IconButton(
        tooltip: label,
        onPressed: () => onSelect(tab),
        icon: Icon(selected == tab ? selectedIcon : icon, color: fg, size: 28),
      ),
    );
  }
}
