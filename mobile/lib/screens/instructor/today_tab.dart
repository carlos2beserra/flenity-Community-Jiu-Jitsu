import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/activity_feature_card.dart';
import '../../ui/widgets/common.dart';
import 'class_attendance_screen.dart';
import 'staff_api.dart';

class TodayTab extends StatefulWidget {
  const TodayTab({super.key, this.onOpenMenu, this.embedded = false});

  final VoidCallback? onOpenMenu;
  final bool embedded;

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  bool _onlyMine = true;

  Future<void> _openAttendance(
    ClassSlot slot,
    Future<void> Function() reload,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClassAttendanceScreen(slot: slot)),
    );
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final api = StaffApi(session.api);
    final myId = session.staff?.id;

    return Loader<List<ClassSlot>>(
      load: api.todayClasses,
      builder: (context, classes, reload) {
        final visible = _onlyMine
            ? classes.where((c) => c.instructor?.id == myId).toList()
            : classes;
        final featured = visible.isEmpty ? null : visible.first;
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
                  eyebrow: 'Detalhes da aula',
                  title: featured?.name ?? 'Sua próxima aula começa aqui',
                  description: featured == null
                      ? 'Hoje não há aulas sob seu filtro. Confira a agenda da academia.'
                      : 'A aula está pronta. Acompanhe as presenças no tatame.',
                  details: featured == null
                      ? weekdayNames[apiWeekday(DateTime.now())].toUpperCase()
                      : '${featured.startTime}–${featured.endTime} · ${featured.modality.name}',
                  host:
                      featured?.instructor?.name ??
                      session.staff?.name ??
                      'Equipe Flenity',
                  hostLabel: featured == null
                      ? session.staff?.academyName ?? 'Flenity'
                      : 'Responsável pela aula',
                  sideNote: featured == null
                      ? (session.staff?.roleLabel ?? 'Equipe')
                      : '${featured.checkInsToday ?? 0}/${featured.capacity} pessoas',
                  badge: featured == null ? 'DIA LIVRE' : 'ATIVIDADE DE HOJE',
                  actionLabel: featured == null
                      ? 'SEM ATIVIDADES HOJE'
                      : 'ABRIR CHAMADA',
                  onAction: featured == null
                      ? null
                      : () => _openAttendance(featured, reload),
                  onMenuTap: widget.onOpenMenu ?? () {},
                  showMenu: !widget.embedded && widget.onOpenMenu != null,
                  actionEnabled: featured != null,
                  icon: Icons.sports_martial_arts_rounded,
                ),
                const SectionTitle('Aulas de hoje'),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Minhas')),
                      ButtonSegment(value: false, label: Text('Todas')),
                    ],
                    selected: {_onlyMine},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _onlyMine = s.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: Palette.blood,
                      selectedForegroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  EmptyState(
                    title: 'Sem aulas',
                    subtitle: _onlyMine
                        ? 'Você não tem aulas hoje. Veja "Todas".'
                        : 'Nenhuma aula na agenda hoje.',
                  ),
                for (final cls in visible.where((c) => c.id != featured?.id))
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        await _openAttendance(cls, reload);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Text(
                                  cls.startTime,
                                  style: displayStyle(26, color: Palette.blood),
                                ),
                                Text(cls.endTime, style: monoStyle()),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cls.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${cls.modality.name} · ${cls.instructor?.name ?? 'sem professor'}',
                                    style: const TextStyle(
                                      color: Palette.ink3,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${cls.checkInsToday ?? 0}',
                                  style: displayStyle(28),
                                ),
                                Text(
                                  'de ${cls.capacity}',
                                  style: monoStyle(size: 11),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Palette.ink3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
