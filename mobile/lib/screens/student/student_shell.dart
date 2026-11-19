import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';

import '../../social/screens/saved_screen.dart';
import '../../social/social_shell.dart';
import '../../social/widgets/community_switcher.dart';
import '../../social/widgets/social_ui.dart';
import '../../tracks/screens/student_tracks_screen.dart';
import '../../tracks/tracks_api.dart';
import '../../tracks/tracks_models.dart';
import '../../tracks/widgets/belt_widgets.dart';
import '../community_screen.dart';
import 'student_profile_tab.dart';

/// App do aluno: a mesma estrutura do app do professor (rede social + painel de atalhos no perfil),
/// com as ferramentas do aluno: agenda e check-in, evolução na faixa e mensalidades,
/// e a aba "Descomplicando a Faixa X" com a trilha da faixa atual.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  static void openSchedule(BuildContext context) =>
      _openSection(context, 'Agenda e check-in', StudentAcademyTab.schedule);
  static void openEvolution(BuildContext context) => _openSection(context, 'Minha evolução', StudentAcademyTab.summary);
  static void openPlans(BuildContext context) =>
      _openSection(context, 'Planos e mensalidades', StudentAcademyTab.plans);

  static void openCommunities(BuildContext context) =>
      openToolPage(context, 'Comunidades', const CommunityScreen(), background: SocialColors.bg);

  /// Cada seção abre sozinha, sem a barra Resumo/Agenda/Planos no topo.
  static void _openSection(BuildContext context, String title, StudentAcademyTab section) =>
      openToolPage(context, title, StudentProfileTab(section: section));

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  TrackBelt? _belt;
  int? _contextVersion;

  /// A aba leva o nome e a cor da faixa do aluno; busca cedo para a barra já mostrar certo.
  Future<void> _loadBelt() async {
    try {
      final track = await TracksApi(context.read<Session>().api).studentTrack();
      if (mounted) setState(() => _belt = track.current);
    } catch (error) {
      debugPrint('Falha ao carregar a faixa do aluno: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ao trocar de academia a faixa muda junto.
    final version = context.select<Session, int>((session) => session.studentContextVersion);
    if (version != _contextVersion) {
      _contextVersion = version;
      _belt = null;
      _loadBelt();
    }
    final belt = _belt;
    return SocialShell(
      extraTab: SocialExtraTab(
        label: belt == null ? 'Minha faixa' : belt.title,
        icon: (selected, dark) => BeltIcon(
          color: belt?.color ?? Colors.white,
          outline: dark ? Colors.white : SocialColors.ink,
          filled: selected,
        ),
        builder: (_) => StudentTracksScreen(
          onBeltLoaded: (loaded) {
            if (mounted && (loaded.id != _belt?.id || loaded.degree != _belt?.degree)) setState(() => _belt = loaded);
          },
        ),
      ),
      onProfileTitleTap: (context) =>
          showCommunitySwitcher(context, onManage: () => StudentShell.openCommunities(context)),
      profileShortcuts: const ProfileShortcutsRow(
        shortcuts: [
          ProfileShortcut(
            key: Key('shortcut-schedule'),
            icon: Icons.event_available_rounded,
            label: 'Agenda',
            onTap: StudentShell.openSchedule,
          ),
          ProfileShortcut(
            key: Key('shortcut-evolution'),
            icon: Icons.military_tech_outlined,
            label: 'Evolução',
            onTap: StudentShell.openEvolution,
          ),
          ProfileShortcut(
            key: Key('shortcut-plans'),
            icon: Icons.receipt_long_outlined,
            label: 'Mensalidades',
            onTap: StudentShell.openPlans,
          ),
        ],
      ),
      menuItems: (context) => [
        const SocialMenuItem(
          icon: Icons.event_available_rounded,
          title: 'Agenda e check-in',
          subtitle: 'Aulas da semana e presença',
          onSelected: StudentShell.openSchedule,
        ),
        const SocialMenuItem(
          icon: Icons.military_tech_outlined,
          title: 'Minha evolução',
          subtitle: 'Faixa, graus e histórico de aulas',
          onSelected: StudentShell.openEvolution,
        ),
        const SocialMenuItem(
          icon: Icons.receipt_long_outlined,
          title: 'Planos e mensalidades',
          onSelected: StudentShell.openPlans,
        ),
        const SocialMenuItem(
          icon: Icons.groups_2_outlined,
          title: 'Comunidades',
          subtitle: 'Trocar de academia ou aceitar convite',
          onSelected: StudentShell.openCommunities,
        ),
        SocialMenuItem(
          icon: Icons.bookmark_border_rounded,
          title: 'Salvos',
          onSelected: (context) =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SavedScreen())),
        ),
      ],
    );
  }
}
