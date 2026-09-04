import '../providers/weight_unit_provider.dart';

/// Conversión pura kg <-> unidad mostrada. El almacenamiento (Drift/Supabase,
/// cálculos de volumen/récords) siempre trabaja en kg -- estas funciones son
/// exclusivamente para lo que se pinta en pantalla y lo que se lee de un
/// input antes de convertir de vuelta a kg.
double kgToDisplay(double kg, WeightUnit unit) => kg * unit.perKg;

double displayToKg(double displayValue, WeightUnit unit) =>
    displayValue / unit.perKg;

/// "80 kg" / "176.4 lb". `decimals` por defecto 1 salvo en kg, donde los
/// pesos de gimnasio suelen no llevar decimales cuando son enteros.
String formatWeight(double kg, WeightUnit unit, {int decimals = 1}) {
  final value = kgToDisplay(kg, unit);
  return '${value.toStringAsFixed(decimals)} ${unit.label}';
}
