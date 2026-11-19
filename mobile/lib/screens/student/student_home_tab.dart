import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/belt_badge.dart';
import '../../ui/widgets/activity_feature_card.dart';
import '../../ui/widgets/common.dart';
import 'class_tile.dart';
import 'student_api.dart';

typedef _HomeData = ({StudentProfile me, List<ClassSlot> classes});

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({
    super.key,
    required this.onOpenSchedule,
    required this.onOpenMenu,
    this.embedded = false,
  });

  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenMenu;
  final bool embedded;

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  late final _api = StudentApi(context.read<Session>().api);
  String? _busyClassId;

  Future<_HomeData> _load() async {
    final results = await Future.wait([_api.me(), _api.classes()]);
    return (
      me: results[0] as StudentProfile,
      classes: results[1] as List<ClassSlot>,
    );
  }

  Future<void> _checkIn(ClassSlot slot, Future<void> Function() reload) async {
    setState(() => _busyClassId = slot.id);
    try {
      await _api.checkIn(slot.id);
      if (mounted) {
        showMessage(
          context,
          'Presença confirmada em ${slot.name}. Bom treino!',
        );
      }
      await reload();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyClassId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<_HomeData>(
      load: _load,
      builder: (context, data, reload) {
        final me = data.me;
        final today = data.classes
            .where((c) => c.weekday == apiWeekday(DateTime.now()))
            .toList();
        final nextClass = nextStudentClass(data.classes, DateTime.now());
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height - 120;
            final featureHeight = (availableHeight - 24).clamp(
              540.0,
              double.infinity,
            );
            return ListView(
              shrinkWrap: widget.embedded,
              physics: widget.embedded
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                ActivityFeatureCard(
                  height: featureHeight,
                  eyebrow: 'Sua próxima aula',
                  title: nextClass?.name ?? 'Seu próximo treino começa aqui',
                  description: nextClass == null
                      ? 'Confira a agenda e encontre sua próxima aula de Jiu-Jitsu.'
                      : 'Cada presença fortalece sua jornada no Jiu-Jitsu.',
                  details: nextClass == null
                      ? me.academyName
                      : '${studentClassDayLabel(nextClass, DateTime.now())} · '
                            '${nextClass.startTime}–${nextClass.endTime} · ${nextClass.modality.name}',
                  host: firstName(me.name),
                  hostLabel: me.academyName,
                  sideNote: me.planNames.isEmpty
                      ? 'Sua jornada'
                      : me.planNames.first,
                  badge: nextClass?.checkedInToday == true
                      ? 'PRESENÇA CONFIRMADA'
                      : nextClass?.checkInOpen == true
                      ? 'CHECK-IN ABERTO'
                      : 'PRÓXIMA ATIVIDADE',
                  actionLabel: nextClass == null
                      ? 'VER MINHA AGENDA'
                      : nextClass.checkedInToday
                      ? 'PRESENÇA CONFIRMADA'
                      : nextClass.checkInOpen
                      ? 'FAZER CHECK-IN'
                      : 'VER MINHA AGENDA',
                  onAction:
                      nextClass?.checkInOpen == true &&
                          nextClass?.checkedInToday == false
                      ? () => _checkIn(nextClass!, reload)
                      : widget.onOpenSchedule,
                  onMenuTap: widget.onOpenMenu,
                  actionEnabled: nextClass?.checkedInToday != true,
                  busy: nextClass != null && _busyClassId == nextClass.id,
                  icon: Icons.sports_martial_arts_rounded,
                ),
                if (me.overdueCount > 0) ...[
                  const SizedBox(height: 16),
                  _Alert(
                    text:
                        '${me.overdueCount} mensalidade(s) em atraso · ${formatMoney(me.overdueCents)}. '
                        'Regularize na recepção para não ter o check-in bloqueado.',
                  ),
                ],
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'Aulas no mês',
                          value: '${me.classesThisMonth}',
                          sub: 'participações',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          label: 'Próx. mensalidade',
                          value: me.nextInvoice == null
                              ? '—'
                              : formatDate(
                                  me.nextInvoice!.dueDate,
                                ).substring(0, 5),
                          sub: me.nextInvoice == null
                              ? 'nada em aberto'
                              : formatMoney(me.nextInvoice!.amountCents),
                        ),
                      ),
                    ],
                  ),
                ),
                SectionTitle(
                  'Agenda de hoje',
                  trailing: Text(
                    weekdayNames[apiWeekday(DateTime.now())],
                    style: monoStyle(),
                  ),
                ),
                if (today.isEmpty)
                  const EmptyState(
                    title: 'Um espaço para você',
                    subtitle: 'Nenhuma aula de Jiu-Jitsu programada para hoje.',
                  )
                else
                  for (final slot in today)
                    ClassTile(
                      slot: slot,
                      busy: _busyClassId == slot.id,
                      onCheckIn: () => _checkIn(slot, reload),
                    ),
                const SectionTitle('Graduações de luta'),
                if (me.ranks.isEmpty)
                  const EmptyState(
                    title: 'Sem graduação',
                    subtitle: 'Sua evolução no Jiu-Jitsu aparece aqui.',
                  ),
                for (final rank in me.ranks) _RankCard(rank: rank),
              ],
            );
          },
        );
      },
    );
  }
}

ClassSlot? nextStudentClass(List<ClassSlot> classes, DateTime now) {
  if (classes.isEmpty) return null;

  final today = apiWeekday(now);
  final currentMinutes = now.hour * 60 + now.minute;
  final ordered =
      classes.map((slot) {
        final [hour, minute] = slot.startTime
            .split(':')
            .map(int.parse)
            .toList();
        var daysAway = (slot.weekday - today + 7) % 7;
        final hasStarted = hour * 60 + minute <= currentMinutes;
        final checkInAvailable = slot.checkInOpen && !slot.checkedInToday;
        if (daysAway == 0 && hasStarted && !checkInAvailable) daysAway = 7;
        return (slot: slot, daysAway: daysAway, start: hour * 60 + minute);
      }).toList()..sort((a, b) {
        final byDay = a.daysAway.compareTo(b.daysAway);
        return byDay != 0 ? byDay : a.start.compareTo(b.start);
      });

  return ordered.first.slot;
}

String studentClassDayLabel(ClassSlot slot, DateTime now) {
  if (slot.weekday != apiWeekday(now)) {
    return weekdayNames[slot.weekday].toUpperCase();
  }
  final [hour, minute] = slot.startTime.split(':').map(int.parse).toList();
  final start = hour * 60 + minute;
  final current = now.hour * 60 + now.minute;
  if (start > current || (slot.checkInOpen && !slot.checkedInToday)) {
    return 'HOJE';
  }
  return 'PRÓXIMA SEMANA';
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.rank});

  final RankProgress rank;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rank.modalityName.toUpperCase(),
                    style: displayStyle(22),
                  ),
                ),
                if (rank.eligible)
                  const StatusChip('Apto a graduar', tone: Tone.good),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                BeltBadge(
                  color: rank.beltColor,
                  degree: rank.degree,
                  width: 120,
                  height: 20,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank.beltName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${degreeLabel(rank.degree)} de ${rank.maxDegrees}',
                      style: const TextStyle(
                        color: Palette.ink3,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ProgressBar(value: rank.progress, highlight: rank.eligible),
            const SizedBox(height: 6),
            Text(
              rank.eligible
                  ? '${rank.classesSince} aulas desde ${formatDate(rank.promotedAt)} — fale com seu professor!'
                  : '${rank.classesSince}/${rank.minClasses} aulas · faltam ${rank.classesRemaining} para a próxima graduação',
              style: monoStyle(size: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: monoStyle(size: 10.5)),
            const SizedBox(height: 8),
            Text(value, style: displayStyle(34)),
            if (sub != null)
              Text(
                sub!,
                style: const TextStyle(color: Palette.ink2, fontSize: 12.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.bad.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.bad.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Palette.bad, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Palette.bad)),
          ),
        ],
      ),
    );
  }
}
