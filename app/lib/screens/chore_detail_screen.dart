import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_comment.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:farm_chore/widgets/status_actions_sheet.dart';

/// Detail screen for a chore instance: description, checklist, comments.
class ChoreDetailScreen extends StatefulWidget {
  const ChoreDetailScreen({
    super.key,
    required this.instance,
    required this.repository,
    required this.myPubkey,
  });

  final ChoreInstance instance;
  final ChoreRepository repository;
  final String myPubkey;

  @override
  State<ChoreDetailScreen> createState() => _ChoreDetailScreenState();
}

class _ChoreDetailScreenState extends State<ChoreDetailScreen> {
  List<ChoreComment> _comments = [];
  Map<String, String> _names = {};
  List<String> _checklist = [];
  String _description = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final comments = await widget.repository.loadComments(widget.instance.dTag);
    final names = await widget.repository.loadMemberNames();
    // Load description and checklist from the role defaults.
    final defaults = await widget.repository.loadBaseRoleDefaultSets();
    final roleSet = defaults
        .where((s) => s.role == widget.instance.role)
        .firstOrNull;
    final choreDefault = roleSet?.chores
        .where((c) => c.title == widget.instance.title)
        .firstOrNull;
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _names = names;
      _description = choreDefault?.description ?? '';
      _checklist = choreDefault?.checklist ?? [];
      _loading = false;
    });
  }

  Future<void> _addComment() async {
    final controller = TextEditingController();
    final posted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add comment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Note about this chore…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (posted != true || !mounted) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    await widget.repository.addComment(widget.instance.dTag, text);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final instance = widget.instance;
    final accent = roleAccent(instance.role);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(instance.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.touch_app),
            tooltip: 'Actions',
            onPressed: () => showStatusActions(
              context: context,
              instance: instance,
              repository: widget.repository,
              today: DateTime.now(),
              onChanged: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Role + status header.
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        instance.role.displayName,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: FarmColors.soilBrown,
                        ),
                      ),
                      const Spacer(),
                      _StatusChip(status: instance.status),
                    ],
                  ),
                ),

                // Assignee.
                if (instance.assignee != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Assigned to',
                    value:
                        _names[instance.assignee!] ??
                        _shortHex(instance.assignee!),
                  ),
                ],

                // Description.
                if (_description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Description', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(_description, style: theme.textTheme.bodyMedium),
                ],

                // Checklist.
                if (_checklist.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Checklist', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  for (final item in _checklist)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_box_outline_blank,
                            size: 20,
                            color: FarmColors.sabbath,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                // Comments section.
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('Comments', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    if (_comments.isNotEmpty)
                      Text(
                        '${_comments.length}',
                        style: theme.textTheme.labelMedium,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No comments yet',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  )
                else
                  for (final comment in _comments)
                    _CommentTile(
                      comment: comment,
                      authorName:
                          _names[comment.author] ?? _shortHex(comment.author),
                    ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _addComment,
            icon: const Icon(Icons.comment, size: 18),
            label: const Text('Add comment'),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ChoreStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ChoreStatus.open => (FarmColors.dawnAmber, 'Open'),
      ChoreStatus.done => (FarmColors.cottonwoodGreen, 'Done'),
      ChoreStatus.skipped => (FarmColors.hayYellow, 'Skipped'),
      ChoreStatus.deferred => (FarmColors.springBlue, 'Deferred'),
      ChoreStatus.cancelled => (FarmColors.soilBrown, 'Cancelled'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: FarmColors.sabbath),
        const SizedBox(width: 8),
        Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.authorName});
  final ChoreComment comment;
  final String authorName;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: FarmColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(authorName, style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                Text(
                  _timeAgo(comment.createdAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(comment.text, style: Theme.of(context).textTheme.bodyMedium),
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
