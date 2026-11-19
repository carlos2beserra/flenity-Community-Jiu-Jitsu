import 'package:flutter/material.dart';

import '../../ui/widgets/common.dart';
import '../social_api.dart';
import '../social_models.dart';
import '../social_navigation.dart';
import '../widgets/social_ui.dart';

enum FollowTab { followers, following }

class FollowListScreen extends StatefulWidget {
  const FollowListScreen({super.key, required this.profile, required this.initialTab});

  final SocialProfile profile;
  final FollowTab initialTab;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: widget.initialTab.index,
    child: Scaffold(
      backgroundColor: SocialColors.bg,
      appBar: AppBar(
        backgroundColor: SocialColors.bg,
        title: Text(widget.profile.author.handle, style: socialTitleStyle.copyWith(fontSize: 18)),
        bottom: TabBar(
          indicatorColor: SocialColors.ink,
          labelColor: SocialColors.ink,
          unselectedLabelColor: SocialColors.ink2,
          tabs: [
            Tab(text: '${compactCount(widget.profile.followers)} seguidores'),
            Tab(text: '${compactCount(widget.profile.following)} seguindo'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          PeopleList(load: (api) => api.followers(widget.profile.author.id)),
          PeopleList(load: (api) => api.following(widget.profile.author.id)),
        ],
      ),
    ),
  );
}

/// Lista de pessoas com botão de seguir (seguidores, seguindo e busca).
class PeopleList extends StatefulWidget {
  const PeopleList({super.key, required this.load, this.emptyText = 'Ninguém por aqui ainda.'});

  final Future<PageResult<SocialPerson>> Function(SocialApi api) load;
  final String emptyText;

  @override
  State<PeopleList> createState() => _PeopleListState();
}

class _PeopleListState extends State<PeopleList> {
  List<SocialPerson>? _people;
  Object? _error;
  final Map<String, bool> _following = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PeopleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) _load();
  }

  Future<void> _load() async {
    try {
      final page = await widget.load(socialApiOf(context));
      if (!mounted) return;
      setState(() {
        _people = page.items;
        _error = null;
        _following
          ..clear()
          ..addEntries(page.items.map((p) => MapEntry(p.author.id, p.isFollowing)));
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _toggle(SocialPerson person) async {
    setState(() => _busy.add(person.author.id));
    try {
      final following = await socialApiOf(context).toggleFollow(person.author.id);
      if (mounted) setState(() => _following[person.author.id] = following);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(person.author.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: errorText(_error), onRetry: _load);
    final people = _people;
    if (people == null) return const Center(child: CircularProgressIndicator());
    if (people.isEmpty) {
      return Center(child: Text(widget.emptyText, style: const TextStyle(color: SocialColors.ink2)));
    }
    return ListView.builder(
      itemCount: people.length,
      itemBuilder: (context, index) {
        final person = people[index];
        return ListTile(
          onTap: () => openProfile(context, person.author),
          leading: SocialAvatar(author: person.author, size: 46),
          title: AuthorHandle(author: person.author),
          subtitle: Text(person.author.name, style: const TextStyle(color: SocialColors.ink2)),
          trailing: person.isMe
              ? null
              : FollowButton(
                  dense: true,
                  following: _following[person.author.id] ?? false,
                  busy: _busy.contains(person.author.id),
                  onPressed: () => _toggle(person),
                ),
        );
      },
    );
  }
}
