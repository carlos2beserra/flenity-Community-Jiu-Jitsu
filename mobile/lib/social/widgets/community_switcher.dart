import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../ui/widgets/common.dart';
import '../social_models.dart';
import 'social_ui.dart';

/// Troca a academia ativa e volta para a tela inicial (o app inteiro passa a usar a nova academia).
Future<bool> switchCommunity(BuildContext context, CommunityMembership community) async {
  final session = context.read<Session>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await session.switchCommunity(community.id);
    navigator.popUntil((route) => route.isFirst);
    messenger?.showSnackBar(SnackBar(content: Text('Agora você está em ${community.name}.')));
    return true;
  } catch (error) {
    if (context.mounted) showMessage(context, errorText(error), error: true);
    return false;
  }
}

/// Folha inferior para alternar rapidamente entre as academias da conta.
Future<void> showCommunitySwitcher(BuildContext context, {required VoidCallback onManage}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: SocialColors.bg,
      builder: (_) => _CommunitySwitcher(onManage: onManage),
    );

class _CommunitySwitcher extends StatefulWidget {
  const _CommunitySwitcher({required this.onManage});

  final VoidCallback onManage;

  @override
  State<_CommunitySwitcher> createState() => _CommunitySwitcherState();
}

class _CommunitySwitcherState extends State<_CommunitySwitcher> {
  List<CommunityMembership>? _communities;
  Object? _error;
  String? _switching;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final communities = await socialApiOf(context).communities();
      if (mounted) setState(() => _communities = communities);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _select(CommunityMembership community) async {
    if (community.isCurrent) {
      Navigator.pop(context);
      return;
    }
    setState(() => _switching = community.id);
    final ok = await switchCommunity(context, community);
    if (!ok && mounted) setState(() => _switching = null);
  }

  @override
  Widget build(BuildContext context) {
    final communities = _communities;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Suas academias', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(errorText(_error), style: const TextStyle(color: SocialColors.ink2)),
            )
          else if (communities == null)
            const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
          else
            for (final community in communities)
              ListTile(
                key: ValueKey('switch-${community.id}'),
                onTap: _switching == null ? () => _select(community) : null,
                leading: AcademyMark(name: community.name, size: 44),
                title: Text(community.name, style: socialBold),
                subtitle: Text('${compactCount(community.memberCount)} membros'),
                trailing: _switching == community.id
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : community.isCurrent
                    ? const Icon(Icons.check_circle_rounded, color: SocialColors.accent)
                    : const Icon(Icons.radio_button_unchecked_rounded, color: SocialColors.line),
              ),
          const Divider(color: SocialColors.line),
          ListTile(
            leading: const Icon(Icons.group_add_outlined, color: SocialColors.ink),
            title: const Text('Entrar em outra academia ou gerenciar', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              widget.onManage();
            },
          ),
        ],
      ),
    );
  }
}

/// "Logo" da academia: iniciais sobre um gradiente com a cor derivada do nome.
class AcademyMark extends StatelessWidget {
  const AcademyMark({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  static const _gradients = [
    [Color(0xFF1689EF), Color(0xFF0B5CAD)],
    [Color(0xFF16A394), Color(0xFF0E7468)],
    [Color(0xFF7C3AED), Color(0xFF5B21B6)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
    [Color(0xFF1F2937), Color(0xFF111827)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[name.codeUnits.fold<int>(0, (sum, c) => sum + c) % _gradients.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      child: Text(
        initials(name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36),
      ),
    );
  }
}
