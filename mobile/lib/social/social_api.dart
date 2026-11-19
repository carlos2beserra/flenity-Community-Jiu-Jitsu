import '../core/api_client.dart';
import 'social_models.dart';

enum FeedScope { all, following }

/// Rotas da comunidade social do aluno (`/student/community/*`).
class SocialApi {
  SocialApi(this.api);

  final ApiClient api;

  static const _base = '/student/community';

  String mediaUrl(String url) => api.resolveUrl(url);

  Future<PageResult<SocialPost>> feed({
    int page = 1,
    FeedScope scope = FeedScope.all,
    PostKind? kind,
    String? authorId,
    int pageSize = 12,
  }) async => PageResult.fromJson(
    await api.get(
          '$_base/posts',
          query: {
            'page': '$page',
            'pageSize': '$pageSize',
            'scope': scope.name,
            'kind': kind == null ? null : (kind == PostKind.reel ? 'REEL' : 'POST'),
            'authorId': authorId,
          },
        )
        as Json,
    SocialPost.fromJson,
  );

  Future<SocialPost> post(String id) async => SocialPost.fromJson(await api.get('$_base/posts/$id') as Json);

  Future<SocialPost> createPost({String content = '', List<String> mediaIds = const [], PostKind kind = PostKind.post}) async =>
      SocialPost.fromJson(
        await api.post('$_base/posts', {
              'content': content,
              'mediaIds': mediaIds,
              'kind': kind == PostKind.reel ? 'REEL' : 'POST',
            })
            as Json,
      );

  Future<void> deletePost(String id) => api.delete('$_base/posts/$id');

  Future<bool> toggleLike(String postId) async => ((await api.post('$_base/posts/$postId/like')) as Json)['liked'] as bool;

  Future<bool> toggleSave(String postId) async => ((await api.post('$_base/posts/$postId/save')) as Json)['saved'] as bool;

  Future<PageResult<SocialComment>> comments(String postId, {int page = 1}) async => PageResult.fromJson(
    await api.get('$_base/posts/$postId/comments', query: {'page': '$page', 'pageSize': '50'}) as Json,
    SocialComment.fromJson,
  );

  Future<SocialComment> addComment(String postId, String content) async =>
      SocialComment.fromJson(await api.post('$_base/posts/$postId/comments', {'content': content}) as Json);

  Future<void> deleteComment(String postId, String commentId) => api.delete('$_base/posts/$postId/comments/$commentId');

  Future<PageResult<SocialPost>> explore({int page = 1}) async => PageResult.fromJson(
    await api.get('$_base/explore', query: {'page': '$page', 'pageSize': '21'}) as Json,
    SocialPost.fromJson,
  );

  Future<PageResult<SocialPost>> saved({int page = 1}) async => PageResult.fromJson(
    await api.get('$_base/saved', query: {'page': '$page', 'pageSize': '21'}) as Json,
    SocialPost.fromJson,
  );

  Future<PageResult<SocialPerson>> people({String? search, int page = 1}) async => PageResult.fromJson(
    await api.get('$_base/people', query: {'search': search, 'page': '$page', 'pageSize': '30'}) as Json,
    SocialPerson.fromJson,
  );

  Future<SocialProfile> profile(String? studentId) async =>
      SocialProfile.fromJson(await api.get('$_base/people/${studentId ?? 'me'}') as Json);

  Future<PageResult<SocialPerson>> followers(String studentId, {int page = 1}) async => PageResult.fromJson(
    await api.get('$_base/people/$studentId/followers', query: {'page': '$page', 'pageSize': '50'}) as Json,
    SocialPerson.fromJson,
  );

  Future<PageResult<SocialPerson>> following(String studentId, {int page = 1}) async => PageResult.fromJson(
    await api.get('$_base/people/$studentId/following', query: {'page': '$page', 'pageSize': '50'}) as Json,
    SocialPerson.fromJson,
  );

  Future<bool> toggleFollow(String studentId) async =>
      ((await api.post('$_base/people/$studentId/follow')) as Json)['following'] as bool;

  /// `avatarMediaId: ''` remove a foto; `null` mantém a atual.
  Future<SocialProfile> updateProfile({String? bio, String? avatarMediaId}) async => SocialProfile.fromJson(
    await api.patch('$_base/profile', {
          'bio': ?bio,
          if (avatarMediaId != null) 'avatarMediaId': avatarMediaId.isEmpty ? null : avatarMediaId,
        })
        as Json,
  );

  Future<SocialMedia> upload(List<int> bytes, String filename) async =>
      SocialMedia.fromJson(await api.upload('$_base/media', bytes, filename) as Json);

  Future<List<StoryGroup>> stories() async =>
      [for (final group in await api.get('$_base/stories') as List) StoryGroup.fromJson(group as Json)];

  Future<void> createStory(String mediaId, {String? caption}) =>
      api.post('$_base/stories', {'mediaId': mediaId, if (caption != null && caption.isNotEmpty) 'caption': caption});

  Future<void> markStoryViewed(String storyId) => api.post('$_base/stories/$storyId/view');

  Future<List<SocialAuthor>> storyViewers(String storyId) async =>
      [for (final viewer in await api.get('$_base/stories/$storyId/viewers') as List) SocialAuthor.fromJson(viewer as Json)];

  Future<void> deleteStory(String storyId) => api.delete('$_base/stories/$storyId');

  Future<List<CommunityMembership>> communities() async => [
    for (final community in await api.get('/student/communities') as List)
      CommunityMembership.fromJson(community as Json),
  ];

  Future<PageResult<SocialNotification>> notifications({int page = 1}) async => PageResult.fromJson(
    await api.get('$_base/notifications', query: {'page': '$page', 'pageSize': '30'}) as Json,
    SocialNotification.fromJson,
  );

  Future<int> unreadNotifications() async =>
      ((await api.get('$_base/notifications/unread-count')) as Json)['count'] as int? ?? 0;

  Future<void> markNotificationsRead() => api.post('$_base/notifications/read');
}
