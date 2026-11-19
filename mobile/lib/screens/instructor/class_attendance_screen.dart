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

/// Chamada da turma: quem já fez check-in hoje e registro manual de presença.
class ClassAttendanceScreen extends StatefulWidget {
  const ClassAttendanceScreen({super.key, required this.slot});

  final ClassSlot slot;

  @override
  State<ClassAttendanceScreen> createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen> {
  late final _api = StaffApi(context.read<Session>().api);
  /// Incrementado após registrar presença para recarregar a chamada.
  int _version = 0;

  Future<void> _addStudent() async {
    final student = await showModalBottomSheet<StudentSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.panel,
      builder: (_) => _StudentPicker(api: _api),
    );
    if (student == null || !mounted) return;
    try {
      await _api.checkIn(student.id, widget.slot.id);
      if (mounted) showMessage(context, 'Presença de ${firstName(student.name)} registrada');
      setState(() => _version++);
    } catch (e) {
      if (mounted) showMessage(context, '${firstName(student.name)}: ${errorText(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    return Scaffold(
      appBar: AppBar(title: Text(slot.name.toUpperCase())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStudent,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Registrar presença'),
      ),
      body: Loader<List<CheckInEntry>>(
        key: ValueKey(_version),
        load: () => _api.attendance(slot.id),
        builder: (context, checkIns, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
          Text('${slot.startTime}–${slot.endTime} · ${slot.modality.name}', style: monoStyle(color: Palette.ink2)),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Text('${checkIns.length}', style: displayStyle(44, color: Palette.blood)),
                const SizedBox(width: 10),
                Text('presentes\nde ${slot.capacity} vagas', style: const TextStyle(color: Palette.ink2)),
              ]),
            ),
          ),
          const SectionTitle('Chamada'),
          if (checkIns.isEmpty) const EmptyState(title: 'Tatame vazio', subtitle: 'Ninguém fez check-in ainda.'),
          for (final c in checkIns)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Avatar(initials(c.student?.name ?? '?'), size: 38),
              title: Text(c.student?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text(formatTime(c.checkedAt), style: monoStyle()),
              onTap: c.student == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailScreen(studentId: c.student!.id))),
            ),
        ]),
      ),
    );
  }
}

class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.api});

  final StaffApi api;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  List<StudentSummary> _results = const [];
  Timer? _debounce;
  bool _loading = false;

  void _search(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (text.trim().length < 2) return setState(() => _results = const []);
      setState(() => _loading = true);
      try {
        final results = await widget.api.searchStudents(text.trim());
        if (mounted) setState(() => _results = results);
      } catch (e) {
        if (mounted) showMessage(context, errorText(e), error: true);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                labelText: 'Buscar aluno',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _loading ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)) : null,
              ),
            ),
          ),
          Expanded(
            child: ListView(children: [
              for (final s in _results)
                ListTile(
                  leading: Avatar(initials(s.name), size: 36),
                  title: Text(s.name),
                  subtitle: Text(s.phone ?? '', style: const TextStyle(color: Palette.ink3)),
                  onTap: () => Navigator.pop(context, s),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
