import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/belt_badge.dart';
import '../../ui/widgets/common.dart';
import 'staff_api.dart';

/// Ficha resumida do aluno para o professor: faixas, presenças e situação financeira.
class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    final api = StaffApi(context.read<Session>().api);
    return Scaffold(
      appBar: AppBar(),
      body: Loader<StudentFile>(
        load: () => api.student(studentId),
        builder: (context, file, _) {
          final now = DateTime.now();
          final overdue = file.invoices.where((i) => i.stateOn(now) == 'OVERDUE').length;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            Row(children: [
              Avatar(initials(file.summary.name), size: 60),
              const SizedBox(width: 14),
              Expanded(child: Text(file.summary.name.toUpperCase(), style: displayStyle(30))),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusChip(file.summary.status == 'ACTIVE' ? 'Ativo' : 'Inativo', tone: file.summary.status == 'ACTIVE' ? Tone.good : Tone.neutral),
              StatusChip(overdue == 0 ? 'Mensalidades em dia' : '$overdue mensalidade(s) em atraso', tone: overdue == 0 ? Tone.good : Tone.bad),
            ]),
            if (file.notes != null && file.notes!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.healing_outlined, color: Palette.warn, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(file.notes!, style: const TextStyle(color: Palette.ink2))),
                  ]),
                ),
              ),
            ],
            const SectionTitle('Faixas'),
            if (file.ranks.isEmpty) const EmptyState(title: 'Sem graduação'),
            for (final rank in file.ranks)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(rank.modality.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${rank.beltName} · ${degreeLabel(rank.degree)} · desde ${formatDate(rank.promotedAt)}',
                    style: const TextStyle(color: Palette.ink3)),
                trailing: BeltBadge(color: rank.beltColor, degree: rank.degree),
              ),
            const SectionTitle('Últimas presenças'),
            if (file.recentCheckIns.isEmpty) const EmptyState(title: 'Sem presenças'),
            for (final c in file.recentCheckIns)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.check_circle_outline, color: Palette.good, size: 20),
                title: Text(c.modality?.name ?? 'Treino'),
                trailing: Text(formatDateTime(c.checkedAt), style: monoStyle()),
              ),
          ]);
        },
      ),
    );
  }
}
