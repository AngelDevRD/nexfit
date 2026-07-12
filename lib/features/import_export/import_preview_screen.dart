import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../repositories/workout_repository.dart';
import 'domain/exercise_resolution_models.dart';
import 'domain/import_result.dart';
import 'domain/validation_models.dart';
import 'import_flow_provider.dart';

/// Elegir un archivo (CSV/Excel/JSON) exportado desde otra app, ver la
/// vista previa (F9a) y confirmar para persistirlo via ImportEngine (F9b).
class ImportPreviewScreen extends StatelessWidget {
  /// Seam de testabilidad: en produccion siempre `null` (la pantalla crea
  /// su propio provider a partir del `WorkoutRepository` del arbol de
  /// Provider). Los tests de widget pueden inyectar uno con estado
  /// preseteado para renderizar preview/error/success sin pasar por el
  /// plugin real de `file_picker` ni una base de datos real.
  @visibleForTesting
  final ImportFlowProvider? debugProvider;

  const ImportPreviewScreen({super.key, this.debugProvider});

  @override
  Widget build(BuildContext context) {
    final provider = debugProvider;
    return (provider != null
        ? ChangeNotifierProvider.value(value: provider, child: _scaffold())
        : ChangeNotifierProvider(
            create: (context) => ImportFlowProvider(
              workoutRepository: context.read<WorkoutRepository>(),
            ),
            child: _scaffold(),
          ));
  }

  Widget _scaffold() {
    return Builder(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Importar desde otra app')),
        body: Consumer<ImportFlowProvider>(
          builder: (context, flow, _) {
            return switch (flow.status) {
              ImportFlowStatus.idle => _IdleView(
                onPick: flow.pickAndAnalyzeFile,
              ),
              ImportFlowStatus.loading || ImportFlowStatus.importing =>
                const Center(child: CircularProgressIndicator()),
              ImportFlowStatus.error => _ErrorView(
                message: flow.errorMessage ?? 'Error desconocido',
                onRetry: flow.reset,
              ),
              ImportFlowStatus.resolvingExercises => _ExerciseResolutionView(
                groups: flow.unresolvedExercises!,
                catalogOptions: flow.catalogOptions!,
                onCancel: flow.reset,
                onSubmit: flow.submitExerciseResolutions,
              ),
              ImportFlowStatus.preview => _PreviewView(
                fileName: flow.fileName ?? '',
                summary: flow.summary!,
                onPickAnother: flow.reset,
                onConfirm: flow.confirmImport,
              ),
              ImportFlowStatus.success => _SuccessView(
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
              'Elegi un archivo CSV, Excel o JSON exportado desde otra app '
              '(Strong, Hevy, FitNotes, etc.) para ver que se importaria.',
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

/// Asistente de un solo dialogo para decidir que hacer con los ejercicios
/// del archivo importado que no existen en el catalogo local. Nunca se
/// muestra como error: el entrenamiento importado sigue siendo valido, solo
/// falta decidir a que ejercicio del catalogo corresponde cada nombre nuevo.
class _ExerciseResolutionView extends StatefulWidget {
  final List<UnresolvedExerciseGroup> groups;
  final List<CatalogExerciseOption> catalogOptions;
  final VoidCallback onCancel;
  final void Function(Map<String, ExerciseResolutionChoice> choices) onSubmit;

  const _ExerciseResolutionView({
    required this.groups,
    required this.catalogOptions,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  State<_ExerciseResolutionView> createState() =>
      _ExerciseResolutionViewState();
}

class _ExerciseResolutionViewState extends State<_ExerciseResolutionView> {
  late final Map<String, ExerciseResolutionAction> _actions = {
    for (final g in widget.groups) g.key: ExerciseResolutionAction.createNew,
  };
  late final Map<String, int?> _mappedIds = {
    for (final g in widget.groups)
      g.key: widget.catalogOptions.isEmpty
          ? null
          : widget.catalogOptions.first.id,
  };

  @override
  Widget build(BuildContext context) {
    final totalRows = widget.groups.fold<int>(
      0,
      (sum, g) => sum + g.rowIndexes.length,
    );
    final pendingMappings = widget.groups
        .where(
          (g) =>
              _actions[g.key] == ExerciseResolutionAction.mapExisting &&
              _mappedIds[g.key] == null,
        )
        .length;
    final canContinue = pendingMappings == 0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Encontramos ${widget.groups.length} ejercicio'
          '${widget.groups.length == 1 ? '' : 's'} que no estan en tu '
          'catalogo ($totalRows fila${totalRows == 1 ? '' : 's'} del '
          'archivo). Tu entrenamiento importado sigue siendo valido -- solo '
          'falta decidir a que ejercicio de tu catalogo corresponde cada '
          'uno.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final group in widget.groups)
          Semantics(
            container: true,
            label: 'Resolucion para el ejercicio ${group.name}',
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${group.rowIndexes.length} fila'
                    '${group.rowIndexes.length == 1 ? '' : 's'} afectada'
                    '${group.rowIndexes.length == 1 ? '' : 's'}',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  RadioListTile<ExerciseResolutionAction>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Crear ejercicio nuevo en mi catalogo'),
                    value: ExerciseResolutionAction.createNew,
                    groupValue: _actions[group.key],
                    onChanged: (v) => setState(() => _actions[group.key] = v!),
                  ),
                  RadioListTile<ExerciseResolutionAction>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Asociar a un ejercicio existente'),
                    value: ExerciseResolutionAction.mapExisting,
                    groupValue: _actions[group.key],
                    onChanged: (v) => setState(() => _actions[group.key] = v!),
                  ),
                  if (_actions[group.key] ==
                      ExerciseResolutionAction.mapExisting)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.lg,
                        bottom: AppSpacing.sm,
                      ),
                      child: Semantics(
                        label: 'Ejercicio del catalogo para ${group.name}',
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _mappedIds[group.key],
                          hint: const Text('Elegi un ejercicio'),
                          items: [
                            for (final option in widget.catalogOptions)
                              DropdownMenuItem(
                                value: option.id,
                                child: Text(option.name),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _mappedIds[group.key] = v),
                        ),
                      ),
                    ),
                  RadioListTile<ExerciseResolutionAction>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Ignorar (omitir solo este ejercicio)'),
                    value: ExerciseResolutionAction.ignore,
                    groupValue: _actions[group.key],
                    onChanged: (v) => setState(() => _actions[group.key] = v!),
                  ),
                ],
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: canContinue
              ? () {
                  final choices = <String, ExerciseResolutionChoice>{
                    for (final group in widget.groups)
                      group.key: switch (_actions[group.key]!) {
                        ExerciseResolutionAction.ignore =>
                          const ExerciseResolutionChoice.ignore(),
                        ExerciseResolutionAction.createNew =>
                          const ExerciseResolutionChoice.createNew(),
                        ExerciseResolutionAction.mapExisting =>
                          ExerciseResolutionChoice.mapExisting(
                            _mappedIds[group.key]!,
                          ),
                      },
                  };
                  widget.onSubmit(choices);
                }
              : null,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Continuar importacion'),
        ),
        if (!canContinue)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Completa la asociacion de $pendingMappings ejercicio'
              '${pendingMappings == 1 ? '' : 's'} para poder continuar.',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: widget.onCancel,
          child: const Text('Cancelar importacion'),
        ),
      ],
    );
  }
}

class _PreviewView extends StatelessWidget {
  final String fileName;
  final PreviewSummary summary;
  final VoidCallback onPickAnother;
  final VoidCallback onConfirm;

  const _PreviewView({
    required this.fileName,
    required this.summary,
    required this.onPickAnother,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
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
              _SummaryRow('Registros totales', '${summary.totalRecords}'),
              _SummaryRow('Validos', '${summary.validRecords}'),
              _SummaryRow('Con errores', '${summary.recordsWithErrors}'),
              _SummaryRow('Con advertencias', '${summary.recordsWithWarnings}'),
              _SummaryRow('Posibles duplicados', '${summary.duplicateRecords}'),
              if (summary.unmappedColumns.isNotEmpty)
                _SummaryRow(
                  'Columnas sin reconocer',
                  summary.unmappedColumns.join(', '),
                ),
            ],
          ),
        ),
        if (summary.issues.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Detalle', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final issue in summary.issues.take(50))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Fila ${issue.rowIndex}: ${issue.message}',
                style: TextStyle(
                  color: issue.severity == ValidationSeverity.error
                      ? AppColors.danger
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (summary.validRecords > 0)
          FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: Text('Importar ${summary.validRecords} registros'),
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
  final ImportResult result;
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
              '${result.setsCreated} series creadas en '
              '${result.sessionsCreated} entrenamientos'
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
