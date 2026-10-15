import 'package:checkin_repository/checkin_repository.dart' show localMidnight;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound_maths/compound_maths.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// The two screens over the expenditure engine (Swift
/// `ExpenditureDetailView` and `EnergyBalanceView`), which share one bloc
/// and the metric layout.
enum ExpenditureMetric {
  /// The adaptive estimate, day by day.
  expenditure('expenditure', 'ExpenditureDetailView'),

  /// What was eaten against the estimate.
  energyBalance('energy-balance', 'EnergyBalanceView');

  new(this.path, this.analyticsName);

  /// The route path under the Progress tab; its name is the enum's.
  final String path;

  /// The Swift screen name its events start with.
  final String analyticsName;

  /// The name of the route listing every entry, under [path].
  String get dataRouteName => '${name}Data';

  /// The screen's localized title.
  String title(AppLocalizations l10n) => switch (this) {
    expenditure => l10n.expenditureTitle,
    energyBalance => l10n.energyBalanceTitle,
  };
}

/// How many days both screens cover, today included.
const expenditureMetricDays = 90;

/// The last [expenditureMetricDays] of [history], one point a day, or the
/// formula's [formulaKcal] on each of those days ending [today] when there
/// is no history (`ExpenditureDetailPresenter.rebuildCaches`).
List<MetricPoint> expenditurePoints(
  List<ExpenditureEstimate> history,
  double formulaKcal,
  String today,
) {
  if (history.isEmpty) {
    return [
      for (var i = expenditureMetricDays - 1; i >= 0; i--)
        (date: localMidnight(addDays(today, -i)), value: formulaKcal),
    ];
  }
  final recent = history.length > expenditureMetricDays
      ? history.sublist(history.length - expenditureMetricDays)
      : history;
  return [
    for (final estimate in recent)
      (date: localMidnight(estimate.day), value: estimate.kcal),
  ];
}

/// One day of Energy Balance: what was spent and what was eaten.
typedef EnergyBalanceDay = ({DateTime date, double expenditure, double intake});

/// The expenditure on every one of the last [expenditureMetricDays] days
/// ending [today], and the days among them with calories logged
/// (`EnergyBalancePresenter.rebuildCaches`): a day with nothing logged is
/// one the app knows nothing about, not a day of eating nothing.
({List<MetricPoint> expenditure, List<EnergyBalanceDay> days}) energyBalance({
  required List<ExpenditureEstimate> history,
  required double formulaKcal,
  required Iterable<MealLogModel> meals,
  required String today,
}) {
  final spent = expenditureOn(history, formulaKcal);
  final byDay = mealsByDay(meals);
  final expenditure = <MetricPoint>[];
  final days = <EnergyBalanceDay>[];
  for (var i = expenditureMetricDays - 1; i >= 0; i--) {
    final day = addDays(today, -i);
    final date = localMidnight(day);
    final kcal = spent(day);
    expenditure.add((date: date, value: kcal));
    final intake = totalsOf(byDay[day] ?? const []).calories;
    if (intake > 0) {
      days.add((date: date, expenditure: kcal, intake: intake));
    }
  }
  return (expenditure: expenditure, days: days);
}
