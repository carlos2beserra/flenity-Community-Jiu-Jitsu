import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../core/api_client.dart';
import '../core/session.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.active = true});

  final bool active;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ApiClient _api = context.read<Session>().api;
  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _contacts = const [];
  Timer? _searchDebounce;
  String _search = '';
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) unawaited(_load());
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (mounted && showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _api.get('/chat/conversations'),
        _api.get('/chat/contacts', query: {'search': _search.trim()}),
      ]);
      if (!mounted) return;
      setState(() {
        _conversations = (results[0] as List).cast<Map<String, dynamic>>();
        _contacts = (results[1] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _searchContacts(String value) {
    _search = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_load(showSpinner: false)),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    final session = context.read<Session>();
    final isStudent = session.status == SessionStatus.student;
    final participant = isStudent
        ? conversation['staff'] as Map<String, dynamic>
        : conversation['student'] as Map<String, dynamic>;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          api: _api,
          conversationId: conversation['id'] as String,
          participantName: participant['name'] as String,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _startConversation(Map<String, dynamic> contact) async {
    try {
      final conversation =
          await _api.post('/chat/conversations', {
                'participantId': contact['id'],
              })
              as Map<String, dynamic>;
      if (!mounted) return;
      await _openConversation(conversation);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final session = context.watch<Session>();
    final isStudent = session.status == SessionStatus.student;
    return RefreshIndicator(
      color: Palette.blood,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
        children: [
          Text('CHAT', style: displayStyle(34)),
          const SizedBox(height: 4),
          const Text(
            'Converse com a equipe da sua academia.',
            style: TextStyle(color: Palette.ink2),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ErrorView(message: errorText(_error), onRetry: _load)
          else ...[
            if (_conversations.isNotEmpty) ...[
              const _SectionHeading('Conversas'),
              const SizedBox(height: 8),
              for (final conversation in _conversations)
                _ConversationTile(
                  conversation: conversation,
                  isStudent: isStudent,
                  onTap: () => _openConversation(conversation),
                ),
              const SizedBox(height: 22),
            ],
            _SectionHeading(
              isStudent ? 'Fale com a equipe' : 'Alunos disponíveis',
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: _searchContacts,
              decoration: const InputDecoration(
                hintText: 'Buscar contato',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            if (_contacts.isEmpty)
              EmptyState(
                title: isStudent
                    ? 'Equipe indisponível'
                    : 'Nenhum aluno disponível',
                subtitle: isStudent
                    ? 'Não encontramos contatos da equipe desta academia.'
                    : 'Alunos ativos com acesso ao app aparecerão aqui.',
              )
            else
              for (final contact in _contacts)
                _ContactTile(
                  contact: contact,
                  onTap: () => _startConversation(contact),
                ),
          ],
        ],
      ),
    );
  }
}

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.api,
    required this.conversationId,
    required this.participantName,
  });

  final ApiClient api;
  final String conversationId;
  final String participantName;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  socket_io.Socket? _socket;
  bool _loading = true;
  bool _sending = false;
  bool _connected = false;
  bool _connectionFailed = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMessages());
    _connect();
  }

  Future<void> _loadMessages() async {
    try {
      final result =
          await widget.api.get(
                '/chat/conversations/${widget.conversationId}/messages',
              )
              as List;
      if (!mounted) return;
      setState(() {
        for (final item in result.cast<Map<String, dynamic>>()) {
          if (!_messages.any((message) => message['id'] == item['id'])) {
            _messages.add(item);
          }
        }
        _messages.sort(
          (a, b) => DateTime.parse(
            a['createdAt'] as String,
          ).compareTo(DateTime.parse(b['createdAt'] as String)),
        );
        _loading = false;
        _error = null;
      });
      _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _connect() {
    final apiUri = Uri.parse(widget.api.baseUrl);
    final baseUri = apiUri.replace(
      path: apiUri.path.replaceFirst(RegExp(r'/api/?$'), ''),
      query: null,
      fragment: null,
    );
    final connection = socket_io.io(
      '${baseUri.toString().replaceFirst(RegExp(r'/$'), '')}/chat',
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': widget.api.token})
          .disableAutoConnect()
          .build(),
    );
    _socket = connection;
    connection.onConnect((_) {
      if (!mounted) return;
      setState(() {
        _connected = true;
        _connectionFailed = false;
      });
    });
    connection.on('chat:ready', (_) {
      connection.emit('chat:join', {'conversationId': widget.conversationId});
    });
    connection.onDisconnect((_) {
      if (mounted) {
        setState(() {
          _connected = false;
          _connectionFailed = true;
        });
      }
    });
    connection.onConnectError((_) {
      if (mounted) {
        setState(() {
          _connected = false;
          _connectionFailed = true;
        });
      }
    });
    connection.on('chat:message', _receiveMessage);
    connection.connect();
  }

  void _receiveMessage(dynamic payload) {
    if (payload is! Map) return;
    final message = Map<String, dynamic>.from(payload);
    if (message['conversationId'] != widget.conversationId) return;
    if (_messages.any((item) => item['id'] == message['id'])) return;
    if (!mounted) return;
    setState(() => _messages.add(message));
    _scrollToLatest();
  }

  Future<void> _send() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message =
          await widget.api.post(
                '/chat/conversations/${widget.conversationId}/messages',
                {'content': content},
              )
              as Map<String, dynamic>;
      if (!mounted) return;
      _messageController.clear();
      _receiveMessage(message);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _socket?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<Session>().staff?.id;
    final isStaff = currentUserId != null;
    return Scaffold(
      backgroundColor: Palette.mat,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: Palette.blood.withValues(alpha: 0.12),
              child: Text(
                _initials(widget.participantName),
                style: const TextStyle(
                  color: Palette.blood,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.participantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Palette.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _connected ? Palette.good : Palette.ink3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _connected
                            ? 'Conectado'
                            : _connectionFailed
                            ? 'Sem conexão em tempo real'
                            : 'Conectando…',
                        style: const TextStyle(
                          color: Palette.ink2,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _messages.isEmpty
                ? ErrorView(message: errorText(_error), onRetry: _loadMessages)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    itemCount: _messages.isEmpty ? 1 : _messages.length,
                    itemBuilder: (context, index) {
                      if (_messages.isEmpty) {
                        return const _ChatWelcome();
                      }
                      final message = _messages[index];
                      final mine = isStaff
                          ? message['senderRole'] == 'STAFF'
                          : message['senderRole'] == 'STUDENT';
                      return _MessageBubble(message: message, mine: mine);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Escreva uma mensagem…',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Palette.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Palette.line),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Palette.blood,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: _sending ? null : _send,
                      tooltip: 'Enviar mensagem',
                      icon: _sending
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                            ),
                    ),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Palette.ink2,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.isStudent,
    required this.onTap,
  });

  final Map<String, dynamic> conversation;
  final bool isStudent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final person =
        (isStudent ? conversation['staff'] : conversation['student'])
            as Map<String, dynamic>;
    final last = conversation['lastMessage'] as Map<String, dynamic>?;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: _PersonAvatar(name: person['name'] as String),
        title: Text(
          person['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          last?['content'] as String? ?? 'Inicie a conversa',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Palette.ink2),
        ),
        trailing: const Icon(Icons.chevron_right, color: Palette.ink3),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final Map<String, dynamic> contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] as String;
    final roleLabel = switch (contact['role'] as String?) {
      'ADMIN' => 'Administrador',
      'INSTRUCTOR' => 'Professor',
      'RECEPTION' => 'Recepção',
      _ => 'Aluno',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: _PersonAvatar(name: name),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(roleLabel, style: const TextStyle(color: Palette.ink2)),
        trailing: const Icon(Icons.chat_bubble_outline, color: Palette.blood),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Palette.blood.withValues(alpha: 0.11),
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Palette.blood,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final Map<String, dynamic> message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(message['createdAt'] as String? ?? '');
    final time = createdAt == null
        ? ''
        : '${createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
              '${createdAt.toLocal().minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 7),
        decoration: BoxDecoration(
          color: mine ? Palette.blood : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C183149),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message['content'] as String,
                style: TextStyle(
                  color: mine ? Colors.white : Palette.ink,
                  height: 1.35,
                ),
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  color: mine ? Colors.white70 : Palette.ink3,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatWelcome extends StatelessWidget {
  const _ChatWelcome();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 80, 14, 30),
      child: Column(
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.line),
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  size: 31,
                  color: Palette.blood,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Conversa nova', style: displayStyle(24)),
          const SizedBox(height: 7),
          const Text(
            'Envie uma mensagem para começar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.ink2),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
