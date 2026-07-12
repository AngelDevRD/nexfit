import 'package:flutter/material.dart';

/// Pantalla/mensaje reutilizable para cualquier función que dependa del
/// backend inteligente (Coach IA, chat, tool-calling -- ver
/// `docs/ARQUITECTURA_BACKEND.md`) mientras ese servicio no esté configurado
/// o no responda. Reemplaza excepciones técnicas, pantallas en blanco o
/// crashes por un mensaje profesional e intencional.
///
/// Fase 0: componente listo pero sin usar todavía en ninguna pantalla real.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({
    super.key,
    this.title = 'Próximamente',
    this.message =
        'Esta función aún no está disponible.\n\n'
        'Estamos trabajando para habilitar el Coach IA y otras funciones '
        'inteligentes en una futura actualización.\n\n'
        'Sigue utilizando el resto de la aplicación con normalidad.',
    this.icon = Icons.auto_awesome_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
