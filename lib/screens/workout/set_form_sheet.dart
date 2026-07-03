import 'package:flutter/material.dart';

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
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Registrar serie',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
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
                      const SizedBox(width: 12),
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
                  const SizedBox(height: 12),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: rirController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'RIR'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: restController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Descanso (segundos)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Serie de calentamiento'),
                    value: isWarmup,
                    onChanged: (v) => setModalState(() => isWarmup = v),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Técnicas avanzadas',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: availableTechniques.entries.map((entry) {
                      final selected = selectedTechniques.contains(entry.key);
                      return FilterChip(
                        label: Text(entry.value),
                        selected: selected,
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
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
