import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/today/logic/today_checklist.dart';

/// The words on Today's checklist (Swift `TodayChecklist.build` and
/// `DayChecklistCard`), from the decisions `today_checklist.dart` makes.
abstract final class TodayText {
  /// The item's title.
  static String title(AppLocalizations l10n, ChecklistItem item) =>
      switch (item) {
        TrainingItem() => l10n.todayTrain,
        NutritionItem() => l10n.todayEatToTarget,
        WeighInItem() => l10n.todayWeighIn,
        StepsItem() => l10n.todaySteps,
      };

  /// The item's glyph.
  static IconData icon(ChecklistItem item) => switch (item) {
    TrainingItem() => AppSymbols.workout,
    NutritionItem() => AppSymbols.meal,
    WeighInItem() => AppSymbols.scaleWeight,
    StepsItem() => AppSymbols.steps,
  };

  /// The line under the item's title: the workout's name, calories and
  /// protein against target, the weight and its week, or steps against the
  /// goal.
  static String detail(
    AppLocalizations l10n,
    ChecklistItem item,
    AppWeightUnit unit, {
    String? locale,
  }) => switch (item) {
    TrainingItem(:final session) => session.name,
    NutritionItem() => _nutrition(l10n, item, locale),
    WeighInItem() => _weighIn(l10n, item, unit, locale),
    StepsItem(:final today, :final goal) => l10n.todayStepsOfGoal(
      AppFormat.number(today, locale: locale),
      AppFormat.number(goal, locale: locale),
    ),
  };

  static String _nutrition(
    AppLocalizations l10n,
    NutritionItem item,
    String? locale,
  ) {
    final calories = AppFormat.number(item.calories, locale: locale);
    if (!item.hasTarget) {
      return item.mealsLogged > 0
          ? l10n.todayKcalLogged(calories)
          : l10n.todayNothingLogged;
    }
    final calorieText = l10n.todayCaloriesOfTarget(
      calories,
      AppFormat.kcal(item.calorieTarget!, locale: locale),
    );
    if (!item.hasProteinTarget) return calorieText;
    final protein = l10n.todayProteinOfTarget(
      AppFormat.grams(item.proteinGrams, locale: locale),
      AppFormat.grams(item.proteinTarget!, locale: locale),
    );
    return '$calorieText · $protein';
  }

  static String _weighIn(
    AppLocalizations l10n,
    WeighInItem item,
    AppWeightUnit unit,
    String? locale,
  ) {
    final latest = item.latestKg;
    if (latest == null) return l10n.todayNoWeighIns;
    final change = item.weekChangeKg;
    final goal = item.goalWeeklyChangeKg;
    return [
      AppFormat.weight(latest, unit, locale: locale),
      if (change != null)
        l10n.todayWeekChange(signedWeight(change, unit, locale: locale)),
      if (goal != null && goal != 0)
        l10n.todayGoalPace(signedWeight(goal, unit, locale: locale)),
    ].join(' · ');
  }

  /// "+0.3 kg", "−0.4 kg", "0 kg": a change under 0.05 kg either way
  /// carries no sign (`TodayChecklist.signedWeight`).
  static String signedWeight(
    double kilograms,
    AppWeightUnit unit, {
    String? locale,
  }) {
    final text = AppFormat.weight(kilograms.abs(), unit, locale: locale);
    if (kilograms > 0.04) return '+$text';
    if (kilograms < -0.04) return '−$text';
    return text;
  }

  /// A getting-started step's title.
  static String starter(
    AppLocalizations l10n,
    StarterStep step, {
    bool appleHealth = true,
  }) => switch (step) {
    StarterStep.firstWorkout => l10n.todayFirstWorkout,
    StarterStep.firstMeal => l10n.todayFirstMeal,
    StarterStep.firstWeighIn => l10n.todayFirstWeighIn,
    StarterStep.appleHealth =>
      appleHealth ? l10n.healthConnectApple : l10n.healthConnectAndroid,
    StarterStep.strava => l10n.stravaOfferConnect,
  };

  /// A getting-started step's glyph.
  static IconData starterIcon(StarterStep step) => switch (step) {
    StarterStep.firstWorkout => AppSymbols.workout,
    StarterStep.firstMeal => AppSymbols.meal,
    StarterStep.firstWeighIn => AppSymbols.scaleWeight,
    StarterStep.appleHealth => AppSymbols.heart,
    StarterStep.strava => AppSymbols.cardio,
  };
}
