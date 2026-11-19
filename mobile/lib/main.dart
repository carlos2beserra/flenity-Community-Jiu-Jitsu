import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'core/api_client.dart';
import 'core/biometrics.dart';
import 'core/session.dart';
import 'core/token_storage.dart';
import 'screens/instructor/instructor_shell.dart';
import 'screens/login_screen.dart';
import 'screens/student/student_shell.dart';
import 'ui/theme.dart';
import 'ui/widgets/flenity_logo.dart';

void main() {
  final session = Session(
    api: ApiClient(baseUrl: apiBaseUrl),
    storage: const SecureTokenStorage(),
    biometrics: DeviceBiometricAuth(),
  )..restore();
  runApp(FlenityApp(session: session));
}

class FlenityApp extends StatelessWidget {
  const FlenityApp({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(
        title: 'Flenity Jiu-Jitsu Community',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _RootGate(),
      ),
    );
  }
}

/// Decide a área do app conforme o tipo de sessão: aluno, professor/equipe ou login.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<Session>().status;
    return switch (status) {
      SessionStatus.loading => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: FlenityLogo(size: 88)),
      ),
      SessionStatus.signedOut => const LoginScreen(),
      SessionStatus.student => const StudentShell(),
      SessionStatus.staff => const InstructorShell(),
    };
  }
}
