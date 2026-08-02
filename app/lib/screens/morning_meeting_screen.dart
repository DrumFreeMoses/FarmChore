import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:farm_chore/widgets/status_actions_sheet.dart';

/// Morning meeting view: today's chores grouped by assignment status.
///
/// Shows auto-assigned chores, unassigned chores (for self-assignment),
/// and a remaining count that drops as chores are handled.
class MorningMeetingScreen extends StatefulWidget {
  const MorningMeetingScreen({
    super.key,
    required this.repository,
    required this.myPubkey,
    this.today,
  });

  final ChoreRepository repository;
  final String myPubkey;
  final DateTime? today;

  @override
  State<MorningMeetingScreen> createState() => _MorningMeetingScreenState();
}

class _MorningMeetingScreenState extends State<MorningMeetingScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  List<ChoreInstance> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await widget.repository.ensureDayGenerated(_today);
    final instances = await widget.repository.loadInstancesForDate(_today);
    if (!mounted) return;
    setState(() {
      _all = instances;
      _loading = false;
    });
  }

  List<ChoreInstance> get _assigned =>
      _all.where((i) => i.assignee != null && i.status.isRemaining).toList();

  List<ChoreInstance> get _unassigned =>
      _all.where((i) => i.assignee == null && i.status.isOpen).toList();

  List<ChoreInstance> get _done => _all.where((i) => i.status.isDone).toList();

  int get _remaining => _all.where((i) => i.status.isRemaining).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Morning Meeting'),
        actions: [
          if (_remaining > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$_remaining remaining',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _remaining == 0
                        ? FarmColors.success
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          if (_remaining == 0)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'All done!',
                  style: TextStyle(
                    color: FarmColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  if (_unassigned.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Unassigned',
                      count: _unassigned.length,
                      color: Colors.orange,
                    ),
                    for (final instance in _unassigned)
                      _MeetingChoreTile(
                        instance: instance,
                        repository: widget.repository,
                        myPubkey: widget.myPubkey,
                        onRefresh: _refresh,
                      ),
                    const Divider(),
                  ],
                  if (_assigned.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Assigned',
                      count: _assigned.length,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    for (final instance in _assigned)
                      _MeetingChoreTile(
                        instance: instance,
                        repository: widget.repository,
                        myPubkey: widget.myPubkey,
                        onRefresh: _refresh,
                      ),
                    const Divider(),
                  ],
                  if (_done.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Done',
                      count: _done.length,
                      color: FarmColors.success,
                    ),
                    for (final instance in _done)
                      _MeetingChoreTile(
                        instance: instance,
                        repository: widget.repository,
                        myPubkey: widget.myPubkey,
                        onRefresh: _refresh,
                      ),
                  ],
                  if (_all.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No chores for today')),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withAlpha(25),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '$title ($count)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingChoreTile extends StatelessWidget {
  const _MeetingChoreTile({
    required this.instance,
    required this.repository,
    required this.myPubkey,
    required this.onRefresh,
  });

  final ChoreInstance instance;
  final ChoreRepository repository;
  final String myPubkey;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isMine = instance.assignee == myPubkey;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: roleAccent(instance.role).withAlpha(40),
        child: Icon(
          instance.assignee != null ? Icons.person : Icons.person_add,
          color: roleAccent(instance.role),
          size: 20,
        ),
      ),
      title: Text(
        instance.title,
        style: TextStyle(
          decoration: instance.status.isDone
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
      subtitle: Text(
        instance.assignee == null
            ? 'Tap to assign'
            : isMine
            ? 'Assigned to you'
            : 'Assigned',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: instance.status.isDone
          ? const Icon(Icons.check_circle, color: FarmColors.success)
          : instance.status.isRemaining
          ? IconButton(
              icon: const Icon(Icons.touch_app),
              tooltip: 'Self-assign',
              onPressed: () => _selfAssign(context),
            )
          : null,
      onTap: () => _showActions(context),
    );
  }

  Future<void> _selfAssign(BuildContext context) async {
    await repository.assign(instance, myPubkey);
    onRefresh();
  }

  void _showActions(BuildContext context) {
    showStatusActions(
      context: context,
      instance: instance,
      repository: repository,
      today: DateTime.now(),
      onChanged: onRefresh,
    );
  }
}
