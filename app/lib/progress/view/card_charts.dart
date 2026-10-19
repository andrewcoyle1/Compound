import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/progress/bloc/progress_bloc.dart' show ProgressPoint;
import 'package:compound_charts/compound_charts.dart';

/// The small charts inside the Progress cards (Swift `SparklineChart`,
/// `SetsBarChart`, `MacroStackedBarChart`, `MacroProgressChart` and the
/// card `ContributionGridView`). [Sparkline] and [StackedBars] are
/// [CartesianChart.compact]s; the others are drawn with a [CustomPainter].
/// Each carries one accessibility summary, [semanticsLabel] and
/// [semanticsValue], since a screen reader cannot read a plot.
sealed class CardChart extends StatelessWidget {
  const new({this.semanticsLabel, this.semanticsValue, super.key});

  /// What the chart shows.
  final String? semanticsLabel;

  /// What it says.
  final String? semanticsValue;

  Widget _chart(BuildContext context);

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    value: semanticsValue,
    child: _chart(context),
  );
}

/// A line through [points], against time, edge to edge and fitted closely
/// to their values, ending in a dot on the latest, over a fill that fades
/// out beneath it unless [area] is false. One point is a dot in the
/// middle; none draws nothing.
final class Sparkline extends CardChart {
  const new({
    required this.points,
    required this.color,
    this.area = true,
    super.semanticsLabel,
    super.semanticsValue,
    super.key,
  });

  /// The readings, oldest first.
  final List<ProgressPoint> points;

  /// The line's colour.
  final Color color;

  /// Whether a fill fades out beneath the line.
  final bool area;

  @override
  Widget _chart(BuildContext context) {
    final points = this.points;
    var start = points.firstOrNull?.date ?? _origin;
    var end = points.lastOrNull?.date ?? _origin;
    // Nothing to span: the one day sits in the middle.
    if (!end.isAfter(start)) {
      start = DateTime(start.year, start.month, start.day - 1);
      end = DateTime(end.year, end.month, end.day + 1);
    }
    return CartesianChart.compact(
      data: ChartData(
        start: start,
        end: end,
        // Readings are moments, so the first and last reach the edges.
        bucketDays: 0,
        series: [
          ChartSeries(
            label: '',
            color: color,
            mark: area ? ChartMark.area : ChartMark.line,
            points: [for (final p in points) (x: p.date, y: p.value)],
          ),
        ],
      ),
    );
  }
}

/// Where [StackedBars]' slots, and an empty [Sparkline]'s window, start:
/// any fixed day, so new data morphs in place.
final _origin = DateTime.utc(2026);

/// Bars in [slots] equal slots, a day each, each stacked from [stacks]'
/// values in [colors] order; slots past the data stand on their stub. A
/// [line], one value a slot, is drawn over them in [lineColor] (Energy
/// Balance's expenditure). Heights are from zero to the tallest bar or line
/// point.
final class StackedBars extends CardChart {
  const new({
    required this.stacks,
    required this.colors,
    this.slots = 7,
    this.line,
    this.lineColor,
    super.semanticsLabel,
    super.semanticsValue,
    super.key,
  });

  /// Each bar's pieces, bottom first.
  final List<List<double>> stacks;

  /// The colour of each piece of a bar.
  final List<Color> colors;

  /// How many bars there is room for.
  final int slots;

  /// A line over the bars, one value a slot.
  final List<double>? line;

  /// The [line]'s colour.
  final Color? lineColor;

  @override
  Widget _chart(BuildContext context) {
    DateTime slot(int i) => _origin.add(Duration(days: i));
    final line = this.line;
    return CartesianChart.compact(
      data: ChartData(
        start: _origin,
        end: slot(slots),
        yFit: ChartYFit.zero,
        series: [
          for (final (j, color) in colors.indexed)
            ChartSeries(
              label: '$j',
              color: color,
              mark: ChartMark.bar,
              points: [
                for (final (i, stack) in stacks.indexed)
                  (x: slot(i), y: j < stack.length ? stack[j] : 0),
              ],
            ),
          if (line != null)
            ChartSeries(
              label: 'line',
              color: lineColor ?? Theme.of(context).colorScheme.onSurface,
              points: [for (final (i, y) in line.indexed) (x: slot(i), y: y)],
            ),
        ],
      ),
    );
  }
}

/// A bar filled to [current] of [maximum], with a mark at [target] when
/// there is one.
final class ProgressBarChart extends CardChart {
  const new({
    required this.current,
    required this.maximum,
    required this.color,
    this.target,
    super.semanticsLabel,
    super.semanticsValue,
    super.key,
  });

  /// How far the bar is filled.
  final double current;

  /// The bar's full width.
  final double maximum;

  /// The target mark, or null for none.
  final double? target;

  /// The fill's colour.
  final Color color;

  @override
  Widget _chart(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _ProgressPainter(
      current: current,
      maximum: maximum,
      target: target,
      color: color,
      mark: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _ProgressPainter extends CustomPainter {
  new({
    required this.current,
    required this.maximum,
    required this.target,
    required this.color,
    required this.mark,
  });

  final double current;
  final double maximum;
  final double? target;
  final Color color;
  final Color mark;

  static const _thickness = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - _thickness) / 2;
    const radius = Radius.circular(_thickness / 2);
    canvas.drawRRect(
      RRect.fromLTRBR(0, top, size.width, top + _thickness, radius),
      Paint()..color = color.withValues(alpha: 0.2),
    );
    double share(double value) =>
        maximum <= 0 ? 0 : (value / maximum).clamp(0, 1);
    final filled = share(current) * size.width;
    if (filled > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(0, top, filled, top + _thickness, radius),
        Paint()..color = color,
      );
    }
    final target = this.target;
    if (target != null && target > 0 && target < maximum) {
      final x = share(target) * size.width;
      canvas.drawLine(
        Offset(x, top - 3),
        Offset(x, top + _thickness + 3),
        Paint()
          ..color = mark.withValues(alpha: 0.5)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.current != current ||
      old.maximum != maximum ||
      old.target != target ||
      old.color != color ||
      old.mark != mark;
}

/// The 30-day habit grid: ten columns of three days, oldest at the top
/// left, read down each column; a filled square for each day with the
/// habit.
final class HabitGridChart extends CardChart {
  const new({
    required this.days,
    required this.color,
    super.semanticsLabel,
    super.semanticsValue,
    super.key,
  });

  /// One per day, oldest first.
  final List<bool> days;

  /// The filled squares' colour.
  final Color color;

  @override
  Widget _chart(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _GridPainter(days: days, color: color),
  );
}

class _GridPainter extends CustomPainter {
  new({required this.days, required this.color});

  final List<bool> days;
  final Color color;

  static const _rows = 3;
  static const _gap = 3.0;
  static const double _corner = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = (days.length / _rows).ceil();
    final cell = math.min(
      (size.width - _gap * (columns - 1)) / columns,
      (size.height - _gap * (_rows - 1)) / _rows,
    );
    final filled = Paint()..color = color;
    final blank = Paint()..color = color.withValues(alpha: 0.15);
    for (final (i, done) in days.indexed) {
      final x = (i ~/ _rows) * (cell + _gap);
      final y = (i % _rows) * (cell + _gap);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          y,
          x + cell,
          y + cell,
          const Radius.circular(_corner),
        ),
        done ? filled : blank,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.days != days || old.color != color;
}
