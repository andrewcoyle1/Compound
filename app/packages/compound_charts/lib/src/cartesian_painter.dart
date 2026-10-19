import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/src/data.dart';
import 'package:compound_charts/src/scale.dart';

/// A value axis as drawn: the values at its bottom and top, its round
/// values, and the room its labels take beside the plot, gap included.
typedef ChartAxis = ({
  double low,
  double high,
  List<double> ticks,
  double labelWidth,
});

/// Where a [CartesianPainter] last drew its plot, for finding the bucket
/// under a finger, and its value axis, for the next transition to start
/// from.
class ChartGeometry {
  /// The plot, inside the axis labels.
  Rect plot = Rect.zero;

  /// The value axis, or null before the first paint.
  ChartAxis? axis;
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
/// edge and the dates beneath, [progress] of the way through [data] once
/// [curve] eases it. It repaints whenever [progress] ticks, so the chart
/// animates without rebuilding.
///
/// - Marks move as [ChartDataTween] says.
/// - The value axis slides from [from] (as last drawn) to fit [data]'s end,
///   its round values fading across; the date labels slide with the window
///   and fade likewise.
/// - Marks are revealed from [startReveal] to fully: bars grow from zero,
///   areas rise, lines draw from the leading edge and dots pop in.
class CartesianPainter extends CustomPainter {
  /// Paints [data], with a rule through [selected] when there is one.
  new({
    required this.data,
    required this.progress,
    required this.labels,
    required this.geometry,
    required this.labelStyle,
    required this.textScaler,
    required this.textDirection,
    required this.gridColor,
    required this.ruleColor,
    this.curve = Curves.linear,
    this.startReveal = 1,
    this.from,
    this.selected,
    this.locale,
  }) : super(repaint: progress);

  /// What to plot, from what was on screen to what is to be.
  final ChartDataTween data;

  /// How far through [data], from 0 to 1, before [curve].
  final Animation<double> progress;

  /// How [progress] eases.
  final Curve curve;

  /// How revealed the marks were at the start, from 0 to 1.
  final double startReveal;

  /// The value axis as last drawn, which this one moves from.
  final ChartAxis? from;

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

  /// How far through [data] it is, eased.
  double get t => curve.transform(progress.value);

  /// What is on screen.
  ChartData get shown => data.transform(t);

  /// How revealed the marks are, from 0 to 1.
  double get reveal => startReveal + (1 - startReveal) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final t = this.t;
    final data = shown;
    final reveal = this.reveal;
    labels.configure(labelStyle, textScaler, textDirection);
    final lineHeight = labels['0'].height;
    final top = lineHeight / 2;
    final bottom = size.height - lineHeight - AppSpacing.xs;
    final room = (bottom - top) / (lineHeight + AppSpacing.s);

    // From what was drawn, or else straight to the end; an axis emptied
    // keeps its scale while its values fade.
    final last = from;
    final target =
        _axis(this.data.end, room) ??
        (last == null
            ? (low: 0.0, high: 1.0, ticks: const <double>[], labelWidth: 0.0)
            : (
                low: last.low,
                high: last.high,
                ticks: const <double>[],
                labelWidth: 0.0,
              ));
    final start = last == null || last.ticks.isEmpty ? target : last;
    final low = lerpDouble(start.low, target.low, t)!;
    final high = lerpDouble(start.high, target.high, t)!;
    final labelWidth = lerpDouble(start.labelWidth, target.labelWidth, t)!;
    geometry.axis = (
      low: low,
      high: high,
      ticks: t < 0.5 ? start.ticks : target.ticks,
      labelWidth: labelWidth,
    );
    final plot = Rect.fromLTRB(0, top, size.width - labelWidth, bottom);
    geometry.plot = plot;

    double yOf(double value) =>
        plot.bottom - plot.height * (value - low) / (high - low);
    double xOf(DateTime x) => plot.left + plot.width * data.fraction(x);

    // The value axis: values in both ends stay, the rest fade across.
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, size.width, bottom + top));
    if (target.ticks.isEmpty) {
      canvas.drawLine(plot.bottomLeft, plot.bottomRight, _gridPaint(1));
    }
    void tick(double value, String text, double alpha) {
      final y = yOf(value);
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        _gridPaint(alpha),
      );
      final label = labels[text];
      _faded(
        canvas,
        alpha,
        () => label.paint(
          canvas,
          Offset(plot.right + AppSpacing.s, y - label.height / 2),
        ),
      );
    }

    for (final (i, text) in _tickLabels(start.ticks).indexed) {
      if (!target.ticks.contains(start.ticks[i])) {
        tick(start.ticks[i], text, 1 - t);
      }
    }
    for (final (i, text) in _tickLabels(target.ticks).indexed) {
      final value = target.ticks[i];
      tick(value, text, start.ticks.contains(value) ? 1 : t);
    }
    canvas.restore();

    // The dates, sliding with the window: those at both ends stay, the
    // rest fade across.
    List<(String, double)> dates(ChartData window) {
      final span = data.end.difference(data.start).inMicroseconds;
      final scale = window.end.difference(window.start).inMicroseconds / span;
      final offset =
          plot.width *
          window.start.difference(data.start).inMicroseconds /
          span;
      return [
        for (final label in dateTicks(
          start: window.start,
          end: window.end,
          width: plot.width,
          measure: (text) => labels[text].width,
          locale: locale,
        ))
          (label.text, plot.left + offset + label.left * scale),
      ];
    }

    final before = dates(this.data.begin);
    final after = dates(this.data.end);
    bool among(List<(String, double)> list, (String, double) label) =>
        list.any((l) => l.$1 == label.$1 && (l.$2 - label.$2).abs() < 0.5);
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, bottom, plot.right, size.height));
    void date((String, double) label, double alpha) => _faded(
      canvas,
      alpha,
      () => labels[label.$1].paint(
        canvas,
        Offset(label.$2, bottom + AppSpacing.xs),
      ),
    );
    for (final label in before) {
      if (!among(after, label)) date(label, 1 - t);
    }
    for (final label in after) {
      date(label, among(before, label) ? 1 : t);
    }
    canvas.restore();

    if (target.ticks.isNotEmpty || start.ticks.isNotEmpty) {
      final bucketWidth =
          plot.width *
          data.bucketDays *
          Duration.minutesPerDay /
          data.end.difference(data.start).inMinutes;
      // Marks stay within the plot's width as the window slides; bars
      // stand on the axis, never below it, even while it slides away from
      // zero.
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(plot.left, 0, plot.right, size.height))
        ..save()
        ..clipRect(Rect.fromLTRB(plot.left, 0, plot.right, plot.bottom));
      _paintBars(canvas, data, xOf, yOf, bucketWidth, reveal);
      canvas.restore();
      for (final s in data.series.where((s) => s.mark == ChartMark.area)) {
        _paintLine(canvas, s, xOf, yOf, reveal, fillTo: plot);
      }
      canvas
        ..save()
        ..clipRect(
          Rect.fromLTRB(
            plot.left,
            0,
            plot.left + plot.width * reveal,
            size.height,
          ),
        );
      for (final s in data.series.where((s) => s.mark == ChartMark.line)) {
        _paintLine(canvas, s, xOf, yOf, reveal);
      }
      canvas.restore();
      for (final s in data.series.where((s) => s.mark == ChartMark.dot)) {
        _paintDots(canvas, s, xOf, yOf, reveal);
      }
      canvas.restore();
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

  Paint _gridPaint(double alpha) => Paint()
    ..color = gridColor.withValues(alpha: gridColor.a * alpha)
    ..strokeWidth = AppChartMark.gridWidth;

  /// Runs [paint] at [opacity].
  void _faded(Canvas canvas, double opacity, VoidCallback paint) {
    if (opacity == 1) return paint();
    // A layer takes only its paint's alpha.
    canvas.saveLayer(
      null,
      Paint()..color = ruleColor.withValues(alpha: opacity),
    );
    paint();
    canvas.restore();
  }

  /// The value axis that fits [data] in [room], the plot's height in
  /// labels, or null when it has nothing to plot.
  ChartAxis? _axis(ChartData data, double room) {
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
    if (values.isEmpty) return null;
    final ticks = _ticks(values, data.yFit, room);
    return (
      low: ticks.first,
      high: ticks.last,
      ticks: ticks,
      labelWidth:
          _tickLabels(ticks)
              .map((text) => labels[text].width)
              .reduce(math.max) +
          AppSpacing.s,
    );
  }

  /// [ticks] written out, to the decimals their step needs.
  List<String> _tickLabels(List<double> ticks) {
    final digits = ticks.length > 1 ? fractionDigits(ticks[1] - ticks[0]) : 0;
    return [
      for (final tick in ticks)
        AppFormat.number(tick, maxFractionDigits: digits, locale: locale),
    ];
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

  /// The bar series, stacked in order with a gap between segments, each
  /// stack's top corners rounded, grown [reveal] of the way from zero.
  void _paintBars(
    Canvas canvas,
    ChartData data,
    double Function(DateTime) xOf,
    double Function(double) yOf,
    double bucketWidth,
    double reveal,
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
        final top = yOf(above * reveal);
        // A segment on another leaves a gap above it.
        final bottom =
            yOf(below * reveal) - (below == 0 ? 0 : AppChartMark.stackGap);
        if (bottom <= top) continue;
        final corner = identical(tops[p.x], s)
            ? const Radius.circular(AppChartMark.barCorner)
            : Radius.zero;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(x - width / 2, top, x + width / 2, bottom),
            topLeft: corner,
            topRight: corner,
          ),
          paint,
        );
      }
    }
  }

  /// A line series, or an area's line and its fill down to [fillTo]'s
  /// bottom, risen [reveal] of the way from it, with its points marked if
  /// it [ChartSeries.showsPoints]. A lone point, with nothing to join, is a
  /// dot.
  void _paintLine(
    Canvas canvas,
    ChartSeries series,
    double Function(DateTime) xOf,
    double Function(double) yOf,
    double reveal, {
    Rect? fillTo,
  }) {
    final floor = fillTo?.bottom;
    final points = [
      for (final p in series.points)
        Offset(
          xOf(p.x),
          floor == null ? yOf(p.y) : lerpDouble(floor, yOf(p.y), reveal)!,
        ),
    ];
    if (points.length < 2 || series.showsPoints) {
      _paintDots(canvas, series, xOf, yOf, reveal, at: points);
      if (points.length < 2) return;
    }
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

  /// A dot per point of [series] (or at each of [at]), popping in as
  /// [reveal] reaches 1.
  void _paintDots(
    Canvas canvas,
    ChartSeries series,
    double Function(DateTime) xOf,
    double Function(double) yOf,
    double reveal, {
    List<Offset>? at,
  }) {
    final radius =
        AppChartMark.dotRadius * Curves.easeOutBack.transform(reveal);
    final paint = Paint()..color = series.color;
    for (final centre
        in at ?? [for (final p in series.points) Offset(xOf(p.x), yOf(p.y))]) {
      canvas.drawCircle(centre, radius, paint);
    }
  }

  @override
  bool shouldRepaint(CartesianPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.progress != progress ||
      oldDelegate.curve != curve ||
      oldDelegate.startReveal != startReveal ||
      oldDelegate.from != from ||
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
