import '../../core/api_client.dart';
import '../../models/models.dart';

/// Chamadas do app do aluno (rotas /student, escopadas pelo token).
class StudentApi {
  StudentApi(this.api);

  final ApiClient api;

  Future<StudentProfile> me() async => StudentProfile.fromJson(await api.get('/student/me') as Json);

  Future<List<ClassSlot>> classes() async =>
      (await api.get('/student/classes') as List).map((c) => ClassSlot.fromJson(c as Json)).toList();

  Future<void> checkIn(String classId) => api.post('/student/check-ins', {'classId': classId});

  Future<List<CheckInEntry>> history() async {
    final page = await api.get('/student/check-ins', query: {'pageSize': '30'}) as Json;
    return (page['items'] as List).map((c) => CheckInEntry.fromJson(c as Json)).toList();
  }

  Future<List<Invoice>> invoices() async =>
      (await api.get('/student/invoices') as List).map((i) => Invoice.fromJson(i as Json)).toList();

  Future<void> changePassword(String current, String next) =>
      api.post('/student/password', {'currentPassword': current, 'newPassword': next});
}
