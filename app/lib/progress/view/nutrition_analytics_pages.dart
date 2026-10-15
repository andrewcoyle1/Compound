import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/progress/bloc/progress_figures.dart';
import 'package:compound/progress/logic/nutrition_analytics.dart';
import 'package:compound/progress/view/progress_cards.dart';
import 'package:compound/progress/view/progress_metric_view.dart';
import 'package:compound/progress/view/progress_names.dart';
import 'package:compound/progress/view/progress_provider.dart';
import 'package:compound/training_analytics/view/workout_consistency_page.dart'
    show ContributionGrid;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Nutrition (Swift `NutritionAnalyticsView`): calories and the macros
/// today against the plan, the week's macros, and every nutrient the meal
/// log records, each opening its daily history.
class NutritionAnalyticsPage extends StatelessWidget {
  const new({super.key});

  /// The path under the Progress tab, and the route name.
  static const path = 'nutrition-analytics';
  static const name = 'nutritionAnalytics';

  @override
  Widget build(BuildContext context) => ProgressProvider(
    screen: 'NutritionAnalyticsView',
    child: ProgressSectionsView(
      title: context.l10n.progressNutritionHeader,
      sections: (context, state) {
        final l10n = context.l10n;
        final cards = ProgressCards(context, state);
        return [
          for (final section in NutritionMetricSection.values)
            ProgressCardSection(
              header: nutritionSectionName(l10n, section),
              cards: [
                for (final metric in NutritionMetric.values)
                  if (metric.section == section)
                    switch (metric) {
                      NutritionMetric.macros => cards.macros(),
                      _ when metric.line == null => cards.macroToday(metric),
                      _ => cards.breakdown(metric),
                    },
              ],
            ),
        ];
      },
    ),
  );
}

/// One nutrition metric's daily values over the last year (Swift
/// `NutritionMetricDetailPresenter`): bars, stacked protein, carbohydrate
/// and fat for Macros. Derived from meals, so nothing here is deleted;
/// the action logs a meal.
class NutritionMetricPage extends StatelessWidget {
  const new({required this.metric, this.allData = false, super.key});

  /// The path under Nutrition, and the route names.
  static const path = ':$metricParameter';
  static const name = 'nutritionMetric';
  static const dataName = 'nutritionMetricData';

  /// The metric's path parameter: its case name.
  static const metricParameter = 'metric';

  /// Which metric.
  final NutritionMetric metric;

  /// Whether to show every entry instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) => ProgressProvider(
    screen: 'NutritionMetricDetailView',
    parameters: {'metric': metric.name},
    child: ProgressMetricView(
      allData: allData,
      allDataRoute: dataName,
      pathParameters: {metricParameter: metric.name},
      metric: (context, state) {
        final l10n = context.l10n;
        final colors = context.appColors;
        final locale = Localizations.localeOf(context).toLanguageTag();
        final days = [
          for (final day in state.nutritionHistory)
            if (metric != NutritionMetric.macros || hasMacros(day.totals)) day,
        ];
        final points = metricPoints(metric, days);
        final title = nutritionMetricName(l10n, metric);
        final macros = metric == NutritionMetric.macros;
        MetricChartSeries bars(
          String label,
          Color color,
          double Function(NutritionDay) of,
        ) => MetricChartSeries(
          label: label,
          points: [for (final d in days) (date: d.date, value: of(d))],
          color: color,
          isBar: true,
        );
        String grams(double value) => AppFormat.grams(value, locale: locale);
        return ProgressMetric(
          title: title,
          unit: macros ? 'g' : metric.unit,
          series: macros
              ? [
                  bars(
                    l10n.progressProtein,
                    colors.protein,
                    (d) => d.totals.proteinGrams,
                  ),
                  bars(
                    l10n.nutritionMacroCarbs,
                    colors.carbs,
                    (d) => d.totals.carbGrams,
                  ),
                  bars(
                    l10n.nutritionMacroFat,
                    colors.fat,
                    (d) => d.totals.fatGrams,
                  ),
                ]
              : [
                  MetricChartSeries(
                    label: title,
                    points: points,
                    color: nutritionMetricColor(colors, metric),
                    isBar: true,
                  ),
                ],
          entries: points,
          entryText: (index) {
            final i = points.length - 1 - index;
            if (macros) {
              final totals = days[i].totals;
              return l10n.nutritionMetricMacrosEntry(
                grams(totals.proteinGrams),
                grams(totals.carbGrams),
                grams(totals.fatGrams),
              );
            }
            final value = nutritionValueText(points[i].value, locale);
            return '$value ${metric.unit}';
          },
          emptyMessage: macros
              ? l10n.nutritionMetricMacrosEmpty
              : l10n.nutritionMetricEmpty(title.toLowerCase()),
          add: logMealAction(context),
        );
      },
    ),
  );
}

/// Every day with food logged on a contribution grid (Swift
/// `FoodLoggingConsistencyView`). Derived from meals, so the action logs a
/// meal.
class FoodLoggingConsistencyPage extends StatelessWidget {
  const new({this.allData = false, super.key});

  /// The path under the Progress tab, and the route names.
  static const path = 'food-logging-consistency';
  static const name = 'foodLoggingConsistency';
  static const dataName = 'foodLoggingConsistencyData';

  /// Whether to show every entry instead of the grid.
  final bool allData;

  @override
  Widget build(BuildContext context) => ProgressProvider(
    screen: 'FoodLoggingConsistencyView',
    child: ProgressMetricView(
      allData: allData,
      allDataRoute: dataName,
      metric: (context, state) {
        final l10n = context.l10n;
        final locale = Localizations.localeOf(context).toLanguageTag();
        final days = [
          for (final day in state.nutritionHistory)
            if (hasMacros(day.totals)) day,
        ];
        final points = [
          for (final d in days) (date: d.date, value: d.totals.calories),
        ];
        final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
        return ProgressMetric(
          title: l10n.progressFoodLogging,
          unit: 'kcal',
          series: const [],
          entries: points,
          entryText: (index) => AppFormat.kcal(
            points[points.length - 1 - index].value.round(),
            locale: locale,
          ),
          emptyMessage: l10n.foodLoggingEmpty,
          add: logMealAction(context),
          chart: days.isEmpty
              ? null
              : ContributionGrid(
                  dates: [for (final d in days) d.date],
                  today: state.today,
                  firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay,
                  color: context.appColors.habits,
                  semanticsLabel: l10n.foodLoggingGridLabel(days.length),
                ),
        );
      },
    ),
  );
}

/// Log Meal: the meal being built, if there is one, rather than a new one
/// replacing it (Swift `onAddPressed`), else a new meal for now.
ProgressMetricAction logMealAction(BuildContext context) =>
    ProgressMetricAction(
      label: context.l10n.nutritionLogMeal,
      icon: AppSymbols.add,
      onPressed: () {
        final draft = context.read<MealDraftCubit>().state;
        unawaited(
          draft != null
              ? AddMealPage.show(context, draft)
              : context.pushNamed<void>(AddMealPage.name),
        );
      },
    );

/// A nutrient amount as an entry shows it (Swift
/// `NutritionMetricEntry.displayValue`): whole from 100 or when whole, else
/// one decimal place.
String nutritionValueText(double value, String locale) {
  final figure = breakdownFigure(value)!;
  return AppFormat.number(
    figure.value,
    maxFractionDigits: figure.decimals,
    locale: locale,
  );
}
