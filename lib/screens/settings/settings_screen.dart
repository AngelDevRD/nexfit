import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/local/database.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme.dart';
import '../../features/import_export/export_screen.dart';
import '../../features/import_export/import_preview_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/weight_unit_provider.dart';
import '../../services/data_export_service.dart';
import '../../services/data_import_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _working = false;

  Future<void> _export() async {
    setState(() => _working = true);
    try {
      final email = sb.Supabase.instance.client.auth.currentUser?.email;
      await DataExportService(
        context.read<AppDatabase>(),
        userEmail: email,
      ).exportAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _import() async {
    final db = context.read<AppDatabase>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar datos'),
        content: const Text(
          'Se van a crear rutinas y entrenamientos nuevos a partir del archivo '
          'elegido. Los registros de nutrición/check-ins de fechas que ya '
          'tengas cargadas se van a omitir, el resto se agrega sin '
          'reemplazar nada existente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elegir archivo'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _working = true);
    try {
      final summary = await DataImportService(db).importAll();
      if (!mounted) return;
      if (summary == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importado: ${summary['routines_created']} rutinas, '
            '${summary['workout_sessions_created']} entrenamientos, '
            '${summary['nutrition_logs_created']} registros de nutrición '
            '(${summary['nutrition_logs_skipped']} omitidos), '
            '${summary['daily_checkins_created']} check-ins '
            '(${summary['daily_checkins_skipped']} omitidos).',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al importar: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mi cuenta'),
        content: const Text(
          'Esta acción es permanente y no se puede deshacer. Se va a borrar '
          'tu cuenta y todos tus datos: rutinas, entrenamientos, series, '
          'objetivos, check-ins y registros de nutrición, tanto los guardados '
          'en este teléfono como los de la nube.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar mi cuenta'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _working = true);
    try {
      final ok = await context.read<AuthProvider>().deleteAccount();
      if (!ok) {
        if (mounted) {
          final error = context.read<AuthProvider>().error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error ?? 'No se pudo eliminar la cuenta.')),
          );
        }
        return;
      }
      await context.read<AppDatabase>().clearAllData();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final syncSettings = context.watch<SyncSettingsProvider>();
    final syncEngine = context.watch<SyncEngine>();
    final weightUnit = context.watch<WeightUnitProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _SectionHeader(icon: Icons.palette_outlined, title: 'Apariencia'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Claro'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Oscuro'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Sistema'),
                  icon: Icon(Icons.smartphone_outlined),
                ),
              ],
              selected: {themeProvider.mode},
              onSelectionChanged: (selection) =>
                  themeProvider.setMode(selection.first),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(icon: Icons.sync, title: 'Sincronización'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tus datos siempre se guardan primero en el teléfono. Esto '
                  'solo define cada cuánto se suben a la nube.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<SyncFrequency>(
                  initialValue: syncSettings.frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia de sync',
                    border: OutlineInputBorder(),
                  ),
                  items: SyncFrequency.values
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(f.label),
                        ),
                      )
                      .toList(),
                  onChanged: (f) {
                    if (f != null) syncSettings.setFrequency(f);
                  },
                ),
                // Antes una falla de sync (ej. el bug de la columna
                // `completed` faltante en Supabase) solo quedaba en
                // developer.log -- invisible sin conectar un debugger. Esto
                // es lo mínimo para que el usuario se entere sin tener que
                // preguntar "¿esto está subiendo a la nube de verdad?".
                if (syncEngine.lastError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.sync_problem,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Último error de sync'
                                '${syncEngine.lastErrorAt != null ? ' (${DateFormat('dd/MM HH:mm').format(syncEngine.lastErrorAt!.toLocal())})' : ''}',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                syncEngine.lastError!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(icon: Icons.scale_outlined, title: 'Unidad de peso'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: SegmentedButton<WeightUnit>(
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
              ],
              selected: {weightUnit.unit},
              onSelectionChanged: (selection) =>
                  weightUnit.setUnit(selection.first),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(icon: Icons.save_outlined, title: 'Mis datos'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  // C3 (ADR): la app sube cambios a la nube pero no puede
                  // restaurarlos todavía -- si reinstalás o cambiás de
                  // teléfono, el historial se recupera solo con "Exportar
                  // datos" y después "Importar datos" en el dispositivo
                  // nuevo. Exportá seguido si te importa no perder nada.
                  'Rutinas, entrenamientos, nutrición, check-ins y metas. '
                  'Exportá antes de cambiar de teléfono o reinstalar: es la '
                  'única forma de recuperar tu historial hoy.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _working ? null : _export,
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Exportar datos'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _working ? null : _import,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Importar datos'),
                ),
                if (_working) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            icon: Icons.swap_vert,
            title: 'Migración avanzada',
            iconColor: AppColors.warning,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: AppSpacing.sm),
            child: Text(
              'Formato de otra app -- distinto de tu backup propio de arriba.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Traé tu historial desde otra app (Strong, Hevy, FitNotes, '
                  'etc.) o exportá el tuyo a un archivo CSV, Excel o JSON.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImportPreviewScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Importar desde archivo'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExportScreen()),
                  ),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Exportar a archivo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            icon: Icons.person_remove_outlined,
            title: 'Cuenta',
            iconColor: AppColors.danger,
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Borra tu cuenta y todos tus datos, en el teléfono y en la '
                  'nube. No se puede deshacer.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger),
                  ),
                  onPressed: _working ? null : _deleteAccount,
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Eliminar mi cuenta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;

  const _SectionHeader({required this.icon, required this.title, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
