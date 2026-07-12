import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../repositories/workout_repository.dart';
import 'domain/import_export_models.dart';
import 'export_flow_provider.dart';

/// Elegir formato (CSV/Excel/JSON) y exportar el historial de
/// entrenamientos a un archivo, usando exclusivamente ExportEngine
/// (CsvWriter/JsonWriter/ExcelWriter via [ExportFlowProvider]).
class ExportScreen extends StatelessWidget {
  @visibleForTesting
  final ExportFlowProvider? debugProvider;

  const ExportScreen({super.key, this.debugProvider});

  @override
  Widget build(BuildContext context) {
    final provider = debugProvider;
    return (provider != null
        ? ChangeNotifierProvider.value(value: provider, child: _scaffold())
        : ChangeNotifierProvider(
            create: (context) => ExportFlowProvider(
              workoutRepository: context.read<WorkoutRepository>(),
            ),
            child: _scaffold(),
          ));
  }

  Widget _scaffold() {
    return Builder(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Exportar a archivo')),
        body: Consumer<ExportFlowProvider>(
          builder: (context, flow, _) {
            return switch (flow.status) {
              ExportFlowStatus.idle => _FormatPickerView(
                onExport: flow.exportTo,
              ),
              ExportFlowStatus.exporting => const Center(
                child: CircularProgressIndicator(),
              ),
              ExportFlowStatus.error => _ErrorView(
                message: flow.errorMessage ?? 'Error desconocido',
                onRetry: flow.reset,
              ),
              ExportFlowStatus.success => _SuccessView(onDone: flow.reset),
            };
          },
        ),
      ),
    );
  }
}

class _FormatPickerView extends StatefulWidget {
  final void Function(ImportSourceFormat format) onExport;

  const _FormatPickerView({required this.onExport});

  @override
  State<_FormatPickerView> createState() => _FormatPickerViewState();
}

class _FormatPickerViewState extends State<_FormatPickerView> {
  ImportSourceFormat _selected = ImportSourceFormat.csv;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Elegi el formato para exportar tu historial de '
              'entrenamientos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<ImportSourceFormat>(
              segments: const [
                ButtonSegment(
                  value: ImportSourceFormat.csv,
                  label: Text('CSV'),
                ),
                ButtonSegment(
                  value: ImportSourceFormat.xlsx,
                  label: Text('Excel'),
                ),
                ButtonSegment(
                  value: ImportSourceFormat.json,
                  label: Text('JSON'),
                ),
              ],
              selected: {_selected},
              onSelectionChanged: (selection) =>
                  setState(() => _selected = selection.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => widget.onExport(_selected),
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Exportar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;

  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.secondary,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Archivo exportado',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Elegi donde guardarlo desde la hoja de compartir que se abrio.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: onDone,
              child: const Text('Exportar otro formato'),
            ),
          ],
        ),
      ),
    );
  }
}
