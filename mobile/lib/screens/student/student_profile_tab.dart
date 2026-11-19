import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../social/social_shell.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/belt_badge.dart';
import 'student_finance_tab.dart';
import 'student_home_tab.dart' show nextStudentClass, studentClassDayLabel;
import 'student_api.dart';
import 'student_schedule_tab.dart';

typedef _ProfileData = ({
  StudentProfile me,
  List<CheckInEntry> history,
  List<ClassSlot> classes,
});

/// Seções da área "Minha academia" do aluno. Cada uma abre sozinha, sem barra de abas.
enum StudentAcademyTab { summary, schedule, plans }

/// Uma seção da área do aluno: resumo (próxima aula, faixa, histórico, dados e conta),
/// agenda com check-in ou planos e mensalidades.
class StudentProfileTab extends StatefulWidget {
  const StudentProfileTab({super.key, this.section = StudentAcademyTab.summary});

  final StudentAcademyTab section;

  @override
  State<StudentProfileTab> createState() => _StudentProfileTabState();
}

class _StudentProfileTabState extends State<StudentProfileTab> {
  bool _showAllHistory = false;
  String? _busyClassId;

  @override
  Widget build(BuildContext context) => switch (widget.section) {
    StudentAcademyTab.summary => _buildProfileContent(context),
    StudentAcademyTab.schedule => const StudentScheduleTab(),
    StudentAcademyTab.plans => const StudentPlansTab(),
  };

  Widget _buildProfileContent(BuildContext context) {
    final session = context.read<Session>();
    final api = StudentApi(session.api);
    return Loader<_ProfileData>(
      load: () async {
        final results = await Future.wait([
          api.me(),
          api.history(),
          api.classes(),
        ]);
        return (
          me: results[0] as StudentProfile,
          history: results[1] as List<CheckInEntry>,
          classes: results[2] as List<ClassSlot>,
        );
      },
      builder: (context, data, reload) {
        final me = data.me;
        final nextClass = nextStudentClass(data.classes, DateTime.now());
        final history = _showAllHistory
            ? data.history
            : data.history.take(4).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _sectionHeading(
              'Próxima aula',
              icon: Icons.event_available_rounded,
              trailing: 'NO SEU ESPAÇO',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _NextClassCard(
                classSlot: nextClass,
                busy: nextClass != null && _busyClassId == nextClass.id,
                onOpenSchedule: () => openToolPage(context, 'Agenda e check-in', const StudentScheduleTab()),
                onCheckIn: nextClass == null
                    ? null
                    : () => _checkIn(nextClass, reload),
              ),
            ),
            if (me.overdueCount > 0) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _PaymentAlert(
                  count: me.overdueCount,
                  amountCents: me.overdueCents,
                  onTap: () => openToolPage(context, 'Planos e mensalidades', const StudentPlansTab()),
                ),
              ),
            ],
            _sectionHeading(
              'Minha evolução',
              icon: Icons.military_tech_outlined,
              trailing: me.ranks.isEmpty ? null : '${me.ranks.length} MOD.',
            ),
            if (me.ranks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: EmptyState(
                  title: 'Sua jornada começa aqui',
                  subtitle:
                      'Sua graduação aparecerá após a primeira matrícula.',
                ),
              )
            else
              for (final rank in me.ranks)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ProfileRankCard(rank: rank),
                ),
            _sectionHeading(
              'Histórico de aulas',
              icon: Icons.history_rounded,
              trailing: data.history.isEmpty
                  ? null
                  : '${data.history.length} REG.',
            ),
            if (data.history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: EmptyState(
                  title: 'Sua próxima aula está esperando',
                  subtitle: 'Quando treinar, sua presença aparecerá aqui.',
                ),
              )
            else
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (var index = 0; index < history.length; index++) ...[
                      if (index > 0) const Divider(indent: 54),
                      _HistoryTile(entry: history[index]),
                    ],
                    if (data.history.length > 4)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(
                            () => _showAllHistory = !_showAllHistory,
                          ),
                          child: Text(
                            _showAllHistory ? 'Mostrar menos' : 'Ver histórico',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            _sectionHeading(
              'Dados pessoais',
              icon: Icons.account_circle_outlined,
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _Info(
                    icon: Icons.alternate_email_rounded,
                    label: 'E-mail',
                    value: me.email ?? 'Não informado',
                  ),
                  const Divider(indent: 54),
                  _Info(
                    icon: Icons.phone_outlined,
                    label: 'Telefone',
                    value: me.phone ?? 'Não informado',
                  ),
                  const Divider(indent: 54),
                  _Info(
                    icon: Icons.cake_outlined,
                    label: 'Nascimento',
                    value: formatDate(me.birthDate),
                  ),
                ],
              ),
            ),
            _sectionHeading('Conta', icon: Icons.settings_outlined),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.lock_outline_rounded,
                      color: Palette.ink2,
                    ),
                    title: const Text('Segurança da conta'),
                    subtitle: const Text('Atualize sua senha de acesso'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _changePassword(context, api),
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Palette.bad,
                    ),
                    title: const Text(
                      'Sair da conta',
                      style: TextStyle(
                        color: Palette.bad,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: session.logout,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkIn(ClassSlot slot, Future<void> Function() reload) async {
    setState(() => _busyClassId = slot.id);
    try {
      await StudentApi(context.read<Session>().api).checkIn(slot.id);
      if (mounted) showMessage(context, 'Presença confirmada. Aproveite!');
      await reload();
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busyClassId = null);
    }
  }

  Widget _sectionHeading(String title, {IconData? icon, String? trailing}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: Palette.blood),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(title, style: displayStyle(18))),
            if (trailing != null)
              Text(trailing, style: monoStyle(size: 10, color: Palette.ink3)),
          ],
        ),
      );

  Future<void> _changePassword(BuildContext context, StudentApi api) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Palette.panel,
        title: Text('TROCAR SENHA', style: displayStyle(24)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha atual'),
                validator: (v) => (v ?? '').isEmpty ? 'Obrigatória' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nova senha (mín. 8)',
                ),
                validator: (v) =>
                    (v ?? '').length < 8 ? 'Mínimo de 8 caracteres' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await api.changePassword(current.text, next.text);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  showMessage(dialogContext, errorText(e), error: true);
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    if (changed == true && context.mounted) {
      showMessage(context, 'Senha alterada!');
    }
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Palette.ink2, size: 21),
      title: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Palette.ink3),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          color: Palette.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      dense: true,
      minVerticalPadding: 8,
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({
    required this.classSlot,
    required this.busy,
    required this.onOpenSchedule,
    required this.onCheckIn,
  });

  final ClassSlot? classSlot;
  final bool busy;
  final VoidCallback onOpenSchedule;
  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final slot = classSlot;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F1F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.sports_martial_arts_rounded,
                color: Palette.ink,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot?.name ?? 'Sua próxima aula começa aqui',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slot == null
                        ? 'Confira os horários disponíveis'
                        : '${studentClassDayLabel(slot, DateTime.now())} · ${slot.startTime}–${slot.endTime}',
                    style: const TextStyle(color: Palette.ink2, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: slot?.checkInOpen == true && !slot!.checkedInToday
                  ? 'Fazer check-in'
                  : 'Abrir agenda',
              onPressed: busy
                  ? null
                  : slot?.checkInOpen == true && !slot!.checkedInToday
                  ? onCheckIn
                  : onOpenSchedule,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      slot?.checkInOpen == true && !slot!.checkedInToday
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRankCard extends StatelessWidget {
  const _ProfileRankCard({required this.rank});

  final RankProgress rank;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rank.modalityName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (rank.eligible)
                  const StatusChip('APTO A GRADUAR', tone: Tone.good),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                BeltBadge(
                  color: rank.beltColor,
                  degree: rank.degree,
                  width: 90,
                  height: 15,
                ),
                const SizedBox(width: 10),
                Text(
                  '${rank.beltName} · ${degreeLabel(rank.degree)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(rank.progress * 100).round()}%',
                  style: monoStyle(size: 11, color: Palette.ink2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ProgressBar(value: rank.progress, highlight: rank.eligible),
            const SizedBox(height: 6),
            Text(
              rank.eligible
                  ? 'Você atingiu o mínimo de aulas para a próxima graduação.'
                  : '${rank.classesSince} de ${rank.minClasses} aulas · faltam ${rank.classesRemaining}',
              style: const TextStyle(color: Palette.ink2, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final CheckInEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Palette.good.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.check_rounded, color: Palette.good, size: 19),
      ),
      title: Text(
        entry.className ?? entry.modality?.name ?? 'Treino',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(
        entry.modality?.name ?? 'Presença confirmada',
        style: const TextStyle(color: Palette.ink3, fontSize: 11),
      ),
      trailing: Text(
        formatDateTime(entry.checkedAt),
        style: monoStyle(size: 9.5),
      ),
    );
  }
}

class _PaymentAlert extends StatelessWidget {
  const _PaymentAlert({
    required this.count,
    required this.amountCents,
    required this.onTap,
  });

  final int count;
  final int amountCents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Palette.bad.withValues(alpha: 0.07),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Palette.bad),
        title: Text(
          '$count mensalidade(s) em atraso',
          style: const TextStyle(
            color: Palette.bad,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          '${formatMoney(amountCents)} · toque para ver detalhes',
          style: const TextStyle(color: Palette.ink2, fontSize: 11),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Palette.bad),
        onTap: onTap,
      ),
    );
  }
}
