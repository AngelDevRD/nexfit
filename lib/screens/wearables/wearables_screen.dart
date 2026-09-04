import 'package:flutter/material.dart';
import 'package:health/health.dart';

import '../../core/theme.dart';
import '../../services/health_service.dart';

/// N5: siempre vive dentro de [CuerpoHubScreen] -- el hub provee
/// Scaffold/AppBar, esta pantalla solo devuelve contenido (sin FAB, no
/// necesita `Scaffold` propio). El botón de actualizar vive en el
/// encabezado de `_SummaryView`, no en un AppBar transparente fantasma.
class WearablesScreen extends StatefulWidget {
  const WearablesScreen({super.key});

  @override
  State<WearablesScreen> createState() => _WearablesScreenState();
}

enum _Stage { loading, sdkUnavailable, needsPermission, ready, error }

class _WearablesScreenState extends State<WearablesScreen> {
  final HealthService _service = HealthService();
  _Stage _stage = _Stage.loading;
  HealthSummary? _summary;
  String? _message;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _stage = _Stage.loading);
    try {
      final status = await _service.sdkStatus();
      if (status != null && status != HealthConnectSdkStatus.sdkAvailable) {
        setState(() => _stage = _Stage.sdkUnavailable);
        return;
      }
      if (await _service.hasPermissions()) {
        await _refresh();
      } else {
        setState(() => _stage = _Stage.needsPermission);
      }
    } catch (e) {
      setState(() {
        _stage = _Stage.error;
        _message = e.toString();
      });
    }
  }

  Future<void> _connect() async {
    setState(() => _stage = _Stage.loading);
    final granted = await _service.requestPermissions();
    if (granted) {
      await _refresh();
    } else {
      if (!mounted) return;
      setState(() => _stage = _Stage.needsPermission);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se concedieron los permisos')),
      );
    }
  }

  Future<void> _refresh() async {
    final summary = await _service.fetchToday();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _stage = _Stage.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.loading => const Center(child: CircularProgressIndicator()),
      _Stage.sdkUnavailable => _InfoState(
        icon: Icons.health_and_safety_outlined,
        title: 'Health Connect no está disponible',
        body:
            'Para sincronizar pasos, pulso, calorías y sueño necesitás la app '
            'Health Connect instalada y actualizada en este dispositivo.',
        actionLabel: 'Instalar Health Connect',
        onAction: _service.installHealthConnect,
      ),
      _Stage.needsPermission => _InfoState(
        icon: Icons.watch_outlined,
        title: 'Conectá tu wearable',
        body:
            'NexFit puede leer tus pasos, frecuencia cardíaca, calorías activas '
            'y sueño desde Health Connect. Solo lectura: nunca escribe tus datos.',
        actionLabel: 'Conectar con Health Connect',
        onAction: _connect,
      ),
      _Stage.error => _InfoState(
        icon: Icons.error_outline,
        title: 'No se pudo acceder a los datos',
        body: _message ?? 'Error desconocido',
        actionLabel: 'Reintentar',
        onAction: _bootstrap,
      ),
      _Stage.ready => _SummaryView(summary: _summary, onRefresh: _refresh),
    };
  }
}

class _SummaryView extends StatelessWidget {
  final HealthSummary? summary;
  final VoidCallback onRefresh;

  const _SummaryView({required this.summary, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return const _InfoStateStatic(
        icon: Icons.info_outline,
        title: 'Sin datos por ahora',
        body:
            'No encontramos métricas de hoy. Entrená con tu wearable y volvé a '
            'actualizar.',
      );
    }
    final s = summary!;
    final sleep = s.sleepMinutes;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Hoy', style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // A5: mismo criterio que `workout_summary_screen.dart` -- alto fijo
        // al contenido (`mainAxisExtent`) en vez de `childAspectRatio`, y la
        // grilla no se estira más allá de un ancho razonable en pantalla
        // ancha.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                mainAxisExtent: 110,
              ),
              children: [
                _MetricCard(
                  icon: Icons.directions_walk,
                  color: AppColors.secondaryContainer,
                  label: 'Pasos',
                  value: '${s.steps}',
                ),
                _MetricCard(
                  icon: Icons.favorite,
                  color: AppColors.danger,
                  label: 'Pulso promedio',
                  value: s.avgHeartRate == null
                      ? '—'
                      : '${s.avgHeartRate!.round()} bpm',
                ),
                _MetricCard(
                  icon: Icons.local_fire_department,
                  color: AppColors.warning,
                  label: 'Calorías activas',
                  value: s.activeCalories == null
                      ? '—'
                      : '${s.activeCalories!.round()} kcal',
                ),
                _MetricCard(
                  icon: Icons.bedtime,
                  color: AppColors.tertiary,
                  label: 'Sueño',
                  value: sleep == null ? '—' : '${sleep ~/ 60}h ${sleep % 60}m',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
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

class _InfoState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _InfoState({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _InfoStateStatic extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoStateStatic({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
