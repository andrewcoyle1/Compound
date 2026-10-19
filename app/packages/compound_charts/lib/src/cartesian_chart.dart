import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/src/cartesian_painter.dart';
import 'package:compound_charts/src/chart_callout.dart';
import 'package:compound_charts/src/data.dart';

/// A chart of [data] over time ([ChartData]): lines, areas, bars, stacked
/// bars and dots on one plot, over faint gridlines, with round values at
/// the trailing edge and dates beneath that never collide. It has no
/// semantics of its own; the caller gives it a summary.
///
/// It draws in when first shown, over [AppMotion.progress]: bars grow,
/// areas rise, lines draw from the leading edge and dots pop in. New [data]
/// morphs from whatever is on screen over [AppMotion.standard], even part
/// way through another animation ([ChartDataTween]). Reduced motion shows
/// each at once.
///
/// Pressing and holding picks the nearest bucket, marked with a rule, and
/// tells [onSelected] its date, then null on letting go (Swift QuickCharts'
/// `chartXSelection`). While one is [selected], [callout] floats above the
/// chart over it ([ChartCallout]).
class CartesianChart extends StatefulWidget {
  /// A chart of [data], [height] tall.
  const new({
    required this.data,
    this.height = AppChartHeight.regular,
    this.selected,
    this.onSelected,
    this.callout,
    super.key,
  });

  /// What to plot.
  final ChartData data;

  /// The chart's height, its date labels included.
  final double height;

  /// The bucket picked, marked with a rule.
  final DateTime? selected;

  /// Called with the bucket under a held finger, and null when let go.
  final ValueChanged<DateTime?>? onSelected;

  /// What the bucket picked holds, shown in a [ChartCallout].
  final Widget? callout;

  @override
  State<CartesianChart> createState() => _CartesianChartState();
}

class _CartesianChartState extends State<CartesianChart>
    with SingleTickerProviderStateMixin {
  final _labels = ChartLabels();
  final _geometry = ChartGeometry();
  late final _controller = AnimationController(vsync: this);
  late var _tween = ChartDataTween(widget.data, widget.data);
  Curve _curve = AppMotion.progress.curve;
  double _startReveal = 0;
  ChartAxis? _from;

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
    if (widget.data == oldWidget.data) return;
    // From what is on screen, however far an animation had got.
    final t = _curve.transform(_controller.value);
    _tween = ChartDataTween(_tween.transform(t), widget.data);
    _startReveal += (1 - _startReveal) * t;
    _from = _geometry.axis;
    _curve = AppMotion.standard.curve;
    _controller
      ..duration = AppMotion.standard.durationOf(context)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _labels.dispose();
    super.dispose();
  }

  double _xOf(DateTime x) =>
      _geometry.plot.left + _geometry.plot.width * widget.data.fraction(x);

  void _pick(Offset position) {
    final buckets = widget.data.buckets;
    if (buckets.isEmpty) return;
    double distance(DateTime x) => (_xOf(x) - position.dx).abs();
    final nearest = buckets.reduce((a, b) => distance(b) < distance(a) ? b : a);
    if (nearest != widget.selected) widget.onSelected!(nearest);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSelected = widget.onSelected;
    final selected = widget.selected;
    if (selected != null && _geometry.plot.isEmpty) {
      // Picked before the plot was first painted: place the callout once
      // it has been.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    return GestureDetector(
      onLongPressStart: onSelected == null
          ? null
          : (details) => _pick(details.localPosition),
      onLongPressMoveUpdate: onSelected == null
          ? null
          : (details) => _pick(details.localPosition),
      onLongPressEnd: onSelected == null ? null : (_) => onSelected(null),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: RepaintBoundary(
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
                  selected: selected,
                  locale: context.dateLocale,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ChartCallout(
              anchorX: selected == null ? 0 : _xOf(selected),
              child: selected == null ? null : widget.callout,
            ),
          ),
        ],
      ),
    );
  }
}
