import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../models/workout.dart';
import '../../providers/weight_unit_provider.dart';

class SetFormResult {
  final double weightKg;
  final int reps;
  final double? rpe;
  final int? rir;
  final int restSeconds;
  final List<String> techniques;
  final bool isWarmup;
  final String? notes;

  SetFormResult({
    required this.weightKg,
    required this.reps,
    this.rpe,
    this.rir,
    required this.restSeconds,
    required this.techniques,
    required this.isWarmup,
    this.notes,
  });
}

Future<SetFormResult?> showSetFormSheet(
  BuildContext context, {
  double initialWeight = 0,
  int initialReps = 0,
  int initialRest = 90,
  double? initialRpe,
  int? initialRir,
  String? initialNotes,
  List<String> initialTechniques = const [],
  bool initialIsWarmup = false,
}) {
  return showModalBottomSheet<SetFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SetFormSheetContent(
      initialWeight: initialWeight,
      initialReps: initialReps,
      initialRest: initialRest,
      initialRpe: initialRpe,
      initialRir: initialRir,
      initialNotes: initialNotes,
      initialTechniques: initialTechniques,
      initialIsWarmup: initialIsWarmup,
    ),
  );
}

/// Contenido del sheet como `StatefulWidget` propio (T7): los 6
/// `TextEditingController` los crea y libera este `State` -- antes vivían en
/// closures de una función y nunca se llamaba `dispose()` sobre ellos.
class _SetFormSheetContent extends StatefulWidget {
  final double initialWeight;
  final int initialReps;
  final int initialRest;
  final double? initialRpe;
  final int? initialRir;
  final String? initialNotes;
  final List<String> initialTechniques;
  final bool initialIsWarmup;

  const _SetFormSheetContent({
    required this.initialWeight,
    required this.initialReps,
    required this.initialRest,
    this.initialRpe,
    this.initialRir,
    this.initialNotes,
    required this.initialTechniques,
    required this.initialIsWarmup,
  });

  @override
  State<_SetFormSheetContent> createState() => _SetFormSheetContentState();
}

class _SetFormSheetContentState extends State<_SetFormSheetContent> {
  late final TextEditingController weightController;
  late final TextEditingController repsController;
  late final TextEditingController rpeController;
  late final TextEditingController rirController;
  late final TextEditingController restController;
  late final TextEditingController notesController;
  late final Set<String> selectedTechniques;
  late bool isWarmup;
  late WeightUnit weightUnit;

  @override
  void initState() {
    super.initState();
    weightUnit = context.read<WeightUnitProvider>().unit;
    final initialDisplayWeight = kgToDisplay(widget.initialWeight, weightUnit);
    weightController = TextEditingController(
      text: initialDisplayWeight > 0
          ? initialDisplayWeight.toStringAsFixed(1)
          : '',
    );
    repsController = TextEditingController(
      text: widget.initialReps > 0 ? widget.initialReps.toString() : '',
    );
    rpeController = TextEditingController(
      text: widget.initialRpe != null ? widget.initialRpe.toString() : '',
    );
    rirController = TextEditingController(
      text: widget.initialRir != null ? widget.initialRir.toString() : '',
    );
    restController = TextEditingController(
      text: widget.initialRest.toString(),
    );
    notesController = TextEditingController(text: widget.initialNotes ?? '');
    selectedTechniques = {...widget.initialTechniques};
    isWarmup = widget.initialIsWarmup;
  }

  @override
  void dispose() {
    weightController.dispose();
    repsController.dispose();
    rpeController.dispose();
    rirController.dispose();
    restController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final enteredWeight = double.tryParse(weightController.text) ?? 0;
    final weightKg = displayToKg(enteredWeight, weightUnit);
    final reps = int.tryParse(repsController.text) ?? 0;
    if (reps <= 0) return;
    Navigator.of(context).pop(
      SetFormResult(
        weightKg: weightKg,
        reps: reps,
        rpe: double.tryParse(rpeController.text),
        rir: int.tryParse(rirController.text),
        restSeconds: int.tryParse(restController.text) ?? 90,
        techniques: selectedTechniques.toList(),
        isWarmup: isWarmup,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Text('Registrar serie', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Peso (${weightUnit.label})',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: repsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Repeticiones',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rpeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'RPE (0-10)'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: rirController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'RIR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: restController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Descanso (segundos)',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                title: const Text('Serie de calentamiento'),
                value: isWarmup,
                onChanged: (v) => setState(() => isWarmup = v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Técnicas avanzadas',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: availableTechniques.entries.map((entry) {
                final selected = selectedTechniques.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: selected,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  onSelected: (v) => setState(() {
                    if (v) {
                      selectedTechniques.add(entry.key);
                    } else {
                      selectedTechniques.remove(entry.key);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _submit,
              child: const Text('Guardar serie'),
            ),
          ],
        ),
      ),
    );
  }
}
