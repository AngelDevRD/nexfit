import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opciones de intervalo de sync ofrecidas en Ajustes. El motor sigue siendo
/// local-first (ver SyncEngine): esto solo cambia cada cuánto se drena lo
/// pendiente hacia Supabase, no si se guarda local primero.
enum SyncFrequency {
  nearInstant(Duration(minutes: 1), 'Casi instantáneo'),
  every10Min(Duration(minutes: 10), 'Cada 10 minutos'),
  every30Min(Duration(minutes: 30), 'Cada 30 minutos'),
  hourly(Duration(hours: 1), 'Cada hora'),
  every3Hours(Duration(hours: 3), 'Cada 3 horas'),
  every5Hours(Duration(hours: 5), 'Cada 5 horas'),
  every12Hours(Duration(hours: 12), 'Cada 12 horas');

  const SyncFrequency(this.interval, this.label);
  final Duration interval;
  final String label;
}

/// Preferencia de frecuencia de sync persistida localmente. Default 3 horas,
/// igual al valor que traía SyncEngine hardcodeado antes de ser configurable.
class SyncSettingsProvider extends ChangeNotifier {
  static const _prefsKey = 'sync_frequency_minutes';

  SyncFrequency _frequency = SyncFrequency.every3Hours;
  SyncFrequency get frequency => _frequency;

  SyncSettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMinutes = prefs.getInt(_prefsKey);
    if (storedMinutes == null) return;
    final match = SyncFrequency.values.where(
      (f) => f.interval.inMinutes == storedMinutes,
    );
    if (match.isEmpty) return;
    _frequency = match.first;
    notifyListeners();
  }

  Future<void> setFrequency(SyncFrequency frequency) async {
    _frequency = frequency;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, frequency.interval.inMinutes);
  }
}
