import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../repositories/exercise_repository.dart';
import '../../widgets/muscle_group_filter.dart';

/// E1: alta/edición de ejercicios propios. Único formulario para los dos
/// puntos de entrada (`ExercisePickerScreen` sin resultados de búsqueda,
/// `ExerciseListScreen` desde el catálogo) y para editar lo ya creado.
/// Pide solo lo que hace falta para registrar una serie -- nombre, grupo
/// muscular, equipo, tipo de movimiento -- no contenido de catálogo
/// (instrucciones/consejos), que es lo que separa un ejercicio propio de uno
/// del catálogo semilla.
class ExerciseFormScreen extends StatefulWidget {
  final Exercise? existing;
  final String? initialName;

  const ExerciseFormScreen({super.key, this.existing, this.initialName});

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _equipmentController;
  String? _muscleGroup;
  String _movementType = 'compound';
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(
      text: existing?.name ?? widget.initialName ?? '',
    );
    _equipmentController = TextEditingController(
      text: existing?.equipment.join(', ') ?? '',
    );
    _muscleGroup = existing?.muscleGroup;
    if (existing != null && existing.movementType.isNotEmpty) {
      _movementType = existing.movementType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _muscleGroup == null) {
      if (_muscleGroup == null) {
        setState(() {}); // fuerza repintar el error del selector de grupo
      }
      return;
    }
    setState(() => _saving = true);
    final repository = context.read<ExerciseRepository>();
    final equipment = _equipmentController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    try {
      final int id;
      if (_isEditing) {
        id = widget.existing!.id;
        await repository.updateExercise(
          id,
          name: _nameController.text.trim(),
          muscleGroup: _muscleGroup!,
          equipment: equipment,
          movementType: _movementType,
        );
      } else {
        id = await repository.createExercise(
          name: _nameController.text.trim(),
          muscleGroup: _muscleGroup!,
          equipment: equipment,
          movementType: _movementType,
        );
      }
      final created = await repository.get(id);
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showMuscleGroupError = _muscleGroup == null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar ejercicio' : 'Nuevo ejercicio'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El nombre es obligatorio'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Grupo muscular',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in muscleGroupColors.entries)
                  MuscleChip(
                    label: entry.key,
                    color: entry.value,
                    selected: _muscleGroup == entry.key,
                    onTap: () => setState(() => _muscleGroup = entry.key),
                  ),
              ],
            ),
            if (showMuscleGroupError)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Elegí un grupo muscular',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _equipmentController,
              decoration: InputDecoration(
                labelText: 'Equipo',
                hintText: 'Ej: mancuernas, banco (separado por comas)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Tipo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'compound', label: Text('Compuesto')),
                ButtonSegment(value: 'isolation', label: Text('Aislamiento')),
              ],
              selected: {_movementType},
              onSelectionChanged: (s) =>
                  setState(() => _movementType = s.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Guardar cambios' : 'Crear ejercicio'),
            ),
          ],
        ),
      ),
    );
  }
}
