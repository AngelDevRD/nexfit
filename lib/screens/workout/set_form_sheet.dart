import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/workout.dart';

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
}) {
  final weightController = TextEditingController(
    text: initialWeight > 0 ? initialWeight.toString() : '',
  );
  final repsController = TextEditingController(
    text: initialReps > 0 ? initialReps.toString() : '',
  );
  final rpeController = TextEditingController();
  final rirController = TextEditingController();
  final restController = TextEditingController(text: initialRest.toString());
  final notesController = TextEditingController();
  final selectedTechniques = <String>{};
  bool isWarmup = false;

  return showModalBottomSheet<SetFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
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
                  Text(
                    'Registrar serie',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Peso (kg)',
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
                          decoration: const InputDecoration(
                            labelText: 'RPE (0-10)',
                          ),
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
                      onChanged: (v) => setModalState(() => isWarmup = v),
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
                        onSelected: (v) => setModalState(() {
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
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () {
                      final weight =
                          double.tryParse(weightController.text) ?? 0;
                      final reps = int.tryParse(repsController.text) ?? 0;
                      if (reps <= 0) return;
                      Navigator.of(context).pop(
                        SetFormResult(
                          weightKg: weight,
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
                    },
                    child: const Text('Guardar serie'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
