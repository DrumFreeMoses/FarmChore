import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/heads_up.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';

/// Farm News: heads-up notices and urgent alerts for the whole farm or
/// one role group. Anyone can post.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key, required this.repository});

  final ChoreRepository repository;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<HeadsUp> _headsUps = [];
  Map<String, String> _names = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final headsUps = await widget.repository.loadHeadsUps();
    final names = await widget.repository.loadMemberNames();
    if (!mounted) return;
    setState(() {
      _headsUps = headsUps;
      _names = names;
      _loading = false;
    });
  }

  Future<void> _addHeadsUp({HeadsUpType type = HeadsUpType.news}) async {
    final textController = TextEditingController();
    FarmRole? scope;
    final isAlert = type == HeadsUpType.alert;
    final posted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              if (isAlert)
                Icon(Icons.warning_amber, color: FarmColors.error)
              else
                Icon(Icons.campaign, color: FarmColors.dawnAmber),
              const SizedBox(width: 8),
              Text(isAlert ? 'Send alert' : 'Heads up'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isAlert)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      color: FarmColors.error.withAlpha(25),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          'This will send an urgent ping to all members in the selected group.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isAlert ? 'Alert message' : 'Notice',
                    hintText: isAlert
                        ? 'e.g. Water pipe burst in the parlor!'
                        : 'e.g. Frost tonight — cover the greens',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<FarmRole?>(
                  initialValue: scope,
                  decoration: const InputDecoration(labelText: 'Send to'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Whole farm'),
                    ),
                    for (final role in FarmRoles.all)
                      DropdownMenuItem(
                        value: role,
                        child: Text(role.displayName),
                      ),
                  ],
                  onChanged: (value) => setDialogState(() => scope = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: isAlert
                  ? FilledButton.styleFrom(backgroundColor: FarmColors.error)
                  : null,
              child: Text(isAlert ? 'Send alert' : 'Post'),
            ),
          ],
        ),
      ),
    );
    if (posted != true || !mounted) return;
    final text = textController.text.trim();
    if (text.isEmpty) return;
    await widget.repository.saveHeadsUp(text, scope: scope, type: type);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farm News')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'alert',
            tooltip: 'Send urgent alert',
            onPressed: () => _addHeadsUp(type: HeadsUpType.alert),
            backgroundColor: FarmColors.error,
            child: const Icon(Icons.warning_amber, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'heads_up',
            tooltip: 'Add heads up',
            onPressed: () => _addHeadsUp(type: HeadsUpType.news),
            child: const Icon(Icons.campaign),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _headsUps.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No news yet. Post the first one!'),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        for (final notice in _headsUps)
                          _HeadsUpCard(
                            notice: notice,
                            authorName:
                                _names[notice.author] ??
                                _shortHex(notice.author),
                          ),
                      ],
                    ),
            ),
    );
  }
}

class _HeadsUpCard extends StatelessWidget {
  const _HeadsUpCard({required this.notice, required this.authorName});

  final HeadsUp notice;
  final String authorName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isAlert = notice.isAlert;
    final accent = isAlert
        ? FarmColors.error
        : notice.scope == null
        ? FarmColors.dawnAmber
        : roleAccent(notice.scope!);
    return Card(
      elevation: isAlert ? 2 : 0,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accent.withValues(alpha: isAlert ? 0.8 : 0.5),
          width: isAlert ? 2 : 1,
        ),
      ),
      color: isAlert ? accent.withAlpha(12) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isAlert)
                  Icon(Icons.warning_amber, size: 16, color: accent)
                else
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const SizedBox(width: 8),
                if (isAlert)
                  Text(
                    'ALERT',
                    style: textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Text(
                    notice.scope == null
                        ? 'Whole farm'
                        : notice.scope!.displayName,
                    style: textTheme.labelSmall?.copyWith(
                      color: FarmColors.soilBrown,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const Spacer(),
                Text(
                  _timeAgo(notice.createdAt),
                  style: textTheme.labelSmall?.copyWith(
                    color: FarmColors.sabbath,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              notice.text,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: isAlert ? FontWeight.w600 : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '— $authorName',
              style: textTheme.labelSmall?.copyWith(
                color: FarmColors.soilBrown.withValues(alpha: 0.7),
              ),
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
