import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Aviso de salud requerido por Play (docs/AUDITORIA_2026-09-04.md Fase 0
/// item 7): las calculadoras, el objetivo de calorías y el Coach dan
/// estimaciones, no diagnósticos ni indicaciones médicas.
class HealthDisclaimer extends StatelessWidget {
  const HealthDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Información orientativa. No sustituye el consejo de un '
              'profesional de la salud.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
