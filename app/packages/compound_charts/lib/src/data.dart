import 'package:app_ui/app_ui.dart';

/// One reading on a chart: when, and its value. The x axis is always time.
typedef ChartPoint = ({DateTime x, double y});

/// How a [ChartSeries] is drawn.
enum ChartMark {
  /// A monotone curve through the points, which never overshoots them.
  line,

  /// A [line] over a fill that fades out towards the axis.
  area,

  /// A bar per point, standing on the axis. Bar series stack, in order.
  bar,

  /// A dot per point.
  dot,
}

/// How the value axis fits the data (Swift QuickCharts' `YAxisFit`).
enum ChartYFit {
  /// From zero, as bars must start.
  zero,

  /// Closely around the values, as a line of readings such as weight is.
  tight,
}

/// One series on a chart.
class const ChartSeries({
  /// What the series is called, as a legend names it.
  required final String label,

  /// One point per bucket, oldest first.
  required final List<ChartPoint> points,

  /// The colour it is drawn in.
  required final Color color,

  /// How it is drawn.
  final ChartMark mark = ChartMark.line,
}) {
  /// Creates a [ChartSeries].
  this;
}

/// What a chart plots, across a window of time.
class const ChartData({
  /// The series, drawn bars first, then areas, lines and dots.
  required final List<ChartSeries> series,

  /// The window's first moment.
  required final DateTime start,

  /// The moment after the window's last.
  required final DateTime end,

  /// How many days a point stands for. It is drawn in the middle of them.
  final double bucketDays = 1,

  /// How the value axis fits the values.
  final ChartYFit yFit = ChartYFit.tight,
}) {
  /// Creates a [ChartData].
  this;

  /// How far across the window a point at [x] is drawn, from 0 to 1: the
  /// middle of its bucket.
  double fraction(DateTime x) {
    final half = bucketDays * Duration.minutesPerDay / 2;
    final minutes = x.difference(start).inMinutes + half;
    return (minutes / end.difference(start).inMinutes).clamp(0, 1);
  }

  /// Every bucket some series has a point in, oldest first.
  List<DateTime> get buckets => {
    for (final s in series)
      for (final p in s.points) p.x,
  }.toList()..sort();
}
