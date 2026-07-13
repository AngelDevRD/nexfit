import '../../import_export/data/auto_mapper.dart' show normalizeHeader;

/// Mapeo directo de encabezado -> campo conocido de medidas corporales. A
/// diferencia del AutoMapper de F9 (sinonimos, multiples apps de origen),
/// acá el esquema es fijo -- una sola fuente conocida (export estilo
/// Hevy/Renpho) -- asi que no hace falta un diccionario de sinonimos, solo
/// comparar el encabezado normalizado ([normalizeHeader]) contra los
/// nombres de columna reales del CSV.
///
/// 'date' es un valor especial: determina la fecha de la fila, no se guarda
/// como medida. El resto de las claves coincide 1:1 con las que espera
/// `BodyMeasurementRepository.upsertForDate`.
const _knownColumns = {
  'date': 'date',
  'weight kg': 'weight_kg',
  'fat percent': 'fat_percent',
  'neck cm': 'neck_cm',
  'shoulder cm': 'shoulder_cm',
  'chest cm': 'chest_cm',
  'left bicep cm': 'left_bicep_cm',
  'right bicep cm': 'right_bicep_cm',
  'left forearm cm': 'left_forearm_cm',
  'right forearm cm': 'right_forearm_cm',
  'abdomen cm': 'abdomen_cm',
  'waist cm': 'waist_cm',
  'hips cm': 'hips_cm',
  'left thigh cm': 'left_thigh_cm',
  'right thigh cm': 'right_thigh_cm',
  'left calf cm': 'left_calf_cm',
  'right calf cm': 'right_calf_cm',
};

/// Mapea las columnas de un dataset a claves conocidas de medidas
/// corporales. Devuelve `sourceColumn -> key` solo para las columnas
/// reconocidas -- las demas quedan afuera (se ignoran, no rompen el import).
Map<String, String> mapMeasurementColumns(List<String> columns) {
  final result = <String, String>{};
  for (final column in columns) {
    final key = _knownColumns[normalizeHeader(column)];
    if (key != null) result[column] = key;
  }
  return result;
}
