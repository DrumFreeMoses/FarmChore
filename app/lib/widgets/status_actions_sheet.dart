import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/theme/farm_theme.dart';

import 'edit_instance_dialog.dart';

/// Bottom sheet with the status actions for one instance:
/// done, skip, defer to tomorrow, cancel. Selection is applied via
/// [repository.editStatus].
class StatusActionsSheet extends StatelessWidget {
  const StatusActionsSheet({
    super.key,
    required this.instance,
    required this.today,
    required this.repository,
    this.onChanged,
  });

  final ChoreInstance instance;
  final DateTime today;
  final ChoreRepository repository;
  final VoidCallback? onChanged;

  Future<void> _apply(BuildContext context, ChoreStatus status) async {
    await repository.editStatus(
      instance,
      status,
      deferredTo: status == ChoreStatus.deferred
          ? today.add(const Duration(days: 1))
          : null,
    );
    if (context.mounted) Navigator.of(context).pop();
    onChanged?.call();
  }

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
          ListTile(
            leading: const Icon(Icons.edit, color: FarmColors.springBlue),
            title: const Text('Edit title…'),
            onTap: () async {
              final changed = await EditInstanceDialog.show(
                context,
                instance: instance,
                repository: repository,
              );
              if (changed) onChanged?.call();
            },
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
      onTap: () => _apply(context, status),
    );
  }
}

/// Shows [StatusActionsSheet] for [instance]. [onChanged] fires whenever a
/// status action was applied.
Future<void> showStatusActions({
  required BuildContext context,
  required ChoreRepository repository,
  required ChoreInstance instance,
  required DateTime today,
  VoidCallback? onChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (_) => StatusActionsSheet(
      instance: instance,
      today: today,
      repository: repository,
      onChanged: onChanged,
    ),
  );
}
