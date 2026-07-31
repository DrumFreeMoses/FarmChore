import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/edit_event.dart';
import 'package:farm_chore/theme/farm_theme.dart';

/// In-line edit for an instance: rename it. Offers "just today" (one-time)
/// vs "update default" (persistent change to the role's default set).
class EditInstanceDialog extends StatefulWidget {
  const EditInstanceDialog({
    super.key,
    required this.instance,
    required this.repository,
  });

  final ChoreInstance instance;
  final ChoreRepository repository;

  /// Shows the dialog; resolves true when an edit was saved.
  static Future<bool> show(
    BuildContext context, {
    required ChoreInstance instance,
    required ChoreRepository repository,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) =>
              EditInstanceDialog(instance: instance, repository: repository),
        ) ??
        false;
  }

  @override
  State<EditInstanceDialog> createState() => _EditInstanceDialogState();
}

class _EditInstanceDialogState extends State<EditInstanceDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.instance.title,
  );
  EditScope _scope = EditScope.oneTime;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newTitle = _controller.text.trim();
    if (newTitle.isEmpty || newTitle == widget.instance.title) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    await widget.repository.updateTitle(
      widget.instance,
      newTitle,
      scope: _scope,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit chore'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 16),
          RadioGroup<EditScope>(
            groupValue: _scope,
            onChanged: (v) => setState(() => _scope = v!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<EditScope>(
                  value: EditScope.oneTime,
                  title: const Text('Just today'),
                  subtitle: const Text('Changes this one instance'),
                  activeColor: FarmColors.springBlue,
                ),
                RadioListTile<EditScope>(
                  value: EditScope.default_,
                  title: const Text('Update default'),
                  subtitle: const Text('Also changes this chore for every day'),
                  activeColor: FarmColors.dawnAmber,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
