import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/farm_message.dart';
import 'package:farm_chore/theme/farm_theme.dart';

/// Messages screen: farm-wide broadcast channel and per-member DM threads.
class MessageScreen extends StatefulWidget {
  const MessageScreen({
    super.key,
    required this.repository,
    required this.myPubkey,
  });

  final ChoreRepository repository;
  final String myPubkey;

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  List<FarmMessage> _messages = [];
  Map<String, String> _names = {};
  bool _loading = true;
  String? _activeConversation; // null = farm-wide

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final messages = await widget.repository.loadMessages();
    final names = await widget.repository.loadMemberNames();
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _names = names;
      _loading = false;
    });
  }

  List<FarmMessage> get _filteredMessages {
    if (_activeConversation == null) {
      return _messages.where((m) => m.isBroadcast).toList();
    }
    return _messages.where((m) {
      if (m.isBroadcast) return false;
      return m.conversationWith(widget.myPubkey) == _activeConversation;
    }).toList();
  }

  /// Unique conversations: 'farm' + each DM partner.
  List<String> get _conversations {
    final seen = <String>{};
    final convos = <String>[];
    for (final m in _messages) {
      final key = m.conversationWith(widget.myPubkey);
      if (seen.add(key)) convos.add(key);
    }
    // Farm first, then alphabetical.
    convos.sort((a, b) {
      if (a == 'farm') return -1;
      if (b == 'farm') return 1;
      return a.compareTo(b);
    });
    return convos;
  }

  String _label(String key) {
    if (key == 'farm') return 'Farm-wide';
    return _names[key] ?? _shortHex(key);
  }

  Future<void> _send() async {
    final controller = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _activeConversation == null ? 'Farm broadcast' : 'Direct message',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Type a message…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (sent != true || !mounted) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    await widget.repository.sendMessage(
      text,
      recipient: _activeConversation == 'farm' ? null : _activeConversation,
    );
    await _refresh();
  }

  void _openConversation(String? key) {
    setState(() => _activeConversation = key);
  }

  @override
  Widget build(BuildContext context) {
    if (_activeConversation != null) {
      return _buildThread();
    }
    return _buildInbox();
  }

  Widget _buildInbox() {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New message',
        onPressed: _showNewConversation,
        child: const Icon(Icons.message),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _conversations.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No messages yet. Say hello!'),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        for (final key in _conversations)
                          _ConversationTile(
                            name: _label(key),
                            isFarmWide: key == 'farm',
                            lastMessage: _messages
                                .where(
                                  (m) =>
                                      m.conversationWith(widget.myPubkey) ==
                                      key,
                                )
                                .lastOrNull,
                            onTap: () => _openConversation(key),
                          ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildThread() {
    final msgs = _filteredMessages;
    return Scaffold(
      appBar: AppBar(
        title: Text(_label(_activeConversation!)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _activeConversation = null),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: msgs.isEmpty
                ? const Center(child: Text('No messages yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (context, index) {
                      final msg = msgs[index];
                      final isMine = msg.author == widget.myPubkey;
                      return _MessageBubble(
                        message: msg,
                        authorName: _names[msg.author] ?? _shortHex(msg.author),
                        isMine: isMine,
                      );
                    },
                  ),
          ),
          _ComposeBar(onSend: _send),
        ],
      ),
    );
  }

  void _showNewConversation() async {
    final members = await widget.repository.loadAllMembers();
    final others = members.where((m) => m.pubkey != widget.myPubkey).toList();
    if (!mounted || others.isEmpty) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Message whom?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('farm'),
            child: const Text('Farm-wide broadcast'),
          ),
          for (final m in others)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(m.pubkey),
              child: Text(m.name.isEmpty ? _shortHex(m.pubkey) : m.name),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    _openConversation(chosen == 'farm' ? null : chosen);
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.name,
    required this.isFarmWide,
    this.lastMessage,
    required this.onTap,
  });

  final String name;
  final bool isFarmWide;
  final FarmMessage? lastMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = lastMessage?.text ?? 'No messages yet';
    final time = lastMessage != null ? _timeAgo(lastMessage!.createdAt) : '';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isFarmWide
            ? FarmColors.dawnAmber
            : FarmColors.springBlue,
        child: Icon(
          isFarmWide ? Icons.campaign : Icons.person,
          color: FarmColors.surface,
          size: 20,
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: time.isNotEmpty
          ? Text(time, style: Theme.of(context).textTheme.labelSmall)
          : null,
      onTap: onTap,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.authorName,
    required this.isMine,
  });

  final FarmMessage message;
  final String authorName;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isMine ? FarmColors.cottonwoodGreen : FarmColors.surfaceVariant;
    final fg = isMine ? FarmColors.surface : FarmColors.onSurface;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  authorName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: fg.withValues(alpha: 0.7),
                  ),
                ),
              ),
            Text(message.text, style: TextStyle(color: fg)),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _timeAgo(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: fg.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  const _ComposeBar({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: FarmColors.surface,
        border: Border(top: BorderSide(color: FarmColors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onSend,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: FarmColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Type a message…',
                    style: TextStyle(color: FarmColors.sabbath),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortHex(String pubkey) =>
    '${pubkey.substring(0, 8)}…${pubkey.substring(pubkey.length - 6)}';

String _timeAgo(int createdAt) {
  final age = DateTime.now().millisecondsSinceEpoch ~/ 1000 - createdAt;
  if (age < 60) return 'just now';
  if (age < 3600) return '${age ~/ 60}m ago';
  if (age < 86400) return '${age ~/ 3600}h ago';
  return '${age ~/ 86400}d ago';
}
