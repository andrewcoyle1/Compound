part of 'weight_metric_bloc.dart';

/// Where the weigh-ins have got to.
enum WeightMetricStatus {
  /// Waiting for the weigh-ins.
  loading,

  /// They have arrived.
  loaded,

  /// They could not be read.
  failure,
}

/// One weight screen: its weigh-ins, their trend, the unit to show them in
/// and the chart's range. Everything the screen draws is derived here, in
/// the user's unit (Swift `ScaleWeightPresenter`, `WeightTrendPresenter`).
final class const WeightMetricState({
  /// Which screen this is.
  required final WeightMetric metric,

  /// Today, at local midnight, when the screen opened: the chart's window
  /// ends on it.
  required final DateTime today,

  /// The chart's range; a week to start, as QuickCharts opens.
  final MetricRange range = MetricRange.week,

  /// The live weigh-ins, oldest first; null until they arrive.
  final List<BodyMeasurementEntry>? weighIns,

  /// The trend at each weigh-in, in kilograms.
  final List<MetricPoint> trendKg = const [],

  /// The profile's weight unit; null when unset or unread.
  final WeightUnitPreference? weightUnitPreference,

  /// Whether reading the weigh-ins failed.
  final bool failed = false,

  /// How many deletes have failed, so the screen alerts on each.
  final int deleteFailures = 0,
}) extends Equatable {
  /// Where the weigh-ins have got to.
  WeightMetricStatus get status => failed
      ? WeightMetricStatus.failure
      : weighIns == null
      ? WeightMetricStatus.loading
      : WeightMetricStatus.loaded;

  /// The unit every value is shown in: pounds if the profile says so,
  /// otherwise kilograms.
  AppWeightUnit get unit => weightUnitPreference == WeightUnitPreference.pounds
      ? AppWeightUnit.pounds
      : AppWeightUnit.kilograms;

  /// Every weigh-in, in [unit]. The chart's first series, which the
  /// readings rows describe.
  List<MetricPoint> get scalePoints => [
    for (final entry in weighIns ?? const <BodyMeasurementEntry>[])
      (date: entry.date, value: _inUnit(entry.weightKg!)),
  ];

  /// The trend line in [unit], on Weight Trend only, and only from two
  /// weigh-ins: one reading is not a trend.
  List<MetricPoint> get trendPoints =>
      metric == WeightMetric.weightTrend && trendKg.length >= 2
      ? [for (final p in trendKg) (date: p.date, value: _inUnit(p.value))]
      : const [];

  /// The rows of All Recorded Data, newest first: the weigh-ins on Scale
  /// Weight, the trend at each on Weight Trend. Weight is stored in
  /// kilograms and smoothed in kilograms; the conversion is linear, so it
  /// is the same curve.
  List<MetricPoint> get entries => switch (metric) {
    WeightMetric.scaleWeight => scalePoints,
    WeightMetric.weightTrend => [
      for (final p in trendKg) (date: p.date, value: _inUnit(p.value)),
    ],
  }.reversed.toList();

  /// The weigh-in behind each of [entries], for deleting it: a trend row
  /// deletes the weigh-in it was worked out at, as in Swift.
  List<String> get entryIds => [
    for (final entry in (weighIns ?? const <BodyMeasurementEntry>[]).reversed)
      entry.id,
  ];

  double _inUnit(double kilograms) => unit == AppWeightUnit.pounds
      ? kilograms * AppFormat.poundsPerKilogram
      : kilograms;

  WeightMetricState copyWith({
    MetricRange? range,
    List<BodyMeasurementEntry>? weighIns,
    List<MetricPoint>? trendKg,
    WeightUnitPreference? Function()? weightUnitPreference,
    bool? failed,
    int? deleteFailures,
  }) => WeightMetricState(
    metric: metric,
    today: today,
    range: range ?? this.range,
    weighIns: weighIns ?? this.weighIns,
    trendKg: trendKg ?? this.trendKg,
    weightUnitPreference: weightUnitPreference == null
        ? this.weightUnitPreference
        : weightUnitPreference(),
    failed: failed ?? this.failed,
    deleteFailures: deleteFailures ?? this.deleteFailures,
  );

  @override
  List<Object?> get props => [
    metric,
    today,
    range,
    weighIns,
    trendKg,
    weightUnitPreference,
    failed,
    deleteFailures,
  ];
}
