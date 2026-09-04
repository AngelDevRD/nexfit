import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/nutrition.dart';
import '../../repositories/nutrition_repository.dart';
import '../../widgets/empty_state.dart';

/// N5: siempre vive dentro de [CuerpoHubScreen] -- el hub provee
/// Scaffold/AppBar, esta pantalla solo devuelve contenido.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final NutritionRepository _repository;
  List<NutritionLog> _logs = [];
  bool _loading = true;
  String? _error;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  final _caloriesController = TextEditingController();
  final _caloriesFocus = FocusNode();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _waterController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<NutritionRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await _repository.list();
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _repository.upsert({
      'log_date': DateTime.now().toIso8601String().split('T').first,
      'calories': double.tryParse(_caloriesController.text) ?? 0,
      'protein_g': double.tryParse(_proteinController.text) ?? 0,
      'carbs_g': double.tryParse(_carbsController.text) ?? 0,
      'fat_g': double.tryParse(_fatController.text) ?? 0,
      'water_ml': double.tryParse(_waterController.text) ?? 0,
    });
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    _waterController.clear();
    setState(() => _saving = false);
    _load();
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _caloriesFocus.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Registrar hoy',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _caloriesController,
                    focusNode: _caloriesFocus,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Calorías'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _waterController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Agua (ml)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _proteinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Proteína (g)',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    controller: _carbsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Carbos (g)'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    controller: _fatController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Grasas (g)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar registro de hoy'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Historial', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!_loading && _error != null)
              EmptyState.error(message: _error!, onRetry: _load),
            if (!_loading && _error == null && _logs.isEmpty)
              EmptyState(
                icon: Icons.restaurant_outlined,
                message: 'Sin registros todavía.',
                actionLabel: 'Registrar hoy',
                onAction: () => FocusScope.of(context).requestFocus(
                  _caloriesFocus,
                ),
              ),
            for (final log in _logs)
              _NutritionLogCard(log: log, dateFormat: _dateFormat),
          ],
        ),
      );

    return body;
  }
}

class _NutritionLogCard extends StatelessWidget {
  final NutritionLog log;
  final DateFormat dateFormat;

  const _NutritionLogCard({required this.log, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                dateFormat.format(log.logDate),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _MacroLabel(letter: 'P', value: '${log.proteinG.toStringAsFixed(0)}g'),
              const SizedBox(width: AppSpacing.md),
              _MacroLabel(letter: 'C', value: '${log.carbsG.toStringAsFixed(0)}g'),
              const SizedBox(width: AppSpacing.md),
              _MacroLabel(letter: 'G', value: '${log.fatG.toStringAsFixed(0)}g'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                  boxShadow: AppGlow.secondary,
                ),
                child: Text(
                  '🔥 ${log.calories.toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (log.waterMl > 0) ...[
            const SizedBox(height: 4),
            Text(
              '💧 ${log.waterMl.toStringAsFixed(0)}ml agua',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroLabel extends StatelessWidget {
  final String letter;
  final String value;

  const _MacroLabel({required this.letter, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          letter,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
