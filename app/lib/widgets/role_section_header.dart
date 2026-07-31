import 'package:flutter/material.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';

/// Bold, role-tinted section header used on every screen that groups
/// chores by role, so roles always read in the same order and color.
class RoleSectionHeader extends StatelessWidget {
  const RoleSectionHeader({
    super.key,
    required this.role,
    this.trailing,
    this.onTap,
  });

  final FarmRole role;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = roleAccent(role);
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  role.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: FarmColors.soilBrown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ?trailing,
              if (onTap != null)
                Icon(Icons.chevron_right, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
