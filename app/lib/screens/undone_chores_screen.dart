import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:farm_chore/widgets/chore_card.dart';
import 'package:farm_chore/widgets/new_item_dialog.dart';
import 'package:farm_chore/widgets/role_section_header.dart';
import 'package:farm_chore/widgets/status_actions_sheet.dart';

/// Today's remaining work, grouped by role with counts: the farm-wide
/// morning-meeting overview. Roles always appear in canonical order.
class UndoneChoresScreen extends StatefulWidget {
  const UndoneChoresScreen({super.key, required this.repository, this.today});

  final ChoreRepository repository;
  final DateTime? today;

  @override
  State<UndoneChoresScreen> createState() => _UndoneChoresScreenState();
}

class _UndoneChoresScreenState extends State<UndoneChoresScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  Map<FarmRole, List<ChoreInstance>> _byRole = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final instances = await widget.repository.loadInstancesForDate(_today);
    if (!mounted) return;
    setState(() {
      _byRole = <FarmRole, List<ChoreInstance>>{};
      for (final instance in instances) {
        if (!instance.status.isRemaining) continue;
        _byRole.putIfAbsent(instance.role, () => []).add(instance);
      }
      _loading = false;
    });
  }

  Future<void> _newItem() async {
    final created = await showNewItemDialog(
      context: context,
      repository: widget.repository,
      today: _today,
    );
    if (created && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remaining Today')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New chore or task',
        onPressed: _newItem,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _byRole.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('All done for today.')),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        for (final role in FarmRoles.all)
                          if (_byRole[role] case final instances?) ...[
                            RoleSectionHeader(
                              role: role,
                              trailing: Text(
                                '${instances.length} remaining',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: roleAccent(role),
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            for (final instance in instances)
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
                      ],
                    ),
            ),
    );
  }
}
