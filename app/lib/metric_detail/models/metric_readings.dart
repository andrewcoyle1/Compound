import 'package:compound/nutrition/logic/meal_day.dart' show startOfDay;

/// One reading on a metric chart: when, and its value in the unit shown.
typedef MetricPoint = ({DateTime date, double value});

/// The ranges the chart's picker offers, as QuickCharts' W, M, 6M and Y.
/// Each is a window of [days] ending today.
enum MetricRange {
  /// The last 7 days, a point a day.
  week(7),

  /// The last 30 days, a point a day.
  month(30),

  /// The last 182 days, a point a week.
  sixMonths(182),

  /// The last 365 days, a point a month.
  year(365);

  new(this.days);

  /// How many days the window covers, today included.
  final int days;

  /// The window's first day, at midnight, when it ends on [today].
  DateTime start(DateTime today) =>
      DateTime(today.year, today.month, today.day - days + 1);

  /// The start of the bucket [date] is averaged into: its day up to a
  /// month, its week (from Monday) at six months, its month at a year.
  DateTime bucket(DateTime date) => switch (this) {
    week || month => startOfDay(date),
    sixMonths => DateTime(date.year, date.month, date.day - date.weekday + 1),
    year => DateTime(date.year, date.month),
  };

  /// [points] inside the window ending on [today], averaged into buckets
  /// (added up for a [total] chart, such as sets), oldest first. A bucket
  /// that starts before the window keeps only the readings inside it, dated
  /// at the window's start.
  List<MetricPoint> visible(
    List<MetricPoint> points,
    DateTime today, {
    bool total = false,
  }) {
    final first = start(today);
    final end = DateTime(today.year, today.month, today.day + 1);
    return combinedBy(
      points.where((p) => !p.date.isBefore(first) && p.date.isBefore(end)),
      (date) {
        final bucket = this.bucket(date);
        return bucket.isBefore(first) ? first : bucket;
      },
      total: total,
    );
  }
}

/// [points] averaged within each [bucket] (added up when [total]), dated
/// at the bucket's start, oldest first.
List<MetricPoint> combinedBy(
  Iterable<MetricPoint> points,
  DateTime Function(DateTime date) bucket, {
  bool total = false,
}) {
  final buckets = <DateTime, List<double>>{};
  for (final point in points) {
    (buckets[bucket(point.date)] ??= []).add(point.value);
  }
  return [
    for (final MapEntry(key: date, :value) in buckets.entries)
      (date: date, value: total ? _sum(value) : _mean(value)),
  ]..sort((a, b) => a.date.compareTo(b.date));
}

/// A metric's readings by day, for the Latest, Highest, Lowest and Average
/// rows under its chart (Swift `MetricChartReadings`), from the chart's
/// first series: the others are derived from it, as Weight Trend's trend
/// line is, so mixing them in would describe neither.
///
/// A bar chart's day is its total (`total`), as Swift's for a single
/// series; a total across several bar series is not ported, as no screen
/// needs it yet.
class MetricReadings {
  /// Groups [points] by day, averaging a day's readings, or adding them up
  /// for a [total] chart.
  new(List<MetricPoint> points, {bool total = false})
    : days = combinedBy(points, startOfDay, total: total);

  /// One reading a day, oldest first.
  final List<MetricPoint> days;

  /// The most recent day.
  MetricPoint? get latest => days.lastOrNull;

  /// The highest day; a tie goes to the most recent.
  MetricPoint? get highest =>
      _last((value) => value == days.map((d) => d.value).reduce(_max));

  /// The lowest day; a tie goes to the most recent.
  MetricPoint? get lowest =>
      _last((value) => value == days.map((d) => d.value).reduce(_min));

  /// Whether the days differ at all, so Highest and Lowest say something
  /// Latest doesn't.
  bool get hasSpread => days.map((d) => d.value).toSet().length > 1;

  /// The average across days, not readings.
  double? get average =>
      days.isEmpty ? null : _mean([for (final d in days) d.value]);

  MetricPoint? _last(bool Function(double) test) =>
      days.isEmpty ? null : days.lastWhere((d) => test(d.value));
}

double _sum(List<double> values) => values.reduce((a, b) => a + b);
double _mean(List<double> values) => _sum(values) / values.length;
double _max(double a, double b) => a > b ? a : b;
double _min(double a, double b) => a < b ? a : b;
