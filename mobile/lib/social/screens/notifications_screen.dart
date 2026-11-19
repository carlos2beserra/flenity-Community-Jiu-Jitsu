import 'package:flutter/material.dart';

import '../../ui/widgets/common.dart';
import '../social_models.dart';
import '../social_navigation.dart';
import '../widgets/social_ui.dart';

/// Atividade: curtidas, comentários e novos seguidores, agrupados por período.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<SocialNotification>? _items;
  Object? _error;
  final Map<String, bool> _following = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = socialApiOf(context);
    try {
      final page = await api.notifications();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _error = null;
        for (final item in page.items) {
          _following[item.actor.id] = item.followingActor;
        }
      });
      if (page.items.any((item) => !item.read)) await api.markNotificationsRead();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _toggleFollow(SocialAuthor actor) async {
    try {
      final following = await socialApiOf(context).toggleFollow(actor.id);
      if (mounted) setState(() => _following[actor.id] = following);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    }
  }

  Future<void> _openPost(String postId) async {
    try {
      final post = await socialApiOf(context).post(postId);
      if (!mounted) return;
      await openPostList(context, title: 'Publicação', posts: [post], initialIndex: 0);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SocialColors.bg,
    appBar: AppBar(
      backgroundColor: SocialColors.bg,
      title: Text('Notificações', style: socialTitleStyle.copyWith(fontSize: 20)),
    ),
    body: _body(),
  );

  Widget _body() {
    if (_error != null) return ErrorView(message: errorText(_error), onRetry: _load);
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border_rounded, size: 56),
              SizedBox(height: 12),
              Text('Atividade da comunidade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text(
                'Quando alguém curtir, comentar ou seguir você, aparece aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SocialColors.ink2),
              ),
            ],
          ),
        ),
      );
    }
    final now = DateTime.now();
    final sections = <String, List<SocialNotification>>{};
    for (final item in items) {
      final age = now.difference(item.createdAt);
      final label = age.inHours < 24 ? 'Hoje' : (age.inDays < 7 ? 'Últimos 7 dias' : 'Anteriores');
      sections.putIfAbsent(label, () => []).add(item);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          for (final entry in sections.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(entry.key, style: socialBold.copyWith(fontSize: 16)),
            ),
            for (final item in entry.value) _tile(item),
          ],
        ],
      ),
    );
  }

  Widget _tile(SocialNotification item) {
    final text = switch (item.type) {
      NotificationType.like => ' curtiu sua publicação.',
      NotificationType.comment => ' comentou na sua publicação.',
      NotificationType.follow => ' começou a seguir você.',
    };
    final Widget? trailing = switch (item.type) {
      NotificationType.follow => FollowButton(
        dense: true,
        following: _following[item.actor.id] ?? false,
        onPressed: () => _toggleFollow(item.actor),
      ),
      _ when item.thumbnail != null && !item.thumbnail!.isVideo => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox.square(dimension: 44, child: MediaView(media: item.thumbnail!)),
      ),
      _ => null,
    };
    return ListTile(
      tileColor: item.read ? null : SocialColors.accent.withValues(alpha: 0.05),
      onTap: item.postId != null ? () => _openPost(item.postId!) : () => openProfile(context, item.actor),
      leading: SocialAvatar(author: item.actor, size: 44, onTap: () => openProfile(context, item.actor)),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: item.actor.handle, style: socialBold),
            TextSpan(text: text),
            TextSpan(
              text: ' ${relativeTime(item.createdAt)}',
              style: const TextStyle(color: SocialColors.ink2),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 14),
      ),
      trailing: trailing,
    );
  }
}
