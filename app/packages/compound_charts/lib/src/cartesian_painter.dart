import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/src/data.dart';
import 'package:compound_charts/src/scale.dart';
import 'package:flutter/foundation.dart';

/// Where a [CartesianPainter] last drew its plot, for finding the bucket
/// under a finger.
class ChartGeometry {
  /// The plot, inside the axis labels.
  Rect plot = Rect.zero;
}

/// Axis labels laid out once and kept while they are still drawn: each
/// paint asks for the labels it needs, and [end] lets go of the rest.
class ChartLabels {
  final _laidOut = <String, TextPainter>{};
  final _used = <String>{};
  TextStyle? _style;
  TextScaler _scaler = TextScaler.noScaling;
  TextDirection _direction = TextDirection.ltr;

  /// Sets how labels are drawn, dropping any drawn otherwise.
  void configure(TextStyle style, TextScaler scaler, TextDirection direction) {
    if (style == _style && scaler == _scaler && direction == _direction) {
      return;
    }
    _style = style;
    _scaler = scaler;
    _direction = direction;
    _clear(_laidOut.keys.toList());
  }

  /// [text], laid out.
  TextPainter operator [](String text) {
    _used.add(text);
    return _laidOut[text] ??= TextPainter(
      text: TextSpan(text: text, style: _style),
      textDirection: _direction,
      textScaler: _scaler,
    )..layout();
  }

  /// Lets go of every label not asked for since the last call.
  void end() {
    _clear([
      for (final text in _laidOut.keys)
        if (!_used.contains(text)) text,
    ]);
    _used.clear();
  }

  /// Lets go of every label.
  void dispose() => _clear(_laidOut.keys.toList());

  void _clear(List<String> texts) {
    for (final text in texts) {
      _laidOut.remove(text)!.dispose();
    }
  }
}

/// Paints [data]'s series over gridlines, with the values at the trailing
/// edge and the dates beneath. It repaints whenever [data] notifies, so an
/// animation of the data can drive it.
class CartesianPainter extends CustomPainter {
  /// Paints [data], with a rule through [selected] when there is one.
  new({
    required this.data,
    required this.labels,
    required this.geometry,
    required this.labelStyle,
    required this.textScaler,
    required this.textDirection,
    required this.gridColor,
    required this.ruleColor,
    this.selected,
    this.locale,
  }) : super(repaint: data);

  /// What to plot.
  final ValueListenable<ChartData> data;

  /// Where labels are laid out, kept between paints.
  final ChartLabels labels;

  /// Where the plot is drawn, filled in while painting.
  final ChartGeometry geometry;

  /// The axis labels' style.
  final TextStyle labelStyle;

  /// The axis labels' scale.
  final TextScaler textScaler;

  /// The axis labels' direction.
  final TextDirection textDirection;

  /// The gridlines' colour.
  final Color gridColor;

  /// The colour of the rule through [selected].
  final Color ruleColor;

  /// The bucket picked.
  final DateTime? selected;

  /// The locale values and dates are written in.
  final String? locale;

  @override
  void paint(Canvas canvas, Size size) {
    final data = this.data.value;
    labels.configure(labelStyle, textScaler, textDirection);
    final lineHeight = labels['0'].height;
    final top = lineHeight / 2;
    final bottom = size.height - lineHeight - AppSpacing.xs;

    // Bars stack, so the axis must reach each stack's total.
    final stacks = <DateTime, double>{};
    final values = <double>[];
    for (final s in data.series) {
      for (final p in s.points) {
        if (s.mark == ChartMark.bar) {
          stacks[p.x] = (stacks[p.x] ?? 0) + p.y;
        } else {
          values.add(p.y);
        }
      }
    }
    values.addAll(stacks.values);
    final ticks = values.isEmpty
        ? const <double>[]
        : _ticks(
            values,
            data.yFit,
            (bottom - top) / (lineHeight + AppSpacing.s),
          );

    final digits = ticks.length > 1 ? fractionDigits(ticks[1] - ticks[0]) : 0;
    final yLabels = [
      for (final tick in ticks)
        labels[AppFormat.number(
          tick,
          maxFractionDigits: digits,
          locale: locale,
        )],
    ];
    final labelWidth = yLabels.fold<double>(0, (w, l) => math.max(w, l.width));
    final plot = Rect.fromLTRB(
      0,
      top,
      size.width - (yLabels.isEmpty ? 0 : labelWidth + AppSpacing.s),
      bottom,
    );
    geometry.plot = plot;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = AppChartMark.gridWidth;
    final low = ticks.firstOrNull ?? 0;
    final high = ticks.lastOrNull ?? 1;
    double yOf(double value) =>
        plot.bottom - plot.height * (value - low) / (high - low);
    double xOf(DateTime x) => plot.left + plot.width * data.fraction(x);
    if (ticks.isEmpty) {
      canvas.drawLine(plot.bottomLeft, plot.bottomRight, grid);
    }
    for (final (i, tick) in ticks.indexed) {
      final y = yOf(tick);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      yLabels[i].paint(
        canvas,
        Offset(plot.right + AppSpacing.s, y - yLabels[i].height / 2),
      );
    }
    for (final label in dateTicks(
      start: data.start,
      end: data.end,
      width: plot.width,
      measure: (text) => labels[text].width,
      locale: locale,
    )) {
      labels[label.text].paint(
        canvas,
        Offset(plot.left + label.left, bottom + AppSpacing.xs),
      );
    }

    if (ticks.isNotEmpty) {
      final bucketWidth =
          plot.width *
          data.bucketDays *
          Duration.minutesPerDay /
          data.end.difference(data.start).inMinutes;
      _paintBars(canvas, data, xOf, yOf, bucketWidth);
      for (final s in data.series.where((s) => s.mark == ChartMark.area)) {
        _paintLine(canvas, s, xOf, yOf, fillTo: plot);
      }
      for (final s in data.series.where((s) => s.mark == ChartMark.line)) {
        _paintLine(canvas, s, xOf, yOf);
      }
      for (final s in data.series.where((s) => s.mark == ChartMark.dot)) {
        _paintDots(canvas, s, xOf, yOf);
      }
    }

    if (selected case final date?) {
      final x = xOf(date);
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = ruleColor
          ..strokeWidth = AppChartMark.ruleWidth,
      );
    }
    labels.end();
  }

  /// The value axis's ticks for [values]: from 2 to 5, and fewer than
  /// [room], the plot's height in labels, so their labels never touch.
  static List<double> _ticks(List<double> values, ChartYFit fit, double room) {
    var low = values.reduce(math.min);
    var high = values.reduce(math.max);
    if (fit == ChartYFit.zero) {
      low = math.min(low, 0);
      high = math.max(high, 0);
      if (low == high) high = 1;
    }
    return niceTicks(low, high, (room.ceil() - 1).clamp(2, 5));
  }

  /// The bar series, stacked in order, each stack's top corners rounded.
  void _paintBars(
    Canvas canvas,
    ChartData data,
    double Function(DateTime) xOf,
    double Function(double) yOf,
    double bucketWidth,
  ) {
    final bars = data.series.where((s) => s.mark == ChartMark.bar).toList();
    // The series on top of each stack.
    final tops = <DateTime, ChartSeries>{
      for (final s in bars)
        for (final p in s.points)
          if (p.y != 0) p.x: s,
    };
    final width = math.max(
      bucketWidth * AppChartMark.barFill,
      AppChartMark.lineWidth,
    );
    final base = <DateTime, double>{};
    for (final s in bars) {
      final paint = Paint()..color = s.color;
      for (final p in s.points) {
        final below = base[p.x] ?? 0;
        final above = below + p.y;
        base[p.x] = above;
        final x = xOf(p.x);
        final corner = identical(tops[p.x], s)
            ? const Radius.circular(AppChartMark.barCorner)
            : Radius.zero;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromPoints(
              Offset(x - width / 2, yOf(below)),
              Offset(x + width / 2, yOf(above)),
            ),
            topLeft: corner,
            topRight: corner,
          ),
          paint,
        );
      }
    }
  }

  /// A line series, or an area's line and its fill down to [fillTo]'s
  /// bottom. A lone point, with nothing to join, is a dot.
  void _paintLine(
    Canvas canvas,
    ChartSeries series,
    double Function(DateTime) xOf,
    double Function(double) yOf, {
    Rect? fillTo,
  }) {
    final points = [for (final p in series.points) Offset(xOf(p.x), yOf(p.y))];
    if (points.length < 2) return _paintDots(canvas, series, xOf, yOf);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final (c1, c2, end) in monotoneCubics(points)) {
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    }
    if (fillTo != null) {
      canvas.drawPath(
        Path.from(path)
          ..lineTo(points.last.dx, fillTo.bottom)
          ..lineTo(points.first.dx, fillTo.bottom)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              series.color.withValues(alpha: AppChartMark.areaOpacity),
              series.color.withValues(alpha: 0),
            ],
          ).createShader(fillTo),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = series.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppChartMark.lineWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintDots(
    Canvas canvas,
    ChartSeries series,
    double Function(DateTime) xOf,
    double Function(double) yOf,
  ) {
    final paint = Paint()..color = series.color;
    for (final p in series.points) {
      canvas.drawCircle(
        Offset(xOf(p.x), yOf(p.y)),
        AppChartMark.dotRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CartesianPainter oldDelegate) =>
      oldDelegate.data.value != data.value ||
      oldDelegate.selected != selected ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.ruleColor != ruleColor ||
      oldDelegate.locale != locale;
}

/// The cubic Bézier segments of a monotone curve through [points], whose x
/// only grows (Fritsch–Carlson): each segment's control points, then its
/// end. The curve never rises above or dips below the points either side
/// of it, so a smoothed line never shows a value that was not read.
List<(Offset, Offset, Offset)> monotoneCubics(List<Offset> points) {
  final n = points.length;
  if (n < 2) return const [];
  final slopes = [
    for (var i = 0; i < n - 1; i++)
      switch (points[i + 1].dx - points[i].dx) {
        0 => 0.0,
        final dx => (points[i + 1].dy - points[i].dy) / dx,
      },
  ];
  // Each point's tangent: the mean of the slopes either side, flat at a
  // peak or a trough.
  final tangents = [
    slopes.first,
    for (var i = 1; i < n - 1; i++)
      if (slopes[i - 1] * slopes[i] <= 0)
        0.0
      else
        (slopes[i - 1] + slopes[i]) / 2,
    slopes.last,
  ];
  for (var i = 0; i < n - 1; i++) {
    if (slopes[i] == 0) {
      tangents[i] = 0;
      tangents[i + 1] = 0;
      continue;
    }
    // Tangents steeper than three times the slope would overshoot.
    final a = tangents[i] / slopes[i];
    final b = tangents[i + 1] / slopes[i];
    final length = math.sqrt(a * a + b * b);
    if (length > 3) {
      tangents[i] = 3 * a / length * slopes[i];
      tangents[i + 1] = 3 * b / length * slopes[i];
    }
  }
  return [
    for (var i = 0; i < n - 1; i++)
      if ((points[i + 1].dx - points[i].dx) / 3 case final third)
        (
          Offset(points[i].dx + third, points[i].dy + tangents[i] * third),
          Offset(
            points[i + 1].dx - third,
            points[i + 1].dy - tangents[i + 1] * third,
          ),
          points[i + 1],
        ),
  ];
}
