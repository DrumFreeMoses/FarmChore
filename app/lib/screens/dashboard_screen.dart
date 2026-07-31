import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/data/demo_seed.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:farm_chore/widgets/chore_card.dart';
import 'package:farm_chore/widgets/new_item_dialog.dart';
import 'package:farm_chore/widgets/role_section_header.dart';
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
        (await widget.repository.loadBaseRoleDefaultSets()).isNotEmpty;
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
            mainAxisExtent: 76,
            children: [
              for (final instance in _byRole[role]!)
                ChoreCard(
                  instance: instance,
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
