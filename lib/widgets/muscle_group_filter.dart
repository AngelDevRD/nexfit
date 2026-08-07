import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Chip de grupo muscular reusado por la lista de ejercicios y por el picker
/// de rutinas -- mismo estilo visual en ambos entry points al catálogo.
class MuscleChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  const MuscleChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.15)
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.full),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.4)
                    : AppColors.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? color : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 4),
                  Icon(trailingIcon, size: 16, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MuscleGroupSheet extends StatelessWidget {
  final String? current;

  const _MuscleGroupSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Text(
              'Grupo muscular',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                MuscleChip(
                  label: 'Todos',
                  color: AppColors.onSurfaceVariant,
                  selected: current == null,
                  onTap: () => Navigator.of(context).pop(null),
                ),
                ...muscleGroupColors.entries.map(
                  (entry) => MuscleChip(
                    label: entry.key,
                    color: entry.value,
                    selected: current == entry.key,
                    onTap: () => Navigator.of(context).pop(entry.key),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre el bottom sheet de selección de grupo muscular. Devuelve el grupo
/// elegido, o `null` para "Todos" (o si se descarta el sheet sin elegir).
Future<String?> showMuscleGroupFilterSheet(
  BuildContext context, {
  required String? current,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    backgroundColor: AppColors.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _MuscleGroupSheet(current: current),
  );
}
