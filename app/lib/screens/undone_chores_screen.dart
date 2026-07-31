import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:farm_chore/widgets/chore_card.dart';
import 'package:farm_chore/widgets/status_actions_sheet.dart';

/// Today's remaining work, grouped by role with counts: the farm-wide
/// morning-meeting overview.
class UndoneChoresScreen extends StatefulWidget {
  const UndoneChoresScreen({super.key, required this.repository, this.today});

  final ChoreRepository repository;
  final DateTime? today;

  @override
  State<UndoneChoresScreen> createState() => _UndoneChoresScreenState();
}

class _UndoneChoresScreenState extends State<UndoneChoresScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  Map<String, List<ChoreInstance>> _byRole = {};
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
      final undone = instances.where((i) => i.status.isRemaining).toList();
      _byRole = <String, List<ChoreInstance>>{};
      for (final instance in undone) {
        _byRole.putIfAbsent(instance.role.displayName, () => []).add(instance);
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final roles = _byRole.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Remaining Today')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: roles.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('All done for today.')),
                        ),
                      ],
                    )
                  : ListView(
                      children: [
                        for (final role in roles) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    role,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: FarmColors.soilBrown),
                                  ),
                                ),
                                Text(
                                  '${_byRole[role]!.length} remaining',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: FarmColors.dawnAmber),
                                ),
                              ],
                            ),
                          ),
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
                      ],
                    ),
            ),
    );
  }
}
