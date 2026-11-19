import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'biometrics.dart';
import 'token_storage.dart';

enum LoginKind { student, staff }

enum SessionStatus { loading, signedOut, student, staff }

/// O usuário cancelou ou falhou na digital/Face ID.
class BiometricCancelled implements Exception {
  const BiometricCancelled();

  @override
  String toString() => 'Biometria cancelada';
}

/// Estado de autenticação do app: um único app, dois perfis (aluno e professor/equipe).
class Session extends ChangeNotifier {
  Session({required this.api, required this.storage, this.biometrics = const UnavailableBiometricAuth()}) {
    api.onUnauthorized = () => _clear();
  }

  final ApiClient api;
  final TokenStorage storage;
  final BiometricAuth biometrics;

  static const _tokenKey = 'flenity.token';
  static const _kindKey = 'flenity.kind';
  static const _lastEmailKey = 'flenity.lastEmail';
  static const _lastKindKey = 'flenity.lastKind';
  // Credencial de biometria deste aparelho (o segredo só é usado após digital/Face ID).
  static const _bioIdKey = 'flenity.bio.id';
  static const _bioSecretKey = 'flenity.bio.secret';
  static const _bioEmailKey = 'flenity.bio.email';
  static const _bioKindKey = 'flenity.bio.kind';

  SessionStatus status = SessionStatus.loading;
  StaffMe? staff;
  int studentContextVersion = 0;

  Future<void> restore() async {
    final token = await storage.read(_tokenKey);
    final kind = await storage.read(_kindKey);
    if (token == null || kind == null) return _set(SessionStatus.signedOut);

    api.token = token;
    try {
      if (kind == LoginKind.staff.name) {
        staff = StaffMe.fromJson(await api.get('/auth/me') as Map<String, dynamic>);
        _set(SessionStatus.staff);
      } else {
        await api.get('/student/me');
        _set(SessionStatus.student);
      }
    } on ApiException catch (e) {
      // Sem rede: mantém a sessão; token inválido: volta ao login.
      if (e.statusCode == 0) {
        _set(kind == LoginKind.staff.name ? SessionStatus.staff : SessionStatus.student);
      } else {
        await _clear();
      }
    }
  }

  /// Login com e-mail e senha. Com `enableBiometrics`, ativa a entrada com biometria em seguida
  /// (se a ativação falhar ou for cancelada, o login continua normalmente).
  Future<void> login(String email, String password, LoginKind kind, {bool enableBiometrics = false}) async {
    final path = kind == LoginKind.student ? '/auth/student/login' : '/auth/login';
    final data = await api.post(path, {'email': email.trim(), 'password': password}) as Map<String, dynamic>;
    await _start(data['accessToken'] as String, kind, email.trim(), beforeEnter: () async {
      if (!enableBiometrics) return;
      try {
        await this.enableBiometrics();
      } catch (error) {
        debugPrint('Biometria não ativada no login: $error');
      }
    });
  }

  Future<void> logout() => _clear();

  /// Último acesso bem-sucedido neste aparelho (e-mail e tipo), para preencher a tela de login.
  Future<({String? email, LoginKind kind})> lastLogin() async {
    final email = await storage.read(_lastEmailKey);
    final kind = await storage.read(_lastKindKey);
    return (email: email, kind: kind == LoginKind.staff.name ? LoginKind.staff : LoginKind.student);
  }

  Future<bool> canUseBiometrics() => biometrics.isAvailable();

  /// E-mail da conta com entrada por biometria neste aparelho, ou null se não estiver ativa.
  Future<String?> biometricLoginEmail() async {
    final id = await storage.read(_bioIdKey);
    return id == null ? null : await storage.read(_bioEmailKey);
  }

  /// Ativa a entrada com biometria para a sessão atual. Exige confirmar a digital/Face ID.
  Future<void> enableBiometrics() async {
    if (api.token == null) throw StateError('Entre na sua conta antes de ativar a biometria');
    if (!await biometrics.authenticate('Confirme para entrar no Flenity com biometria')) {
      throw const BiometricCancelled();
    }
    final previousId = await storage.read(_bioIdKey);
    final data = await api.post('/auth/device-credentials', {'label': 'App Flenity'}) as Map<String, dynamic>;
    await storage.write(_bioIdKey, data['credentialId'] as String);
    await storage.write(_bioSecretKey, data['secret'] as String);
    await storage.write(_bioEmailKey, await storage.read(_lastEmailKey) ?? '');
    await storage.write(_bioKindKey, await storage.read(_kindKey) ?? LoginKind.student.name);
    if (previousId != null) await _revokeRemote(previousId);
  }

  /// Desativa a entrada com biometria neste aparelho e revoga a credencial no servidor.
  Future<void> disableBiometrics() async {
    final id = await storage.read(_bioIdKey);
    await _clearBiometrics();
    if (id != null) await _revokeRemote(id);
  }

  /// Entra com digital/Face ID. Retorna false se o usuário cancelar.
  Future<bool> loginWithBiometrics() async {
    final id = await storage.read(_bioIdKey);
    final secret = await storage.read(_bioSecretKey);
    if (id == null || secret == null) return false;
    if (!await biometrics.authenticate('Entrar no Flenity')) return false;

    final Map<String, dynamic> data;
    try {
      data = await api.post('/auth/device-login', {'credentialId': id, 'secret': secret}) as Map<String, dynamic>;
    } on ApiException catch (e) {
      // Credencial expirada ou revogada: some do aparelho e o usuário volta a usar a senha.
      if (e.statusCode == 401) await _clearBiometrics();
      rethrow;
    }
    final kind = data['kind'] == 'staff' ? LoginKind.staff : LoginKind.student;
    await _start(data['accessToken'] as String, kind, await storage.read(_bioEmailKey) ?? '');
    return true;
  }

  Future<void> switchCommunity(String studentId) async {
    final result = await api.post('/student/communities/$studentId/switch') as Map<String, dynamic>;
    final token = result['accessToken'] as String;
    api.token = token;
    await storage.write(_tokenKey, token);
    studentContextVersion++;
    notifyListeners();
  }

  Future<void> acceptCommunityInvite(String token) async {
    await api.post('/student/communities/invitations/accept', {'token': token});
  }

  /// Guarda o token e entra no app. `beforeEnter` roda com o token já ativo, ainda na tela de login.
  Future<void> _start(String token, LoginKind kind, String email, {Future<void> Function()? beforeEnter}) async {
    api.token = token;
    if (kind == LoginKind.staff) {
      staff = StaffMe.fromJson(await api.get('/auth/me') as Map<String, dynamic>);
    }
    await storage.write(_tokenKey, token);
    await storage.write(_kindKey, kind.name);
    // Lembra só o e-mail e o tipo de acesso para preencher o login da próxima vez (nunca a senha).
    if (email.isNotEmpty) await storage.write(_lastEmailKey, email);
    await storage.write(_lastKindKey, kind.name);
    await beforeEnter?.call();
    _set(kind == LoginKind.student ? SessionStatus.student : SessionStatus.staff);
  }

  Future<void> _revokeRemote(String credentialId) async {
    try {
      await api.delete('/auth/device-credentials/$credentialId');
    } catch (error) {
      // Sem rede ou já expirada: a credencial expira sozinha no servidor.
      debugPrint('Não foi possível revogar a credencial de biometria: $error');
    }
  }

  Future<void> _clearBiometrics() async {
    for (final key in [_bioIdKey, _bioSecretKey, _bioEmailKey, _bioKindKey]) {
      await storage.delete(key);
    }
  }

  /// Sair encerra a sessão, mas mantém a entrada com biometria para o próximo acesso.
  Future<void> _clear() async {
    api.token = null;
    staff = null;
    studentContextVersion = 0;
    await storage.delete(_tokenKey);
    await storage.delete(_kindKey);
    _set(SessionStatus.signedOut);
  }

  void _set(SessionStatus next) {
    status = next;
    notifyListeners();
  }
}
