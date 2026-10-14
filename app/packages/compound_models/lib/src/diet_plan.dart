import 'package:compound_models/src/firestore_values.dart';

/// Field names of a [DailyMacroTarget]. Swift declares no `CodingKeys`, so
/// these are its camelCase property names.
abstract final class DailyMacroTargetKeys {
  /// `calories`.
  static const calories = 'calories';

  /// `proteinGrams`.
  static const proteinGrams = 'proteinGrams';

  /// `carbGrams`.
  static const carbGrams = 'carbGrams';

  /// `fatGrams`.
  static const fatGrams = 'fatGrams';

  /// Every field, in declaration order.
  static const List<String> all = [calories, proteinGrams, carbGrams, fatGrams];
}

/// One day's calorie and macro targets (Swift `DailyMacroTarget`).
class const DailyMacroTarget({
  /// Calories, in kcal.
  required final double calories,

  /// Protein, in grams.
  required final double proteinGrams,

  /// Carbohydrate, in grams.
  required final double carbGrams,

  /// Fat, in grams.
  required final double fatGrams,
}) {
  /// Creates a [DailyMacroTarget].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does; an int widens.
  factory fromFirestore(Map<String, Object?> data) => DailyMacroTarget(
    calories: readDouble(data[DailyMacroTargetKeys.calories]),
    proteinGrams: readDouble(data[DailyMacroTargetKeys.proteinGrams]),
    carbGrams: readDouble(data[DailyMacroTargetKeys.carbGrams]),
    fatGrams: readDouble(data[DailyMacroTargetKeys.fatGrams]),
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    DailyMacroTargetKeys.calories: calories,
    DailyMacroTargetKeys.proteinGrams: proteinGrams,
    DailyMacroTargetKeys.carbGrams: carbGrams,
    DailyMacroTargetKeys.fatGrams: fatGrams,
  };
}

/// Field names of `diet_plans/{uid}`. Swift declares no `CodingKeys`, so
/// these are its camelCase property names.
abstract final class DietPlanKeys {
  /// `planId`.
  static const planId = 'planId';

  /// `userId`: the security rules require it to match the document id.
  static const userId = 'userId';

  /// `createdAt`.
  static const createdAt = 'createdAt';

  /// `tdeeEstimate`.
  static const tdeeEstimate = 'tdeeEstimate';

  /// `preferredDiet`.
  static const preferredDiet = 'preferredDiet';

  /// `calorieFloor`.
  static const calorieFloor = 'calorieFloor';

  /// `trainingType`.
  static const trainingType = 'trainingType';

  /// `calorieDistribution`.
  static const calorieDistribution = 'calorieDistribution';

  /// `proteinIntake`.
  static const proteinIntake = 'proteinIntake';

  /// `days`.
  static const days = 'days';

  /// Every field, in declaration order.
  static const List<String> all = [
    planId,
    userId,
    createdAt,
    tdeeEstimate,
    preferredDiet,
    calorieFloor,
    trainingType,
    calorieDistribution,
    proteinIntake,
    days,
  ];
}

/// The user's nutrition plan at `diet_plans/{uid}` (Swift `DietPlan`).
///
/// The onboarding choices are kept as the strings Swift stores (the raw
/// values of its `PreferredDiet`, `CalorieFloor`, `CalorieDistribution` and
/// `ProteinIntake`), so a value a newer build writes survives.
class const DietPlan({
  /// The plan's id: the user's id for every plan written since the fix in
  /// `NutritionManager.computeDietPlan`.
  required final String planId,

  /// When it was made.
  required final DateTime createdAt,

  /// The expenditure it was built on, in kcal.
  required final double tdeeEstimate,

  /// The diet chosen, such as `balanced`.
  required final String preferredDiet,

  /// The calorie floor chosen, such as `standard`.
  required final String calorieFloor,

  /// The training focus it assumed.
  required final String trainingType,

  /// How calories are spread over the week, such as `even`.
  required final String calorieDistribution,

  /// The protein level chosen, such as `high`.
  required final String proteinIntake,

  /// The targets for each day, Monday first: seven of them.
  required final List<DailyMacroTarget> days,

  /// The owner.
  final String? userId,
}) {
  /// Creates a [DietPlan].
  this;

  /// Decodes as Swift's synthesized decoder does, strictly. A null `userId`
  /// reads as absent.
  factory fromFirestore(Map<String, Object?> data) => DietPlan(
    planId: data[DietPlanKeys.planId]! as String,
    userId: data[DietPlanKeys.userId] as String?,
    createdAt: data[DietPlanKeys.createdAt]! as DateTime,
    tdeeEstimate: readDouble(data[DietPlanKeys.tdeeEstimate]),
    preferredDiet: data[DietPlanKeys.preferredDiet]! as String,
    calorieFloor: data[DietPlanKeys.calorieFloor]! as String,
    trainingType: data[DietPlanKeys.trainingType]! as String,
    calorieDistribution: data[DietPlanKeys.calorieDistribution]! as String,
    proteinIntake: data[DietPlanKeys.proteinIntake]! as String,
    days: [
      for (final day in data[DietPlanKeys.days]! as List<Object?>)
        DailyMacroTarget.fromFirestore(readMap(day)),
    ],
  );

  /// The Firestore-shaped map Swift writes: a null `userId` is left out.
  Map<String, Object?> toFirestore() => {
    DietPlanKeys.planId: planId,
    DietPlanKeys.userId: ?userId,
    DietPlanKeys.createdAt: createdAt,
    DietPlanKeys.tdeeEstimate: tdeeEstimate,
    DietPlanKeys.preferredDiet: preferredDiet,
    DietPlanKeys.calorieFloor: calorieFloor,
    DietPlanKeys.trainingType: trainingType,
    DietPlanKeys.calorieDistribution: calorieDistribution,
    DietPlanKeys.proteinIntake: proteinIntake,
    DietPlanKeys.days: [for (final day in days) day.toFirestore()],
  };
}
