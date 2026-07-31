import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/widgets/chore_card.dart';
import 'package:farm_chore/widgets/new_item_dialog.dart';
import 'package:farm_chore/widgets/status_actions_sheet.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final all = await widget.repository.loadInstancesForDate(_today);
    if (!mounted) return;
    setState(() {
      _instances = all.where((i) => i.role == widget.role).toList();
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
                          onTap: () => showStatusActions(
                            context: context,
                            repository: widget.repository,
                            instance: instance,
                            today: _today,
                            onChanged: _refresh,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
