import '../../../models/workout.dart';
import 'import_export_models.dart';

/// Encabezados canonicos de exportacion. A proposito son exactamente
/// sinonimos ya reconocidos por `defaultSynonyms` (F5, `data/auto_mapper.
/// dart`) -- un archivo exportado por esta app se puede reimportar por esta
/// misma app (o cualquier otra que respete estos nombres) sin necesitar
/// mapeo manual. Este orden es el "formato estandar documentado" pedido
/// para la exportacion.
const List<String> exportColumns = [
  'Exercise Name',
  'Date',
  'Set',
  'Weight',
  'Reps',
  'RPE',
  'RIR',
  'Rest',
  'Warmup',
  'Notes',
];

/// Tabla lista para escribir a disco: mismas columnas para cualquier
/// formato de salida (CSV/Excel/JSON), analoga a [ParsedDataset] pero en
/// sentido inverso.
class ExportDataset {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;

  const ExportDataset({required this.columns, required this.rows});
}

/// Aplana sesiones de entrenamiento ya cargadas (modelo de dominio, no
/// Drift) a filas tabulares: una fila por set. Es cambio de representacion,
/// no interpretacion -- no agrega ni descarta informacion, solo la
/// reacomoda en columnas.
ExportDataset workoutSessionsToExportDataset(List<WorkoutSession> sessions) {
  final rows = <Map<String, dynamic>>[];
  for (final session in sessions) {
    for (final set in session.sets) {
      rows.add({
        'Exercise Name': set.exercise.name,
        'Date': session.startedAt.toIso8601String(),
        'Set': set.setNumber,
        'Weight': set.weightKg,
        'Reps': set.reps,
        'RPE': set.rpe,
        'RIR': set.rir,
        'Rest': set.restSeconds,
        'Warmup': set.isWarmup,
        'Notes': set.notes,
      });
    }
  }
  return ExportDataset(columns: exportColumns, rows: rows);
}

/// Contrato que debe implementar cada escritor de formato (CSV, Excel,
/// JSON...). Punto de extension simetrico a [FileParser]: sumar un formato
/// nuevo de exportacion es implementar esta interfaz, sin tocar el resto
/// del ExportEngine.
abstract class FileWriter {
  ImportSourceFormat get format;

  List<int> write(ExportDataset dataset);
}
