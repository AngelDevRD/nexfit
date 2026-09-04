import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../features/measurements_import/import_measurements_screen.dart';
import '../../models/body_measurement.dart';
import '../../providers/weight_unit_provider.dart';
import '../../repositories/body_measurement_repository.dart';
import '../../widgets/empty_state.dart';

/// Historial de medidas corporales (peso, % grasa, circunferencias): lista
/// + alta manual + entrada al importador de archivos
/// ([ImportMeasurementsScreen]). Solo local (ver comentario en
/// `BodyMeasurements` en `core/local/database.dart`) -- no sincroniza con
/// Supabase todavia.
/// N5: siempre vive dentro de [CuerpoHubScreen]. La acción de importar ya no
/// cuelga de un AppBar transparente fantasma -- vive en el encabezado del
/// contenido.
class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  late final BodyMeasurementRepository _repository;
  List<BodyMeasurement> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<BodyMeasurementRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await _repository.history();
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openImport() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ImportMeasurementsScreen()));
    _load();
  }

  Future<void> _openAddForm({BodyMeasurement? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _MeasurementFormSheet(repository: _repository, existing: existing),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Medidas corporales',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          IconButton(
            onPressed: _openImport,
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Importar desde archivo',
          ),
        ],
      ),
    );
    final list = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: EmptyState.error(message: _error!, onRetry: _load))
        : _history.isEmpty
        ? _EmptyState(onImport: _openImport, onAdd: () => _openAddForm())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                final previous = index + 1 < _history.length
                    ? _history[index + 1]
                    : null;
                return _MeasurementTile(
                  entry: entry,
                  previous: previous,
                  onTap: () => _openAddForm(existing: entry),
                );
              },
            ),
          );
    final fab = FloatingActionButton(
      onPressed: () => _openAddForm(),
      child: const Icon(Icons.add),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: fab,
      body: Column(children: [header, Expanded(child: list)]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onAdd;

  const _EmptyState({required this.onImport, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Todavia no cargaste ninguna medicion.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Agregar medicion'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Importar desde archivo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  final BodyMeasurement entry;
  final BodyMeasurement? previous;
  final VoidCallback onTap;

  const _MeasurementTile({
    required this.entry,
    required this.previous,
    required this.onTap,
  });

  String? _deltaLabel(WeightUnit weightUnit) {
    final current = entry.weightKg;
    final prev = previous?.weightKg;
    if (current == null || prev == null) return null;
    final deltaKg = current - prev;
    if (deltaKg.abs() < 0.05) return 'sin cambios';
    final sign = deltaKg > 0 ? '+' : '';
    return '$sign${kgToDisplay(deltaKg, weightUnit).toStringAsFixed(1)} '
        '${weightUnit.label} vs. anterior';
  }

  @override
  Widget build(BuildContext context) {
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    final dateLabel = DateFormat('dd/MM/yyyy').format(entry.measuredAt);
    final delta = _deltaLabel(weightUnit);

    return Card(
      color: AppColors.surfaceContainer,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        title: Text(dateLabel),
        subtitle: Text(
          [
            if (entry.weightKg != null)
              formatWeight(entry.weightKg!, weightUnit),
            if (entry.fatPercent != null)
              '${entry.fatPercent!.toStringAsFixed(1)}% grasa',
            ?delta,
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Formulario de alta/edicion con los 16 campos opcionales, agrupados en
/// una hoja modal scrolleable (mismo criterio de "todo opcional" que el
/// resto del modulo -- no todos los dias se miden las 14 circunferencias).
class _MeasurementFormSheet extends StatefulWidget {
  final BodyMeasurementRepository repository;
  final BodyMeasurement? existing;

  const _MeasurementFormSheet({required this.repository, this.existing});

  @override
  State<_MeasurementFormSheet> createState() => _MeasurementFormSheetState();
}

class _MeasurementFormSheetState extends State<_MeasurementFormSheet> {
  late DateTime _date;
  late final Map<String, TextEditingController> _controllers;
  late final WeightUnit _weightUnit;
  bool _saving = false;

  // 'weight_kg' es el único campo en unidad de peso -- el resto son
  // circunferencias en cm, sin equivalente kg/lb. Su label real ("Peso
  // (kg)"/"Peso (lb)") se arma en build() con la unidad actual.
  static const _fields = <String, String>{
    'weight_kg': 'Peso',
    'fat_percent': '% grasa',
    'neck_cm': 'Cuello (cm)',
    'shoulder_cm': 'Hombro (cm)',
    'chest_cm': 'Pecho (cm)',
    'left_bicep_cm': 'Biceps izq. (cm)',
    'right_bicep_cm': 'Biceps der. (cm)',
    'left_forearm_cm': 'Antebrazo izq. (cm)',
    'right_forearm_cm': 'Antebrazo der. (cm)',
    'abdomen_cm': 'Abdomen (cm)',
    'waist_cm': 'Cintura (cm)',
    'hips_cm': 'Cadera (cm)',
    'left_thigh_cm': 'Muslo izq. (cm)',
    'right_thigh_cm': 'Muslo der. (cm)',
    'left_calf_cm': 'Gemelo izq. (cm)',
    'right_calf_cm': 'Gemelo der. (cm)',
  };

  @override
  void initState() {
    super.initState();
    _weightUnit = context.read<WeightUnitProvider>().unit;
    final existing = widget.existing;
    _date = existing?.measuredAt ?? DateTime.now();
    _controllers = {
      for (final key in _fields.keys)
        key: TextEditingController(
          text: _valueFor(existing, key)?.toString() ?? '',
        ),
    };
  }

  double? _valueFor(BodyMeasurement? entry, String key) {
    if (entry == null) return null;
    if (key == 'weight_kg') {
      return entry.weightKg == null
          ? null
          : kgToDisplay(entry.weightKg!, _weightUnit);
    }
    return switch (key) {
      'fat_percent' => entry.fatPercent,
      'neck_cm' => entry.neckCm,
      'shoulder_cm' => entry.shoulderCm,
      'chest_cm' => entry.chestCm,
      'left_bicep_cm' => entry.leftBicepCm,
      'right_bicep_cm' => entry.rightBicepCm,
      'left_forearm_cm' => entry.leftForearmCm,
      'right_forearm_cm' => entry.rightForearmCm,
      'abdomen_cm' => entry.abdomenCm,
      'waist_cm' => entry.waistCm,
      'hips_cm' => entry.hipsCm,
      'left_thigh_cm' => entry.leftThighCm,
      'right_thigh_cm' => entry.rightThighCm,
      'left_calf_cm' => entry.leftCalfCm,
      'right_calf_cm' => entry.rightCalfCm,
      _ => null,
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final fields = <String, double?>{
      for (final entry in _controllers.entries)
        if (entry.value.text.trim().isNotEmpty)
          entry.key: () {
            final parsed = double.tryParse(
              entry.value.text.trim().replaceAll(',', '.'),
            );
            if (parsed == null) return null;
            // El resto de los campos (todos cm) se guardan tal cual -- solo
            // el peso se ingresó en la unidad elegida y hay que volverlo a
            // kg antes de escribir (el almacenamiento siempre es en kg).
            return entry.key == 'weight_kg'
                ? displayToKg(parsed, _weightUnit)
                : parsed;
          }(),
    };
    await widget.repository.upsertForDate(_date, fields);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nueva medicion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(DateFormat('dd/MM/yyyy').format(_date)),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in _fields.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: TextField(
                        controller: _controllers[entry.key],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: entry.key == 'weight_kg'
                              ? '${entry.value} (${_weightUnit.label})'
                              : entry.value,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
