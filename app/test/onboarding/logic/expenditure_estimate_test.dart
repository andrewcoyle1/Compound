import 'package:compound/onboarding/logic/expenditure_estimate.dart';
import 'package:compound_models/compound_models.dart' show UserModelKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

/// Mirrors `OnboardingExpenditurePresenterTests`.
void main() {
  final now = DateTime(2026, 10, 15);
  AccountAnswers answers({
    double weight = 80,
    double height = 180,
    DateTime? dateOfBirth,
    Gender gender = Gender.male,
    ActivityLevel activity = ActivityLevel.moderate,
  }) => (
    gender: gender,
    dateOfBirth: dateOfBirth ?? DateTime(1996, 10, 15),
    heightCentimetres: height,
    lengthUnit: LengthUnitPreference.centimeters,
    weightKilograms: weight,
    weightUnit: WeightUnitPreference.kilograms,
    exerciseFrequency: ExerciseFrequency.threeToFour,
    activityLevel: activity,
  );

  group('expenditureBreakdown', () {
    test('is Mifflin-St Jeor times the PAL, the parts adding up', () {
      // 10·80 + 6.25·180 − 5·30 + 5 = 1780; × 1.7 = 3026.
      final figures = expenditureBreakdown(answers(), now: now);
      expect(figures.totalKcal, 3026);
      expect(figures.restingKcal, 1780);
      expect(figures.digestionKcal, 303);
      expect(figures.activityKcal, 3026 - 1780 - 303);
      expect(figures.activityMultiplier, 1.7);
    });

    test('clamps the inputs as the Swift screen does', () {
      final tiny = expenditureBreakdown(
        answers(weight: 10, height: 50, dateOfBirth: DateTime(2020)),
        now: now,
      );
      final clamped = expenditureBreakdown(
        answers(weight: 30, height: 100, dateOfBirth: DateTime(2012)),
        now: now,
      );
      expect(tiny, clamped);
      final unusable = expenditureBreakdown(
        answers(weight: double.nan, height: double.infinity),
        now: now,
      );
      expect(
        unusable,
        expenditureBreakdown(answers(weight: 30, height: 100), now: now),
      );
    });

    test('never shows less than the 1,000 kcal minimum', () {
      final figures = expenditureBreakdown(
        answers(
          weight: 30,
          height: 100,
          dateOfBirth: DateTime(1906),
          gender: Gender.female,
          activity: ActivityLevel.sedentary,
        ),
        now: now,
      );
      expect(figures.totalKcal, 1000);
      expect(
        figures.restingKcal + figures.activityKcal + figures.digestionKcal,
        1000,
      );
    });
  });

  test('accountSetupFields are the eight keys Swift saves, and no more', () {
    final fields = accountSetupFields(answers());
    expect(
      {for (final field in fields) field.key: field.value},
      {
        UserModelKeys.submittedGender: 'male',
        UserModelKeys.submittedDateOfBirth: DateTime(1996, 10, 15),
        UserModelKeys.submittedHeightCentimeters: 180.0,
        UserModelKeys.submittedLengthUnitPreference: 'centimeters',
        UserModelKeys.submittedWeightKilograms: 80.0,
        UserModelKeys.submittedWeightUnitPreference: 'kilograms',
        UserModelKeys.submittedDailyActivityLevel: 'moderate',
        UserModelKeys.submittedExerciseFrequency: '3-4',
      },
    );
  });
}
