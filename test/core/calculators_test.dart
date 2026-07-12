import 'package:appgym/core/calculators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1RM usa Epley por encima de 1 repetición', () {
    expect(Calculators.oneRepMax(100, 1), 100.0);
    expect(Calculators.oneRepMax(100, 10), 133.3);
  });

  test('IMC clasifica en las 4 categorías', () {
    final (bmi, category) = Calculators.bmi(70, 175);
    expect(bmi, 22.9);
    expect(category, 'normal');

    final (_, obesidad) = Calculators.bmi(110, 175);
    expect(obesidad, 'obesidad');
  });

  test('masa magra usa % de grasa cuando está disponible', () {
    expect(Calculators.leanBodyMass(80, 175, 'male', bodyFatPct: 20), 64.0);
  });

  test('masa magra cae a la fórmula Boer sin % de grasa', () {
    final male = Calculators.leanBodyMass(80, 175, 'male');
    final female = Calculators.leanBodyMass(80, 175, 'female');
    expect(male, isNot(equals(female)));
  });

  test('nutrición reparte proteína/grasa/carbos según el objetivo', () {
    final result = Calculators.nutrition(
      weightKg: 80,
      heightCm: 175,
      age: 30,
      sex: 'male',
      activityLevel: 'moderate',
      goal: 'fat_loss',
    );
    expect(result['protein_g'], 176.0); // 2.2 * 80
    expect(result['fat_g'], 64.0); // 0.8 * 80
    expect(result['water_ml'], Calculators.waterIntake(80));
  });

  test('ritmo de pérdida de grasa exige objetivo alcanzable', () {
    final result = Calculators.fatLossRate(90, 80);
    expect(result['weight_to_lose_kg'], 10.0);
    expect(result['min_weekly_loss_kg'], 0.45);
    expect(result['max_weekly_loss_kg'], 0.9);
  });
}
