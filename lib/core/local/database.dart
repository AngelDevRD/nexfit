import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// Catálogo de ejercicios: semilla local de solo lectura (se carga desde
// assets/data/exercises.json en el primer arranque). El `id` es estable y
// coincide con el del catálogo del backend.
class Exercises extends Table {
  IntColumn get id => integer()();
  TextColumn get slug => text()();
  TextColumn get name => text()();
  TextColumn get muscleGroup => text()();
  TextColumn get difficulty => text()();
  TextColumn get imageUrl => text().nullable()();
  // Resto de campos (músculos, equipo, instrucciones, tips…) como JSON.
  TextColumn get detailJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

// Raíz de agregado -> lleva metadata de sync.
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get goal => text().nullable()();
  IntColumn get daysPerWeek => integer().withDefault(const Constant(3))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

class RoutineDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get dayIndex => integer()();
  TextColumn get name => text()();
  TextColumn get muscleFocus => text().nullable()();
}

class RoutineExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayId =>
      integer().references(RoutineDays, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer()();
  IntColumn get orderIndex => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetRepsMin => integer().withDefault(const Constant(8))();
  IntColumn get targetRepsMax => integer().withDefault(const Constant(12))();
  IntColumn get targetRestSeconds =>
      integer().withDefault(const Constant(90))();
  TextColumn get notes => text().nullable()();
}

// Raíz de agregado -> lleva metadata de sync.
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get routineId => integer().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  // Id del set en el backend, una vez sincronizado. Null mientras el set
  // solo existe local (todavía no viajó al servidor).
  IntColumn get serverId => integer().nullable()();
  IntColumn get exerciseId => integer()();
  IntColumn get setNumber => integer()();
  RealColumn get weightKg => real().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  RealColumn get rpe => real().nullable()();
  IntColumn get rir => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  TextColumn get techniques => text().withDefault(const Constant('[]'))();
  IntColumn get supersetGroupId => integer().nullable()();
  TextColumn get tempo => text().nullable()();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

class PersonalRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().nullable()();
  TextColumn get recordType => text()();
  RealColumn get value => real()();
  RealColumn get previousValue => real().nullable()();
  DateTimeColumn get achievedAt => dateTime()();
}

// Cola de operaciones pendientes sobre sets de una sesión ya sincronizada
// (serverId != null). Evita re-enviar el árbol completo de la sesión en cada
// sync: el SyncEngine drena esta cola set por set contra el backend.
class PendingSetOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get localSetId => integer().nullable()();
  IntColumn get serverSetId => integer().nullable()();
  // 'insert' | 'update' | 'delete'
  TextColumn get op => text()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    Exercises,
    Routines,
    RoutineDays,
    RoutineExercises,
    WorkoutSessions,
    WorkoutSets,
    PersonalRecords,
    PendingSetOps,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'nexfit'));

  // Para tests: base en memoria u otra conexión.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(pendingSetOps);
      }
      if (from < 3) {
        await m.addColumn(workoutSets, workoutSets.serverId);
      }
    },
  );
}
