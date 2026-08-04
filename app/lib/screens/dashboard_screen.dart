import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/data/demo_seed.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/screens/invite_screen.dart';
import 'package:farm_chore/screens/morning_meeting_screen.dart';
import 'package:farm_chore/screens/notification_screen.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:farm_chore/widgets/chore_card.dart';
import 'package:farm_chore/widgets/new_item_dialog.dart';
import 'package:farm_chore/widgets/role_section_header.dart';
import 'package:farm_chore/widgets/status_actions_sheet.dart';
import 'package:farm_chore/widgets/sync_status_badge.dart';

import 'role_chores_screen.dart';

/// Landing page: one card per role showing today's done/open counts.
/// Tapping a card drills into that role's chore list.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.repository, this.today});

  final ChoreRepository repository;

  /// Injected for tests; defaults to the current day.
  final DateTime? today;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  Map<FarmRole, List<ChoreInstance>> _byRole = {};
  Map<String, String> _names = {};
  bool _loading = true;
  bool _hasDefaults = false;
  bool _gridMode = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final hasDefaults =
        (await widget.repository.loadBaseRoleDefaultSets()).isNotEmpty;
    await widget.repository.ensureDayGenerated(_today);
    final instances = await widget.repository.loadInstancesForDate(_today);
    final names = await widget.repository.loadMemberNames();
    final notifications = await widget.repository.loadNotifications();
    if (!mounted) return;
    setState(() {
      _hasDefaults = hasDefaults;
      _names = names;
      _byRole = {
        for (final role in FarmRoles.all)
          role: _workOrder(instances.where((i) => i.role == role).toList()),
      };
      _unreadCount = notifications.where((n) => !n.read).length;
      _loading = false;
    });
  }

  /// Remaining work first, done items last; stable within each group.
  static List<ChoreInstance> _workOrder(List<ChoreInstance> instances) {
    final remaining = instances.where((i) => i.status.isRemaining).toList()
      ..sort((a, b) => a.slug.compareTo(b.slug));
    final done = instances.where((i) => !i.status.isRemaining).toList()
      ..sort((a, b) => a.slug.compareTo(b.slug));
    return [...remaining, ...done];
  }

  Future<void> _editName() async {
    final controller = TextEditingController(
      text: _names[widget.repository.myPubkey] ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'First name',
            hintText: 'Shown to the farm on assignments',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await widget.repository.saveMyName(name);
    await _refresh();
  }

  Future<void> _loadDemoData() async {
    final messenger = ScaffoldMessenger.of(context);
    await seedFarmDefaults(widget.repository);
    await _refresh();
    messenger.showSnackBar(
      const SnackBar(content: Text('Demo data loaded — edit to fit the farm')),
    );
  }

  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This will delete all chores, profiles, messages, and settings. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: FarmColors.error),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.repository.purgeAllData();
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All data deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FarmChore for Jacob Springs Farm'),
        actions: [
          SyncStatusBadge(repository: widget.repository, onSync: _refresh),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'load_demo') _loadDemoData();
              if (value == 'reset_all') _resetAllData();
            },
            itemBuilder: (_) => [
              if (!_hasDefaults)
                const PopupMenuItem(
                  value: 'load_demo',
                  child: ListTile(
                    leading: Icon(Icons.agriculture),
                    title: Text('Load demo data'),
                    dense: true,
                  ),
                ),
              const PopupMenuItem(
                value: 'reset_all',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: FarmColors.error),
                  title: Text('Reset all data'),
                  dense: true,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_gridMode ? Icons.view_list : Icons.grid_view),
            tooltip: _gridMode ? 'Show list' : 'Show grid',
            onPressed: () => setState(() => _gridMode = !_gridMode),
          ),
          IconButton(
            icon: const Icon(Icons.groups),
            tooltip: 'Morning meeting',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MorningMeetingScreen(
                    repository: widget.repository,
                    myPubkey: widget.repository.myPubkey,
                  ),
                ),
              );
              _refresh();
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Notifications',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationScreen(repository: widget.repository),
                ),
              );
              _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'Your name',
            onPressed: _editName,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'Invite via QR',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InviteScreen(
                    relayUrl: const String.fromEnvironment(
                      'FARMCHORE_RELAY',
                      defaultValue: 'ws://localhost:7447',
                    ),
                    farmPubkey:
                        widget.repository.farmPubkey ??
                        widget.repository.myPubkey,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _gridMode ? _gridBody() : _listBody(),
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New chore or task',
        onPressed: () async {
          final created = await showNewItemDialog(
            context: context,
            repository: widget.repository,
            today: _today,
          );
          if (created && mounted) _refresh();
        },
      ),
    );
  }

  Widget _listBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _todayHeader(),
        const SizedBox(height: 4),
        for (final role in FarmRoles.all) ...[
          RoleSectionHeader(
            role: role,
            trailing: _counts(role),
            onTap: () => _openRole(role),
          ),
          if (_byRole[role]!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No chores today',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: FarmColors.sabbath),
              ),
            )
          else
            for (final instance in _byRole[role]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChoreCard(
                  instance: instance,
                  memberNames: _names,
                  onTap: () => showStatusActions(
                    context: context,
                    repository: widget.repository,
                    instance: instance,
                    today: _today,
                    onChanged: _refresh,
                  ),
                ),
              ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _gridBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _todayHeader(),
        const SizedBox(height: 4),
        for (final role in FarmRoles.all) ...[
          RoleSectionHeader(
            role: role,
            trailing: _counts(role),
            onTap: () => _openRole(role),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 96,
            children: [
              for (final instance in _byRole[role]!)
                ChoreCard(
                  instance: instance,
                  memberNames: _names,
                  onTap: () => showStatusActions(
                    context: context,
                    repository: widget.repository,
                    instance: instance,
                    today: _today,
                    onChanged: _refresh,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _counts(FarmRole role) {
    final open = _byRole[role]!.where((i) => i.status.isRemaining).length;
    final done = _byRole[role]!.where((i) => i.status.isDone).length;
    if (_byRole[role]!.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$done done',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: FarmColors.cottonwoodGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$open open',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: FarmColors.soilBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _todayHeader() {
    return Text(
      'Today · ${_formatDate(_today)}',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Future<void> _openRole(FarmRole role) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoleChoresScreen(
          repository: widget.repository,
          role: role,
          today: _today,
        ),
      ),
    );
    if (mounted) _refresh();
  }
}

String _formatDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
