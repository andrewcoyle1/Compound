import 'dart:math';

import 'package:compound/onboarding/logic/body_units.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:user_repository/user_repository.dart';

/// The answers account setup collects, saved together on the expenditure
/// screen.
typedef AccountAnswers = ({
  Gender gender,
  DateTime dateOfBirth,
  double heightCentimetres,
  LengthUnitPreference lengthUnit,
  double weightKilograms,
  WeightUnitPreference weightUnit,
  ExerciseFrequency exerciseFrequency,
  ActivityLevel activityLevel,
});

/// The onboarding expenditure screen's figures (`ExpenditurePresenter`),
/// each whole so the three parts add up to the total.
typedef ExpenditureBreakdown = ({
  int totalKcal,
  int restingKcal,
  int activityKcal,
  int digestionKcal,
  double activityMultiplier,
});

/// Mifflin-St Jeor times the activity's PAL, as the onboarding expenditure
/// screen shows it before anything is saved
/// (`ExpenditurePresenter.breakdownItems`): weight clamped to 30–500 kg,
/// height to 100–260 cm (the height wheel reaches 100, so this clamps lower
/// than `NutritionManager`'s 120), age to 14–120 years. Digestion is 10% of
/// the total; activity is what is left above resting.
ExpenditureBreakdown expenditureBreakdown(
  AccountAnswers answers, {
  required DateTime now,
}) {
  double clamped(double value, double low, double high) =>
      value.isFinite ? value.clamp(low, high) : low;
  final weight = clamped(answers.weightKilograms, 30, 500);
  final height = clamped(answers.heightCentimetres, 100, 260);
  final age = wholeYears(answers.dateOfBirth, now).clamp(14, 120);
  final gender = maths.Gender.tryParse(answers.gender.value)!;
  final activity = maths.ActivityLevel.tryParse(answers.activityLevel.value)!;
  final resting =
      10 * weight + 6.25 * height - 5 * age + gender.mifflinStJeorCoefficient;
  final total = max(maths.minimumTotalKcal, resting * activity.multiplier);
  final totalKcal = total.round();
  final restingKcal = min(resting.round(), totalKcal);
  final digestionKcal = min((total * 0.1).round(), totalKcal - restingKcal);
  return (
    totalKcal: totalKcal,
    restingKcal: restingKcal,
    activityKcal: max(totalKcal - restingKcal - digestionKcal, 0),
    digestionKcal: digestionKcal,
    activityMultiplier: activity.multiplier,
  );
}

/// The account-setup answers as the expenditure screen saves them, in one
/// update (`ExpenditurePresenter.swift:185-193`). Cardio fitness is no
/// longer asked, so it isn't written: a profile that has one keeps it.
List<UserFieldValue> accountSetupFields(AccountAnswers answers) => [
  UserField.submittedGender(answers.gender),
  UserField.submittedDateOfBirth(answers.dateOfBirth),
  UserField.submittedHeightCentimeters(answers.heightCentimetres),
  UserField.submittedLengthUnitPreference(answers.lengthUnit),
  UserField.submittedWeightKilograms(answers.weightKilograms),
  UserField.submittedWeightUnitPreference(answers.weightUnit),
  UserField.submittedDailyActivityLevel(answers.activityLevel),
  UserField.submittedExerciseFrequency(answers.exerciseFrequency),
];
