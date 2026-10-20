import 'package:body_repository/body_repository.dart';
import 'package:compound/onboarding/logic/diet_plan_builder.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';

/// The pure part of `DietPlanPresenter.createPlan` and
/// `NutritionManager.computeDietPlan`; the arithmetic itself is checked
/// against Swift by compound_maths' `nutrition-parity.json`.
void main() {
  final now = DateTime(2026, 10, 15);
  final user = UserModel(
    userId: 'uid',
    submittedGender: Gender.female,
    submittedDateOfBirth: DateTime(1996, 10, 15),
    submittedHeightCentimeters: 168,
    submittedWeightKilograms: 72,
    submittedDailyActivityLevel: ActivityLevel.moderate,
    submittedExerciseFrequency: ExerciseFrequency.oneToTwo,
  );
  Mesocycle program(String id) =>
      PrebuiltCatalogue.instance.mesocycles.firstWhere((m) => m.id == id);
  WeightGoal goal(GoalStatus status) => WeightGoal(
    goalId: 'g',
    userId: 'uid',
    objective: OverarchingObjective.loseWeight,
    startingWeightKg: 72,
    targetWeightKg: 65,
    weeklyChangeKg: 0.5,
    createdAt: now,
    status: status,
  );
  const choices = (
    diet: maths.PreferredDiet.balanced,
    distribution: maths.CalorieDistribution.even,
    protein: maths.ProteinIntake.moderate,
  );

  test('training days and the recommended split follow the mesocycle', () {
    expect(trainingDays(program('program-upper-lower')), 4);
    expect(trainingDays(program('program-full-body')), 3);
    expect(
      recommendedDistribution(program('program-upper-lower')),
      maths.CalorieDistribution.varied,
    );
    expect(
      recommendedDistribution(program('program-full-body')),
      maths.CalorieDistribution.even,
    );
    expect(recommendedDistribution(null), maths.CalorieDistribution.even);
    expect(recommendedDietChoices(null), choices);
  });

  test('formula expenditure and resting match NutritionManager', () {
    // 10·72 + 6.25·168 − 5·30 − 161 = 1459; × 1.7.
    expect(formulaRestingKcal(user, now: now), 1459);
    expect(formulaExpenditure(user, now: now), closeTo(1459 * 1.7, 1e-9));
    // Nothing known: 70 kg, 175 cm, 30 years, the midpoint, moderate.
    const blank = UserModel(userId: 'x');
    expect(
      formulaRestingKcal(blank, now: now),
      10 * 70 + 6.25 * 175 - 150 - 78,
    );
    expect(
      formulaRestingKcal(
        UserModel(
          userId: 'x',
          submittedWeightKilograms: double.nan,
          submittedDateOfBirth: DateTime(2020),
        ),
        now: now,
      ),
      10 * 70 + 6.25 * 175 - 5 * 14 - 78,
    );
  });

  test('builds the plan under the user id, with the answers as stored', () {
    final plan = buildDietPlan(
      user: user,
      choices: choices,
      now: now,
      goal: goal(GoalStatus.active),
      mesocycle: program('program-upper-lower'),
    );
    final expected = maths.dietPlanDays(
      expenditureKcal: 1459 * 1.7,
      diet: choices.diet,
      distribution: choices.distribution,
      protein: choices.protein,
      goalWeeklyChangeKg: -0.5,
      goalWeightKg: 65,
      gender: maths.Gender.female,
      weightKg: 72,
      heightCm: 168,
      ageYears: 30,
      trainingDaysPerWeek: 4,
    );
    expect(plan.planId, 'uid');
    expect(plan.userId, 'uid');
    expect(plan.createdAt, now);
    expect(plan.tdeeEstimate, (1459 * 1.7).roundToDouble());
    expect(plan.preferredDiet, 'balanced');
    expect(plan.calorieFloor, 'standard');
    expect(plan.calorieDistribution, 'even');
    expect(plan.proteinIntake, 'moderate');
    expect(plan.trainingType, 'Upper/Lower');
    expect(
      [for (final day in plan.days) day.calories],
      [for (final day in expected) day.calories],
    );
    expect(plan.days.first.proteinGrams, expected.first.proteinGrams);
  });

  test('only an active goal counts; without a mesocycle the training '
      'focus comes from the exercise frequency', () {
    final abandoned = buildDietPlan(
      user: user,
      choices: choices,
      now: now,
      goal: goal(GoalStatus.abandoned),
    );
    final none = buildDietPlan(user: user, choices: choices, now: now);
    expect(abandoned.days.first.calories, none.days.first.calories);
    expect(none.trainingType, 'light');
    for (final (frequency, focus) in [
      (null, 'moderate'),
      (ExerciseFrequency.never, 'none'),
      (ExerciseFrequency.threeToFour, 'moderate'),
      (ExerciseFrequency.fiveToSix, 'frequent'),
      (ExerciseFrequency.daily, 'daily'),
    ]) {
      expect(
        buildDietPlan(
          user: UserModel(userId: 'u', submittedExerciseFrequency: frequency),
          choices: choices,
          now: now,
        ).trainingType,
        focus,
      );
    }
  });
}
