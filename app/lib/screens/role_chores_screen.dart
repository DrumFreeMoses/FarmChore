import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/widgets/chore_card.dart';

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

  Future<void> _showActions(ChoreInstance instance) async {
    final status = await showModalBottomSheet<ChoreStatus>(
      context: context,
      builder: (context) => _StatusSheet(instance: instance),
    );
    if (status == null || !mounted) return;
    if (status == ChoreStatus.deferred) {
      await widget.repository.editStatus(instance, ChoreStatus.deferred);
      final deferred = instance.copyWith(
        status: ChoreStatus.deferred,
        deferredTo: _today.add(const Duration(days: 1)),
      );
      await widget.repository.saveInstance(deferred);
    } else {
      await widget.repository.editStatus(instance, status);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.role.displayName)),
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
                          onTap: () => _showActions(instance),
                        );
                      },
                    ),
            ),
    );
  }
}

class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.instance});

  final ChoreInstance instance;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              instance.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          _action(context, ChoreStatus.done, Icons.check_circle, 'Mark done'),
          _action(
            context,
            ChoreStatus.skipped,
            Icons.skip_next,
            'Skip for today',
          ),
          _action(
            context,
            ChoreStatus.deferred,
            Icons.arrow_forward,
            'Defer to tomorrow',
          ),
          _action(
            context,
            ChoreStatus.cancelled,
            Icons.remove_circle,
            'Cancel this one',
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context,
    ChoreStatus status,
    IconData icon,
    String label,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      enabled: status == ChoreStatus.cancelled
          ? instance.status != ChoreStatus.done
          : instance.status.isRemaining,
      onTap: () => Navigator.of(context).pop(status),
    );
  }
}
