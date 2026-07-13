import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/body_measurement_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late local.AppDatabase db;
  late BodyMeasurementRepository repo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = BodyMeasurementRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsertForDate crea una fila nueva con los campos dados', () async {
    await repo.upsertForDate(DateTime(2026, 2, 11), {
      'weight_kg': 73.48,
      'waist_cm': 81,
    });

    final history = await repo.history();
    expect(history, hasLength(1));
    expect(history.single.measuredAt, DateTime(2026, 2, 11));
    expect(history.single.weightKg, 73.48);
    expect(history.single.waistCm, 81);
    expect(history.single.neckCm, isNull);
  });

  test(
    'upsertForDate en la misma fecha actualiza en vez de duplicar',
    () async {
      await repo.upsertForDate(DateTime(2026, 2, 11), {'weight_kg': 73.0});
      await repo.upsertForDate(DateTime(2026, 2, 11), {'weight_kg': 74.5});

      final history = await repo.history();
      expect(history, hasLength(1));
      expect(history.single.weightKg, 74.5);
    },
  );

  test(
    'upsertForDate no pisa campos ya cargados que no vienen en esta llamada',
    () async {
      await repo.upsertForDate(DateTime(2026, 2, 11), {
        'weight_kg': 73.0,
        'waist_cm': 81,
      });
      await repo.upsertForDate(DateTime(2026, 2, 11), {'fat_percent': 15.2});

      final entry = (await repo.history()).single;
      expect(entry.weightKg, 73.0);
      expect(entry.waistCm, 81);
      expect(entry.fatPercent, 15.2);
    },
  );

  test('history() ordena por fecha descendente', () async {
    await repo.upsertForDate(DateTime(2026, 1, 1), {'weight_kg': 70});
    await repo.upsertForDate(DateTime(2026, 3, 1), {'weight_kg': 72});
    await repo.upsertForDate(DateTime(2026, 2, 1), {'weight_kg': 71});

    final history = await repo.history();
    expect(history.map((e) => e.measuredAt.month), [3, 2, 1]);
  });
}
