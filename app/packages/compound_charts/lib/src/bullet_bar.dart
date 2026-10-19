import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// A value along a rounded track, with an optional tick at a [target] and
/// a caret when well over it (Swift's `TargetCellView` and macro bars,
/// Syncfusion's bullet gauge).
///
/// The fill runs from [from] to [value] on a track from 0 to [maximum]:
/// from its start edge across (the start of the reading order), or from
/// the foot up when [direction] is [Axis.vertical]. Values past either end
/// stop there. A [from] above 0 shows what is left rather than what is
/// done. A fill shorter than the bar is thick keeps the track's rounded
/// end, so a small amount still reads.
///
/// It fills from empty when first shown and moves to each new value, over
/// [AppMotion.progress]; reduced motion shows the value at once.
///
/// It fills the length it is given, which must be bounded, and is
/// [thickness] across at the default text size, scaled with the text up to
/// the room it has across; given more, it sits in the middle. A screen
/// reader hears [semanticLabel] and [semanticValue] (the share filled, by
/// default).
class BulletBar extends StatelessWidget {
  /// A bar in [color] filled to [value] of [maximum].
  const new({
    required this.value,
    required this.color,
    this.from = 0,
    this.maximum = 1,
    this.target,
    this.over,
    this.direction = Axis.horizontal,
    this.thickness = AppChartMark.bulletWidth,
    this.trackColor,
    this.semanticLabel,
    this.semanticValue,
    super.key,
  });

  /// Where the fill ends.
  final double value;

  /// Where the fill starts.
  final double from;

  /// The track's full length, in [value]'s units.
  final double maximum;

  /// Where the target's tick goes, or null for none; a target of zero or
  /// less draws none.
  final double? target;

  /// Whether to show the over-target caret past the track's end. Null
  /// leaves no room for one; false keeps the room empty, so a row of bars
  /// where only some are over stays level.
  final bool? over;

  /// Which way the bar runs.
  final Axis direction;

  /// How thick the bar is at the default text size:
  /// [AppChartMark.bulletWidth] or [AppChartMark.bulletWidthSmall].
  final double thickness;

  /// The fill's colour.
  final Color color;

  /// The unfilled track: the theme's neutral `outlineVariant` unless given.
  final Color? trackColor;

  /// What the bar measures.
  final String? semanticLabel;

  /// How full it is; the share filled as a percentage unless given.
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    double share(double at) =>
        maximum <= 0 ? 0 : (at / maximum).clamp(0, 1).toDouble();
    final end = share(value);
    final start = math.min(share(from), end);
    final target = this.target;
    final tick = target == null || target <= 0 ? null : share(target);
    final scheme = Theme.of(context).colorScheme;
    final vertical = direction == Axis.vertical;
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
          final room = vertical ? constraints.maxWidth : constraints.maxHeight;
          // The tick and the caret stand proud of the bar across.
          final natural =
              thickness +
              (tick == null && over == null
                  ? 0
                  : 2 * AppChartMark.tickOverhang);
          // Grow with the text, but only as far as there is room across.
          final scale = math.min(
            MediaQuery.textScalerOf(context).scale(thickness) / thickness,
            room / natural,
          );
          final length = vertical
              ? constraints.maxHeight
              : constraints.maxWidth;
          final size = natural * scale;
          return Align(
            widthFactor: 1,
            heightFactor: 1,
            child: TweenAnimationBuilder<_Span>(
              tween: _SpanTween(
                begin: (from: start, to: start, tick: tick),
                end: (from: start, to: end, tick: tick),
              ),
              duration: AppMotion.progress.durationOf(context),
              curve: AppMotion.progress.curve,
              builder: (context, span, _) => CustomPaint(
                size: vertical ? Size(size, length) : Size(length, size),
                painter: _BulletPainter(
                  span: span,
                  vertical: vertical,
                  textDirection: Directionality.of(context),
                  thickness: thickness * scale,
                  scale: scale,
                  over: over,
                  color: color,
                  track: trackColor ?? scheme.outlineVariant,
                  mark: scheme.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The fill's ends and the tick, as shares of the track.
typedef _Span = ({double from, double to, double? tick});

class _SpanTween extends Tween<_Span> {
  new({super.begin, super.end});

  @override
  _Span lerp(double t) {
    double at(double a, double b) => a + (b - a) * t;
    final (b, e) = (begin!, end!);
    final tick = e.tick;
    return (
      from: at(b.from, e.from),
      to: at(b.to, e.to),
      tick: tick == null ? null : at(b.tick ?? tick, tick),
    );
  }
}

/// Paints a [BulletBar] lying along x from 0, rotated or mirrored into
/// place: the track, the fill clipped to it, the tick, then the caret.
class _BulletPainter extends CustomPainter {
  const new({
    required this.span,
    required this.vertical,
    required this.textDirection,
    required this.thickness,
    required this.scale,
    required this.over,
    required this.color,
    required this.track,
    required this.mark,
  });

  final _Span span;
  final bool vertical;
  final TextDirection textDirection;
  final double thickness;
  final double scale;
  final bool? over;
  final Color color;
  final Color track;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (vertical) {
      canvas
        ..translate(0, size.height)
        ..rotate(-math.pi / 2);
    } else if (textDirection == TextDirection.rtl) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final length = vertical ? size.height : size.width;
    final middle = (vertical ? size.width : size.height) / 2;
    final caret = AppChartMark.caretSize * scale;
    final gap = AppChartMark.tickOverhang * scale;
    final reach = length - (over == null ? 0 : gap + caret);
    final half = thickness / 2;
    final bar = RRect.fromLTRBR(
      0,
      middle - half,
      reach,
      middle + half,
      Radius.circular(half),
    );
    canvas.drawRRect(bar, Paint()..color = track);
    var (left, right) = (span.from * reach, span.to * reach);
    if (right > left) {
      // Too short to round both ends: lengthen it under the track's cap.
      if (right - left < thickness) {
        if (left <= 0) {
          left = right - thickness;
        } else {
          right = left + thickness;
        }
      }
      canvas
        ..save()
        ..clipRRect(bar)
        ..drawRRect(
          RRect.fromLTRBR(
            left,
            middle - half,
            right,
            middle + half,
            Radius.circular(half),
          ),
          Paint()..color = color,
        )
        ..restore();
    }
    final line = Paint()
      ..color = mark
      ..strokeWidth = AppChartMark.tickWidth * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final tick = span.tick;
    if (tick != null) {
      final x = tick * reach;
      canvas.drawLine(
        Offset(x, middle - half - gap),
        Offset(x, middle + half + gap),
        line,
      );
    }
    if (over ?? false) {
      final x = reach + gap;
      canvas.drawPath(
        Path()
          ..moveTo(x, middle - caret)
          ..lineTo(x + caret, middle)
          ..lineTo(x, middle + caret),
        line,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BulletPainter old) =>
      old.span != span ||
      old.vertical != vertical ||
      old.textDirection != textDirection ||
      old.thickness != thickness ||
      old.scale != scale ||
      old.over != over ||
      old.color != color ||
      old.track != track ||
      old.mark != mark;
}
