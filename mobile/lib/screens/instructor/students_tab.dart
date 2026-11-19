import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import 'staff_api.dart';
import 'student_detail_screen.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  late final _api = StaffApi(context.read<Session>().api);
  List<StudentSummary> _results = const [];
  Timer? _debounce;
  bool _loading = false;
  bool _searched = false;

  void _search(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _loading = true);
      try {
        final results = await _api.searchStudents(text.trim());
        if (mounted) {
          setState(() {
            _results = results;
            _searched = true;
          });
        }
      } catch (e) {
        if (mounted) showMessage(context, errorText(e), error: true);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 32), children: [
      Text('ALUNOS', style: displayStyle(40)),
      const SizedBox(height: 14),
      TextField(
        onChanged: _search,
        decoration: InputDecoration(
          labelText: 'Buscar por nome, e-mail ou CPF',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _loading ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)) : null,
        ),
      ),
      const SizedBox(height: 10),
      if (_searched && _results.isEmpty) const EmptyState(title: 'Nenhum aluno encontrado'),
      for (final s in _results)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Avatar(initials(s.name), size: 40),
          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(s.phone ?? s.email ?? '', style: const TextStyle(color: Palette.ink3)),
          trailing: const Icon(Icons.chevron_right, color: Palette.ink3),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailScreen(studentId: s.id))),
        ),
    ]);
  }
}
