import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';

/// One series on a metric chart: what it is called, its points in the unit
/// shown, its colour, and whether it is drawn as a line, as bars or as dots.
/// Bars are totals (sets, say), so their buckets add up rather than average.
class const MetricChartSeries({
  required final String label,
  required final List<MetricPoint> points,
  required final Color color,
  final bool isLine = false,
  final bool isBar = false,
}) {
  /// This series with [points] in place of its own.
  MetricChartSeries withPoints(List<MetricPoint> points) => MetricChartSeries(
    label: label,
    points: points,
    color: color,
    isLine: isLine,
    isBar: isBar,
  );
}

/// The plot under a metric's header: [series] between [start] and [end],
/// with three value gridlines labelled at the trailing edge. Drawn with a
/// [CustomPainter] rather than a chart package. It has no semantics of its
/// own; the caller gives it a summary.
class MetricChart extends StatelessWidget {
  const new({
    required this.series,
    required this.start,
    required this.end,
    required this.bucketDays,
    super.key,
  });

  /// The series, already windowed and bucketed, dots before lines.
  final List<MetricChartSeries> series;

  /// The first day shown, at midnight.
  final DateTime start;

  /// The day after the last one shown, at midnight.
  final DateTime end;

  /// How many days one plotted point stands for, so it sits in the middle
  /// of its bucket.
  final double bucketDays;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SizedBox(
      height: AppChartHeight.regular,
      child: CustomPaint(
        size: Size.infinite,
        painter: _MetricChartPainter(
          series: series,
          start: start,
          end: end,
          bucketDays: bucketDays,
          gridColor: scheme.outlineVariant,
          labelStyle: AppTextStyles.label.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textScaler: MediaQuery.textScalerOf(context),
          locale: locale,
        ),
      ),
    );
  }
}

class _MetricChartPainter extends CustomPainter {
  new({
    required this.series,
    required this.start,
    required this.end,
    required this.bucketDays,
    required this.gridColor,
    required this.labelStyle,
    required this.textScaler,
    required this.locale,
  });

  final List<MetricChartSeries> series;
  final DateTime start;
  final DateTime end;
  final double bucketDays;
  final Color gridColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final String locale;

  static const _dotRadius = 3.5;
  static const _lineWidth = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final s in series)
        for (final p in s.points) p.value,
    ];
    if (values.isEmpty) return;
    // Bars stand on zero.
    final bars = series.any((s) => s.isBar);
    final (low, high) = niceBounds(
      bars ? 0 : values.reduce(math.min),
      values.reduce(math.max),
    );

    final labels = [
      for (final value in [high, (low + high) / 2, low])
        TextPainter(
          text: TextSpan(
            text: AppFormat.number(value, maxFractionDigits: 1, locale: locale),
            style: labelStyle,
          ),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout(),
    ];
    final labelWidth = labels.map((l) => l.width).reduce(math.max);
    final plot = Rect.fromLTRB(
      0,
      labels.first.height / 2,
      size.width - labelWidth - AppSpacing.s,
      size.height - labels.last.height / 2,
    );

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final (i, label) in labels.indexed) {
      final y = plot.top + plot.height * i / (labels.length - 1);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      label.paint(
        canvas,
        Offset(plot.right + AppSpacing.s, y - label.height / 2),
      );
    }

    final span = end.difference(start).inMinutes;
    final half = (bucketDays * 24 * 60 / 2).round();
    Offset at(MetricPoint p) {
      final minutes = p.date.difference(start).inMinutes + half;
      final x = (minutes / span).clamp(0.0, 1.0);
      return Offset(
        plot.left + plot.width * x,
        plot.bottom - plot.height * (p.value - low) / (high - low),
      );
    }

    final bucketWidth = plot.width * half * 2 / span;
    for (final s in series) {
      final points = s.points.map(at).toList();
      if (s.isBar) {
        final bar = Paint()..color = s.color;
        final width = math.max(bucketWidth * 0.6, 2);
        for (final point in points) {
          canvas.drawRRect(
            RRect.fromLTRBAndCorners(
              point.dx - width / 2,
              point.dy,
              point.dx + width / 2,
              plot.bottom,
              topLeft: const Radius.circular(2),
              topRight: const Radius.circular(2),
            ),
            bar,
          );
        }
      } else if (s.isLine && points.length > 1) {
        canvas.drawPath(
          Path()..addPolygon(points, false),
          Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = _lineWidth
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
      } else {
        // Dots, and a line's lone reading, which has nothing to join.
        final dot = Paint()..color = s.color;
        for (final point in points) {
          canvas.drawCircle(point, _dotRadius, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MetricChartPainter old) =>
      old.series != series ||
      old.start != start ||
      old.end != end ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old.locale != locale;
}

/// The value axis for readings from [low] to [high]: whole numbers around
/// them, at least two apart, with an even span so the middle gridline is
/// whole too.
(double, double) niceBounds(double low, double high) {
  var bottom = low.floorToDouble();
  var top = high.ceilToDouble();
  if (top - bottom < 2) {
    bottom = ((low + high) / 2).roundToDouble() - 1;
    top = bottom + 2;
  }
  if ((top - bottom) % 2 != 0) top += 1;
  return (bottom, top);
}
