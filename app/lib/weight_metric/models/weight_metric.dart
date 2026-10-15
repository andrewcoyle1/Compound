import 'package:body_repository/body_repository.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show dayKeyOf;
import 'package:compound_maths/compound_maths.dart' show weightTrend;

/// The two screens over the user's weigh-ins (Swift `ScaleWeightView` and
/// `WeightTrendView`), which share one bloc and one layout.
enum WeightMetric {
  /// Every weigh-in as logged.
  scaleWeight('scale-weight'),

  /// The weigh-ins with the Kalman trend through them.
  weightTrend('weight-trend');

  new(this.path);

  /// The route path under the Progress tab; its name is the enum's.
  final String path;

  /// The Swift view's analytics name, for `_Appear`, `_Disappear` and
  /// `_DeleteEntry_*`.
  String get analyticsName => switch (this) {
    scaleWeight => 'ScaleWeightView',
    weightTrend => 'WeightTrendView',
  };

  /// The name of the route listing every entry, under [path].
  String get dataRouteName => '${name}Data';

  /// The screen's localized title.
  String title(AppLocalizations l10n) => switch (this) {
    scaleWeight => l10n.scaleWeightTitle,
    weightTrend => l10n.weightTrendTitle,
  };
}

/// [measurements] that hold a weight and are not deleted, oldest first
/// (Swift `weightEntries`): an entry with only a waist measurement has no
/// weight to plot.
List<BodyMeasurementEntry> weighInsOf(
  Iterable<BodyMeasurementEntry> measurements,
) => [
  for (final entry in measurements)
    if (entry.deletedAt == null && entry.weightKg != null) entry,
]..sort((a, b) => a.date.compareTo(b.date));

/// The smoothed trend at each of [weighIns], in kilograms
/// (`WeightTrendCalculator.trend`). Each weigh-in's day is its local
/// calendar day, as Swift's `startOfDay`.
List<MetricPoint> trendOf(List<BodyMeasurementEntry> weighIns) {
  final trend = weightTrend(
    [for (final entry in weighIns) entry.weightKg!],
    days: [for (final entry in weighIns) dayKeyOf(entry.date)],
  );
  return [
    for (final (i, entry) in weighIns.indexed)
      (date: entry.date, value: trend[i]),
  ];
}

/// The trend weight at the latest weigh-in, in kilograms, or null with none
/// logged (`GoalTimeline.latestTrendWeightKg`). Goal progress is measured
/// from it, so a day of water does not move the bar. A weight that is not a
/// positive number is left out.
double? latestTrendWeightKg(Iterable<BodyMeasurementEntry> measurements) {
  final weighIns = [
    for (final entry in weighInsOf(measurements))
      if (entry.weightKg!.isFinite && entry.weightKg! > 0) entry,
  ];
  return weighIns.isEmpty ? null : trendOf(weighIns).last.value;
}
