// T-C1 revisión 1 -- Tests escritos por el SUPERVISOR (Opus) tras auditar la
// primera implementación. Caso real: con Supabase, `login()` llama a
// `prepareForUser` y el evento `signedIn` de `authStateChanges` lo llama OTRA
// vez casi al mismo tiempo. Si la primera llamada en terminar marca la cuenta
// como "lista" mientras la otra todavía va a limpiar la base, el sync puede
// correr en esa ventana y los datos nuevos de la cuenta se pueden borrar.
// Invariante: `isReadyFor` nunca es verdadero mientras quede una preparación
// pendiente, y una misma cuenta no se limpia dos veces.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'package:appgym/core/auth/account_data_guard.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _insertRoutine(local.AppDatabase db, String name) => db
    .into(db.routines)
    .insert(
      local.RoutinesCompanion.insert(name: name, updatedAt: DateTime.now()),
    );

Future<int> _routineCount(local.AppDatabase db) async =>
    (await db.select(db.routines).get()).length;

void main() {
  late local.AppDatabase db;
  late AccountDataGuard guard;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    guard = AccountDataGuard(db);
    await guard.prepareForUser('id-a');
    await _insertRoutine(db, 'Rutina de A');
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'dos preparaciones concurrentes de la misma cuenta: no queda "lista" con otra pendiente',
    () async {
      var secondDone = false;
      final first = guard.prepareForUser('id-b');
      final second = guard.prepareForUser('id-b').then((wiped) {
        secondDone = true;
        return wiped;
      });

      await first;
      if (guard.isReadyFor('id-b')) {
        expect(
          secondDone,
          isTrue,
          reason:
              'isReadyFor(id-b) es true pero la segunda preparación sigue '
              'pendiente: el sync podría correr y la base volver a limpiarse',
        );
      }

      await second;
      expect(guard.isReadyFor('id-b'), isTrue);
    },
  );

  test(
    'datos creados por la cuenta nueva apenas queda lista no se borran por una preparación duplicada',
    () async {
      final first = guard.prepareForUser('id-b');
      final second = guard.prepareForUser('id-b');

      await first;
      await second;
      expect(guard.isReadyFor('id-b'), isTrue);
      await _insertRoutine(db, 'Rutina de B');

      // Una tercera notificación de la MISMA cuenta (p. ej. renovación de
      // token) no debe limpiar nada.
      expect(await guard.prepareForUser('id-b'), isFalse);
      expect(await _routineCount(db), 1);
    },
  );

  test(
    'la misma cuenta limpia una sola vez aunque se prepare en paralelo',
    () async {
      final results = await Future.wait([
        guard.prepareForUser('id-b'),
        guard.prepareForUser('id-b'),
        guard.prepareForUser('id-b'),
      ]);

      expect(
        results.where((wiped) => wiped),
        hasLength(1),
        reason: 'la base de A se limpia una vez; las otras llamadas ya ven a B',
      );
      expect(await _routineCount(db), 0);
    },
  );

  test(
    'preparaciones concurrentes de cuentas distintas: gana la última y ninguna queda lista antes de tiempo',
    () async {
      var secondDone = false;
      final forB = guard.prepareForUser('id-b');
      final forC = guard.prepareForUser('id-c').then((wiped) {
        secondDone = true;
        return wiped;
      });

      await forB;
      if (!secondDone) {
        expect(guard.isReadyFor('id-b'), isFalse);
        expect(guard.isReadyFor('id-c'), isFalse);
      }

      await forC;
      expect(guard.isReadyFor('id-c'), isTrue);
      expect(guard.isReadyFor('id-b'), isFalse);
      expect(await _routineCount(db), 0);

      // Tras reiniciar, la última cuenta recordada es C.
      final afterRestart = AccountDataGuard(db);
      expect(await afterRestart.prepareForUser('id-c'), isFalse);
    },
  );
}
