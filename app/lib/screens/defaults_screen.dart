import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';

/// Manage one role's default chore set: edit the active chores and keep
/// named alternates ("compressor down", "harvest week", ...) that can be
/// activated and deactivated at any time.
class DefaultsScreen extends StatefulWidget {
  const DefaultsScreen({
    super.key,
    required this.repository,
    required this.role,
    this.today,
  });

  final ChoreRepository repository;
  final FarmRole role;
  final DateTime? today;

  @override
  State<DefaultsScreen> createState() => _DefaultsScreenState();
}

class _DefaultsScreenState extends State<DefaultsScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  RoleDefaultSet? _base;
  List<RoleDefaultSet> _variants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final all = await widget.repository.loadRoleDefaultSets();
    if (!mounted) return;
    setState(() {
      _base = all.where((s) => s.role == widget.role && s.isBase).firstOrNull;
      _variants = all.where((s) => s.role == widget.role && !s.isBase).toList()
        ..sort((a, b) => a.name!.compareTo(b.name!));
      _loading = false;
    });
  }

  Future<void> _saveBase(List<ChoreDefault> chores) async {
    await widget.repository.saveRoleDefaultSet(
      RoleDefaultSet(role: widget.role, chores: chores),
    );
    await widget.repository.syncDayToDefaults(_today);
    await _refresh();
  }

  Future<void> _addChore() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add default chore'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Chore title',
            hintText: 'e.g. Ice the milk',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || !mounted) return;
    await _saveBase([
      ...?_base?.chores,
      ChoreDefault(title: title, weekdays: const [1, 2, 3, 4, 5, 6]),
    ]);
  }

  Future<void> _removeChore(String title) async {
    await _saveBase([
      for (final chore in _base?.chores ?? [])
        if (chore.title != title) chore,
    ]);
  }

  Future<void> _saveVariant() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as variant'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Variant name',
            hintText: 'e.g. Compressor down — icing',
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
    await widget.repository.saveRoleVariant(
      widget.role,
      name,
      _base?.chores ?? const [],
    );
    await _refresh();
  }

  Future<void> _activate(RoleDefaultSet variant) async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.repository.activateRoleSet(variant);
    await widget.repository.syncDayToDefaults(_today);
    await _refresh();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Activated "${variant.name}" for ${widget.role.displayName}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.role.displayName} defaults')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Active defaults', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_base == null || _base!.chores.isEmpty)
                  Text(
                    'No default chores yet — add the first one.',
                    style: textTheme.bodySmall?.copyWith(
                      color: FarmColors.sabbath,
                    ),
                  )
                else
                  for (final chore in _base!.chores)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: FarmColors.dawnAmber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: ListTile(
                        title: Text(chore.title),
                        subtitle: Text(_weekdaySummary(chore.weekdays)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove chore',
                          onPressed: () => _removeChore(chore.title),
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addChore,
                        icon: const Icon(Icons.add),
                        label: const Text('Add chore'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saveVariant,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Save as variant'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Alternates', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_variants.isEmpty)
                  Text(
                    'No alternates yet. Save the current set to switch '
                    'back to it later (e.g. when the compressor is fixed).',
                    style: textTheme.bodySmall?.copyWith(
                      color: FarmColors.sabbath,
                    ),
                  )
                else
                  for (final variant in _variants)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: FarmColors.springBlue.withValues(alpha: 0.5),
                        ),
                      ),
                      child: ListTile(
                        title: Text(variant.name!),
                        subtitle: Text(
                          '${variant.chores.length} '
                          '${variant.chores.length == 1 ? 'chore' : 'chores'}',
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () => _activate(variant),
                          child: const Text('Activate'),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String _weekdaySummary(List<int> weekdays) {
  if (weekdays.length == 6) return 'Every workday';
  return weekdays.map((w) => _dayNames[w - 1]).join(', ');
}
