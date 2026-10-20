import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// How far round a [ProgressArc] goes.
enum ArcSweep {
  /// A full turn from the top, clockwise.
  ring(-math.pi / 2, 2 * math.pi),

  /// Three quarters of a turn, open at the foot, clockwise from its left.
  gauge(0.75 * math.pi, 1.5 * math.pi);

  new(this.start, this.angle);

  /// Where it starts, in radians clockwise from three o'clock.
  final double start;

  /// How far it goes, in radians.
  final double angle;
}

/// A ring or a gauge filled to [value] over a track, with round caps and
/// an optional [child] in its middle (Swift's rings, Syncfusion's radial
/// gauge).
///
/// [value] is a share of the sweep: 0 is empty and 1 full. A [ArcSweep.ring]
/// keeps going past 1, lapping itself the way Apple's Activity rings do,
/// its tip casting a shadow on the lap beneath so the overlap reads; a
/// [ArcSweep.gauge] stops at full, since a lap of an open arc reads as a
/// break. [from] starts the fill part way round instead, to show what is
/// left (within one turn).
///
/// It fills from empty when first shown and moves to each new value, over
/// [AppMotion.progress]; reduced motion shows the value at once.
///
/// It grows with the text: [diameter] and [strokeWidth] are its size at
/// the default text size, scaled by the user's, up to the space it is
/// given. [child] keeps the user's text size in the square inside the
/// ring, and is scaled down only if it still cannot fit there, so it never
/// meets the stroke. A screen reader hears
/// [semanticLabel] and [semanticValue] (the share filled, by default), not
/// the child.
class ProgressArc extends StatelessWidget {
  /// A [diameter]-wide arc in [color], filled to [value].
  const new({
    required this.value,
    required this.color,
    required this.diameter,
    this.from = 0,
    this.sweep = ArcSweep.ring,
    this.strokeWidth = AppChartMark.arcWidth,
    this.trackColor,
    this.semanticLabel,
    this.semanticValue,
    this.child,
    super.key,
  });

  /// Where the fill ends, as a share of the sweep.
  final double value;

  /// Where the fill starts, as a share of the sweep.
  final double from;

  /// The fill's colour.
  final Color color;

  /// How wide the arc is at the default text size, its stroke included.
  final double diameter;

  /// A full ring or an open gauge.
  final ArcSweep sweep;

  /// The stroke's width at the default text size: [AppChartMark.arcWidth]
  /// or [AppChartMark.arcWidthSmall].
  final double strokeWidth;

  /// The unfilled part: the theme's neutral `outlineVariant` unless given,
  /// which shows in dark mode too, where a tint of a dark hue all but
  /// vanishes.
  final Color? trackColor;

  /// What the arc measures.
  final String? semanticLabel;

  /// How full it is; the share filled as a percentage unless given.
  final String? semanticValue;

  /// What sits in the middle: the figure, usually.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final end = math.max(
      sweep == ArcSweep.ring ? value : math.min(value, 1),
      0,
    );
    final start = end > 1 ? 0.0 : from.clamp(0, end).toDouble();
    return Semantics(
      label: semanticLabel,
      value:
          semanticValue ??
          AppFormat.percent(
            end - start,
            locale: Localizations.localeOf(context).toLanguageTag(),
          ),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(
            MediaQuery.textScalerOf(context).scale(diameter),
            constraints.biggest.shortestSide,
          );
          final stroke = strokeWidth * side / diameter;
          final inner = (side - 2 * stroke) / math.sqrt2;
          // Square and centred, however the parent constrains it.
          return Align(
            widthFactor: 1,
            heightFactor: 1,
            child: TweenAnimationBuilder<(double, double)>(
              tween: _SpanTween(
                begin: (start, start),
                end: (start, end.toDouble()),
              ),
              duration: AppMotion.progress.durationOf(context),
              curve: AppMotion.progress.curve,
              builder: (context, span, child) => CustomPaint(
                painter: _ArcPainter(
                  from: span.$1,
                  to: span.$2,
                  sweep: sweep,
                  width: stroke,
                  color: color,
                  track:
                      trackColor ??
                      Theme.of(context).colorScheme.outlineVariant,
                  shadow: Theme.of(context).colorScheme.shadow
                      .withValues(alpha: AppChartMark.lapShadowOpacity),
                ),
                child: child,
              ),
              child: SizedBox.square(
                dimension: side,
                child: Center(
                  child: SizedBox.square(
                    dimension: math.max(inner, 0),
                    child: child == null
                        ? null
                        : FittedBox(fit: BoxFit.scaleDown, child: child),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpanTween extends Tween<(double, double)> {
  new({super.begin, super.end});

  @override
  (double, double) lerp(double t) => (
    begin!.$1 + (end!.$1 - begin!.$1) * t,
    begin!.$2 + (end!.$2 - begin!.$2) * t,
  );
}

/// Paints a [ProgressArc]: the track, then the fill from [from] to [to].
class _ArcPainter extends CustomPainter {
  /// The arc's painter.
  const new({
    required this.from,
    required this.to,
    required this.sweep,
    required this.width,
    required this.color,
    required this.track,
    required this.shadow,
  });

  /// Where the fill starts, as a share of the sweep.
  final double from;

  /// Where the fill ends, past 1 for a ring that laps.
  final double to;

  /// The arc's shape.
  final ArcSweep sweep;

  /// The stroke's width.
  final double width;

  /// The fill's colour.
  final Color color;

  /// The track's colour.
  final Color track;

  /// The colour of the shadow a lapping tip casts.
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    double angle(double at) => sweep.start + sweep.angle * at;
    canvas.drawArc(rect, sweep.start, sweep.angle, false, paint..color = track);
    if (to <= from) return;
    paint.color = color;
    if (to <= 1) {
      canvas.drawArc(
        rect,
        angle(from),
        sweep.angle * (to - from),
        false,
        paint,
      );
      return;
    }
    // A full lap beneath, then the last half turn over it, its tip
    // shadowed onto the lap (kept within the stroke).
    canvas
      ..drawArc(rect, sweep.start, sweep.angle, false, paint)
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(rect.inflate(width / 2))
          ..addOval(rect.deflate(width / 2)),
      )
      ..drawCircle(
        // Just ahead of the tip, so the shadow falls on the lap it leads.
        rect.center +
            Offset.fromDirection(angle(to), rect.width / 2) +
            Offset.fromDirection(angle(to) + math.pi / 2, width / 3),
        width / 2,
        Paint()
          ..color = shadow
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width / 2),
      )
      ..restore()
      ..drawArc(rect, angle(to - 0.5), sweep.angle / 2, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.sweep != sweep ||
      oldDelegate.width != width ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.shadow != shadow;
}
