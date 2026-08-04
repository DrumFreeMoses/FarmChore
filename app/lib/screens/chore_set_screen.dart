import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';

/// Screen to manage chore sets for a role: view saved sets, activate one,
/// save the current chore list as a new set, or delete a set.
class ChoreSetScreen extends StatefulWidget {
  const ChoreSetScreen({
    super.key,
    required this.repository,
    required this.role,
  });

  final ChoreRepository repository;
  final FarmRole role;

  @override
  State<ChoreSetScreen> createState() => _ChoreSetScreenState();
}

class _ChoreSetScreenState extends State<ChoreSetScreen> {
  RoleDefaultSet? _activeSet;
  List<RoleDefaultSet> _variants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final bases = await widget.repository.loadBaseRoleDefaultSets();
    final variants = await widget.repository.loadChoreSets(widget.role);
    if (!mounted) return;
    setState(() {
      _activeSet = bases.where((s) => s.role == widget.role).firstOrNull;
      _variants = variants;
      _loading = false;
    });
  }

  Future<void> _saveCurrentAsSet() async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save chore set'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Rainy day, Holiday week…',
            labelText: 'Set name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final chores = _activeSet?.chores ?? [];
    await widget.repository.saveChoreSet(widget.role, name, chores);
    await _refresh();
  }

  Future<void> _activateSet(RoleDefaultSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Activate "${set.name}"?'),
        content: const Text(
          'This will replace the current chore list with this set. '
          'The current list will be saved as a set first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.repository.activateChoreSet(set);
    await _refresh();
  }

  Future<void> _deleteSet(RoleDefaultSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${set.name}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: FarmColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.repository.deleteChoreSet(set);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final accent = roleAccent(widget.role);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role.displayName} chore sets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save current as set',
            onPressed: _saveCurrentAsSet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Active set.
                Text('Active set', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_activeSet != null)
                  _SetActiveCard(
                    set: _activeSet!,
                    accent: accent,
                    choreCount: _activeSet!.chores.length,
                  )
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No active set — seed defaults first'),
                    ),
                  ),

                // Saved sets.
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('Saved sets', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      '${_variants.length}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_variants.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No saved sets. Tap the save icon to save the current list.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  for (final variant in _variants)
                    _VariantTile(
                      set: variant,
                      accent: accent,
                      onActivate: () => _activateSet(variant),
                      onDelete: () => _deleteSet(variant),
                    ),
              ],
            ),
    );
  }
}

class _SetActiveCard extends StatelessWidget {
  const _SetActiveCard({
    required this.set,
    required this.accent,
    required this.choreCount,
  });

  final RoleDefaultSet set;
  final Color accent;
  final int choreCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Active',
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('$choreCount chores'),
              ],
            ),
            const SizedBox(height: 12),
            for (final chore in set.chores.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• ${chore.title}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (set.chores.length > 5)
              Text(
                '+ ${set.chores.length - 5} more…',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.set,
    required this.accent,
    required this.onActivate,
    required this.onDelete,
  });

  final RoleDefaultSet set;
  final Color accent;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: FarmColors.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(Icons.folder_open, color: accent),
        title: Text(set.name ?? 'Unnamed'),
        subtitle: Text('${set.chores.length} chores'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 20),
              tooltip: 'Activate this set',
              onPressed: onActivate,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
