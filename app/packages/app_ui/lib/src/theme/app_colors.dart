import 'package:material_ui/material_ui.dart';

/// {@template app_colors}
/// Compound's named colours beyond the [ColorScheme].
///
/// The accent is the [ColorScheme]'s `primary`, and text drawn on it is
/// `onPrimary` (the Swift app's `onAccent`). Changing those two recolours the
/// whole app, which only holds if no widget writes the accent's current value
/// (black or white) where the accent is meant. The user's own goal progress
/// is the accent too, not a metric colour.
///
/// - [canvas] is the screen background, [surface] a card or grouped row on it.
/// - [tintedSurface] is the one fill for tinted tiles, chips and badges.
/// - Macro, nutrient and metric colours are data: use each for its own data
///   only. No two metrics share a hue, and none uses a macro colour.
/// - Status colours are never the only signal: pair them with an icon or text.
///
/// Values are the iOS system colours the Swift app uses, so both apps match.
/// {@endtemplate}
class AppColors extends ThemeExtension<AppColors> {
  /// {@macro app_colors}
  const new({
    required this.canvas,
    required this.surface,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.vitamins,
    required this.minerals,
    required this.otherNutrients,
    required this.success,
    required this.warning,
    required this.danger,
    required this.warmup,
    required this.superset,
    required this.personalRecord,
    required this.workouts,
    required this.steps,
    required this.expenditure,
    required this.scaleWeight,
    required this.bodyFat,
    required this.measurements,
    required this.nutrition,
    required this.muscleGroups,
    required this.exercises,
    required this.habits,
  });

  /// The light palette.
  static const light = AppColors(
    canvas: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    calories: Color(0xFF007AFF),
    protein: Color(0xFFE6664D),
    carbs: Color(0xFF66BF80),
    fat: Color(0xFFF2BF33),
    vitamins: Color(0xFF8C59BF),
    minerals: Color(0xFFF280A6),
    otherNutrients: Color(0xFF8CC7F2),
    success: Color(0xFF34C759),
    warning: Color(0xFFFF9500),
    // Apple's increased-contrast system red: 5.4:1 on white, where the
    // standard #FF3B30 is 3.6:1, below WCAG AA for text (owner, 19 Oct 2026).
    danger: Color(0xFFD70015),
    warmup: Color(0xFFFF9500),
    superset: Color(0xFF5856D6),
    personalRecord: Color(0xFFFFCC00),
    workouts: Color(0xFFFF9500),
    steps: Color(0xFF00C7BE),
    expenditure: Color(0xFFFF2D55),
    scaleWeight: Color(0xFFAF52DE),
    bodyFat: Color(0xFF30B0C7),
    measurements: Color(0xFFA2845E),
    nutrition: Color(0xFFA2845E),
    muscleGroups: Color(0xFF5856D6),
    exercises: Color(0xFF32ADE6),
    habits: Color(0xFFCC4DBF),
  );

  /// The dark palette.
  static const dark = AppColors(
    canvas: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    calories: Color(0xFF0A84FF),
    protein: Color(0xFFE6664D),
    carbs: Color(0xFF66BF80),
    fat: Color(0xFFF2BF33),
    vitamins: Color(0xFF8C59BF),
    minerals: Color(0xFFF280A6),
    otherNutrients: Color(0xFF8CC7F2),
    success: Color(0xFF30D158),
    warning: Color(0xFFFF9F0A),
    danger: Color(0xFFFF453A),
    warmup: Color(0xFFFF9F0A),
    superset: Color(0xFF5E5CE6),
    personalRecord: Color(0xFFFFD60A),
    workouts: Color(0xFFFF9F0A),
    steps: Color(0xFF63E6E2),
    expenditure: Color(0xFFFF375F),
    scaleWeight: Color(0xFFBF5AF2),
    bodyFat: Color(0xFF40C8E0),
    measurements: Color(0xFFAC8E68),
    nutrition: Color(0xFFAC8E68),
    muscleGroups: Color(0xFF5E5CE6),
    exercises: Color(0xFF64D2FF),
    habits: Color(0xFFCC4DBF),
  );

  /// The fill for tinted tiles, chips and badges: [color] at 15% opacity.
  static Color tintedSurface(Color color) =>
      color.withValues(alpha: color.a * 0.15);

  /// A colour the user chose, stored as `#RRGGBB` (the `#` optional), such
  /// as a gym plate's or a mesocycle's. User data, so not a token. Null when
  /// [hex] is not six hex digits.
  static Color? fromHex(String? hex) {
    final digits = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex ?? '')?[1];
    return digits == null
        ? null
        : Color(0xFF000000 | int.parse(digits, radix: 16));
  }

  /// The screen background behind surfaces (iOS `systemGroupedBackground`).
  final Color canvas;

  /// A card or grouped row on the canvas
  /// (iOS `secondarySystemGroupedBackground`).
  final Color surface;

  /// Calories. Data: use it for calories only.
  final Color calories;

  /// Protein.
  final Color protein;

  /// Carbohydrates.
  final Color carbs;

  /// Fat.
  final Color fat;

  /// Vitamins.
  final Color vitamins;

  /// Minerals.
  final Color minerals;

  /// Other nutrients.
  final Color otherNutrients;

  /// Success. Never colour alone: pair it with an icon or text.
  final Color success;

  /// Warning. Never colour alone: pair it with an icon or text.
  final Color warning;

  /// Errors, always, toasts included. Never colour alone.
  final Color danger;

  /// A warm-up set.
  final Color warmup;

  /// A superset.
  final Color superset;

  /// A personal record.
  final Color personalRecord;

  /// The workouts metric.
  final Color workouts;

  /// The steps metric.
  final Color steps;

  /// The expenditure metric.
  final Color expenditure;

  /// The scale-weight metric.
  final Color scaleWeight;

  /// The body-fat metric.
  final Color bodyFat;

  /// The measurements metric.
  final Color measurements;

  /// The nutrition metric.
  final Color nutrition;

  /// The muscle-groups metric.
  final Color muscleGroups;

  /// The exercises metric.
  final Color exercises;

  /// The habits metric.
  final Color habits;

  @override
  AppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? calories,
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? vitamins,
    Color? minerals,
    Color? otherNutrients,
    Color? success,
    Color? warning,
    Color? danger,
    Color? warmup,
    Color? superset,
    Color? personalRecord,
    Color? workouts,
    Color? steps,
    Color? expenditure,
    Color? scaleWeight,
    Color? bodyFat,
    Color? measurements,
    Color? nutrition,
    Color? muscleGroups,
    Color? exercises,
    Color? habits,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      vitamins: vitamins ?? this.vitamins,
      minerals: minerals ?? this.minerals,
      otherNutrients: otherNutrients ?? this.otherNutrients,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      warmup: warmup ?? this.warmup,
      superset: superset ?? this.superset,
      personalRecord: personalRecord ?? this.personalRecord,
      workouts: workouts ?? this.workouts,
      steps: steps ?? this.steps,
      expenditure: expenditure ?? this.expenditure,
      scaleWeight: scaleWeight ?? this.scaleWeight,
      bodyFat: bodyFat ?? this.bodyFat,
      measurements: measurements ?? this.measurements,
      nutrition: nutrition ?? this.nutrition,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      exercises: exercises ?? this.exercises,
      habits: habits ?? this.habits,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      calories: mix(calories, other.calories),
      protein: mix(protein, other.protein),
      carbs: mix(carbs, other.carbs),
      fat: mix(fat, other.fat),
      vitamins: mix(vitamins, other.vitamins),
      minerals: mix(minerals, other.minerals),
      otherNutrients: mix(otherNutrients, other.otherNutrients),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      warmup: mix(warmup, other.warmup),
      superset: mix(superset, other.superset),
      personalRecord: mix(personalRecord, other.personalRecord),
      workouts: mix(workouts, other.workouts),
      steps: mix(steps, other.steps),
      expenditure: mix(expenditure, other.expenditure),
      scaleWeight: mix(scaleWeight, other.scaleWeight),
      bodyFat: mix(bodyFat, other.bodyFat),
      measurements: mix(measurements, other.measurements),
      nutrition: mix(nutrition, other.nutrition),
      muscleGroups: mix(muscleGroups, other.muscleGroups),
      exercises: mix(exercises, other.exercises),
      habits: mix(habits, other.habits),
    );
  }
}
