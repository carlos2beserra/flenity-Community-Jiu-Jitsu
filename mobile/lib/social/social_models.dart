import '../models/models.dart' show Json;

export '../models/models.dart' show Json;

DateTime _date(Object? value) => DateTime.parse(value as String).toLocal();

/// Página de uma listagem da API (`{ items, total, page, pageSize }`).
class PageResult<T> {
  const PageResult({required this.items, required this.total, required this.page, required this.pageSize});

  factory PageResult.fromJson(Json json, T Function(Json) parse) => PageResult(
    items: (json['items'] as List).map((item) => parse(item as Json)).toList(),
    total: json['total'] as int? ?? 0,
    page: json['page'] as int? ?? 1,
    pageSize: json['pageSize'] as int? ?? 20,
  );

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;
}

/// Autor de conteúdo na comunidade: um aluno ou alguém da equipe (professor, administração).
class SocialAuthor {
  const SocialAuthor({
    required this.id,
    required this.name,
    required this.handle,
    this.avatarUrl,
    this.isStaff = false,
    this.roleLabel,
  });

  factory SocialAuthor.fromJson(Json json) {
    final name = json['name'] as String? ?? '';
    return SocialAuthor(
      id: json['id'] as String,
      name: name,
      handle: json['handle'] as String? ?? handleFromName(name),
      avatarUrl: json['avatarUrl'] as String?,
      isStaff: json['isStaff'] as bool? ?? false,
      roleLabel: json['roleLabel'] as String?,
    );
  }

  final String id;
  final String name;
  final String handle;
  final String? avatarUrl;
  final bool isStaff;

  /// "Professor" ou "Equipe" para a equipe da academia; null para alunos.
  final String? roleLabel;
}

/// Mesmo critério da API: "Ana Silva" → "ana.silva".
String handleFromName(String name) {
  const accents = {'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'é': 'e', 'ê': 'e', 'è': 'e', 'í': 'i', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ú': 'u', 'ü': 'u', 'ç': 'c'};
  final plain = name.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  final handle = plain.trim().replaceAll(RegExp(r'[^a-z0-9]+'), '.').replaceAll(RegExp(r'^\.+|\.+$'), '');
  return handle.isEmpty ? 'aluno' : handle;
}

enum MediaKind { image, video }

class SocialMedia {
  const SocialMedia({required this.id, required this.kind, required this.url});

  factory SocialMedia.fromJson(Json json) => SocialMedia(
    id: json['id'] as String,
    kind: json['kind'] == 'VIDEO' ? MediaKind.video : MediaKind.image,
    url: json['url'] as String,
  );

  final String id;
  final MediaKind kind;
  final String url;

  bool get isVideo => kind == MediaKind.video;
}

class SocialComment {
  const SocialComment({required this.id, required this.content, required this.createdAt, required this.author});

  factory SocialComment.fromJson(Json json) => SocialComment(
    id: json['id'] as String,
    content: json['content'] as String,
    createdAt: _date(json['createdAt']),
    author: SocialAuthor.fromJson((json['author'] ?? json['student']) as Json),
  );

  final String id;
  final String content;
  final DateTime createdAt;
  final SocialAuthor author;
}

enum PostKind { post, reel }

class SocialPost {
  const SocialPost({
    required this.id,
    required this.kind,
    required this.content,
    required this.createdAt,
    required this.author,
    required this.media,
    required this.likes,
    required this.comments,
    required this.likedByMe,
    required this.savedByMe,
    required this.recentComments,
  });

  factory SocialPost.fromJson(Json json) {
    final counts = json['_count'] as Json? ?? const {};
    return SocialPost(
      id: json['id'] as String,
      kind: json['kind'] == 'REEL' ? PostKind.reel : PostKind.post,
      content: json['content'] as String? ?? '',
      createdAt: _date(json['createdAt']),
      author: SocialAuthor.fromJson(json['author'] as Json),
      media: [for (final m in json['media'] as List? ?? const []) SocialMedia.fromJson(m as Json)],
      likes: counts['likes'] as int? ?? 0,
      comments: counts['comments'] as int? ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      savedByMe: json['savedByMe'] as bool? ?? false,
      recentComments: [for (final c in json['comments'] as List? ?? const []) SocialComment.fromJson(c as Json)],
    );
  }

  final String id;
  final PostKind kind;
  final String content;
  final DateTime createdAt;
  final SocialAuthor author;
  final List<SocialMedia> media;
  final int likes;
  final int comments;
  final bool likedByMe;
  final bool savedByMe;
  final List<SocialComment> recentComments;

  bool get isReel => kind == PostKind.reel;
  SocialMedia? get cover => media.isEmpty ? null : media.first;

  SocialPost copyWith({int? likes, int? comments, bool? likedByMe, bool? savedByMe, List<SocialComment>? recentComments}) =>
      SocialPost(
        id: id,
        kind: kind,
        content: content,
        createdAt: createdAt,
        author: author,
        media: media,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        recentComments: recentComments ?? this.recentComments,
      );
}

class SocialBelt {
  const SocialBelt({required this.name, required this.color, required this.degree});

  final String name;
  final String color;
  final int degree;
}

class SocialProfile {
  const SocialProfile({
    required this.author,
    required this.bio,
    required this.academyName,
    required this.posts,
    required this.followers,
    required this.following,
    required this.isMe,
    required this.isFollowing,
    required this.followsMe,
    this.belt,
  });

  factory SocialProfile.fromJson(Json json) {
    final counts = json['counts'] as Json? ?? const {};
    final belt = json['belt'] as Json?;
    return SocialProfile(
      author: SocialAuthor.fromJson(json),
      bio: json['bio'] as String? ?? '',
      academyName: json['academyName'] as String? ?? '',
      posts: counts['posts'] as int? ?? 0,
      followers: counts['followers'] as int? ?? 0,
      following: counts['following'] as int? ?? 0,
      isMe: json['isMe'] as bool? ?? false,
      isFollowing: json['isFollowing'] as bool? ?? false,
      followsMe: json['followsMe'] as bool? ?? false,
      belt: belt == null
          ? null
          : SocialBelt(name: belt['name'] as String, color: belt['color'] as String, degree: belt['degree'] as int? ?? 0),
    );
  }

  final SocialAuthor author;
  final String bio;
  final String academyName;
  final int posts;
  final int followers;
  final int following;
  final bool isMe;
  final bool isFollowing;
  final bool followsMe;
  final SocialBelt? belt;

  SocialProfile copyWith({bool? isFollowing, int? followers}) => SocialProfile(
    author: author,
    bio: bio,
    academyName: academyName,
    posts: posts,
    followers: followers ?? this.followers,
    following: following,
    isMe: isMe,
    isFollowing: isFollowing ?? this.isFollowing,
    followsMe: followsMe,
    belt: belt,
  );
}

/// Pessoa em listas (busca, seguidores, seguindo).
class SocialPerson {
  const SocialPerson({required this.author, required this.isMe, required this.isFollowing});

  factory SocialPerson.fromJson(Json json) => SocialPerson(
    author: SocialAuthor.fromJson(json),
    isMe: json['isMe'] as bool? ?? false,
    isFollowing: json['isFollowing'] as bool? ?? false,
  );

  final SocialAuthor author;
  final bool isMe;
  final bool isFollowing;
}

class SocialStory {
  const SocialStory({required this.id, required this.media, required this.createdAt, required this.seen, this.caption});

  factory SocialStory.fromJson(Json json) => SocialStory(
    id: json['id'] as String,
    media: SocialMedia.fromJson(json['media'] as Json),
    createdAt: _date(json['createdAt']),
    seen: json['seen'] as bool? ?? false,
    caption: json['caption'] as String?,
  );

  final String id;
  final SocialMedia media;
  final DateTime createdAt;
  final bool seen;
  final String? caption;
}

class StoryGroup {
  const StoryGroup({required this.author, required this.isMe, required this.hasUnseen, required this.stories});

  factory StoryGroup.fromJson(Json json) => StoryGroup(
    author: SocialAuthor.fromJson(json['author'] as Json),
    isMe: json['isMe'] as bool? ?? false,
    hasUnseen: json['hasUnseen'] as bool? ?? false,
    stories: [for (final s in json['stories'] as List) SocialStory.fromJson(s as Json)],
  );

  final SocialAuthor author;
  final bool isMe;
  final bool hasUnseen;
  final List<SocialStory> stories;
}

enum NotificationType { like, comment, follow }

class SocialNotification {
  const SocialNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.read,
    required this.actor,
    required this.followingActor,
    this.postId,
    this.thumbnail,
  });

  factory SocialNotification.fromJson(Json json) {
    final post = json['post'] as Json?;
    final thumb = post?['thumbnail'] as Json?;
    return SocialNotification(
      id: json['id'] as String,
      type: switch (json['type']) {
        'LIKE' => NotificationType.like,
        'COMMENT' => NotificationType.comment,
        _ => NotificationType.follow,
      },
      createdAt: _date(json['createdAt']),
      read: json['read'] as bool? ?? false,
      actor: SocialAuthor.fromJson(json['actor'] as Json),
      followingActor: json['followingActor'] as bool? ?? false,
      postId: post?['id'] as String?,
      thumbnail: thumb == null ? null : SocialMedia.fromJson(thumb),
    );
  }

  final String id;
  final NotificationType type;
  final DateTime createdAt;
  final bool read;
  final SocialAuthor actor;
  final bool followingActor;
  final String? postId;
  final SocialMedia? thumbnail;
}

/// Tempo relativo curto, no estilo das redes sociais: "agora", "5 min", "3 h", "2 d", "4 sem".
String relativeTime(DateTime date, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inHours < 1) return '${diff.inMinutes} min';
  if (diff.inDays < 1) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} d';
  return '${diff.inDays ~/ 7} sem';
}

/// "1.234" e "12,5 mil" para contadores.
String compactCount(int value) {
  if (value < 10000) {
    final text = value.toString();
    return text.length > 3 ? '${text.substring(0, text.length - 3)}.${text.substring(text.length - 3)}' : text;
  }
  if (value < 1000000) {
    final thousands = value / 1000;
    final formatted = thousands >= 100 ? thousands.toStringAsFixed(0) : thousands.toStringAsFixed(1).replaceAll('.', ',');
    return '${formatted.replaceAll(RegExp(r',0$'), '')} mil';
  }
  return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',').replaceAll(RegExp(r',0$'), '')} mi';
}

/// Academia à qual a conta do aluno está vinculada (uma "comunidade").
class CommunityMembership {
  const CommunityMembership({
    required this.id,
    required this.academyId,
    required this.name,
    required this.plans,
    required this.isCurrent,
    required this.memberCount,
    required this.postsThisWeek,
  });

  factory CommunityMembership.fromJson(Json json) => CommunityMembership(
    id: json['id'] as String,
    academyId: json['academyId'] as String? ?? '',
    name: json['name'] as String,
    plans: [for (final plan in json['plans'] as List? ?? const []) plan as String],
    isCurrent: json['isCurrent'] as bool? ?? false,
    memberCount: json['memberCount'] as int? ?? 0,
    postsThisWeek: json['postsThisWeek'] as int? ?? 0,
  );

  /// Id do perfil de aluno nessa academia (usado para trocar de comunidade).
  final String id;
  final String academyId;
  final String name;
  final List<String> plans;
  final bool isCurrent;
  final int memberCount;
  final int postsThisWeek;
}

final _inviteInLink = RegExp(r'(?:^|[?&#])token=([a-f0-9]{64})(?:[&#]|$)', caseSensitive: false);
final _inviteRaw = RegExp(r'^[a-f0-9]{64}$', caseSensitive: false);

/// Extrai o código do convite de um link (`...?token=<64 hex>`) ou do código puro.
/// Retorna null quando o texto não contém um convite válido.
String? parseInviteToken(String input) {
  final text = input.trim();
  final token = _inviteInLink.firstMatch(text)?.group(1) ?? (_inviteRaw.hasMatch(text) ? text : null);
  return token?.toLowerCase();
}
