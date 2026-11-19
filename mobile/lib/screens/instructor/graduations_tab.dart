import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/belt_badge.dart';
import '../../ui/widgets/common.dart';
import 'staff_api.dart';

class GraduationsTab extends StatefulWidget {
  const GraduationsTab({super.key});

  @override
  State<GraduationsTab> createState() => _GraduationsTabState();
}

class _GraduationsTabState extends State<GraduationsTab> {
  late final _api = StaffApi(context.read<Session>().api);
  bool _eligibleOnly = true;

  Future<void> _promote(
    RankProgress row,
    Future<void> Function() reload,
  ) async {
    final ok = await confirmDialog(
      context,
      'Graduar',
      'Graduar ${row.studentName} em ${row.modalityName}?',
      confirm: 'Graduar',
    );
    if (!ok) return;
    try {
      await _api.promote(row.studentId, row.modalityId);
      if (mounted) {
        showMessage(
          context,
          '${firstName(row.studentName)} graduado(a)! Oss! 🥋',
        );
      }
      await reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<RankProgress>>(
      key: ValueKey(_eligibleOnly),
      load: () => _api.graduationBoard(eligibleOnly: _eligibleOnly),
      builder: (context, rows, reload) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Text('RÉGUA DE EVOLUÇÃO', style: monoStyle(color: Palette.blood)),
          const SizedBox(height: 6),
          Text('GRADUAÇÕES', style: displayStyle(40)),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Aptos')),
                ButtonSegment(value: false, label: Text('Todos')),
              ],
              selected: {_eligibleOnly},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _eligibleOnly = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Palette.blood,
                selectedForegroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const EmptyState(
              title: 'Ninguém apto',
              subtitle: 'Nenhum aluno atingiu a frequência mínima.',
            ),
          for (final row in rows)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.studentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                row.modalityName,
                                style: const TextStyle(
                                  color: Palette.ink3,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: () => _promote(row, reload),
                          style: row.eligible
                              ? FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                )
                              : FilledButton.styleFrom(
                                  backgroundColor: Palette.panel2,
                                  foregroundColor: Palette.ink,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                          child: const Text('GRADUAR'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        BeltBadge(color: row.beltColor, degree: row.degree),
                        const SizedBox(width: 12),
                        Text(
                          '${row.beltName} · ${degreeLabel(row.degree)}',
                          style: const TextStyle(color: Palette.ink2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ProgressBar(value: row.progress, highlight: row.eligible),
                    const SizedBox(height: 4),
                    Text(
                      '${row.classesSince}/${row.minClasses} aulas desde ${formatDate(row.promotedAt)}',
                      style: monoStyle(size: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
