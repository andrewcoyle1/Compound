import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';

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
@immutable
class const ChartSeries({
  /// What the series is called, as a legend names it.
  required final String label,

  /// One point per bucket, oldest first.
  required final List<ChartPoint> points,

  /// The colour it is drawn in.
  required final Color color,

  /// How it is drawn.
  final ChartMark mark = ChartMark.line,

  /// Whether a [ChartMark.line] or [ChartMark.area] also marks each point
  /// with a dot, as a sparse series reads better with.
  final bool showsPoints = false,
}) {
  /// Creates a [ChartSeries].
  this;

  @override
  bool operator ==(Object other) =>
      other is ChartSeries &&
      other.label == label &&
      other.color == color &&
      other.mark == mark &&
      other.showsPoints == showsPoints &&
      listEquals(other.points, points);

  @override
  int get hashCode =>
      Object.hash(label, color, mark, showsPoints, Object.hashAll(points));
}

/// What a chart plots, across a window of time.
@immutable
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

  /// [a] becoming [b], [t] of the way (0 to 1) ([ChartDataTween]).
  static ChartData lerp(ChartData a, ChartData b, double t) =>
      ChartDataTween(a, b).transform(t);

  /// How far across the window a point at [x] is drawn, from 0 to 1 for a
  /// point inside it: the middle of its bucket.
  double fraction(DateTime x) {
    final half = bucketDays * Duration.minutesPerDay / 2;
    final minutes = x.difference(start).inMinutes + half;
    return minutes / end.difference(start).inMinutes;
  }

  /// Whether a point at [x] is drawn inside the window.
  bool contains(DateTime x) {
    final f = fraction(x);
    return f >= 0 && f <= 1;
  }

  /// Every bucket some series has a point in, oldest first.
  List<DateTime> get buckets => {
    for (final s in series)
      for (final p in s.points) p.x,
  }.toList()..sort();

  @override
  bool operator ==(Object other) =>
      other is ChartData &&
      other.start == start &&
      other.end == end &&
      other.bucketDays == bucketDays &&
      other.yFit == yFit &&
      listEquals(other.series, series);

  @override
  int get hashCode =>
      Object.hash(start, end, bucketDays, yFit, Object.hashAll(series));
}

/// One series through a [ChartDataTween]: each point's value at either end.
typedef _Track = ({
  ChartSeries series,
  Color from,
  Color to,
  List<(DateTime x, double from, double to)> points,
});

/// [begin] becoming [end]. Series are matched by label and points by date,
/// once, so each frame only interpolates:
///
/// - the window, the bucket size, the colours and every value move
///   between the two;
/// - a bar that appears grows from zero, and one that goes shrinks to it;
/// - a point that appears on a line, area or dot series starts on the
///   series as it was drawn (between its neighbours, or level with its
///   end), so a line reshapes without spikes; one that goes ends on the
///   new series;
/// - a whole series that appears rises from the baseline (zero on a
///   [ChartYFit.zero] axis, else the lowest value either side), and one
///   that goes sinks to it.
///
/// At 0 it is [begin] and at 1 [end], exactly.
class ChartDataTween extends Animatable<ChartData> {
  /// [begin] becoming [end].
  new(this.begin, this.end) : _tracks = _align(begin, end);

  /// The data at the start.
  final ChartData begin;

  /// The data at the end.
  final ChartData end;

  final List<_Track> _tracks;

  @override
  ChartData transform(double t) {
    if (t == 0) return begin;
    // Drawing in has nothing to move.
    if (t == 1 || identical(begin, end)) return end;
    DateTime time(DateTime a, DateTime b) =>
        DateTime.fromMicrosecondsSinceEpoch(
          lerpDouble(
            a.microsecondsSinceEpoch,
            b.microsecondsSinceEpoch,
            t,
          )!.round(),
        );
    return ChartData(
      start: time(begin.start, end.start),
      end: time(begin.end, end.end),
      bucketDays: lerpDouble(begin.bucketDays, end.bucketDays, t)!,
      yFit: end.yFit,
      series: [
        for (final track in _tracks)
          ChartSeries(
            label: track.series.label,
            color: Color.lerp(track.from, track.to, t)!,
            mark: track.series.mark,
            showsPoints: track.series.showsPoints,
            points: [
              for (final (x, from, to) in track.points)
                (x: x, y: lerpDouble(from, to, t)!),
            ],
          ),
      ],
    );
  }

  static List<_Track> _align(ChartData a, ChartData b) {
    final baseline = b.yFit == ChartYFit.zero
        ? 0.0
        : [
            for (final s in [...a.series, ...b.series])
              if (s.mark != ChartMark.bar)
                for (final p in s.points) p.y,
          ].fold(double.infinity, math.min);
    ChartSeries? named(ChartData data, String label) =>
        data.series.where((s) => s.label == label).firstOrNull;
    // The value [series] stands at on [x], where it has no point there.
    double absent(ChartSeries? series, ChartMark mark, DateTime x) =>
        switch ((series, mark)) {
          (_, ChartMark.bar) => 0,
          (final s?, _) when s.points.isNotEmpty => _valueAt(s.points, x),
          _ => baseline,
        };
    return [
      for (final label in {
        for (final s in [...b.series, ...a.series]) s.label,
      })
        _track(named(a, label), named(b, label), absent),
    ];
  }

  /// One series through the tween, from [from] to [to], one of which may
  /// be missing; [absent] gives a value where a side has no point.
  static _Track _track(
    ChartSeries? from,
    ChartSeries? to,
    double Function(ChartSeries? series, ChartMark mark, DateTime x) absent,
  ) {
    final series = (to ?? from)!;
    final a = {
      for (final p in [...?from?.points]) p.x: p.y,
    };
    final b = {
      for (final p in [...?to?.points]) p.x: p.y,
    };
    return (
      series: series,
      from: (from ?? series).color,
      to: series.color,
      points: [
        for (final x in {...a.keys, ...b.keys}.toList()..sort())
          (
            x,
            a[x] ?? absent(from, series.mark, x),
            b[x] ?? absent(to, series.mark, x),
          ),
      ],
    );
  }

  /// [points]' value at [x], read along straight lines between them, and
  /// level with the first or last beyond them.
  static double _valueAt(List<ChartPoint> points, DateTime x) {
    var before = points.first;
    for (final p in points) {
      if (!p.x.isBefore(x)) {
        if (identical(p, points.first)) return p.y;
        final f =
            x.difference(before.x).inMicroseconds /
            p.x.difference(before.x).inMicroseconds;
        return lerpDouble(before.y, p.y, f)!;
      }
      before = p;
    }
    return before.y;
  }
}
