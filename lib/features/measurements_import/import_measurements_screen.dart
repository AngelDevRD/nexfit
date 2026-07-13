import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../repositories/body_measurement_repository.dart';
import 'data/measurement_import_engine.dart';
import 'data/measurement_validator.dart';
import 'import_measurements_flow_provider.dart';

/// Elegir un archivo (CSV/Excel/JSON) de medidas corporales exportado desde
/// otra app (Hevy, Renpho, etc.), ver un resumen corto y confirmar. No
/// reusa la UI de F9 ([ImportPreviewScreen]) porque el flujo es mas chico:
/// sin mapeo manual de columnas ni resolucion de ejercicios.
class ImportMeasurementsScreen extends StatelessWidget {
  @visibleForTesting
  final ImportMeasurementsFlowProvider? debugProvider;

  const ImportMeasurementsScreen({super.key, this.debugProvider});

  @override
  Widget build(BuildContext context) {
    final provider = debugProvider;
    return (provider != null
        ? ChangeNotifierProvider.value(value: provider, child: _scaffold())
        : ChangeNotifierProvider(
            create: (context) => ImportMeasurementsFlowProvider(
              repository: context.read<BodyMeasurementRepository>(),
            ),
            child: _scaffold(),
          ));
  }

  Widget _scaffold() {
    return Builder(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Importar medidas corporales')),
        body: Consumer<ImportMeasurementsFlowProvider>(
          builder: (context, flow, _) {
            return switch (flow.status) {
              MeasurementImportStatus.idle => _IdleView(
                onPick: flow.pickAndAnalyzeFile,
              ),
              MeasurementImportStatus.loading ||
              MeasurementImportStatus.importing => const Center(
                child: CircularProgressIndicator(),
              ),
              MeasurementImportStatus.error => _ErrorView(
                message: flow.errorMessage ?? 'Error desconocido',
                onRetry: flow.reset,
              ),
              MeasurementImportStatus.preview => _PreviewView(
                fileName: flow.fileName ?? '',
                rows: flow.rows!,
                onPickAnother: flow.reset,
                onConfirm: flow.confirmImport,
              ),
              MeasurementImportStatus.success => _SuccessView(
                result: flow.result!,
                onDone: () => Navigator.of(context).pop(),
                onImportAnother: flow.reset,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  final VoidCallback onPick;

  const _IdleView({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Elegi un archivo CSV, Excel o JSON con tu historial de '
              'medidas corporales (peso, % grasa, circunferencias).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Elegir archivo'),
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

class _PreviewView extends StatelessWidget {
  final String fileName;
  final List<MeasurementRow> rows;
  final VoidCallback onPickAnother;
  final VoidCallback onConfirm;

  const _PreviewView({
    required this.fileName,
    required this.rows,
    required this.onPickAnother,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final validRows = rows.where((r) => r.isValid).length;
    final invalidRows = rows.length - validRows;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(fileName, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow('Registros totales', '${rows.length}'),
              _SummaryRow('Validos', '$validRows'),
              _SummaryRow('Con errores', '$invalidRows'),
            ],
          ),
        ),
        if (invalidRows > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Detalle', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final row in rows.where((r) => !r.isValid).take(50))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Fila ${row.rowIndex}: ${row.error}',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (validRows > 0)
          FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: Text('Importar $validRows registros'),
          )
        else
          Text(
            'No hay registros validos para importar.',
            style: TextStyle(color: AppColors.danger),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: onPickAnother,
          child: const Text('Elegir otro archivo'),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final MeasurementImportResult result;
  final VoidCallback onDone;
  final VoidCallback onImportAnother;

  const _SuccessView({
    required this.result,
    required this.onDone,
    required this.onImportAnother,
  });

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
              'Importacion completa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${result.imported} mediciones cargadas'
              '${result.skipped > 0 ? ', ${result.skipped} filas omitidas' : ''}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onDone, child: const Text('Listo')),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onImportAnother,
              child: const Text('Importar otro archivo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.onSurfaceVariant)),
          Text(value),
        ],
      ),
    );
  }
}
