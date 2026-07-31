import 'package:flutter/material.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/theme/farm_theme.dart';

/// A scheduled item card.
///
/// Visual distinction (docs/design.md):
/// - chore = dawn amber filled card + square badge
/// - task  = spring blue outlined card + rounded badge
class ChoreCard extends StatelessWidget {
  const ChoreCard({
    super.key,
    required this.instance,
    this.onTap,
    this.trailing,
  });

  final ChoreInstance instance;
  final VoidCallback? onTap;
  final Widget? trailing;

  bool get _isChore => instance.type == ChoreType.chore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final done = instance.status == ChoreStatus.done;
    final card = Card(
      elevation: _isChore ? 2 : 0,
      color: done ? FarmColors.sabbath.withValues(alpha: 0.18) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_isChore ? 8 : 16),
        side: _isChore
            ? BorderSide.none
            : const BorderSide(color: FarmColors.springBlue, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_isChore ? 8 : 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _Badge(isChore: _isChore),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instance.title,
                      style: textTheme.titleMedium?.copyWith(
                        color: FarmColors.soilBrown,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (instance.assignee case final assignee?)
                      Text(
                        'Assigned: $assignee',
                        style: textTheme.bodySmall?.copyWith(
                          color: FarmColors.soilBrown.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
              if (instance.status != ChoreStatus.open)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: StatusChip(status: instance.status),
                ),
              ?trailing,
            ],
          ),
        ),
      ),
    );

    if (_isChore) {
      return ColoredBox(
        color: FarmColors.dawnAmber.withValues(alpha: 0.14),
        child: card,
      );
    }
    return card;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.isChore});

  final bool isChore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isChore ? FarmColors.dawnAmber : FarmColors.springBlue,
        borderRadius: isChore ? BorderRadius.zero : BorderRadius.circular(4),
      ),
    );
  }
}

/// Status chip per docs/design.md:
/// done = green check, skipped = hay yellow, deferred = blue arrow,
/// cancelled = soil brown strike, open = no chip.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ChoreStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ChoreStatus.open:
        return const SizedBox.shrink();
      case ChoreStatus.done:
        return const _Chip(
          icon: Icons.check,
          color: FarmColors.cottonwoodGreen,
          label: 'Done',
        );
      case ChoreStatus.skipped:
        return const _Chip(
          icon: Icons.skip_next,
          color: FarmColors.hayYellow,
          label: 'Skipped',
        );
      case ChoreStatus.deferred:
        return const _Chip(
          icon: Icons.arrow_forward,
          color: FarmColors.springBlue,
          label: 'Deferred',
        );
      case ChoreStatus.cancelled:
        return const _Chip(
          icon: Icons.remove,
          color: FarmColors.sabbath,
          label: 'Cancelled',
        );
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final onColor = label == 'Skipped' ? FarmColors.soilBrown : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: onColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: onColor),
          ),
        ],
      ),
    );
  }
}
