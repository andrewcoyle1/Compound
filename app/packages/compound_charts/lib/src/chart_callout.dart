import 'dart:math' as math;
import 'dart:ui';

import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/src/chart_legend.dart';
import 'package:compound_charts/src/data.dart';

/// Swift QuickCharts' `chartCallout`: [child] in a floating panel just
/// above the chart this fills (put it in a `Positioned.fill` over the
/// plot), centred on [anchorX] and kept inside the chart's width. It pops
/// in and out, keyed on whether there is a [child] rather than which, so it
/// jumps between buckets instead of sliding. It never takes a touch.
class ChartCallout extends StatefulWidget {
  /// A callout at [anchorX] showing [child], or hidden when it is null.
  const new({required this.anchorX, required this.child, super.key});

  /// Where the selected bucket sits across the chart.
  final double anchorX;

  /// The callout's content; null hides it.
  final Widget? child;

  @override
  State<ChartCallout> createState() => _ChartCalloutState();
}

class _ChartCalloutState extends State<ChartCallout>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this)
    ..addStatusListener((status) {
      // Faded out: let go of the content.
      if (status.isDismissed) setState(() => _child = null);
    });
  late final _curved = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.quick.curve,
  );

  /// The last content shown, kept while it fades out.
  Widget? _child;
  double _anchorX = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.quick.durationOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(ChartCallout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.child case final child?) {
      _child = child;
      _anchorX = widget.anchorX;
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _child;
    if (child == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: CustomSingleChildLayout(
        delegate: _CalloutLayout(_anchorX),
        child: FadeTransition(
          opacity: _curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(_curved),
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.s),
              // Swift's `.ultraThinMaterial`.
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: ColoredBox(
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.85),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centres the callout on its x, inside the chart's width, its foot a
/// small gap above the chart's top.
class _CalloutLayout extends SingleChildLayoutDelegate {
  new(this.x);

  final double x;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (x - childSize.width / 2).clamp(
      0,
      math.max(0, size.width - childSize.width),
    ),
    -childSize.height - AppSpacing.s,
  );

  @override
  bool shouldRelayout(_CalloutLayout oldDelegate) => oldDelegate.x != x;
}

/// One line of a [ChartCalloutSummary]: a series' name in its colour,
/// after its [ChartSwatch] when its `mark` is given, over its value. A
/// chart of one unnamed series leaves the name out.
typedef ChartCalloutRow = ({
  String? name,
  Color? color,
  ChartMark? mark,
  String value,
});

/// What a [ChartCallout] says (Swift's `SeriesSummary`): each series' name
/// over its value, side by side (stacked when they don't fit), then a rule
/// and the bucket's dates. With no rows it says [noData].
class ChartCalloutSummary extends StatelessWidget {
  /// Says [rows] over [footer], or [noData] when there are no rows.
  const new({
    required this.rows,
    required this.footer,
    required this.noData,
    super.key,
  });

  /// One per series with a value in the bucket.
  final List<ChartCalloutRow> rows;

  /// The bucket's dates, already formatted.
  final String footer;

  /// What to say when no series has a value.
  final String noData;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          if (rows.isEmpty)
            Text(noData, style: AppTextStyles.metric.copyWith(color: secondary))
          else
            // Side by side while they fit, else one above another, so
            // large text wraps rather than overflowing the chart.
            OverflowBar(
              spacing: AppSpacing.m,
              overflowSpacing: AppSpacing.xs,
              children: [
                for (final row in rows)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (row.name case final name?)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: AppSpacing.xs,
                          children: [
                            if ((row.mark, row.color) case (
                              final mark?,
                              final color?,
                            ))
                              ChartSwatch(mark: mark, color: color),
                            Flexible(
                              child: Text(
                                name,
                                style: AppTextStyles.rowDetail.copyWith(
                                  color: row.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      Text(row.value, style: AppTextStyles.metric),
                    ],
                  ),
              ],
            ),
          const Divider(height: 1),
          Text(
            footer,
            style: AppTextStyles.emphasized(AppTextStyles.label)
                .copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}
