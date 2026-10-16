import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';

/// One series on a metric chart: what it is called, its points in the unit
/// shown, its colour, and whether it is drawn as a line, as bars or as dots.
/// Bars are totals (sets, say), so their buckets add up rather than average,
/// unless [total] says otherwise: Energy Balance's intake is drawn as bars
/// of readings, as Swift's combo chart does.
class const MetricChartSeries({
  required final String label,
  required final List<MetricPoint> points,
  required final Color color,
  final bool isLine = false,
  final bool isBar = false,
  final bool? total,
}) {
  /// Whether the series is a total: its buckets add up, its figures are
  /// whole and its average is a daily one. Bars are, unless [total] says.
  bool get isTotal => total ?? isBar;

  /// This series with [points] in place of its own.
  MetricChartSeries withPoints(List<MetricPoint> points) => MetricChartSeries(
    label: label,
    points: points,
    color: color,
    isLine: isLine,
    isBar: isBar,
    total: total,
  );
}

/// The plot under a metric's header: [series] between [start] and [end],
/// with three value gridlines labelled at the trailing edge. Drawn with a
/// [CustomPainter] rather than a chart package. It has no semantics of its
/// own; the caller gives it a summary.
///
/// Pressing and holding picks the nearest plotted bucket, marked with a
/// stick, and tells [onSelected] its date, then null on letting go (Swift
/// QuickCharts' `chartXSelection`).
class MetricChart extends StatefulWidget {
  const new({
    required this.series,
    required this.start,
    required this.end,
    required this.bucketDays,
    this.selected,
    this.onSelected,
    super.key,
  });

  /// The bucket picked, marked with a stick.
  final DateTime? selected;

  /// Called with the bucket under a held finger, and null when let go.
  final ValueChanged<DateTime?>? onSelected;

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
  State<MetricChart> createState() => _MetricChartState();
}

class _MetricChartState extends State<MetricChart> {
  /// Where the painter last drew each point, to find the one under a finger.
  final _plotted = <(DateTime, double)>[];

  void _pick(Offset position) {
    final onSelected = widget.onSelected;
    if (onSelected == null || _plotted.isEmpty) return;
    var nearest = _plotted.first;
    for (final point in _plotted) {
      if ((point.$2 - position.dx).abs() < (nearest.$2 - position.dx).abs()) {
        nearest = point;
      }
    }
    if (nearest.$1 != widget.selected) onSelected(nearest.$1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final onSelected = widget.onSelected;
    return GestureDetector(
      onLongPressStart: onSelected == null
          ? null
          : (details) => _pick(details.localPosition),
      onLongPressMoveUpdate: onSelected == null
          ? null
          : (details) => _pick(details.localPosition),
      onLongPressEnd: onSelected == null ? null : (_) => onSelected(null),
      child: SizedBox(
        height: AppChartHeight.regular,
        child: CustomPaint(
          size: Size.infinite,
          painter: _MetricChartPainter(
            series: widget.series,
            start: widget.start,
            end: widget.end,
            bucketDays: widget.bucketDays,
            selected: widget.selected,
            plotted: _plotted,
            gridColor: scheme.outlineVariant,
            stickColor: scheme.onSurfaceVariant,
            labelStyle: AppTextStyles.label.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textScaler: MediaQuery.textScalerOf(context),
            locale: locale,
          ),
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
    required this.selected,
    required this.plotted,
    required this.gridColor,
    required this.stickColor,
    required this.labelStyle,
    required this.textScaler,
    required this.locale,
  });

  final List<MetricChartSeries> series;
  final DateTime start;
  final DateTime end;
  final double bucketDays;
  final DateTime? selected;

  /// Filled in while painting: each point's date and x.
  final List<(DateTime, double)> plotted;
  final Color gridColor;
  final Color stickColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final String locale;

  static const _dotRadius = 3.5;
  static const _lineWidth = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    // Bars stand on zero, and several bar series stack: each bar starts
    // where the one below it on that date ends.
    final bars = series.any((s) => s.isBar);
    final stacked = <DateTime, double>{};
    for (final s in series.where((s) => s.isBar)) {
      for (final p in s.points) {
        stacked[p.date] = (stacked[p.date] ?? 0) + p.value;
      }
    }
    final values = [
      ...stacked.values,
      for (final s in series)
        if (!s.isBar)
          for (final p in s.points) p.value,
    ];
    plotted.clear();
    if (values.isEmpty) return;
    final (low, high) = bars
        ? niceBounds(0, values.reduce(math.max))
        : readingBounds(values.reduce(math.min), values.reduce(math.max));

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
    final base = <DateTime, double>{};
    for (final s in series) {
      final points = s.points.map(at).toList();
      for (final (i, point) in points.indexed) {
        plotted.add((s.points[i].date, point.dx));
      }
      if (s.isBar) {
        final bar = Paint()..color = s.color;
        final width = math.max(bucketWidth * 0.6, 2);
        for (final (i, point) in points.indexed) {
          final date = s.points[i].date;
          final below = base[date] ?? 0;
          base[date] = below + s.points[i].value;
          final bottom = at((date: date, value: below)).dy;
          final top = at((date: date, value: base[date]!)).dy;
          canvas.drawRRect(
            RRect.fromLTRBAndCorners(
              point.dx - width / 2,
              top,
              point.dx + width / 2,
              bottom,
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

    // The stick through the bucket picked.
    if (selected case final date?) {
      final x = at((date: date, value: low)).dx;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = stickColor
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_MetricChartPainter old) =>
      old.series != series ||
      old.start != start ||
      old.end != end ||
      old.selected != selected ||
      old.gridColor != gridColor ||
      old.stickColor != stickColor ||
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

/// [niceBounds] for readings, in tenths when every reading is between 0 and
/// 2, such as a body ratio, which whole numbers would flatten.
(double, double) readingBounds(double low, double high) {
  if (low < 0 || high >= 2) return niceBounds(low, high);
  final (bottom, top) = niceBounds(low * 10, high * 10);
  return (bottom / 10, top / 10);
}
