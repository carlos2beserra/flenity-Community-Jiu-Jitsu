import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../social/screens/follow_list_screen.dart';
import '../social/social_models.dart';
import '../social/social_navigation.dart';
import '../social/widgets/community_switcher.dart';
import '../social/widgets/social_ui.dart';
import '../ui/widgets/common.dart';

/// Comunidades do aluno: resumo da academia atual, pessoas para seguir,
/// troca entre academias e entrada em uma nova academia por convite.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.active = true});

  final bool active;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _invite = TextEditingController();
  List<CommunityMembership> _communities = const [];
  List<SocialPerson> _suggestions = const [];
  final Map<String, bool> _following = {};
  final Set<String> _followBusy = {};
  bool _loading = true;
  bool _joining = false;
  String? _inviteError;
  Object? _error;

  CommunityMembership? get _current => _communities.where((c) => c.isCurrent).firstOrNull;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  @override
  void dispose() {
    _invite.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = socialApiOf(context);
    setState(() {
      _loading = _communities.isEmpty;
      _error = null;
    });
    try {
      final communities = await api.communities();
      if (!mounted) return;
      setState(() {
        _communities = communities;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
      return;
    }
    await _loadSuggestions();
  }

  /// Sugestões são um extra: se falharem, a tela continua utilizável.
  Future<void> _loadSuggestions() async {
    try {
      final people = await socialApiOf(context).people();
      if (!mounted) return;
      setState(() {
        _suggestions = people.items.where((p) => !p.isMe && !p.isFollowing).take(12).toList();
        for (final person in _suggestions) {
          _following[person.author.id] = false;
        }
      });
    } catch (error) {
      debugPrint('Falha ao carregar sugestões da comunidade: $error');
    }
  }

  Future<void> _toggleFollow(SocialPerson person) async {
    setState(() => _followBusy.add(person.author.id));
    try {
      final following = await socialApiOf(context).toggleFollow(person.author.id);
      if (mounted) setState(() => _following[person.author.id] = following);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _followBusy.remove(person.author.id));
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      showMessage(context, 'A área de transferência está vazia.', error: true);
      return;
    }
    _invite.text = text;
    setState(() => _inviteError = null);
  }

  Future<void> _acceptInvite() async {
    final token = parseInviteToken(_invite.text);
    if (token == null) {
      setState(() => _inviteError = 'Esse não parece um convite válido. Cole o link completo enviado pela academia.');
      return;
    }
    setState(() {
      _joining = true;
      _inviteError = null;
    });
    try {
      await context.read<Session>().acceptCommunityInvite(token);
      _invite.clear();
      await _load();
      if (mounted) showMessage(context, 'Você entrou na comunidade!');
    } catch (error) {
      if (mounted) setState(() => _inviteError = errorText(error));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _confirmSwitch(CommunityMembership community) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: SocialColors.bg,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AcademyMark(name: community.name, size: 64),
              const SizedBox(height: 12),
              Text(
                'Trocar para ${community.name}?',
                textAlign: TextAlign.center,
                style: socialTitleStyle.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 6),
              const Text(
                'Feed, flashes, agenda, mensalidades e chat passam a mostrar essa academia. '
                'Você pode voltar quando quiser.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SocialColors.ink2),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('confirm-switch'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Trocar de academia'),
                ),
              ),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) await switchCommunity(context, community);
  }

  void _openAllMembers() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: SocialColors.bg,
        appBar: AppBar(
          backgroundColor: SocialColors.bg,
          title: Text('Membros', style: socialTitleStyle.copyWith(fontSize: 18)),
        ),
        body: PeopleList(load: (api) => api.people(), emptyText: 'Ainda não há outros membros no app.'),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return ColoredBox(
      color: SocialColors.bg,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (_loading)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              ErrorView(message: errorText(_error), onRetry: _load)
            else ...[
              if (_current != null) _hero(_current!),
              if (_suggestions.isNotEmpty) ..._suggestionsSection(),
              ..._academiesSection(),
            ],
            _inviteSection(),
          ],
        ),
      ),
    );
  }

  Widget _hero(CommunityMembership community) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2A44), Color(0xFF1689EF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AcademyMark(name: community.name, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VOCÊ ESTÁ EM',
                      style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      community.name,
                      key: const Key('current-community-name'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (community.plans.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final plan in community.plans)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      plan,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _HeroStat(value: compactCount(community.memberCount), label: 'membros no app')),
              Expanded(child: _HeroStat(value: compactCount(community.postsThisWeek), label: 'publicações na semana')),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F2A44),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Ver feed'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  List<Widget> _suggestionsSection() => [
    _SectionHeader(title: 'Pessoas da sua academia', action: 'Ver todos', onAction: _openAllMembers),
    SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final person = _suggestions[index];
          final id = person.author.id;
          return Container(
            width: 148,
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            decoration: BoxDecoration(
              border: Border.all(color: SocialColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                SocialAvatar(author: person.author, size: 64, onTap: () => openProfile(context, person.author)),
                const SizedBox(height: 8),
                Text(
                  person.author.handle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: socialBold.copyWith(fontSize: 13),
                ),
                Text(
                  person.author.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SocialColors.ink2, fontSize: 12),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FollowButton(
                    key: ValueKey('suggest-follow-$id'),
                    dense: true,
                    following: _following[id] ?? false,
                    busy: _followBusy.contains(id),
                    onPressed: () => _toggleFollow(person),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  ];

  List<Widget> _academiesSection() {
    final others = _communities.where((c) => !c.isCurrent).toList();
    return [
      const _SectionHeader(title: 'Suas outras academias'),
      if (others.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Você está vinculado a uma academia. Treina em outra também? Use o convite abaixo.',
            style: TextStyle(color: SocialColors.ink2),
          ),
        ),
      for (final community in others)
        ListTile(
          key: ValueKey('community-${community.id}'),
          onTap: () => _confirmSwitch(community),
          leading: AcademyMark(name: community.name, size: 46),
          title: Text(community.name, style: socialBold),
          subtitle: Text(
            [
              if (community.plans.isNotEmpty) community.plans.join(' · '),
              '${compactCount(community.memberCount)} membros',
            ].join(' — '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton(onPressed: () => _confirmSwitch(community), child: const Text('Trocar')),
        ),
    ];
  }

  Widget _inviteSection() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: SocialColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mail_outline_rounded, color: SocialColors.ink),
              SizedBox(width: 8),
              Expanded(
                child: Text('Entrar em outra academia', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'A recepção da academia envia um link de convite para o seu e-mail cadastrado. '
            'Ele vale por 14 dias e só funciona com o mesmo e-mail desta conta.',
            style: TextStyle(color: SocialColors.ink2, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _invite,
            enabled: !_joining,
            onChanged: (_) {
              if (_inviteError != null) setState(() => _inviteError = null);
            },
            onSubmitted: (_) => _acceptInvite(),
            decoration: InputDecoration(
              hintText: 'Link ou código do convite',
              isDense: true,
              filled: true,
              fillColor: SocialColors.bg,
              errorText: _inviteError,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: 'Colar convite',
                onPressed: _joining ? null : _paste,
                icon: const Icon(Icons.content_paste_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _joining ? null : _acceptInvite,
              icon: _joining
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.group_add_outlined),
              label: const Text('Entrar na comunidade'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
    ],
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
    child: Row(
      children: [
        Expanded(child: Text(title, style: socialBold.copyWith(fontSize: 16))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}
