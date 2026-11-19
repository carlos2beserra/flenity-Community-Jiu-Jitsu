import 'package:flutter/material.dart';

import 'screens/post_list_screen.dart';
import 'screens/profile_screen.dart';
import 'social_models.dart';

/// Abre o perfil de um aluno da comunidade.
Future<void> openProfile(BuildContext context, SocialAuthor author) => Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => ProfileScreen(studentId: author.id, title: author.handle)),
);

/// Abre uma lista de publicações (perfil, explorar, salvos) começando pela tocada.
/// Retorna a lista atualizada (curtidas, salvos, publicações apagadas).
Future<List<SocialPost>?> openPostList(
  BuildContext context, {
  required String title,
  required List<SocialPost> posts,
  required int initialIndex,
}) => Navigator.of(context).push(
  MaterialPageRoute<List<SocialPost>>(
    builder: (_) => PostListScreen(title: title, posts: posts, initialIndex: initialIndex),
  ),
);
