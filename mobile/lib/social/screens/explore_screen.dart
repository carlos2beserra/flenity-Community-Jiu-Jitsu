import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/widgets/common.dart';
import '../social_models.dart';
import '../social_navigation.dart';
import '../widgets/social_ui.dart';
import 'follow_list_screen.dart';

/// Explorar: busca de pessoas da academia e grade das publicações em alta.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.active = true});

  final bool active;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<SocialPost> _posts = const [];
  PageResult<SocialPost>? _lastPage;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _searching = _focus.hasFocus || _query.isNotEmpty));
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_loaded) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading || (more && !(_lastPage?.hasMore ?? false))) return;
    _loading = true;
    try {
      final page = await socialApiOf(context).explore(page: more ? _lastPage!.page + 1 : 1);
      if (!mounted) return;
      setState(() {
        _posts = more ? [..._posts, ...page.items] : page.items;
        _lastPage = page;
        _loaded = true;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _loading = false;
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _cancelSearch() {
    _search.clear();
    _focus.unfocus();
    setState(() {
      _query = '';
      _searching = false;
    });
  }

  Future<void> _open(int index) async {
    final updated = await openPostList(context, title: 'Explorar', posts: _posts, initialIndex: index);
    if (updated != null && mounted) setState(() => _posts = updated);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SocialColors.bg,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('explore-search'),
                  controller: _search,
                  focusNode: _focus,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar pessoas da academia',
                    prefixIcon: const Icon(Icons.search_rounded, color: SocialColors.ink2),
                    filled: true,
                    fillColor: SocialColors.surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (_searching) TextButton(onPressed: _cancelSearch, child: const Text('Cancelar')),
            ],
          ),
        ),
        Expanded(child: _searching ? _results() : _grid()),
      ],
    ),
  );

  Widget _results() => PeopleList(
    key: ValueKey('search-$_query'),
    load: (api) => api.people(search: _query.isEmpty ? null : _query),
    emptyText: _query.isEmpty ? 'Ninguém da academia ainda.' : 'Nenhum resultado para "$_query".',
  );

  Widget _grid() {
    if (_error != null && _posts.isEmpty) return ErrorView(message: errorText(_error), onRetry: _load);
    if (!_loaded) return widget.active ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink();
    if (_posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Quando a comunidade publicar fotos e vídeos, os destaques aparecem aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SocialColors.ink2),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) => loadMoreWhenNearEnd(notification, () => _load(more: true)),
        child: CustomScrollView(slivers: [PostGrid(posts: _posts, onTap: _open)]),
      ),
    );
  }
}
