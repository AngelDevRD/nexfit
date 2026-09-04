import 'package:flutter/material.dart';

import '../core/theme.dart';

/// U5: estado vacío/error reutilizable -- ícono + explicación + acción que
/// lo resuelve (crear el primer registro, o reintentar tras un error). Antes
/// cada pantalla tenía como mucho una línea de texto suelta para el vacío, y
/// ninguna manejaba errores (un fallo dejaba el spinner girando para
/// siempre).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  /// Estado de error con el mismo look, ícono y copy por defecto -- solo
  /// hace falta pasar el mensaje y qué hacer al reintentar.
  const EmptyState.error({
    super.key,
    this.message = 'Ocurrió un error al cargar los datos.',
    required VoidCallback onRetry,
    this.icon = Icons.error_outline,
    this.iconColor = AppColors.danger,
  }) : actionLabel = 'Reintentar',
       onAction = onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 40,
            color: iconColor ?? AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
