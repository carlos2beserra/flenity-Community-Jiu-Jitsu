import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../ui/widgets/common.dart';
import 'class_tile.dart';
import 'student_api.dart';

class StudentScheduleTab extends StatefulWidget {
  const StudentScheduleTab({super.key});

  @override
  State<StudentScheduleTab> createState() => _StudentScheduleTabState();
}

class _StudentScheduleTabState extends State<StudentScheduleTab> {
  late final _api = StudentApi(context.read<Session>().api);
  String? _busyClassId;

  Future<void> _checkIn(ClassSlot slot, Future<void> Function() reload) async {
    setState(() => _busyClassId = slot.id);
    try {
      await _api.checkIn(slot.id);
      if (mounted) showMessage(context, 'Presença confirmada em ${slot.name}.');
      await reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyClassId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<ClassSlot>>(
      load: _api.classes,
      builder: (context, classes, reload) {
        final today = apiWeekday(DateTime.now());
        // Semana começando por hoje.
        final days = [for (var i = 0; i < 7; i++) (today + i) % 7];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const SectionTitle('Agenda da semana'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Faça check-in em cada aula de Jiu-Jitsu que participar, respeitando o limite semanal do seu plano. Todas as presenças ficam registradas; para a graduação, conta no máximo uma por dia.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (classes.isEmpty)
              const EmptyState(
                title: 'Sem aulas',
                subtitle:
                    'Seu plano ainda não tem aulas de Jiu-Jitsu na agenda.',
              ),
            for (final day in days)
              if (classes.any((c) => c.weekday == day)) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text(
                    day == today
                        ? 'HOJE · ${weekdayNames[day].toUpperCase()}'
                        : weekdayNames[day].toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: day == today
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                for (final slot in classes.where((c) => c.weekday == day))
                  ClassTile(
                    slot: slot,
                    busy: _busyClassId == slot.id,
                    onCheckIn: () => _checkIn(slot, reload),
                  ),
              ],
          ],
        );
      },
    );
  }
}
