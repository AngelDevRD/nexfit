// T-C1 (cierre del gate de cobertura) -- Tests escritos por el SUPERVISOR
// (Opus): intervalo de respaldo del SyncEngine y registro de errores.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'package:appgym/core/local/database.dart';
import 'package:appgym/core/sync/sync_engine.dart';
import 'package:appgym/core/sync/syncable.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingEntity implements SyncableEntity {
  _CountingEntity({this.fail = false});

  bool fail;
  int pushCount = 0;

  @override
  String get name => 'counting';

  @override
  Future<void> push(AppDatabase db) async {
    pushCount++;
    if (fail) throw Exception('sin red');
  }
}

void main() {
  test('updateInterval programa pasadas periódicas con el nuevo intervalo', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final entity = _CountingEntity();
    final engine = SyncEngine(
      db: db,
      entities: [entity],
      backupInterval: const Duration(hours: 3),
    );

    engine.updateInterval(const Duration(milliseconds: 40));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(engine.backupInterval, const Duration(milliseconds: 40));
    expect(entity.pushCount, greaterThanOrEqualTo(2));

    engine.dispose();
    final afterDispose = entity.pushCount;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(entity.pushCount, afterDispose, reason: 'dispose cancela el timer');
    await db.close();
  });

  test('updateInterval con el mismo intervalo no programa nada', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final entity = _CountingEntity();
    final engine = SyncEngine(
      db: db,
      entities: [entity],
      backupInterval: const Duration(milliseconds: 40),
    );

    engine.updateInterval(const Duration(milliseconds: 40));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(entity.pushCount, 0, reason: 'sin start() ni cambio real no hay timer');
    engine.dispose();
    await db.close();
  });

  test('lastError registra la falla y se limpia en la siguiente pasada sana', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final entity = _CountingEntity(fail: true);
    final engine = SyncEngine(db: db, entities: [entity]);

    await engine.syncNow();
    expect(engine.lastError, contains('counting'));
    expect(engine.lastErrorAt, isNotNull);

    entity.fail = false;
    await engine.syncNow();
    expect(engine.lastError, isNull);

    engine.dispose();
    await db.close();
  });
}
