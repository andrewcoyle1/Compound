import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/progress/bloc/progress_bloc.dart' show ProgressPoint;

/// The small charts inside the Progress cards (Swift `SparklineChart`,
/// `SetsBarChart`, `MacroStackedBarChart`, `MacroProgressChart` and the
/// card `ContributionGridView`). Each is drawn with a [CustomPainter] and
/// carries one accessibility summary, [semanticsLabel] and
/// [semanticsValue], since a screen reader cannot read a plot.
sealed class CardChart extends StatelessWidget {
  const new({this.semanticsLabel, this.semanticsValue, super.key});

  /// What the chart shows.
  final String? semanticsLabel;

  /// What it says.
  final String? semanticsValue;

  CustomPainter _painter(BuildContext context);

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    value: semanticsValue,
    child: CustomPaint(painter: _painter(context), size: Size.infinite),
  );
}

/// A line through [points], against time, ending in a dot. One point is a
/// dot; none draws nothing.
final class Sparkline extends CardChart {
  const new({
    required this.points,
    required this.color,
    super.semanticsLabel,
    super.semanticsValue,
    super.key,
  });

  /// The readings, oldest first.
  final List<ProgressPoint> points;

  /// The line's colour.
  final Color color;

  @override
  CustomPainter _painter(BuildContext context) =>
      _SparklinePainter(points: points, color: color);
}

class _SparklinePainter extends CustomPainter {
  new({required this.points, required this.color});

  final List<ProgressPoint> points;
  final Color color;

  static const _dot = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = points.map((p) => p.value);
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final first = points.first.date.millisecondsSinceEpoch;
    final span = points.last.date.millisecondsSinceEpoch - first;
    final width = size.width - _dot * 2;
    final height = size.height - _dot * 2;
    Offset at(ProgressPoint p) => Offset(
      _dot +
          (span == 0
              ? width / 2
              : (p.date.millisecondsSinceEpoch - first) / span * width),
      _dot +
          (high == low ? height / 2 : (high - p.value) / (high - low) * height),
    );
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final point in points.skip(1)) {
      path.lineTo(at(point).dx, at(point).dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(at(points.last), _dot, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}

/// Bars in [slots] equal slots, each stacked from [stacks]' values in
/// [colors] order; slots past the data stay empty. A [line], one value a
/// slot, is drawn over them in [lineColor] (Energy Balance's expenditure).
/// Heights are against the tallest bar or line point.
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
  CustomPainter _painter(BuildContext context) => _BarsPainter(
    stacks: stacks,
    colors: colors,
    slots: slots,
    line: line ?? const [],
    lineColor: lineColor ?? Theme.of(context).colorScheme.onSurface,
    empty: Theme.of(context).colorScheme.outlineVariant,
  );
}

class _BarsPainter extends CustomPainter {
  new({
    required this.stacks,
    required this.colors,
    required this.slots,
    required this.empty,
    this.line = const [],
    this.lineColor = const Color(0x00000000),
  });

  final List<List<double>> stacks;
  final List<Color> colors;
  final int slots;
  final Color empty;
  final List<double> line;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final totals = [for (final s in stacks) s.fold<double>(0, (a, b) => a + b)];
    final tallest = [...totals, ...line].fold<double>(0, math.max);
    final slot = size.width / slots;
    final barWidth = slot * 0.6;
    for (var i = 0; i < slots; i++) {
      final left = i * slot + (slot - barWidth) / 2;
      final total = i < totals.length ? totals[i] : 0.0;
      if (total <= 0 || tallest <= 0) {
        // A stub, so an empty slot still reads as a day.
        canvas.drawRRect(
          RRect.fromLTRBR(
            left,
            size.height - 2,
            left + barWidth,
            size.height,
            const Radius.circular(1),
          ),
          Paint()..color = empty,
        );
        continue;
      }
      var bottom = size.height;
      for (final (j, value) in stacks[i].indexed) {
        if (value <= 0) continue;
        final top = bottom - value / tallest * size.height;
        canvas.drawRect(
          Rect.fromLTRB(left, top, left + barWidth, bottom),
          Paint()..color = colors[j % colors.length],
        );
        bottom = top;
      }
    }
    if (line.isEmpty || tallest <= 0) return;
    Offset at(int i) => Offset(
      i * slot + slot / 2,
      size.height - line[i] / tallest * size.height,
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < line.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.stacks != stacks ||
      old.colors != colors ||
      old.empty != empty ||
      old.line != line ||
      old.lineColor != lineColor;
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
  CustomPainter _painter(BuildContext context) => _ProgressPainter(
    current: current,
    maximum: maximum,
    target: target,
    color: color,
    mark: Theme.of(context).colorScheme.onSurface,
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
  CustomPainter _painter(BuildContext context) =>
      _GridPainter(days: days, color: color);
}

class _GridPainter extends CustomPainter {
  new({required this.days, required this.color});

  final List<bool> days;
  final Color color;

  static const _rows = 3;
  static const _gap = 3.0;

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
        RRect.fromLTRBR(x, y, x + cell, y + cell, const Radius.circular(2)),
        done ? filled : blank,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.days != days || old.color != color;
}
