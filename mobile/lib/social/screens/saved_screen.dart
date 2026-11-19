import 'package:flutter/material.dart';

import '../../ui/widgets/common.dart';
import '../social_models.dart';
import '../social_navigation.dart';
import '../widgets/social_ui.dart';

/// Coleção privada de publicações salvas.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<SocialPost>? _posts;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await socialApiOf(context).saved();
      if (mounted) setState(() => _posts = page.items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _open(int index) async {
    final updated = await openPostList(context, title: 'Salvos', posts: _posts!, initialIndex: index);
    if (updated != null && mounted) setState(() => _posts = updated.where((post) => post.savedByMe).toList());
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    return Scaffold(
      backgroundColor: SocialColors.bg,
      appBar: AppBar(
        backgroundColor: SocialColors.bg,
        title: Text('Salvos', style: socialTitleStyle.copyWith(fontSize: 18)),
      ),
      body: _error != null
          ? ErrorView(message: errorText(_error), onRetry: _load)
          : posts == null
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Toque no marcador de uma publicação para guardá-la aqui. Só você vê seus salvos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SocialColors.ink2),
                ),
              ),
            )
          : CustomScrollView(slivers: [PostGrid(posts: posts, onTap: _open)]),
    );
  }
}
