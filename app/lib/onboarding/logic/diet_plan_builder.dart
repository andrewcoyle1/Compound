import 'dart:math';

import 'package:body_repository/body_repository.dart';
import 'package:compound/onboarding/logic/body_units.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

/// The diet answers (`DietPlanDelegate`). The floor is always the standard
/// one: onboarding applies it without asking (Swift decision 3b).
typedef DietChoices = ({
  maths.PreferredDiet diet,
  maths.CalorieDistribution distribution,
  maths.ProteinIntake protein,
});

/// The only calorie floor, as stored (`CalorieFloor.standard`).
const standardCalorieFloor = 'standard';

/// Training days in [mesocycle]'s week: its day plans with exercises
/// (`CalorieDistribution.trainingDays`).
int trainingDays(Mesocycle mesocycle) =>
    mesocycle.workoutTemplates.where((day) => day.exercises.isNotEmpty).length;

/// Even for three training days or fewer (or no mesocycle), varied from
/// four (`CalorieDistribution.recommended`).
maths.CalorieDistribution recommendedDistribution(Mesocycle? mesocycle) =>
    (mesocycle == null ? 0 : trainingDays(mesocycle)) <= 3
    ? maths.CalorieDistribution.even
    : maths.CalorieDistribution.varied;

/// "Use Recommended Plan": a balanced diet, the split the mesocycle
/// suggests and moderate protein
/// (`CustomisingDietProgramPresenter.onUseRecommendedPlanPressed`).
DietChoices recommendedDietChoices(Mesocycle? mesocycle) => (
  diet: maths.PreferredDiet.balanced,
  distribution: recommendedDistribution(mesocycle),
  protein: maths.ProteinIntake.moderate,
);

maths.Gender? _gender(UserModel user) =>
    maths.Gender.tryParse(user.submittedGender?.value);

int? _age(UserModel user, DateTime now) => switch (user.submittedDateOfBirth) {
  null => null,
  final dob => max(14, wholeYears(dob, now)),
};

/// The formula expenditure `NutritionManager.estimateTDEE` works out for
/// [user] (Mifflin-St Jeor; onboarding has no body fat or settings yet).
double formulaExpenditure(UserModel user, {required DateTime now}) =>
    maths.estimateTdee(
      gender: _gender(user),
      weightKg: user.submittedWeightKilograms,
      heightCm: user.submittedHeightCentimeters,
      ageYears: _age(user, now),
      activity: maths.ActivityLevel.tryParse(
        user.submittedDailyActivityLevel?.value,
      ),
    );

/// The resting part of [formulaExpenditure], for the plan screen's
/// below-resting warning (`estimateRestingKcal`).
double formulaRestingKcal(UserModel user, {required DateTime now}) {
  double clamped(double? value, double low, double high, double fallback) {
    final v = value ?? fallback;
    return v.isFinite ? v.clamp(low, high) : fallback;
  }

  final gender = _gender(user) ?? maths.Gender.preferNotToSay;
  return 10 * clamped(user.submittedWeightKilograms, 30, 500, 70) +
      6.25 * clamped(user.submittedHeightCentimeters, 120, 260, 175) -
      5 * (_age(user, now) ?? 30) +
      gender.mifflinStJeorCoefficient;
}

String _trainingFocus(ExerciseFrequency? frequency) =>
    switch (frequency ?? ExerciseFrequency.threeToFour) {
      ExerciseFrequency.never => 'none',
      ExerciseFrequency.oneToTwo => 'light',
      ExerciseFrequency.threeToFour => 'moderate',
      ExerciseFrequency.fiveToSix => 'frequent',
      ExerciseFrequency.daily => 'daily',
    };

/// The diet plan `NutritionManager.computeDietPlan` builds from the formula
/// expenditure, the active [goal] (only an active one counts) and the
/// active [mesocycle]'s training days. Its id is the user's: that is where
/// the plan is read from, and the rules refuse any other.
DietPlan buildDietPlan({
  required UserModel user,
  required DietChoices choices,
  required DateTime now,
  WeightGoal? goal,
  Mesocycle? mesocycle,
}) {
  final tdee = formulaExpenditure(user, now: now);
  final active = goal != null && goal.status == GoalStatus.active ? goal : null;
  final days = maths.dietPlanDays(
    expenditureKcal: tdee,
    diet: choices.diet,
    distribution: choices.distribution,
    protein: choices.protein,
    goalWeeklyChangeKg: active == null
        ? null
        : maths.signedWeeklyChangeKg(
            startingWeightKg: active.startingWeightKg,
            targetWeightKg: active.targetWeightKg,
            weeklyChangeKg: active.weeklyChangeKg,
          ),
    goalWeightKg: active?.targetWeightKg,
    gender: _gender(user),
    weightKg: user.submittedWeightKilograms,
    heightCm: user.submittedHeightCentimeters,
    ageYears: _age(user, now),
    trainingDaysPerWeek: mesocycle == null ? 0 : trainingDays(mesocycle),
  );
  return DietPlan(
    planId: user.userId,
    userId: user.userId,
    createdAt: now,
    tdeeEstimate: tdee.roundToDouble(),
    preferredDiet: choices.diet.name,
    calorieFloor: standardCalorieFloor,
    trainingType:
        mesocycle?.name ?? _trainingFocus(user.submittedExerciseFrequency),
    calorieDistribution: choices.distribution.name,
    proteinIntake: choices.protein.name,
    days: [
      for (final day in days)
        DailyMacroTarget(
          calories: day.calories,
          proteinGrams: day.proteinGrams,
          carbGrams: day.carbGrams,
          fatGrams: day.fatGrams,
        ),
    ],
  );
}
