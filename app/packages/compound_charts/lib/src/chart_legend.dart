import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/src/data.dart';

/// A key to a chart's [series]: each one's [ChartSwatch] and name, side by
/// side, wrapping onto more lines when they do not fit. For a chart of more
/// than one series; it sits outside the chart, so it reflows with the text.
class ChartLegend extends StatelessWidget {
  /// A key to [series].
  const new({required this.series, super.key});

  /// The series to name, in order.
  final List<ChartSeries> series;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.label.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Wrap(
      spacing: AppSpacing.m,
      runSpacing: AppSpacing.xs,
      children: [
        for (final s in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              ChartSwatch(mark: s.mark, color: s.color),
              Flexible(child: Text(s.label, style: style)),
            ],
          ),
      ],
    );
  }
}

/// A series' key in [color], shaped like its [mark]: a dash for a line or
/// an area, a dot for dots and a small square for bars, so series differ by
/// shape as well as colour.
class ChartSwatch extends StatelessWidget {
  /// The key to a series drawn as [mark] in [color].
  const new({required this.mark, required this.color, super.key});

  /// How the series is drawn.
  final ChartMark mark;

  /// The series' colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final (size, shape) = switch (mark) {
      ChartMark.line || ChartMark.area => (
        const Size(AppSpacing.l, AppSpacing.xs),
        const StadiumBorder(),
      ),
      ChartMark.bar => (
        const Size.square(AppSpacing.s),
        const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppChartMark.barCorner),
          ),
        ),
      ),
      ChartMark.dot => (const Size.square(AppSpacing.s), const CircleBorder()),
    };
    // One width for every mark, so the names line up.
    return SizedBox(
      width: AppSpacing.l,
      child: Center(
        child: SizedBox.fromSize(
          size: size,
          child: DecoratedBox(
            decoration: ShapeDecoration(color: color, shape: shape),
          ),
        ),
      ),
    );
  }
}
