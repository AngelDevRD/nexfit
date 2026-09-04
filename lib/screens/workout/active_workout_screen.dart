import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../models/exercise.dart';
import '../../models/routine.dart';
import '../../models/workout.dart';
import '../../providers/weight_unit_provider.dart';
import '../../repositories/active_workout_repository.dart';
import '../../repositories/personal_records_service.dart';
import '../../repositories/routine_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../widgets/exercise_thumb.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/stepper_field.dart';
import '../exercises/exercise_picker_screen.dart';
import 'rest_timer_banner.dart';
import 'set_form_sheet.dart';
import 'workout_summary_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final int sessionId;

  const ActiveWorkoutScreen({super.key, required this.sessionId});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with WidgetsBindingObserver {
  late final WorkoutRepository _repository;
  late final ActiveWorkoutRepository _activeRepository;
  late final RoutineRepository _routineRepository;
  WorkoutSession? _session;
  DateTime? _restEndsAt;
  int? _restTotalSeconds;
  bool _finishing = false;
  List<ResolvedRecord>? _newRecords;
  // Récords logrados en toda la sesión (no solo la última serie agregada) --
  // se muestran en WorkoutSummaryScreen al finalizar, en vez de descartarse.
  final List<ResolvedRecord> _sessionRecords = [];
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  // C4: objetivos de la rutina para el día que se está entrenando (si la
  // sesión viene de una), por exerciseId. Se resuelve una sola vez.
  Map<int, RoutineExercise> _routineTargets = {};
  bool _routineTargetsLoaded = false;
  // C6: última vez que se hizo cada ejercicio (sesión anterior ya
  // terminada), por exerciseId -- solo para precargar el peso/reps de la
  // PRIMERA serie al agregar el ejercicio (`_addExercise`).
  final Map<int, WorkoutSet?> _lastSets = {};
  // A2: todas las series de la última sesión de cada ejercicio, por
  // exerciseId -- alimenta la columna "ANTERIOR" (serie 1 contra serie 1,
  // serie 2 contra serie 2), no solo un valor suelto en el encabezado.
  final Map<int, List<WorkoutSet>> _previousSets = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = context.read<WorkoutRepository>();
    _activeRepository = context.read<ActiveWorkoutRepository>();
    _routineRepository = context.read<RoutineRepository>();
    _load();
  }

  Future<void> _load() async {
    final session = await _repository.get(widget.sessionId);
    // El descanso persiste como instante absoluto en el draft -> si la app se
    // cerró a mitad de un descanso, al reabrir se restaura el mismo estado
    // (RestTimerBanner recalcula el restante contra `DateTime.now()`).
    final restEndsAt = await _activeRepository.restEndsAt();

    if (!_routineTargetsLoaded &&
        session.routineId != null &&
        session.routineDayId != null) {
      _routineTargetsLoaded = true;
      final routine = await _routineRepository.get(session.routineId!);
      RoutineDay? day;
      for (final d in routine.days) {
        if (d.id == session.routineDayId) {
          day = d;
          break;
        }
      }
      if (day != null) {
        _routineTargets = {for (final e in day.exercises) e.exercise.id: e};
      }
    }

    final exerciseIds = session.sets.map((s) => s.exercise.id).toSet();
    for (final exerciseId in exerciseIds) {
      if (_lastSets.containsKey(exerciseId)) continue;
      _lastSets[exerciseId] = await _repository.lastSetFor(
        exerciseId,
        excludeSessionId: widget.sessionId,
      );
      _previousSets[exerciseId] =
          (await _repository.lastSessionFor(exerciseId))?.sets ?? const [];
    }

    if (!mounted) return;
    setState(() {
      _session = session;
      _restEndsAt = restEndsAt;
    });
    _elapsedTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(session.startedAt));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver del background, el `Timer` puede haber quedado pausado por el
    // SO -- se recalcula el elapsed/descanso de inmediato en vez de esperar
    // hasta el próximo tick, para que la UI no se vea "congelada" un segundo.
    if (state == AppLifecycleState.resumed && _session != null) {
      setState(() => _elapsed = DateTime.now().difference(_session!.startedAt));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsedTimer?.cancel();
    // No basta con cancelar los timers -- hay que VOLCAR lo pendiente, si no
    // un toque de "+" seguido de cerrar la pantalla dentro de los 500ms
    // pierde esa escritura para siempre. `dispose()` es sync, así que esto
    // no se espera; el repositorio sigue vivo y la escritura sigue su curso
    // en segundo plano.
    for (final timer in _updateDebouncers.values) {
      timer.cancel();
    }
    for (final entry in _pendingSetUpdates.entries) {
      if (entry.value.isEmpty) continue;
      _repository.updateSet(entry.key, entry.value);
    }
    _updateDebouncers.clear();
    _pendingSetUpdates.clear();
    super.dispose();
  }

  // T2: cada toque de +/- en un stepper llamaba `updateSet` + `_load()`
  // completo -- una recarga de TODA la sesión (con el N+1 de T1 antes de
  // arreglarlo) por cada tap. Ahora el cambio se aplica en memoria al
  // instante (la UI no espera nada) y la escritura real a la base se
  // debouncea: varios toques seguidos sobre la misma serie terminan en UNA
  // sola escritura con el valor final, no una por toque.
  final Map<int, Timer> _updateDebouncers = {};
  final Map<int, Map<String, num>> _pendingSetUpdates = {};

  Future<void> _updateSetField(WorkoutSet set, String field, num value) async {
    if (_session == null) return;
    setState(() {
      _session = _applySetFieldInMemory(_session!, set.id, field, value);
    });

    (_pendingSetUpdates[set.id] ??= {})[field] = value;

    _updateDebouncers[set.id]?.cancel();
    _updateDebouncers[set.id] = Timer(const Duration(milliseconds: 500), () {
      final payload = _pendingSetUpdates.remove(set.id);
      _updateDebouncers.remove(set.id);
      if (payload == null || payload.isEmpty) return;
      _repository.updateSet(set.id, payload);
    });
  }

  /// Vuelca a la base, YA, el cambio pendiente de una serie -- cancela su
  /// debounce y escribe el payload acumulado. Obligatorio antes de cualquier
  /// lectura que dependa de la fila en la base (`setCompleted` lee
  /// weight/reps con una query propia) o de cualquier cierre de pantalla:
  /// si no, la carrera entre el debounce (500ms) y esa lectura/cierre puede
  /// ganarla la lectura, evaluando un récord contra el valor viejo, o
  /// perderse la escritura directamente. Sin esto, C5 (completar la serie)
  /// podía evaluar el peso de ANTES de los últimos toques del stepper.
  Future<void> _flushPendingSetUpdate(int setId) async {
    _updateDebouncers[setId]?.cancel();
    _updateDebouncers.remove(setId);
    final payload = _pendingSetUpdates.remove(setId);
    if (payload == null || payload.isEmpty) return;
    await _repository.updateSet(setId, payload);
  }

  Future<void> _flushAllPendingSetUpdates() async {
    final setIds = _pendingSetUpdates.keys.toList();
    for (final setId in setIds) {
      await _flushPendingSetUpdate(setId);
    }
  }

  WorkoutSession _applySetFieldInMemory(
    WorkoutSession session,
    int setId,
    String field,
    num value,
  ) {
    final sets = [
      for (final s in session.sets)
        if (s.id == setId)
          switch (field) {
            'weight_kg' => s.copyWith(weightKg: value.toDouble()),
            'reps' => s.copyWith(reps: value.toInt()),
            'rpe' => s.copyWith(rpe: value.toDouble()),
            _ => s,
          }
        else
          s,
    ];
    return WorkoutSession(
      id: session.id,
      routineId: session.routineId,
      routineDayId: session.routineDayId,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      notes: session.notes,
      sets: sets,
    );
  }

  Map<int, List<WorkoutSet>> _groupedSets() {
    final grouped = <int, List<WorkoutSet>>{};
    for (final set in _session!.sets) {
      grouped.putIfAbsent(set.exercise.id, () => []).add(set);
    }
    return grouped;
  }

  /// Agrega el ejercicio elegido con una serie que nace en el peso/reps de
  /// la última vez que se hizo ese ejercicio (C6) -- si nunca se entrenó,
  /// 0/0/0 como antes. El usuario edita los valores directamente con los
  /// steppers o tocando el número (ver `StepperField`). El sheet completo de
  /// 8 campos sigue existiendo como acción secundaria (ícono "más opciones"
  /// de cada fila, `_openAdvancedEditor`), para quien quiera cargar RPE/RIR/
  /// técnicas.
  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<ExerciseSummary>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise == null) return;
    final last = await _repository.lastSetFor(
      exercise.id,
      excludeSessionId: widget.sessionId,
    );
    _lastSets[exercise.id] = last;
    _previousSets[exercise.id] =
        (await _repository.lastSessionFor(exercise.id))?.sets ?? const [];
    await _quickAddSet(
      exercise,
      setNumber: 1,
      weightKg: last?.weightKg ?? 0,
      reps: last?.reps ?? 0,
    );
  }

  /// "Añadir serie" dentro de una tarjeta ya agregada: copia peso/reps de la
  /// última serie en vez de reabrir el formulario completo.
  Future<void> _addSetFor(
    ExerciseSummary exercise,
    List<WorkoutSet> sets,
  ) async {
    await _quickAddSet(
      exercise,
      setNumber: nextSetNumber(sets),
      weightKg: sets.last.weightKg,
      reps: sets.last.reps,
    );
  }

  Future<void> _quickAddSet(
    ExerciseSummary exercise, {
    required int setNumber,
    required double weightKg,
    required int reps,
  }) async {
    final outcome = await _repository.addSet(widget.sessionId, {
      'exercise_id': exercise.id,
      'set_number': setNumber,
      'weight_kg': weightKg,
      'reps': reps,
      'rest_seconds': 90,
      'techniques': const [],
      'is_warmup': false,
      'completed': false,
    });
    await _load();
    if (outcome.newRecords.isNotEmpty && mounted) {
      _sessionRecords.addAll(outcome.newRecords);
      setState(() => _newRecords = outcome.newRecords);
    }
  }

  /// Check por serie (C5): es el gesto central del bucle de gimnasio, así
  /// que es el círculo grande de la izquierda de cada fila (ver
  /// `_ExerciseFocusCard`), no una acción escondida. Al completar (no al
  /// descompletar) arranca el descanso con el `restSeconds` de la propia
  /// serie -- antes esto solo pasaba si se abría el editor avanzado, y en el
  /// flujo normal (agregar serie, mover steppers) nunca se llamaba.
  Future<void> _toggleSetCompleted(WorkoutSet set) async {
    final completing = !set.completed;
    // Volcar ANTES de completar: `setCompleted` evalúa récords leyendo
    // weight/reps de la base, no de `set` (el objeto en memoria que ya tiene
    // el valor del último toque). Sin este flush, subir el peso con el
    // stepper y completar la serie enseguida evaluaba contra el valor viejo
    // -- la regresión que reabrió C2.
    await _flushPendingSetUpdate(set.id);
    final newRecords = await _repository.setCompleted(set.id, completing);
    await _load();
    if (newRecords.isNotEmpty && mounted) {
      _sessionRecords.addAll(newRecords);
      setState(() => _newRecords = newRecords);
    }
    if (!completing || !mounted) return;

    final restSeconds = set.restSeconds ?? 90;
    final restEndsAt = DateTime.now().add(Duration(seconds: restSeconds));
    await _activeRepository.updateProgress(
      currentExerciseId: set.exercise.id,
      currentSetNumber: set.setNumber,
      restEndsAt: restEndsAt,
    );
    if (mounted) {
      setState(() {
        _restEndsAt = restEndsAt;
        _restTotalSeconds = restSeconds;
      });
    }
  }

  /// Descanso editable por ejercicio (pedido explícito del usuario): la
  /// etiqueta "⏱ Xs" del encabezado es tocable y cambia el `rest_seconds` de
  /// TODAS las series de ese ejercicio -- no solo de la próxima que se
  /// complete. Antes esa etiqueta era puro texto informativo.
  Future<void> _editExerciseRest(List<WorkoutSet> sets) async {
    final current = sets.isEmpty ? 90 : (sets.first.restSeconds ?? 90);
    final controller = TextEditingController(text: current.toString());
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Descanso entre series'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Segundos'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    final seconds = entered == null ? null : int.tryParse(entered);
    if (seconds == null || seconds <= 0) return;

    for (final set in sets) {
      // Volcar antes: `_load()` de abajo relee la sesión entera de la base,
      // y sin esto un peso/reps recién tocado con el stepper (todavía sin
      // escribir) se pisaría momentáneamente con el valor viejo.
      await _flushPendingSetUpdate(set.id);
      await _repository.updateSet(set.id, {'rest_seconds': seconds});
    }
    await _load();
  }

  /// Acción secundaria contextual (ícono "más opciones" de cada fila): abre
  /// el formulario completo original, precargado con los valores actuales de
  /// esa serie, para cargar RPE/RIR/técnicas/notas/descanso custom sin perder
  /// nada de la funcionalidad que ya existía.
  Future<void> _openAdvancedEditor(WorkoutSet set) async {
    final result = await showSetFormSheet(
      context,
      initialWeight: set.weightKg,
      initialReps: set.reps,
      initialRest: set.restSeconds ?? 90,
      initialRpe: set.rpe,
      initialRir: set.rir,
      initialNotes: set.notes,
      initialTechniques: set.techniques,
      initialIsWarmup: set.isWarmup,
    );
    if (result == null) return;

    // El sheet ya arrancó con `set.weightKg`/`set.reps` (que sí reflejan lo
    // último tocado en el stepper, en memoria) y el usuario pudo haber
    // guardado sin tocarlos -- pero la escritura de abajo va a viajar YA,
    // mientras el debounce del stepper puede seguir pendiente y pisarla más
    // tarde con un valor viejo si no se vuelca antes.
    await _flushPendingSetUpdate(set.id);
    await _repository.updateSet(set.id, {
      'weight_kg': result.weightKg,
      'reps': result.reps,
      'rpe': result.rpe,
      'rir': result.rir,
      'notes': result.notes,
      'is_warmup': result.isWarmup,
      'techniques': result.techniques,
      'rest_seconds': result.restSeconds,
    });
    await _load();

    final restEndsAt = DateTime.now().add(
      Duration(seconds: result.restSeconds),
    );
    await _activeRepository.updateProgress(
      currentExerciseId: set.exercise.id,
      currentSetNumber: set.setNumber,
      restEndsAt: restEndsAt,
    );
    if (mounted) {
      setState(() {
        _restEndsAt = restEndsAt;
        _restTotalSeconds = result.restSeconds;
      });
    }
  }

  /// A4: "Reemplazar ejercicio" -- reusa `ExercisePickerScreen` (ya usado
  /// por `_addExercise`/el builder de rutinas) y mueve las series
  /// existentes al ejercicio elegido, en vez de perderlas.
  Future<void> _replaceExercise(ExerciseSummary exercise) async {
    final replacement = await Navigator.of(context).push<ExerciseSummary>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (replacement == null || replacement.id == exercise.id) return;
    await _repository.replaceExerciseInSession(
      widget.sessionId,
      exercise.id,
      replacement.id,
    );
    _lastSets.remove(exercise.id);
    _previousSets.remove(exercise.id);
    await _load();
  }

  Future<void> _deleteExercise(ExerciseSummary exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Eliminar ejercicio'),
        content: Text(
          '¿Eliminar "${exercise.name}" y todas sus series de esta sesión?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteExerciseFromSession(widget.sessionId, exercise.id);
    await _load();
  }

  /// Nota a nivel EJERCICIO (distinta de la nota por serie del editor
  /// avanzado, `_openAdvancedEditor`) -- p. ej. "usar agarre cerrado" o
  /// "máquina 3, no la 5".
  Future<void> _editExerciseNotes(
    ExerciseSummary exercise,
    List<WorkoutSet> sets,
  ) async {
    final current = sets.isEmpty ? null : sets.first.exerciseNotes;
    final controller = TextEditingController(text: current ?? '');
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text('Notas de ${exercise.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Ej: agarre cerrado'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (entered == null) return;
    final trimmed = entered.trim();
    await _repository.updateExerciseNotes(
      widget.sessionId,
      exercise.id,
      trimmed.isEmpty ? null : trimmed,
    );
    await _load();
  }

  /// A4: "Reordenar ejercicios" -- lista simple con flechas arriba/abajo
  /// (reusa el mismo `AlertDialog` que el resto de las acciones de esta
  /// pantalla, sin drag&drop nuevo).
  Future<void> _reorderExercises(
    List<MapEntry<int, ExerciseSummary>> exercisesInOrder,
  ) async {
    final order = exercisesInOrder.map((e) => e.key).toList();
    final names = {for (final e in exercisesInOrder) e.key: e.value.name};
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: const Text('Reordenar ejercicios'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: order.length,
              itemBuilder: (context, index) {
                final exerciseId = order[index];
                return ListTile(
                  dense: true,
                  title: Text(names[exerciseId] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up),
                        onPressed: index == 0
                            ? null
                            : () => setDialogState(() {
                                final item = order.removeAt(index);
                                order.insert(index - 1, item);
                              }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: index == order.length - 1
                            ? null
                            : () => setDialogState(() {
                                final item = order.removeAt(index);
                                order.insert(index + 1, item);
                              }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _repository.reorderExercisesInSession(
                  widget.sessionId,
                  order,
                );
                await _load();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExerciseActions(
    ExerciseSummary exercise,
    List<WorkoutSet> sets,
    List<MapEntry<int, ExerciseSummary>> exercisesInOrder,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Reemplazar ejercicio'),
              onTap: () => Navigator.of(ctx).pop('replace'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_vert),
              title: const Text('Reordenar ejercicios'),
              onTap: () => Navigator.of(ctx).pop('reorder'),
            ),
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('Notas del ejercicio'),
              onTap: () => Navigator.of(ctx).pop('notes'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: const Text('Eliminar ejercicio'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'replace':
        await _replaceExercise(exercise);
      case 'reorder':
        await _reorderExercises(exercisesInOrder);
      case 'notes':
        await _editExerciseNotes(exercise, sets);
      case 'delete':
        await _deleteExercise(exercise);
    }
  }

  Future<void> _extendRest(int seconds) async {
    final current = _restEndsAt ?? DateTime.now();
    final extended = current.add(Duration(seconds: seconds));
    await _activeRepository.updateProgress(restEndsAt: extended);
    if (mounted) {
      setState(() {
        _restEndsAt = extended;
        if (_restTotalSeconds != null) {
          _restTotalSeconds = _restTotalSeconds! + seconds;
        }
      });
    }
  }

  Future<void> _dismissRest() async {
    await _activeRepository.updateProgress(clearRest: true);
    if (mounted) {
      setState(() {
        _restEndsAt = null;
        _restTotalSeconds = null;
      });
    }
  }

  /// N4: minimizar -- igual que finalizar, no puede dejar una escritura
  /// pendiente del stepper colgada al salir de la pantalla.
  Future<void> _minimize() async {
    await _flushAllPendingSetUpdates();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  /// N4: pide confirmación antes de cerrar la sesión -- antes "Finalizar" no
  /// tenía vuelta atrás, ni siquiera con 0 series cargadas.
  Future<void> _confirmFinish() async {
    final setCount = _session?.sets.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('¿Finalizar entrenamiento?'),
        content: Text(
          setCount == 0
              ? 'Todavía no registraste ninguna serie.'
              : 'Vas a cerrar la sesión con $setCount serie'
                    '${setCount == 1 ? '' : 's'} registrada'
                    '${setCount == 1 ? '' : 's'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir entrenando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _finish();
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    // Volcar todo lo pendiente antes de cerrar -- `finishSession` corre
    // `rebuildPersonalRecords()` como red de seguridad, pero eso no salva un
    // toque de "+" de los últimos 500ms si la fila en la base todavía tiene
    // el valor viejo cuando se lee para el resumen.
    await _flushAllPendingSetUpdates();
    await _activeRepository.finish(widget.sessionId);
    if (!mounted) return;
    final finishedSession = await _repository.get(widget.sessionId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          session: finishedSession,
          records: _sessionRecords,
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final grouped = _groupedSets();
    final exercisesInSession = <int, ExerciseSummary>{};
    for (final set in _session!.sets) {
      exercisesInSession[set.exercise.id] = set.exercise;
    }
    // A4: "Reordenar ejercicios" persiste `exerciseOrder` en las series de
    // cada ejercicio (ver `reorderExercisesInSession`) -- se respeta acá
    // (null va al final, en el orden de aparición original) para que el
    // orden elegido sobreviva a un `_load()`.
    final orderedEntries = exercisesInSession.entries.toList()
      ..sort((a, b) {
        final orderA = grouped[a.key]!.first.exerciseOrder;
        final orderB = grouped[b.key]!.first.exerciseOrder;
        if (orderA == null && orderB == null) return 0;
        if (orderA == null) return 1;
        if (orderB == null) return -1;
        return orderA.compareTo(orderB);
      });
    // A3: métricas en vivo (antes solo se veían al finalizar, en
    // WorkoutSummaryScreen) -- se recalculan sobre `_session!.sets` en cada
    // build, así que se actualizan solas con cada toque del stepper (T2) y
    // con cada tick del cronómetro (_elapsedTimer ya dispara setState cada
    // segundo).
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    final liveVolumeKg = _session!.sets
        .where((s) => !s.isWarmup)
        .fold(0.0, (sum, s) => sum + s.weightKg * s.reps);
    final liveSetCount = _session!.sets.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        // N4: minimizar -- vuelve al shell sin finalizar; la sesión sigue
        // activa (el banner de N3 la muestra) y se puede retomar desde ahí
        // o consultar una rutina/ejercicio a mitad del entrenamiento. Antes
        // la única salida era "Finalizar" o cerrar la app entera.
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          tooltip: 'Minimizar (seguir después)',
          onPressed: _minimize,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Entrenamiento en curso',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 13, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatElapsed(_elapsed),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: _finishing ? null : _confirmFinish,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: _finishing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          'Finalizar',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.onPrimary),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Con el descanso corriendo se oculta -- el banner ocupa ese mismo lugar
      // y es lo que importa mirar en ese momento.
      floatingActionButton: _restEndsAt != null
          ? null
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                boxShadow: AppGlow.primary,
              ),
              child: FloatingActionButton.extended(
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Agregar ejercicio'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                ),
              ),
            ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.timer_outlined,
                        color: AppColors.secondary,
                        label: 'Duración',
                        value: _formatElapsed(_elapsed),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatTile(
                        icon: Icons.bar_chart,
                        color: AppColors.primary,
                        label: 'Volumen',
                        value: formatWeight(
                          liveVolumeKg,
                          weightUnit,
                          decimals: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatTile(
                        icon: Icons.format_list_numbered,
                        color: AppColors.tertiary,
                        label: 'Series',
                        value: '$liveSetCount',
                      ),
                    ),
                  ],
                ),
              ),
              if (_newRecords != null && _newRecords!.isNotEmpty)
                _RecordBanner(
                  records: _newRecords!,
                  onDismiss: () => setState(() => _newRecords = null),
                ),
              Expanded(
                child: exercisesInSession.isEmpty
                    ? const Center(
                        child: Text(
                          'Agregá un ejercicio para empezar a registrar series.',
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          120,
                        ),
                        children: orderedEntries.map((entry) {
                          final exercise = entry.value;
                          final sets = grouped[entry.key]!;
                          return _ExerciseFocusCard(
                            exercise: exercise,
                            sets: sets,
                            target: _routineTargets[exercise.id],
                            previousSets:
                                _previousSets[exercise.id] ?? const [],
                            onAddSet: () => _addSetFor(exercise, sets),
                            onDeleteSet: (set) async {
                              await _repository.deleteSet(set.id);
                              _load();
                            },
                            onUpdateSet: _updateSetField,
                            onMarkCompleted: () async {
                              await _repository.markExerciseCompleted(
                                widget.sessionId,
                                exercise.id,
                              );
                              _load();
                            },
                            onToggleSetCompleted: _toggleSetCompleted,
                            onEditRest: () => _editExerciseRest(sets),
                            onOpenAdvancedEditor: _openAdvancedEditor,
                            // A4: acciones por ejercicio (reemplazar/
                            // reordenar/eliminar/notas) -- antes solo
                            // existían acciones POR SERIE.
                            onOpenExerciseActions: () => _showExerciseActions(
                              exercise,
                              sets,
                              orderedEntries,
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
          // Barra completa anclada abajo (C5): visible de entrada, no una
          // píldora chica que se pierde entre el resto de la pantalla.
          if (_restEndsAt != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RestTimerBanner(
                endsAt: _restEndsAt!,
                totalSeconds: _restTotalSeconds,
                onDismiss: _dismissRest,
                onAddSeconds: _extendRest,
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordBanner extends StatelessWidget {
  final List<ResolvedRecord> records;
  final VoidCallback onDismiss;

  const _RecordBanner({required this.records, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.secondaryContainer.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 20,
              color: AppColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Récord Personal!',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.secondary),
                ),
                for (final r in records)
                  Text(
                    '${recordTypeLabels[r.recordType] ?? r.recordType}: ${r.value}'
                    '${r.previousValue != null ? ' (antes: ${r.previousValue})' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.onSurfaceVariant,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

typedef _SetFieldUpdate =
    Future<void> Function(WorkoutSet set, String field, num value);

class _ExerciseFocusCard extends StatelessWidget {
  final ExerciseSummary exercise;
  final List<WorkoutSet> sets;
  // C4: objetivo de la rutina para este ejercicio, si la sesión viene de una.
  final RoutineExercise? target;
  // A2: todas las series de la última sesión de este ejercicio -- alimenta
  // la columna "ANTERIOR" (serie 1 contra serie 1, no un valor suelto).
  final List<WorkoutSet> previousSets;
  final VoidCallback onAddSet;
  final ValueChanged<WorkoutSet> onDeleteSet;
  final _SetFieldUpdate onUpdateSet;
  final VoidCallback onMarkCompleted;
  final ValueChanged<WorkoutSet> onToggleSetCompleted;
  final VoidCallback onEditRest;
  final ValueChanged<WorkoutSet> onOpenAdvancedEditor;
  final VoidCallback onOpenExerciseActions;

  const _ExerciseFocusCard({
    required this.exercise,
    required this.sets,
    this.target,
    this.previousSets = const [],
    required this.onAddSet,
    required this.onDeleteSet,
    required this.onUpdateSet,
    required this.onMarkCompleted,
    required this.onToggleSetCompleted,
    required this.onEditRest,
    required this.onOpenAdvancedEditor,
    required this.onOpenExerciseActions,
  });

  /// A2: serie de la sesión anterior que corresponde a este número de serie
  /// (serie 1 contra serie 1), o `null` si esa serie no existía la vez
  /// pasada (ejercicio nuevo en la rutina, o esta vez se hicieron más
  /// series que la anterior).
  WorkoutSet? _previousFor(int setNumber) {
    for (final s in previousSets) {
      if (s.setNumber == setNumber) return s;
    }
    return null;
  }

  bool get _completed => sets.every((s) => s.completed);

  double get _volumeKg => sets
      .where((s) => !s.isWarmup)
      .fold(0.0, (sum, s) => sum + s.weightKg * s.reps);

  double get _maxWeightKg =>
      sets.fold(0.0, (max, s) => s.weightKg > max ? s.weightKg : max);

  // Descanso objetivo entre series de este ejercicio -- lo trae la primera
  // serie (`_quickAddSet`/rutina lo cargan igual para todas por defecto; el
  // editor avanzado permite customizarlo serie por serie).
  int get _restSeconds => sets.isEmpty ? 90 : (sets.first.restSeconds ?? 90);

  /// Prioridad: resumen si ya está completo -> objetivo de la rutina (C4) ->
  /// grupo muscular como último recurso. A2: la rama "última vez" (C6) se
  /// eliminó de acá -- ahora vive por serie en la columna "ANTERIOR" de la
  /// tabla, que es donde se toma la decisión (serie 1 contra serie 1, no un
  /// valor suelto en el encabezado que había que recordar).
  String _subtitle(WeightUnit weightUnit) {
    if (_completed) {
      return '${sets.length} series · Volumen: '
          '${formatWeight(_volumeKg, weightUnit, decimals: 0)} · '
          'Máx: ${formatWeight(_maxWeightKg, weightUnit)}';
    }
    final target = this.target;
    if (target != null) {
      return 'Objetivo: ${target.targetSets}×'
          '${target.targetRepsMin}-${target.targetRepsMax}';
    }
    return exercise.muscleGroup;
  }

  @override
  Widget build(BuildContext context) {
    final color = muscleGroupColors[exercise.muscleGroup] ?? Colors.grey;
    final completed = _completed;
    final accent = completed ? AppColors.secondary : color;
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: accent.withValues(alpha: completed ? 0.4 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                ExerciseThumb(
                  slug: exercise.slug,
                  color: color,
                  muscleGroup: exercise.muscleGroup,
                  size: 44,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _subtitle(weightUnit),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: completed
                                        ? AppColors.secondary
                                        : AppColors.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Tocable: cambia el descanso de TODAS las series de
                          // este ejercicio (pedido explícito -- antes era
                          // solo texto y `targetRestSeconds` de la rutina se
                          // ignoraba, así que el descanso siempre arrancaba
                          // en 90s aunque el usuario haya puesto otro valor).
                          Tooltip(
                            message: 'Editar descanso entre series',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              onTap: onEditRest,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 12,
                                      color: AppColors.onSurfaceVariant
                                          .withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${_restSeconds}s',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppColors.onSurfaceVariant
                                                .withValues(alpha: 0.7),
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: AppColors
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: completed
                        ? AppColors.secondary.withValues(alpha: 0.15)
                        : AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: completed ? AppGlow.secondary : null,
                  ),
                  child: IconButton(
                    tooltip: completed
                        ? 'Ejercicio completado'
                        : 'Marcar como completado',
                    icon: Icon(
                      completed
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: completed
                          ? AppColors.secondary
                          : AppColors.onSurfaceVariant,
                    ),
                    onPressed: completed ? null : onMarkCompleted,
                  ),
                ),
                // A4: acciones por ejercicio (reemplazar/reordenar/
                // eliminar/notas) -- antes agregar un ejercicio por error
                // obligaba a borrar sus series una por una con el swipe.
                // Tap target angosto (no el IconButton de 48dp por defecto):
                // a 320dp+200% de escala de texto, sumado al ícono de
                // completado, desbordaba la fila por unos pocos px (D4).
                SizedBox(
                  width: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Más acciones del ejercicio',
                    icon: const Icon(Icons.more_vert, size: 20),
                    color: AppColors.onSurfaceVariant,
                    onPressed: onOpenExerciseActions,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.outlineVariant),
                bottom: BorderSide(color: AppColors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 34),
                _headerCell(context, 'SET'),
                // A2: peso × reps de ESA MISMA serie la última vez -- serie 1
                // contra serie 1, no un valor suelto en el encabezado (que
                // se eliminó, ver `_subtitle`).
                _headerCell(context, 'ANTERIOR'),
                _headerCell(context, weightUnit.label.toUpperCase()),
                _headerCell(context, 'REPS'),
                _headerCell(context, 'RPE'),
                const SizedBox(width: 32),
              ],
            ),
          ),
          for (final set in sets)
            Dismissible(
              key: ValueKey('set-${set.id}'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onDeleteSet(set),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.dangerContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    // Check por serie (C5): tocar el círculo marca la serie
                    // completada Y arranca el descanso -- es el elemento más
                    // grande y accesible de la fila, no un ícono aparte.
                    SizedBox(
                      width: 34,
                      child: Center(
                        child: Tooltip(
                          message: set.completed
                              ? 'Serie completada'
                              : 'Marcar serie y empezar descanso'
                                    '${set.restSeconds != null ? ' (${set.restSeconds}s)' : ''}',
                          child: InkWell(
                            key: ValueKey('set-check-${set.id}'),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            onTap: () => onToggleSetCompleted(set),
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: set.completed
                                    ? AppColors.secondary
                                    : (set.isWarmup
                                          ? Colors.transparent
                                          : AppColors.surfaceContainerHighest),
                                shape: BoxShape.circle,
                                border: !set.completed && set.isWarmup
                                    ? Border.all(color: AppColors.outline)
                                    : null,
                                boxShadow: set.completed
                                    ? AppGlow.secondary
                                    : null,
                              ),
                              child: set.completed
                                  ? const Icon(
                                      Icons.check,
                                      size: 18,
                                      color: AppColors.onSecondary,
                                    )
                                  : Text(
                                      '${set.setNumber}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // A2: peso × reps de esta MISMA serie (por número) la
                    // última vez -- no editable, solo referencia para
                    // comparar de un vistazo mientras se entrena.
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final previous = _previousFor(set.setNumber);
                          return Text(
                            previous == null
                                ? '-'
                                : '${formatWeight(previous.weightKg, weightUnit, decimals: 0)} × ${previous.reps}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.onSurfaceVariant),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: StepperField(
                        value: kgToDisplay(set.weightKg, weightUnit),
                        decimals: 1,
                        step: weightUnit == WeightUnit.kg ? 2.5 : 5.0,
                        fieldLabel: 'peso',
                        onChanged: (v) => onUpdateSet(
                          set,
                          'weight_kg',
                          displayToKg(v, weightUnit),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: StepperField(
                        value: set.reps.toDouble(),
                        fieldLabel: 'repeticiones',
                        onChanged: (v) => onUpdateSet(set, 'reps', v.round()),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: StepperField(
                        value: set.rpe ?? 0,
                        decimals: 1,
                        step: 0.5,
                        fieldLabel: 'RPE',
                        onChanged: (v) => onUpdateSet(set, 'rpe', v),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    SizedBox(
                      width: 32,
                      height: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Más opciones (RPE, RIR, técnicas, notas)',
                        icon: const Icon(Icons.tune, size: 18),
                        color: AppColors.onSurfaceVariant,
                        onPressed: () => onOpenAdvancedEditor(set),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Material(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: onAddSet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      // D4: sin `Flexible` acá, el texto escalado al 200%
                      // (accesibilidad) pedía más ancho del que el Row tenía
                      // disponible y desbordaba -- ver test de 320dp.
                      Flexible(
                        child: Text(
                          'Añadir serie',
                          style: Theme.of(context).textTheme.labelLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(BuildContext context, String label) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}
