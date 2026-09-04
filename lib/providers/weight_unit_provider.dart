import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unidad de peso mostrada en toda la app. Es puramente de presentación --
/// todo lo que se guarda en Drift/Supabase sigue en kg sin excepción (ver
/// `formatWeight`/`weightFromDisplay` en `lib/core/units.dart`).
enum WeightUnit {
  kg('kg', 1.0),
  lb('lb', 2.2046226218);

  const WeightUnit(this.label, this.perKg);
  final String label;
  final double perKg;
}

/// Preferencia de unidad de peso persistida localmente. Mismo patrón que
/// `SyncSettingsProvider`/`ThemeProvider`: carga optimista, notifica antes de
/// persistir.
class WeightUnitProvider extends ChangeNotifier {
  static const _prefsKey = 'weight_unit';

  WeightUnit _unit = WeightUnit.kg;
  WeightUnit get unit => _unit;

  WeightUnitProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final loaded = switch (stored) {
      'lb' => WeightUnit.lb,
      'kg' => WeightUnit.kg,
      _ => WeightUnit.kg,
    };
    if (loaded != _unit) {
      _unit = loaded;
      notifyListeners();
    }
  }

  Future<void> setUnit(WeightUnit unit) async {
    _unit = unit;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, unit.name);
  }
}
