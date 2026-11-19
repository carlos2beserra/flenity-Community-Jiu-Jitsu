import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import 'staff_api.dart';

/// Administrador cria o acesso de um novo professor. Fecha com `true` quando criado.
class CreateInstructorDialog extends StatefulWidget {
  const CreateInstructorDialog({super.key, required this.api});

  final StaffApi api;

  @override
  State<CreateInstructorDialog> createState() =>
      CreateInstructorDialogState();
}

class CreateInstructorDialogState extends State<CreateInstructorDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.api.createInstructor(
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar professor'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('instructor-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Informe o nome do professor'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('instructor-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Informe um e-mail válido'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('instructor-password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha inicial'),
                  validator: (value) => value == null || value.length < 8
                      ? 'A senha deve ter pelo menos 8 caracteres'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Palette.bad),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _pending ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _pending ? null : _submit,
          child: _pending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar acesso'),
        ),
      ],
    );
  }
}
