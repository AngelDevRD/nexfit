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
  // uuid de Supabase una vez sincronizada (era IntColumn cuando el destino
  // era el id serial de FastAPI -- ver docs/ARQUITECTURA_BACKEND.md Fase 2).
  TextColumn get serverId => text().nullable()();
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
  // Peso objetivo planificado (kg). Null = sin objetivo definido.
  RealColumn get targetWeightKg => real().nullable()();
  // Tipo de serie planificado: 'normal' | 'superset' | 'dropset' | 'giant_set'
  // | 'myo_reps' | 'rest_pause' | 'warm_up' | 'back_off' | 'failure'. Es el
  // tipo *planeado* del ejercicio en la rutina; distinto de
  // `WorkoutSets.techniques`, que registra lo *ejecutado*.
  TextColumn get setType => text().withDefault(const Constant('normal'))();
  TextColumn get tempo => text().nullable()();
  RealColumn get targetRpe => real().nullable()();
  IntColumn get targetRir => integer().nullable()();
  TextColumn get notes => text().nullable()();
}

// Raíz de agregado -> lleva metadata de sync.
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  IntColumn get routineId => integer().nullable()();
  // Nombre del entrenamiento (ej. "Viernes pierna volumen"). Lo trae el export
  // de Hevy en la columna `title`; null para sesiones creadas a mano.
  TextColumn get title => text().nullable()();
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
  // Id (uuid) del set en Supabase, una vez sincronizado. Null mientras el set
  // solo existe local (todavía no viajó al servidor).
  TextColumn get serverId => text().nullable()();
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

// Bitácora de récords personales: UNA fila por cada vez que un set superó el
// máximo previo del ejercicio (progresión). No es única por (ejercicio, tipo)
// a propósito -> la serie temporal alimenta `recordPrediction` (regresión
// lineal sobre la progresión). Para mostrar "el récord vigente" se agrupa al
// máximo por ejercicio en la capa de presentación, no se colapsa la historia.
//
// El bug que se corrige (docs/PLAN_ENTRENAMIENTO_V2.md §0.2) no eran las filas
// en sí, sino que al importar quedaban con `achievedAt = ahora` y por eso
// `sessionRecords` (que filtraba por fecha) las colgaba todas de la última
// sesión. Ahora `achievedAt` es la fecha real de la sesión y `sessionId`
// referencia la sesión donde se logró.
class PersonalRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().nullable()();
  IntColumn get sessionId => integer().nullable()();
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
  TextColumn get serverSetId => text().nullable()();
  // 'insert' | 'update' | 'delete'
  TextColumn get op => text()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Perfil del usuario autenticado (Fase 2). Fila única por usuario, `id` =
// mismo texto que `AuthRepository.currentUser.id` (uuid de Supabase Auth) --
// a diferencia de Routines/WorkoutSessions, acá el "serverId" siempre se
// conoce desde el principio (es el propio id del usuario logueado), no hace
// falta esperar una respuesta del servidor para tener uno.
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get age => integer().nullable()();
  TextColumn get sex => text().nullable()();
  RealColumn get heightCm => real().nullable()();
  RealColumn get weightKg => real().nullable()();
  RealColumn get bodyFatPct => real().nullable()();
  TextColumn get goal => text().nullable()();
  TextColumn get experienceLevel => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get metric => text()();
  IntColumn get exerciseId => integer().nullable()();
  RealColumn get startingValue => real()();
  RealColumn get targetValue => real()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  DateTimeColumn get achievedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

// Un registro por día (clave natural = fecha) -> upsert, no create-or-delete
// como Routines.
class NutritionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  DateTimeColumn get logDate => dateTime()();
  RealColumn get calories => real().withDefault(const Constant(0))();
  RealColumn get proteinG => real().withDefault(const Constant(0))();
  RealColumn get carbsG => real().withDefault(const Constant(0))();
  RealColumn get fatG => real().withDefault(const Constant(0))();
  RealColumn get waterMl => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

// Recovery: check-ins diarios (sleep/fatiga). Un registro por día.
class DailyCheckins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  DateTimeColumn get checkinDate => dateTime()();
  RealColumn get sleepHours => real()();
  IntColumn get perceivedFatigue => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

// Historial de medidas corporales (peso, % grasa, circunferencias). Un
// registro por día, cargado a mano o importado desde un CSV externo
// (Hevy/Renpho). Solo local por ahora -- sin `dirty`/`serverId` porque no
// sincroniza con Supabase todavía; si se agrega sync despues, seguir el
// patron de `DailyCheckins`/`RecoverySyncable` via `ALTER TABLE`.
class BodyMeasurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get measuredAt => dateTime()();
  RealColumn get weightKg => real().nullable()();
  RealColumn get fatPercent => real().nullable()();
  RealColumn get neckCm => real().nullable()();
  RealColumn get shoulderCm => real().nullable()();
  RealColumn get chestCm => real().nullable()();
  RealColumn get leftBicepCm => real().nullable()();
  RealColumn get rightBicepCm => real().nullable()();
  RealColumn get leftForearmCm => real().nullable()();
  RealColumn get rightForearmCm => real().nullable()();
  RealColumn get abdomenCm => real().nullable()();
  RealColumn get waistCm => real().nullable()();
  RealColumn get hipsCm => real().nullable()();
  RealColumn get leftThighCm => real().nullable()();
  RealColumn get rightThighCm => real().nullable()();
  RealColumn get leftCalfCm => real().nullable()();
  RealColumn get rightCalfCm => real().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
}

// Borrador del entrenamiento en curso: fila única (id fijo = 1) que persiste
// el estado de la UI de la sesión activa para poder restaurarla tal cual tras
// cerrar/reabrir la app. NO es la fuente de verdad de la duración ni del
// descanso: esos se derivan siempre de timestamps absolutos
// (`WorkoutSessions.startedAt`, `restEndsAt`), nunca de un contador. Acá solo
// vive lo que el usuario tipeó y no está todavía guardado como set.
class ActiveWorkoutDrafts extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get sessionId => integer()();
  IntColumn get currentExerciseId => integer().nullable()();
  IntColumn get currentSetNumber => integer().nullable()();
  // Instante en que termina el descanso en curso (absoluto). Null = sin
  // descanso activo. El widget solo repinta; el cálculo es `restEndsAt - now`.
  DateTimeColumn get restEndsAt => dateTime().nullable()();
  // Valores tipeados aún no persistidos como set (pesos, reps, notas,
  // supersets, dropsets) serializados como JSON. Esquema libre: es un
  // borrador de UI, no un modelo de dominio sincronizable.
  TextColumn get draftJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
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
    Profiles,
    Goals,
    NutritionLogs,
    DailyCheckins,
    BodyMeasurements,
    ActiveWorkoutDrafts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'appgym'));

  // Para tests: base en memoria u otra conexión.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

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
      if (from < 4) {
        // Fase 2 (ver docs/ARQUITECTURA_BACKEND.md): el destino de sync pasa
        // de FastAPI (ids int) a Supabase (ids uuid). Los serverId viejos
        // apuntaban a filas que ya no existen en el esquema nuevo, así que no
        // hay nada que preservar ahí -- se descartan explícitamente (columna
        // recreada como texto, valor forzado a null) y se remarca todo como
        // dirty para que el SyncEngine lo vuelva a subir contra las tablas
        // nuevas. Los datos de negocio (nombres, sets, reps, fechas) no se
        // tocan -- solo se pierde el enlace viejo con un backend que ya no
        // existe.
        await m.alterTable(
          TableMigration(
            routines,
            columnTransformer: {routines.serverId: const Constant(null)},
          ),
        );
        await m.alterTable(
          TableMigration(
            workoutSessions,
            columnTransformer: {workoutSessions.serverId: const Constant(null)},
          ),
        );
        await m.alterTable(
          TableMigration(
            workoutSets,
            columnTransformer: {workoutSets.serverId: const Constant(null)},
          ),
        );
        await m.alterTable(
          TableMigration(
            pendingSetOps,
            columnTransformer: {
              pendingSetOps.serverSetId: const Constant(null),
            },
          ),
        );
        await m.createTable(profiles);
        await m.createTable(goals);
        await m.createTable(nutritionLogs);
        await m.createTable(dailyCheckins);
        await customStatement('UPDATE routines SET dirty = 1');
        await customStatement('UPDATE workout_sessions SET dirty = 1');
      }
      if (from < 5) {
        await m.createTable(bodyMeasurements);
      }
      if (from < 6) {
        // Sistema de entrenamiento v2 (ver docs/PLAN_ENTRENAMIENTO_V2.md).
        await m.addColumn(workoutSessions, workoutSessions.title);
        await m.addColumn(routineExercises, routineExercises.targetWeightKg);
        await m.addColumn(routineExercises, routineExercises.setType);
        await m.addColumn(routineExercises, routineExercises.tempo);
        await m.addColumn(routineExercises, routineExercises.targetRpe);
        await m.addColumn(routineExercises, routineExercises.targetRir);
        await m.createTable(activeWorkoutDrafts);
        // `PersonalRecords` viejo está contaminado (una fila por cada
        // progresión histórica, todas con `achievedAt` = momento de la
        // importación) y no tiene la clave única ni `sessionId`. No se puede
        // deduplicar preservando la verdad histórica -> se descarta y se
        // recrea vacío con el esquema nuevo. `PersonalRecordsService.rebuildAll`
        // (Fase 2) lo repuebla replayando los sets en orden cronológico.
        await m.deleteTable('personal_records');
        await m.createTable(personalRecords);
      }
    },
  );
}
