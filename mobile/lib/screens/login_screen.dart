import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../social/widgets/social_ui.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/flenity_logo.dart';

/// Login único do app: aluno ou professor/equipe.
/// Capa com a marca Flenity, entrada com biometria (quando ativada) e formulário com e-mail e senha.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  LoginKind _kind = LoginKind.student;
  bool _pending = false;
  bool _obscure = true;
  String? _error;
  bool _biometricsAvailable = false;
  bool _rememberBiometrics = true;
  /// E-mail da conta com biometria ativa neste aparelho (null = não ativada).
  String? _biometricEmail;

  @override
  void initState() {
    super.initState();
    _restoreLastLogin();
    _loadBiometrics(autoPrompt: true);
  }

  Future<void> _loadBiometrics({bool autoPrompt = false}) async {
    final session = context.read<Session>();
    try {
      final available = await session.canUseBiometrics();
      final email = available ? await session.biometricLoginEmail() : null;
      if (!mounted) return;
      setState(() {
        _biometricsAvailable = available;
        _biometricEmail = email;
      });
      // Abre a digital/Face ID assim que a tela aparece, como nos apps de banco.
      if (autoPrompt && email != null) await _loginWithBiometrics();
    } catch (error) {
      debugPrint('Não foi possível verificar a biometria: $error');
    }
  }

  Future<void> _loginWithBiometrics() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await context.read<Session>().loginWithBiometrics();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.statusCode == 401) await _loadBiometrics();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Preenche o e-mail e o tipo de acesso usados por último neste aparelho.
  Future<void> _restoreLastLogin() async {
    try {
      final last = await context.read<Session>().lastLogin();
      if (!mounted || _email.text.isNotEmpty) return;
      setState(() {
        _kind = last.kind;
        if (last.email != null) _email.text = last.email!;
      });
    } catch (error) {
      debugPrint('Não foi possível ler o último login: $error');
    }
  }

  void _selectKind(LoginKind kind) {
    if (kind == _kind) return;
    HapticFeedback.selectionClick();
    setState(() {
      _kind = kind;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_pending || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await context.read<Session>().login(
        _email.text,
        _password.text,
        _kind,
        enableBiometrics: _offerBiometrics && _rememberBiometrics,
      );
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  bool get _offerBiometrics => _biometricsAvailable && _biometricEmail == null;

  Future<void> _forgotPassword() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: SocialColors.bg,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_reset_rounded, size: 40, color: SocialColors.accent),
            const SizedBox(height: 12),
            Text('Esqueceu a senha?', style: socialTitleStyle.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              _kind == LoginKind.student
                  ? 'Peça à recepção da sua academia para liberar o app de novo. '
                        'Eles geram uma senha provisória na sua ficha, e você pode trocá-la depois em '
                        'Minha evolução → Segurança da conta.'
                  : 'Peça a um administrador da academia para redefinir seu acesso no sistema web, em Equipe.',
              style: const TextStyle(color: SocialColors.ink2, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final heroHeight = (size.height * 0.34).clamp(170.0, 320.0);
    return Scaffold(
      backgroundColor: SocialColors.bg,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            _Hero(height: heroHeight),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: SocialColors.bg,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
                    child: SafeArea(top: false, child: _formContent()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formContent() => AutofillGroup(
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Entrar', style: socialTitleStyle.copyWith(fontSize: 26)),
          if (_biometricEmail != null) ...[
            const SizedBox(height: 14),
            _BiometricButton(email: _biometricEmail!, busy: _pending, onPressed: _loginWithBiometrics),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: Divider(color: SocialColors.line)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('ou use sua senha', style: TextStyle(color: SocialColors.ink2, fontSize: 12.5)),
                ),
                Expanded(child: Divider(color: SocialColors.line)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          const Text('Como você treina na academia?', style: TextStyle(color: SocialColors.ink2)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _KindCard(
                  key: const Key('kind-student'),
                  icon: Icons.sports_martial_arts_rounded,
                  title: 'Aluno',
                  subtitle: 'Treinos, faixa e comunidade',
                  selected: _kind == LoginKind.student,
                  onTap: () => _selectKind(LoginKind.student),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KindCard(
                  key: const Key('kind-staff'),
                  icon: Icons.verified_rounded,
                  title: 'Professor ou equipe',
                  subtitle: 'Aulas, chamada e graduações',
                  selected: _kind == LoginKind.staff,
                  onTap: () => _selectKind(LoginKind.staff),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('email'),
            controller: _email,
            enabled: !_pending,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            decoration: _fieldDecoration('E-mail', Icons.alternate_email_rounded),
            validator: (v) {
              final value = (v ?? '').trim();
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value) ? null : 'Informe um e-mail válido';
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('password'),
            controller: _password,
            focusNode: _passwordFocus,
            enabled: !_pending,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: _fieldDecoration('Senha', Icons.lock_outline_rounded).copyWith(
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _forgotPassword, child: const Text('Esqueci minha senha')),
          ),
          if (_offerBiometrics)
            CheckboxListTile(
              key: const Key('remember-biometrics'),
              value: _rememberBiometrics,
              onChanged: _pending ? null : (value) => setState(() => _rememberBiometrics = value ?? false),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              secondary: const Icon(Icons.fingerprint_rounded, color: SocialColors.accent),
              title: const Text('Entrar com biometria nas próximas vezes', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Digital ou Face ID. Sua senha não fica salva no celular.'),
            ),
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('login-submit'),
              onPressed: _pending ? null : _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: _pending
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_kind == LoginKind.student ? 'Entrar como aluno' : 'Entrar como equipe'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _kind == LoginKind.student
                ? 'Primeiro acesso? A recepção da sua academia libera o app e envia uma senha provisória.'
                : 'O acesso da equipe é criado por um administrador da academia.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: SocialColors.ink2, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    ),
  );

  InputDecoration _fieldDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: SocialColors.ink2),
    filled: true,
    fillColor: SocialColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SocialColors.accent, width: 1.6),
    ),
  );
}

/// Capa com a marca: degradê azul-noite, faixas diagonais nas cores das graduações e o logo.
class _Hero extends StatelessWidget {
  const _Hero({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height + 28,
    width: double.infinity,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B1F33), Color(0xFF0F2A44), Color(0xFF14558F)],
            ),
          ),
        ),
        const CustomPaint(painter: _BeltStripesPainter()),
        Positioned(
          left: 24,
          right: 24,
          bottom: 52,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FlenityWordmark(logoSize: 52, textSize: 40, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  'Sua comunidade de Jiu-Jitsu, sempre com você.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Faixas diagonais translúcidas nas cores da graduação (branca, azul, roxa, marrom e preta).
class _BeltStripesPainter extends CustomPainter {
  const _BeltStripesPainter();

  static const _belts = [Color(0xFFFFFFFF), Color(0xFF1E5BD6), Color(0xFF7C3AED), Color(0xFF8B5A2B), Color(0xFF000000)];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * 0.62, -size.height * 0.15);
    canvas.rotate(0.62);
    final width = size.height * 0.11;
    for (var i = 0; i < _belts.length; i++) {
      final paint = Paint()..color = _belts[i].withValues(alpha: i == 0 ? 0.10 : 0.22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * width * 1.35, 0, width, size.height * 1.8), Radius.circular(width / 3)),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BeltStripesPainter oldDelegate) => false;
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({required this.email, required this.busy, required this.onPressed});

  final String email;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: SocialColors.accent.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: const Key('biometric-login'),
      borderRadius: BorderRadius.circular(16),
      onTap: busy ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: SocialColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Entrar com biometria', style: socialBold.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: SocialColors.ink2, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: SocialColors.accent),
          ],
        ),
      ),
    ),
  );
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: title,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? SocialColors.accent.withValues(alpha: 0.08) : SocialColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? SocialColors.accent : SocialColors.line, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: selected ? SocialColors.accent : SocialColors.ink2),
                  const Spacer(),
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: selected ? SocialColors.accent : SocialColors.line,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: socialBold.copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: SocialColors.ink2, fontSize: 11.5, height: 1.25)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Palette.bad.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Palette.bad.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Palette.bad),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Palette.bad, fontWeight: FontWeight.w600))),
      ],
    ),
  );
}
