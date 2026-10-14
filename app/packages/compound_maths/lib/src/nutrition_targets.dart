/// The arithmetic that turns a calorie target and the diet answers into a week
/// of macro targets (`NutritionTargets.swift`, and the assembly in
/// `NutritionManager.computeDietPlan` and `goalTarget`).
///
/// Sources, as in the Swift: the floors from Jensen 2014; protein from
/// Morton 2018 and Helms 2014, on a reference weight in obesity (Weijs 2025,
/// Dekker 2022), at least 1.2 g/kg from 65 (Bauer 2013); fat 20–35% of energy
/// (IOM 2005) and at least 0.5 g/kg (Iraki 2019); keto's 30 g inside
/// Feinman 2015's 20–50 g.
library;

import 'package:compound_maths/src/daily_macros.dart';
import 'package:compound_maths/src/energy_density.dart';
import 'package:compound_maths/src/formula_expenditure.dart';

/// The protein answer (`ProteinIntake`), with its grams per kilogram.
enum ProteinIntake(final double gramsPerKg) {
  low(1.6),
  moderate(2),
  high(2.2),
  veryHigh(2.6);

  /// The case stored as [raw] (the case name), or `null`.
  static ProteinIntake? tryParse(String? raw) =>
      values.where((p) => p.name == raw).firstOrNull;
}

/// The diet answer (`PreferredDiet`), with fat's share of the day for the
/// diets set by fat; low-carb sets carbohydrate's share and keto a gram cap.
enum PreferredDiet(final double? fatShare) {
  balanced(0.3),
  lowFat(0.2),
  lowCarb(null),
  keto(null);

  /// The case stored as [raw] (the case name), or `null`.
  static PreferredDiet? tryParse(String? raw) =>
      values.where((d) => d.name == raw).firstOrNull;
}

/// How the week's calories are spread (`CalorieDistribution`).
enum CalorieDistribution {
  even,
  varied;

  /// The case stored as [raw] (the case name), or `null`.
  static CalorieDistribution? tryParse(String? raw) =>
      values.where((d) => d.name == raw).firstOrNull;
}

/// The constants, with the Swift's names. Those marked Compound's own are
/// design choices, not findings.
abstract final class NutritionTargets {
  /// The largest deficit a goal may set, as a share of expenditure. Compound's
  /// own.
  static const maximumDeficitShare = 0.25;

  /// From this BMI up, protein is on a reference weight.
  static const referenceWeightBmi = 30.0;

  static const olderAdultMinimumGramsPerKg = 1.2;
  static const olderAdultAge = 65;

  /// Fat never below this many grams per kg of reference weight.
  static const fatFloorGramsPerKg = 0.5;

  /// Nor below this share of the day's calories.
  static const fatFloorEnergyShare = 0.2;

  static const ketoCarbGrams = 30.0;
  static const lowCarbEnergyShare = 0.2;

  /// The share added to a high day. Compound's own.
  static const highDayBonus = 0.1;

  /// No other day below this share of the target. Compound's own.
  static const lowestDayShare = 0.85;
}

/// The lowest daily target a plan writes: 1,200 kcal for women, 1,500 for men,
/// 1,350 when not said (`CalorieFloor.standard.minimumValue(for:)`).
double calorieFloor(Gender? gender) => switch (gender) {
  Gender.female => 1200,
  Gender.male => 1500,
  Gender.preferNotToSay || null => 1350,
};

/// A goal's weekly change with its direction put back: negative to lose,
/// positive to gain, 0 when the two weights match
/// (`WeightGoal.signedWeeklyChangeKg`).
double signedWeeklyChangeKg({
  required double startingWeightKg,
  required double targetWeightKg,
  required double weeklyChangeKg,
}) {
  final magnitude = weeklyChangeKg.abs();
  if (targetWeightKg < startingWeightKg) return -magnitude;
  if (targetWeightKg > startingWeightKg) return magnitude;
  return 0;
}

/// What to eat to move at the active goal's [goalWeeklyChangeKg] (signed;
/// `null` without an active goal): expenditure plus the rate's daily share of
/// 7,700 kcal/kg, a deficit capped at a quarter of expenditure
/// (`NutritionManager.goalTarget`).
double goalTargetKcal({
  required double expenditureKcal,
  double? goalWeeklyChangeKg,
}) {
  if (goalWeeklyChangeKg == null) return expenditureKcal;
  final change = dailyKcalForWeeklyChange(goalWeeklyChangeKg);
  final cap = -NutritionTargets.maximumDeficitShare * expenditureKcal;
  return expenditureKcal + (change > cap ? change : cap);
}

/// The weight protein and the fat floor are worked out on: total weight below
/// a BMI of 30; from 30, the weight at a BMI of 30 for the height, or the goal
/// weight if higher, never more than they weigh. Total weight without a usable
/// height (`NutritionTargets.referenceWeightKg`).
double referenceWeightKg({
  required double weightKg,
  double? heightCm,
  double? goalWeightKg,
}) {
  if (heightCm == null || !heightCm.isFinite || !(heightCm > 0)) {
    return weightKg;
  }
  final heightM = heightCm / 100;
  final atThreshold = NutritionTargets.referenceWeightBmi * heightM * heightM;
  if (!(weightKg > atThreshold)) return weightKg;
  final goal = goalWeightKg != null && goalWeightKg.isFinite && goalWeightKg > 0
      ? goalWeightKg
      : 0.0;
  final reference = atThreshold > goal ? atThreshold : goal;
  return weightKg < reference ? weightKg : reference;
}

/// Grams of protein a day, at least 1.2 g/kg from 65
/// (`NutritionTargets.proteinGrams`).
double proteinGrams({
  required ProteinIntake intake,
  required double referenceWeightKg,
  int? ageYears,
}) {
  var perKg = intake.gramsPerKg;
  if (ageYears != null &&
      ageYears >= NutritionTargets.olderAdultAge &&
      perKg < NutritionTargets.olderAdultMinimumGramsPerKg) {
    perKg = NutritionTargets.olderAdultMinimumGramsPerKg;
  }
  return perKg * referenceWeightKg;
}

double _max(double a, double b) => a > b ? a : b;
double _min(double a, double b) => a < b ? a : b;

/// One day's grams, rounded: protein fixed; fat by the diet, raised to the fat
/// floor; carbohydrate takes the rest (`NutritionTargets.macros`).
Macros dailyMacros({
  required double calories,
  required double proteinGrams,
  required PreferredDiet diet,
  required double referenceWeightKg,
}) {
  final remaining = _max(calories - proteinGrams * 4, 0);
  var fatCalories = switch (diet) {
    PreferredDiet.balanced || PreferredDiet.lowFat => calories * diet.fatShare!,
    PreferredDiet.lowCarb =>
      remaining - calories * NutritionTargets.lowCarbEnergyShare,
    PreferredDiet.keto =>
      remaining - _min(NutritionTargets.ketoCarbGrams * 4, remaining),
  };
  final floorCalories = _max(
    NutritionTargets.fatFloorGramsPerKg * referenceWeightKg * 9,
    NutritionTargets.fatFloorEnergyShare * calories,
  );
  fatCalories = _min(_max(_max(fatCalories, floorCalories), 0), remaining);
  final carbCalories = _max(remaining - fatCalories, 0);
  return (
    calories: calories.roundToDouble(),
    proteinGrams: proteinGrams.roundToDouble(),
    carbGrams: (carbCalories / 4).roundToDouble(),
    fatGrams: (fatCalories / 9).roundToDouble(),
  );
}

/// [count] weekday indices (Monday = 0) spread through the week: 3 gives
/// Monday, Wednesday and Friday (`NutritionTargets.highDayIndices`).
List<int> highDayIndices(int count) => [
  for (var i = 0; i < (count < 7 ? count : 7); i++) (i * 7 / count).floor(),
];

/// Seven daily calorie targets, Monday first, that total seven times
/// [target]: even, or one high day per training day with the rest lowered,
/// none under 85% of the target nor the [floor]
/// (`NutritionTargets.dailyCalories`).
List<double> dailyCalories({
  required double target,
  required double floor,
  required CalorieDistribution distribution,
  required int trainingDaysPerWeek,
}) {
  final highDays = trainingDaysPerWeek.clamp(0, 7);
  if (distribution != CalorieDistribution.varied ||
      highDays == 0 ||
      highDays == 7) {
    return List.filled(7, _max(target, floor));
  }
  final restDays = 7 - highDays;
  final bonus = _min(
    NutritionTargets.highDayBonus,
    (1 - NutritionTargets.lowestDayShare) * restDays / highDays,
  );
  final high = target * (1 + bonus);
  final low = target * (1 - bonus * highDays / restDays);
  final highIndices = highDayIndices(highDays).toSet();
  return [
    for (var i = 0; i < 7; i++)
      _max(highIndices.contains(i) ? high : low, floor),
  ];
}

/// A week of macro targets, Monday first: the pure part of
/// `NutritionManager.computeDietPlan`.
///
/// [targetKcal] replaces the goal target worked out from [expenditureKcal] and
/// [goalWeeklyChangeKg]; either way the sex's floor holds. [goalWeeklyChangeKg]
/// (signed) and [goalWeightKg] are the active goal's, `null` without one.
/// A missing or unusable weight reads as 70 kg, clamped to 30–500.
/// [ageYears] is whole years from the date of birth, `null` without one.
List<Macros> dietPlanDays({
  required double expenditureKcal,
  required PreferredDiet diet,
  required CalorieDistribution distribution,
  required ProteinIntake protein,
  double? targetKcal,
  double? goalWeeklyChangeKg,
  double? goalWeightKg,
  Gender? gender,
  double? weightKg,
  double? heightCm,
  int? ageYears,
  int trainingDaysPerWeek = 0,
}) {
  final floor = calorieFloor(gender);
  final target = _max(
    targetKcal ??
        goalTargetKcal(
          expenditureKcal: expenditureKcal,
          goalWeeklyChangeKg: goalWeeklyChangeKg,
        ),
    floor,
  );
  final weight = weightKg ?? 70;
  final reference = referenceWeightKg(
    weightKg: weight.isFinite ? weight.clamp(30, 500).toDouble() : 70,
    heightCm: heightCm,
    goalWeightKg: goalWeightKg,
  );
  final grams = proteinGrams(
    intake: protein,
    referenceWeightKg: reference,
    ageYears: ageYears,
  );
  return [
    for (final calories in dailyCalories(
      target: target,
      floor: floor,
      distribution: distribution,
      trainingDaysPerWeek: trainingDaysPerWeek,
    ))
      dailyMacros(
        calories: calories,
        proteinGrams: grams,
        diet: diet,
        referenceWeightKg: reference,
      ),
  ];
}
