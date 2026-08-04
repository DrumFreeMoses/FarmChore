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

  /// Shows a full dialog to create or edit a chore with mandatory
  /// description and checklist.
  Future<void> _addOrEditChore({ChoreDefault? existing}) async {
    final result = await showDialog<ChoreDefault>(
      context: context,
      builder: (context) => _ChoreEditDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    final chores = List<ChoreDefault>.from(_base?.chores ?? []);
    if (existing != null) {
      final idx = chores.indexWhere((c) => c.title == existing.title);
      if (idx >= 0) chores[idx] = result;
    } else {
      chores.add(result);
    }
    await _saveBase(chores);
  }

  Future<void> _removeChore(String title) async {
    await _saveBase([
      for (final chore in _base?.chores ?? [])
        if (chore.title != title) chore,
    ]);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final chores = List<ChoreDefault>.from(_base?.chores ?? []);
    if (oldIndex < newIndex) newIndex -= 1;
    final item = chores.removeAt(oldIndex);
    chores.insert(newIndex, item);
    await _saveBase(chores);
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
                const SizedBox(height: 4),
                Text(
                  'Drag to reorder. Tap to edit description & checklist.',
                  style: textTheme.bodySmall?.copyWith(
                    color: FarmColors.sabbath,
                  ),
                ),
                const SizedBox(height: 8),
                if (_base == null || _base!.chores.isEmpty)
                  Text(
                    'No default chores yet — add the first one.',
                    style: textTheme.bodySmall?.copyWith(
                      color: FarmColors.sabbath,
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _base!.chores.length,
  // ignore: deprecated_member_use
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final chore = _base!.chores[index];
                      return Card(
                        key: ValueKey('${chore.title}-$index'),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: FarmColors.dawnAmber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.drag_handle,
                            color: FarmColors.sabbath,
                          ),
                          title: Text(chore.title),
                          subtitle: Text(
                            _choreSummary(chore),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit chore',
                                onPressed: () =>
                                    _addOrEditChore(existing: chore),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                tooltip: 'Remove chore',
                                onPressed: () => _removeChore(chore.title),
                              ),
                            ],
                          ),
                          onTap: () => _addOrEditChore(existing: chore),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addOrEditChore(),
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

String _choreSummary(ChoreDefault chore) {
  final parts = <String>[];
  if (chore.description.isNotEmpty) {
    parts.add(chore.description);
  }
  if (chore.checklist.isNotEmpty) {
    parts.add('${chore.checklist.length} checklist items');
  }
  if (parts.isEmpty) {
    return _weekdaySummary(chore.weekdays);
  }
  return parts.join(' · ');
}

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String _weekdaySummary(List<int> weekdays) {
  if (weekdays.length == 6) return 'Every workday';
  return weekdays.map((w) => _dayNames[w - 1]).join(', ');
}

// ── Chore edit dialog ────────────────────────────────────────────────

/// Full-screen-capable dialog for creating or editing a chore with
/// mandatory description and checklist.
class _ChoreEditDialog extends StatefulWidget {
  const _ChoreEditDialog({this.existing});
  final ChoreDefault? existing;

  @override
  State<_ChoreEditDialog> createState() => _ChoreEditDialogState();
}

class _ChoreEditDialogState extends State<_ChoreEditDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final List<TextEditingController> _checklistCtrls;
  late List<int> _weekdays;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _checklistCtrls = [
      for (final item in e?.checklist ?? []) TextEditingController(text: item),
    ];
    _weekdays = List<int>.from(e?.weekdays ?? const [1, 2, 3, 4, 5, 6]);
    if (_checklistCtrls.isEmpty) _checklistCtrls.add(TextEditingController());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _checklistCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addChecklistItem() {
    setState(() => _checklistCtrls.add(TextEditingController()));
  }

  void _removeChecklistItem(int index) {
    if (_checklistCtrls.length <= 1) return;
    setState(() {
      _checklistCtrls[index].dispose();
      _checklistCtrls.removeAt(index);
    });
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final checklist = _checklistCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Description is required — explain how to do this chore',
          ),
        ),
      );
      return;
    }
    if (checklist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one checklist item is required'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      ChoreDefault(
        title: title,
        weekdays: _weekdays,
        assigneeHint: widget.existing?.assigneeHint,
        requiredSkills: widget.existing?.requiredSkills ?? const [],
        description: desc,
        checklist: checklist,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit chore' : 'New chore'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g. Ice the milk',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'How to do this chore — step by step',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Checklist *',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: 'Add item',
                    onPressed: _addChecklistItem,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (int i = 0; i < _checklistCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_box_outline_blank,
                        size: 20,
                        color: FarmColors.sabbath,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _checklistCtrls[i],
                          decoration: InputDecoration(
                            hintText: 'Checklist item ${i + 1}',
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_checklistCtrls.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeChecklistItem(i),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text('Workdays', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (int d = 1; d <= 6; d++)
                    FilterChip(
                      label: Text(_dayNames[d - 1]),
                      selected: _weekdays.contains(d),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _weekdays.add(d);
                          } else {
                            _weekdays.remove(d);
                          }
                          _weekdays.sort();
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
