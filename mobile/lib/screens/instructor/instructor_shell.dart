import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../social/screens/saved_screen.dart';
import '../../social/social_shell.dart';
import '../../social/widgets/social_ui.dart';
import '../../tracks/screens/staff_tracks_screen.dart';
import '../../tracks/widgets/belt_widgets.dart';
import '../../ui/widgets/common.dart';
import 'create_instructor_dialog.dart';
import 'graduations_tab.dart';
import 'staff_api.dart';
import 'students_tab.dart';
import 'today_tab.dart';

/// App do professor/equipe: a mesma rede social dos alunos (publica, posta flashes e rolas,
/// segue e é seguido, com selo de "Professor") + ferramentas de aula no perfil
/// e a aba "Descomplicando", onde monta as trilhas de cada faixa e libera para os alunos.
class InstructorShell extends StatelessWidget {
  const InstructorShell({super.key});

  static void openClasses(BuildContext context) => openToolPage(context, 'Aulas de hoje', const TodayTab());
  static void openGraduations(BuildContext context) => openToolPage(context, 'Graduações', const GraduationsTab());
  static void openStudents(BuildContext context) => openToolPage(context, 'Alunos', const StudentsTab());

  static Future<void> _addInstructor(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => CreateInstructorDialog(api: StaffApi(context.read<Session>().api)),
    );
    if (created == true && context.mounted) showMessage(context, 'Acesso de professor criado.');
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<Session>().staff?.role;
    final isAdmin = role == 'ADMIN';
    final managesTracks = isAdmin || role == 'INSTRUCTOR';
    return SocialShell(
      extraTab: managesTracks
          ? SocialExtraTab(
              label: 'Descomplicando',
              icon: (selected, dark) => BeltIcon(
                color: const Color(0xFF111418),
                outline: dark ? Colors.white : SocialColors.ink,
                filled: selected,
              ),
              builder: (_) => const StaffTracksScreen(),
            )
          : null,
      profileShortcuts: const ProfileShortcutsRow(
        shortcuts: [
          ProfileShortcut(
            key: Key('shortcut-classes'),
            icon: Icons.event_available_rounded,
            label: 'Aulas',
            onTap: openClasses,
          ),
          ProfileShortcut(
            key: Key('shortcut-graduations'),
            icon: Icons.military_tech_outlined,
            label: 'Graduações',
            onTap: openGraduations,
          ),
          ProfileShortcut(
            key: Key('shortcut-students'),
            icon: Icons.groups_outlined,
            label: 'Alunos',
            onTap: openStudents,
          ),
        ],
      ),
      menuItems: (context) => [
        const SocialMenuItem(
          icon: Icons.event_available_rounded,
          title: 'Aulas de hoje e chamada',
          onSelected: openClasses,
        ),
        const SocialMenuItem(
          icon: Icons.military_tech_outlined,
          title: 'Graduações',
          subtitle: 'Quem está apto a graduar',
          onSelected: openGraduations,
        ),
        const SocialMenuItem(icon: Icons.groups_outlined, title: 'Alunos', onSelected: openStudents),
        SocialMenuItem(
          icon: Icons.bookmark_border_rounded,
          title: 'Salvos',
          onSelected: (context) =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SavedScreen())),
        ),
        if (isAdmin)
          const SocialMenuItem(
            icon: Icons.person_add_alt_1_outlined,
            title: 'Adicionar professor',
            subtitle: 'Criar acesso ao app para a equipe',
            onSelected: _addInstructor,
          ),
      ],
    );
  }
}
