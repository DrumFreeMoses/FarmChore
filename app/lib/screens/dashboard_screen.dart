import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/data/demo_seed.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:farm_chore/widgets/chore_card.dart';
import 'package:farm_chore/widgets/status_actions_sheet.dart';

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
  bool _loading = true;
  bool _hasDefaults = false;
  bool _gridMode = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final hasDefaults =
        (await widget.repository.loadRoleDefaultSets()).isNotEmpty;
    await widget.repository.ensureDayGenerated(_today);
    final instances = await widget.repository.loadInstancesForDate(_today);
    if (!mounted) return;
    setState(() {
      _hasDefaults = hasDefaults;
      _byRole = {
        for (final role in FarmRoles.all)
          role: instances.where((i) => i.role == role).toList(),
      };
      _loading = false;
    });
  }

  Future<void> _loadDemoData() async {
    final messenger = ScaffoldMessenger.of(context);
    await seedFarmDefaults(widget.repository);
    await _refresh();
    messenger.showSnackBar(
      const SnackBar(content: Text('Demo data loaded — edit to fit the farm')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FarmChore'),
        actions: [
          if (!_hasDefaults)
            IconButton(
              icon: const Icon(Icons.agriculture),
              tooltip: 'Load demo data',
              onPressed: _loadDemoData,
            ),
          IconButton(
            icon: Icon(_gridMode ? Icons.view_list : Icons.grid_view),
            tooltip: _gridMode ? 'Show list' : 'Show grid',
            onPressed: () => setState(() => _gridMode = !_gridMode),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _gridMode ? _gridBody() : _listBody(),
            ),
    );
  }

  Widget _listBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _todayHeader(),
        const SizedBox(height: 12),
        for (final role in FarmRoles.all) ...[
          _RoleHeader(
            role: role,
            instances: _byRole[role]!,
            onTap: () => _openRole(role),
          ),
          const SizedBox(height: 8),
          for (final instance in _byRole[role]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChoreCard(
                instance: instance,
                onTap: () => showStatusActions(
                  context: context,
                  repository: widget.repository,
                  instance: instance,
                  today: _today,
                  onChanged: _refresh,
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _gridBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _todayHeader(),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            for (final role in FarmRoles.all)
              _RoleCard(
                role: role,
                instances: _byRole[role]!,
                onTap: () => _openRole(role),
              ),
          ],
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.instances,
    required this.onTap,
  });

  final FarmRole role;
  final List<ChoreInstance> instances;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = instances.where((i) => i.status.isRemaining).length;
    final done = instances.where((i) => i.status.isDone).length;
    final total = instances.length;
    final accent = role == FarmRole.nonJsf
        ? FarmColors.springBlue
        : FarmColors.dawnAmber;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                role.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: FarmColors.soilBrown),
              ),
              if (total == 0)
                Text(
                  'No chores today',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: FarmColors.sabbath),
                )
              else
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: FarmColors.cottonwoodGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$done done',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      '$open open',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleHeader extends StatelessWidget {
  const _RoleHeader({
    required this.role,
    required this.instances,
    required this.onTap,
  });

  final FarmRole role;
  final List<ChoreInstance> instances;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = instances.where((i) => i.status.isRemaining).length;
    final done = instances.where((i) => i.status.isDone).length;
    final total = instances.length;
    final accent = role == FarmRole.nonJsf
        ? FarmColors.springBlue
        : FarmColors.dawnAmber;
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  role.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: FarmColors.soilBrown),
                ),
              ),
              if (total == 0)
                Text(
                  'No chores today',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: FarmColors.sabbath),
                )
              else
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: FarmColors.cottonwoodGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$done done',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$open open',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
