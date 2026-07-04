import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'database.dart';

/// Carga el catálogo de ejercicios (assets/data/exercises.json) en la base
/// local la primera vez. Idempotente: si ya hay ejercicios, no hace nada.
Future<void> seedExercisesIfEmpty(AppDatabase db) async {
  final existing = await db.select(db.exercises).get();
  if (existing.isNotEmpty) return;

  final raw = await rootBundle.loadString('assets/data/exercises.json');
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

  await db.batch((b) {
    b.insertAll(db.exercises, [
      for (final e in list)
        ExercisesCompanion.insert(
          id: Value(e['id'] as int),
          slug: e['slug'] as String,
          name: e['name'] as String,
          muscleGroup: e['muscle_group'] as String,
          difficulty: e['difficulty'] as String,
          imageUrl: Value(e['image_url'] as String?),
          detailJson: Value(
            jsonEncode({
              'primary_muscles': e['primary_muscles'],
              'secondary_muscles': e['secondary_muscles'],
              'equipment': e['equipment'],
              'movement_type': e['movement_type'],
              'description': e['description'],
              'instructions': e['instructions'],
              'tips': e['tips'],
              'common_mistakes': e['common_mistakes'],
              'variants': e['variants'],
              'benefits': e['benefits'],
            }),
          ),
        ),
    ]);
  });
}
