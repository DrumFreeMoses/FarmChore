import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/daily_generator.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';

/// One popup to add a chore or a one-off task, anywhere in the app.
///
/// Defaults to today. Chores can optionally be added to the role's
/// default set so they repeat every workday.
Future<bool> showNewItemDialog({
  required BuildContext context,
  required ChoreRepository repository,
  DateTime? today,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => NewItemDialog(repository: repository, today: today),
      ) ??
      false;
}

class NewItemDialog extends StatefulWidget {
  const NewItemDialog({super.key, required this.repository, this.today});

  final ChoreRepository repository;
  final DateTime? today;

  @override
  State<NewItemDialog> createState() => _NewItemDialogState();
}

class _NewItemDialogState extends State<NewItemDialog> {
  late DateTime _date = widget.today ?? DateTime.now();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _newCheckItem = TextEditingController();
  ChoreType _type = ChoreType.chore;
  FarmRole _role = FarmRoles.all.first;
  String? _assignee;
  bool _addToDefault = false;
  List<String> _members = [];
  List<String> _checklist = [];

  @override
  void initState() {
    super.initState();
    _members = [widget.repository.myPubkey];
  }

  Future<void> _loadMembers() async {
    final known = await widget.repository.loadKnownMembers();
    if (!mounted) return;
    setState(() => _members = known);
  }

  String _shortHex(String pubkey) =>
      '${pubkey.substring(0, 8)}…${pubkey.substring(pubkey.length - 6)}';

  void _addCheckItem() {
    final text = _newCheckItem.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add(text);
      _newCheckItem.clear();
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final instance = ChoreInstance(
      date: _date,
      role: _role,
      slug: DailyGenerator.slugify(title),
      title: title,
      type: _type,
      assignee: _assignee,
    );
    await widget.repository.saveInstance(instance);
    if (_addToDefault && _type == ChoreType.chore) {
      final desc = _description.text.trim();
      await widget.repository.addDefaultChore(
        _role,
        title,
        description: desc,
        checklist: _checklist,
      );
      await widget.repository.syncDayToDefaults(_date);
    }
    if (_assignee != null && _assignee != widget.repository.myPubkey) {
      await widget.repository.assign(instance, _assignee!);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final showDefaultFields = _addToDefault && _type == ChoreType.chore;

    return AlertDialog(
      title: const Text('New chore or task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ChoreType>(
              segments: const [
                ButtonSegment(
                  value: ChoreType.chore,
                  label: Text('Chore'),
                  icon: Icon(Icons.repeat),
                ),
                ButtonSegment(
                  value: ChoreType.task,
                  label: Text('Task'),
                  icon: Icon(Icons.bolt),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'What needs doing?',
                hintText: 'e.g. Ice the milk',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FarmRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final role in FarmRoles.all)
                  DropdownMenuItem(value: role, child: Text(role.displayName)),
              ],
              onChanged: (role) => setState(() => _role = role ?? _role),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _assignee,
              decoration: const InputDecoration(labelText: 'Assignee'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                for (var i = 0; i < _members.length; i++)
                  DropdownMenuItem(
                    value: _members[i],
                    child: Text(i == 0 ? 'Me' : _shortHex(_members[i])),
                  ),
              ],
              onChanged: (value) => setState(() => _assignee = value),
              onTap: _loadMembers,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(_formatDate(_date)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(_date.year - 2),
                  lastDate: DateTime(_date.year + 1),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            if (_type == ChoreType.chore)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add to role defaults'),
                subtitle: Text(
                  'Repeats every workday for ${_role.displayName}',
                ),
                value: _addToDefault,
                onChanged: (value) => setState(() => _addToDefault = value),
              ),
            if (showDefaultFields) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (required)',
                  hintText: 'How to do this chore',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Text('Checklist', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              if (_checklist.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'No items yet',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: FarmColors.sabbath),
                  ),
                ),
              for (var i = 0; i < _checklist.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_checklist[i])),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _checklist.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCheckItem,
                      decoration: const InputDecoration(
                        hintText: 'Add item…',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addCheckItem(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addCheckItem,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}'
    '/${d.year}';
