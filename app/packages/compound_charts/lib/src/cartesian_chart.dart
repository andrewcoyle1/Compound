import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/src/cartesian_painter.dart';
import 'package:compound_charts/src/chart_callout.dart';
import 'package:compound_charts/src/data.dart';
import 'package:compound_charts/src/pinch_gesture_recognizer.dart';
import 'package:flutter/gestures.dart';

/// A chart of [data] over time ([ChartData]): lines, areas, bars, stacked
/// bars and dots on one plot, over faint gridlines, with round values at
/// the trailing edge and dates beneath that never collide. The caller gives
/// it a summary for screen readers; with a [bucketLabel], each bucket is
/// also a node of its own.
///
/// It draws in when first shown, over [AppMotion.progress]: bars grow,
/// areas rise, lines draw from the leading edge and dots pop in. New [data]
/// morphs from whatever is on screen over [AppMotion.standard], even part
/// way through another animation ([ChartDataTween]). Reduced motion shows
/// each at once.
///
/// While a bucket is [selected], a rule runs through it, every series there
/// is marked, and [callout] floats above the chart over it
/// ([ChartCallout]).
///
/// An [interactive] chart, for a detail screen, also takes gestures (a
/// card's chart takes none):
///
/// - Pressing and holding is a trackball: it picks the nearest bucket and
///   follows the finger, telling [onSelected] each bucket with a selection
///   haptic, then null on letting go (Swift QuickCharts'
///   `chartXSelection`).
/// - Pinching zooms into part of the window, from one bucket to all of it,
///   the dates re-ticking as it goes; the value axis refits to what is
///   shown once the fingers lift. One finger then pans, and a double tap
///   shows the whole window again.
/// - Flinging sideways tells [onPage] to show the window before (-1) or
///   after (1); when zoomed in, only from the edge already reached.
///
/// A one-finger drag that starts vertically always reaches the page's
/// scroll.
///
/// A [CartesianChart.compact] chart is a card's: the marks alone.
class CartesianChart extends StatefulWidget {
  /// A chart of [data], [height] tall.
  const new({
    required this.data,
    this.height = AppChartHeight.regular,
    this.interactive = false,
    this.selected,
    this.onSelected,
    this.callout,
    this.onPage,
    this.bucketLabel,
    super.key,
  }) : compact = false;

  /// A card's small chart of [data], filling the space it is given: no
  /// gridlines, labels or gestures, so a carousel or a swipe row around it
  /// keeps every drag. A [ChartYFit.tight] axis fits the values exactly;
  /// a line is finer ([AppChartMark.sparkWidth]) and ends in a dot on the
  /// latest reading; each bucket of a bar chart stands on a stub
  /// ([AppChartMark.stubHeight]), so an empty one still reads as a day. It
  /// draws in and morphs as the full chart does.
  const new compact({required this.data, super.key})
    : height = 0,
      interactive = false,
      selected = null,
      onSelected = null,
      callout = null,
      onPage = null,
      bucketLabel = null,
      compact = true;

  /// What to plot.
  final ChartData data;

  /// The chart's height, its date labels included.
  final double height;

  /// Whether it takes the trackball, zoom, pan and paging gestures.
  final bool interactive;

  /// The bucket picked, marked with a rule and a marker on each series.
  final DateTime? selected;

  /// Called with the bucket under a held finger, and null when let go.
  final ValueChanged<DateTime?>? onSelected;

  /// What the bucket picked holds, shown in a [ChartCallout].
  final Widget? callout;

  /// Called with -1 for the window before this one, 1 for the one after.
  final ValueChanged<int>? onPage;

  /// What a screen reader says for each bucket, as the callout would.
  final String Function(DateTime bucket)? bucketLabel;

  /// Whether it is a card's chart ([CartesianChart.compact]).
  final bool compact;

  @override
  State<CartesianChart> createState() => _CartesianChartState();
}

class _CartesianChartState extends State<CartesianChart>
    with SingleTickerProviderStateMixin {
  final _labels = ChartLabels();
  final _geometry = ChartGeometry();
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener((status) {
      // The plot has settled: place the screen reader's buckets on it. (An
      // animation without a duration ends in a build already under way.)
      if (status.isCompleted && _controller.duration != Duration.zero) {
        setState(() {});
      }
    });
  late var _tween = ChartDataTween(widget.data, widget.data);
  Curve _curve = AppMotion.progress.curve;
  double _startReveal = 0;
  ChartAxis? _from;

  /// The part of the window zoomed into, in microseconds since the epoch,
  /// or null for all of it.
  (double, double)? _view;

  /// The view and the moment under the fingers as a pinch began.
  late ({double span, double anchor}) _pinch;

  /// Whether the view reached the window's start and end as a drag began.
  late (bool, bool) _edges;

  double get _first => widget.data.start.microsecondsSinceEpoch.toDouble();

  double get _last => widget.data.end.microsecondsSinceEpoch.toDouble();

  /// What is to be shown: [CartesianChart.data] within [_view].
  ChartData get _shown {
    final data = widget.data;
    if (_view case (final start, final end)) {
      DateTime time(double microseconds) =>
          DateTime.fromMicrosecondsSinceEpoch(microseconds.round());
      return ChartData(
        series: data.series,
        start: time(start),
        end: time(end),
        bucketDays: data.bucketDays,
        yFit: data.yFit,
      );
    }
    return data;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Drawn in once, when first shown.
    if (_controller.isDismissed) {
      _controller
        ..duration = AppMotion.progress.durationOf(context)
        ..forward();
    }
  }

  @override
  void didUpdateWidget(CartesianChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.data;
    if (data == oldWidget.data) return;
    // Data arriving where there was none draws in, as on first showing,
    // rather than sliding in from the empty window.
    if (oldWidget.data.buckets.isEmpty) {
      _view = null;
      _tween = ChartDataTween(data, data);
      _startReveal = 0;
      _from = null;
      _curve = AppMotion.progress.curve;
      _controller
        ..duration = AppMotion.progress.durationOf(context)
        ..forward(from: 0);
      return;
    }
    // A new window shows all of itself.
    if (data.start != oldWidget.data.start || data.end != oldWidget.data.end) {
      _view = null;
    }
    _morph();
  }

  @override
  void dispose() {
    _controller.dispose();
    _labels.dispose();
    super.dispose();
  }

  /// Morphs to [_shown] from what is on screen, however far an animation
  /// had got.
  void _morph() {
    final t = _curve.transform(_controller.value);
    _tween = ChartDataTween(_tween.transform(t), _shown);
    _startReveal += (1 - _startReveal) * t;
    _from = _geometry.axis;
    _curve = AppMotion.standard.curve;
    _controller
      ..duration = AppMotion.standard.durationOf(context)
      ..forward(from: 0);
  }

  /// Holds what is on screen, its value axis included, so a gesture moves
  /// only the window until [_morph] refits the axis.
  void _freeze() {
    final t = _curve.transform(_controller.value);
    final now = _tween.transform(t);
    _tween = ChartDataTween(now, now);
    _startReveal += (1 - _startReveal) * t;
    _from = _geometry.axis;
    _controller.value = 0;
  }

  /// Shows [span] microseconds of the window, [anchor] lying [at] across
  /// the plot, kept between one bucket and the whole window.
  void _zoomTo(double span, {required double anchor, double at = 0}) {
    final whole = _last - _first;
    final bucket = widget.data.bucketDays * Duration.microsecondsPerDay;
    final shown = span.clamp(math.min(bucket, whole), whole);
    final start = (anchor - shown * at).clamp(_first, _last - shown);
    _view = shown >= whole ? null : (start, start + shown);
    final data = _shown;
    _tween = ChartDataTween(data, data);
  }

  /// How far across the plot [dx] is, from 0 to 1.
  double _across(double dx) {
    final plot = _geometry.plot;
    return (dx - plot.left) / plot.width;
  }

  double _xOf(DateTime x) =>
      _geometry.plot.left + _geometry.plot.width * _shown.fraction(x);

  void _pick(Offset position) {
    final shown = _shown;
    final buckets = shown.buckets.where(shown.contains);
    if (buckets.isEmpty) return;
    double distance(DateTime x) => (_xOf(x) - position.dx).abs();
    final nearest = buckets.reduce((a, b) => distance(b) < distance(a) ? b : a);
    if (nearest == widget.selected) return;
    unawaited(AppHaptics.selection());
    widget.onSelected!(nearest);
  }

  void _onPinchStart(ScaleStartDetails details) {
    final (start, end) = _view ?? (_first, _last);
    _pinch = (
      span: end - start,
      anchor: start + (end - start) * _across(details.localFocalPoint.dx),
    );
    setState(_freeze);
  }

  void _onPinchUpdate(ScaleUpdateDetails details) {
    final pinch = _pinch;
    setState(
      () => _zoomTo(
        pinch.span / details.scale,
        anchor: pinch.anchor,
        at: _across(details.localFocalPoint.dx),
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    final view = _view;
    _edges = view == null
        ? (true, true)
        : (view.$1 <= _first, view.$2 >= _last);
    if (view != null) setState(_freeze);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_view case (final start, final end)) {
      final span = end - start;
      setState(
        () => _zoomTo(
          span,
          anchor: start - span * details.delta.dx / _geometry.plot.width,
        ),
      );
    }
  }

  void _onDragEnd(DragEndDetails details) {
    // Zero unless it was a fling.
    final velocity = details.velocity.pixelsPerSecond.dx;
    final (atStart, atEnd) = _edges;
    if (velocity > 0 && atStart) {
      widget.onPage?.call(-1);
    } else if (velocity < 0 && atEnd) {
      widget.onPage?.call(1);
    }
    if (_view != null) setState(_morph);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;
    if (selected != null && _geometry.plot.isEmpty) {
      // Picked before the plot was first painted: place the callout once
      // it has been.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    final plot = RepaintBoundary(
      child: CustomPaint(
        painter: CartesianPainter(
          data: _tween,
          progress: _controller,
          curve: _curve,
          startReveal: _startReveal,
          from: _from,
          labels: _labels,
          geometry: _geometry,
          labelStyle: AppTextStyles.label.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          gridColor: scheme.outlineVariant,
          ruleColor: scheme.onSurfaceVariant,
          markerRing: context.appColors.canvas,
          selected: selected,
          locale: context.dateLocale,
          bucketLabel: widget.bucketLabel,
          compact: widget.compact,
        ),
      ),
    );
    if (widget.compact) return SizedBox.expand(child: plot);
    final chart = Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(height: widget.height, width: double.infinity, child: plot),
        Positioned.fill(
          child: ChartCallout(
            anchorX: selected == null ? 0 : _xOf(selected),
            child: selected == null ? null : widget.callout,
          ),
        ),
      ],
    );
    if (!widget.interactive) return chart;
    final onSelected = widget.onSelected;
    return RawGestureDetector(
      gestures: {
        if (onSelected != null)
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(debugOwner: this),
                (recognizer) => recognizer
                  ..onLongPressStart = ((d) => _pick(d.localPosition))
                  ..onLongPressMoveUpdate = ((d) => _pick(d.localPosition))
                  ..onLongPressEnd = ((_) => onSelected(null)),
              ),
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              HorizontalDragGestureRecognizer
            >(
              () => HorizontalDragGestureRecognizer(debugOwner: this),
              (recognizer) => recognizer
                ..onStart = _onDragStart
                ..onUpdate = _onDragUpdate
                ..onEnd = _onDragEnd,
            ),
        PinchGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PinchGestureRecognizer>(
              PinchGestureRecognizer.new,
              (recognizer) => recognizer
                ..onStart = _onPinchStart
                ..onUpdate = _onPinchUpdate
                ..onEnd = ((_) => setState(_morph)),
            ),
        if (_view != null)
          DoubleTapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
                () => DoubleTapGestureRecognizer(debugOwner: this),
                (recognizer) => recognizer
                  ..onDoubleTap = (() => setState(() {
                    _view = null;
                    _morph();
                  })),
              ),
      },
      child: chart,
    );
  }
}
