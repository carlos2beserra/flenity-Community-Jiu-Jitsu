import '../../core/api_client.dart';
import '../../models/models.dart';

/// Chamadas da área do professor (mesmas rotas da equipe no sistema web).
class StaffApi {
  StaffApi(this.api);

  final ApiClient api;

  Future<List<ClassSlot>> todayClasses() async =>
      (await api.get('/classes/today') as List).map((c) => ClassSlot.fromJson(c as Json)).toList();

  Future<List<CheckInEntry>> attendance(String classId) async {
    final data = await api.get('/classes/$classId/attendance') as Json;
    return (data['checkIns'] as List).map((c) => CheckInEntry.fromJson(c as Json)).toList();
  }

  Future<void> checkIn(String studentId, String classId) => api.post('/check-ins', {'studentId': studentId, 'classId': classId});

  Future<List<StudentSummary>> searchStudents(String search) async {
    final page = await api.get('/students', query: {'search': search, 'status': 'ACTIVE', 'pageSize': '20'}) as Json;
    return (page['items'] as List).map((s) => StudentSummary.fromJson(s as Json)).toList();
  }

  Future<StudentFile> student(String id) async => StudentFile.fromJson(await api.get('/students/$id') as Json);

  Future<List<RankProgress>> graduationBoard({required bool eligibleOnly}) async =>
      (await api.get('/graduations', query: {'eligibleOnly': '$eligibleOnly'}) as List)
          .map((r) => RankProgress.fromJson(r as Json))
          .toList();

  Future<void> promote(String studentId, String modalityId) =>
      api.post('/graduations/promote', {'studentId': studentId, 'modalityId': modalityId});

  Future<void> createInstructor({
    required String name,
    required String email,
    required String password,
  }) async {
    await api.post('/users', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'role': 'INSTRUCTOR',
    });
  }
}
