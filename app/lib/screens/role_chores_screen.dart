import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/screens/chore_detail_screen.dart';
import 'package:farm_chore/widgets/chore_card.dart';
import 'package:farm_chore/widgets/new_item_dialog.dart';

import 'chore_set_screen.dart';
import 'defaults_screen.dart';

/// One role's chore list for a day (e.g. "Milker's Chores").
/// Tapping an item opens status actions: done, skip, defer, cancel.
class RoleChoresScreen extends StatefulWidget {
  const RoleChoresScreen({
    super.key,
    required this.repository,
    required this.role,
    this.today,
  });

  final ChoreRepository repository;
  final FarmRole role;
  final DateTime? today;

  @override
  State<RoleChoresScreen> createState() => _RoleChoresScreenState();
}

class _RoleChoresScreenState extends State<RoleChoresScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  List<ChoreInstance> _instances = [];
  Map<String, String> _names = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final all = await widget.repository.loadInstancesForDate(_today);
    final names = await widget.repository.loadMemberNames();
    // Load default order.
    final bases = await widget.repository.loadBaseRoleDefaultSets();
    final baseSet = bases.where((s) => s.role == widget.role).firstOrNull;
    final defaultOrder = {
      for (int i = 0; i < (baseSet?.chores.length ?? 0); i++)
        baseSet!.chores[i].title: i,
    };
    if (!mounted) return;
    final instances = all.where((i) => i.role == widget.role).toList();
    // Sort: open first, then by default order, then done last.
    instances.sort((a, b) {
      if (a.status.isRemaining && !b.status.isRemaining) return -1;
      if (!a.status.isRemaining && b.status.isRemaining) return 1;
      final orderA = defaultOrder[a.title] ?? 999;
      final orderB = defaultOrder[b.title] ?? 999;
      return orderA.compareTo(orderB);
    });
    setState(() {
      _names = names;
      _instances = instances;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_books),
            tooltip: 'Chore sets',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChoreSetScreen(
                    repository: widget.repository,
                    role: widget.role,
                  ),
                ),
              );
              if (mounted) _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Edit defaults',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DefaultsScreen(
                    repository: widget.repository,
                    role: widget.role,
                    today: _today,
                  ),
                ),
              );
              if (mounted) _refresh();
            },
          ),
        ],
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
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _instances.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No chores scheduled for today'),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _instances.length,
                      itemBuilder: (context, index) {
                        final instance = _instances[index];
                        return ChoreCard(
                          instance: instance,
                          memberNames: _names,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChoreDetailScreen(
                                  instance: instance,
                                  repository: widget.repository,
                                  myPubkey: widget.repository.myPubkey,
                                ),
                              ),
                            );
                            _refresh();
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
