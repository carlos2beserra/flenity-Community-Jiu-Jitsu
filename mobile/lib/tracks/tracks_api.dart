import '../core/api_client.dart';
import '../social/social_models.dart';
import 'tracks_models.dart';

/// Rotas das trilhas: `/student/tracks` (aluno) e `/tracks` (professor/admin).
class TracksApi {
  TracksApi(this.api);

  final ApiClient api;

  Future<StudentTrack> studentTrack({String? beltId}) async =>
      StudentTrack.fromJson(await api.get('/student/tracks', query: {'beltId': beltId}) as Json);

  Future<void> setCompleted(String lessonId, bool completed) async {
    final path = '/student/tracks/lessons/$lessonId/complete';
    completed ? await api.post(path) : await api.delete(path);
  }

  Future<StaffTrack> staffTrack({String? beltId}) async =>
      StaffTrack.fromJson(await api.get('/tracks', query: {'beltId': beltId}) as Json);

  Future<TrackLesson> createLesson({
    required String beltId,
    required TrackCategory category,
    required String title,
    String? description,
    String? mediaId,
    bool published = false,
  }) async => TrackLesson.fromJson(
    await api.post('/tracks/lessons', {
          'beltId': beltId,
          'category': category.apiName,
          'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
          'mediaId': ?mediaId,
          'published': published,
        })
        as Json,
  );

  /// `removeMedia` apaga o vídeo/foto atual; `mediaId` troca por outro.
  Future<TrackLesson> updateLesson(
    String id, {
    TrackCategory? category,
    String? title,
    String? description,
    String? mediaId,
    bool removeMedia = false,
    bool? published,
  }) async => TrackLesson.fromJson(
    await api.patch('/tracks/lessons/$id', {
          if (category != null) 'category': category.apiName,
          'title': ?title,
          'description': ?description,
          if (mediaId != null) 'mediaId': mediaId else if (removeMedia) 'mediaId': null,
          'published': ?published,
        })
        as Json,
  );

  Future<void> deleteLesson(String id) => api.delete('/tracks/lessons/$id');

  Future<void> moveLesson(String id, {required bool up}) =>
      api.post('/tracks/lessons/$id/move', {'direction': up ? 'up' : 'down'});

  /// Retorna quantos foram alterados e, ao liberar, quantos ficaram em rascunho por ainda não ter vídeo.
  Future<({int updated, int withoutVideo})> publishAll(
    String beltId, {
    required bool published,
    TrackCategory? category,
  }) async {
    final result =
        await api.post('/tracks/publish', {'beltId': beltId, 'category': ?category?.apiName, 'published': published})
            as Json;
    return (updated: result['updated'] as int, withoutVideo: result['withoutVideo'] as int? ?? 0);
  }

  Future<int> importStarter(String beltId) async =>
      ((await api.post('/tracks/starter', {'beltId': beltId})) as Json)['created'] as int;
}
