import 'package:nexfit/core/local/database.dart';
import 'package:nexfit/core/sync/sync_engine.dart';
import 'package:nexfit/core/sync/syncable.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEntity implements SyncableEntity {
  _FakeEntity(this.name, {this.onPush});

  @override
  final String name;

  final Future<void> Function()? onPush;
  int pushCount = 0;

  @override
  Future<void> push(AppDatabase db) async {
    pushCount++;
    await onPush?.call();
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('syncNow corre push() de cada entidad en orden', () async {
    final calls = <String>[];
    final a = _FakeEntity('a', onPush: () async => calls.add('a'));
    final b = _FakeEntity('b', onPush: () async => calls.add('b'));
    final engine = SyncEngine(db: db, entities: [a, b]);

    await engine.syncNow();

    expect(calls, ['a', 'b']);
  });

  test('una entidad que falla no frena a las demás', () async {
    final failing = _FakeEntity(
      'failing',
      onPush: () async => throw Exception('sin red'),
    );
    final ok = _FakeEntity('ok');
    final engine = SyncEngine(db: db, entities: [failing, ok]);

    await engine.syncNow();

    expect(failing.pushCount, 1);
    expect(ok.pushCount, 1);
  });

  test('syncNow concurrente no duplica llamadas (lock _syncing)', () async {
    final entity = _FakeEntity(
      'slow',
      onPush: () => Future.delayed(const Duration(milliseconds: 50)),
    );
    final engine = SyncEngine(db: db, entities: [entity]);

    await Future.wait([engine.syncNow(), engine.syncNow(), engine.syncNow()]);

    expect(entity.pushCount, 1);
  });
}
