import 'package:app_ui/app_ui.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound_charts/compound_charts.dart' show BulletBar;

/// A Progress tile (Swift `AnalyticsCard`) as a summary card
/// ([AppSummaryCard]): [icon] in its data colour and the title as an
/// overline, the headline value and its unit over a small chart, and what
/// the chart covers under it. With [onTap] the whole card opens the
/// metric's screen; without, it is display only. Screen readers hear the
/// chart's own summary after the value.
class ProgressCard extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.chart,
    this.unit,
    this.icon,
    this.tint,
    this.onTap,
    super.key,
  });

  /// The metric's name.
  final String title;

  /// What the chart covers, or why it is empty.
  final String subtitle;

  /// The headline number, or `AppFormat.placeholder`.
  final String value;

  /// Shown after [value], such as `kg` or "sets".
  final String? unit;

  /// The metric's glyph, from [AppSymbols].
  final IconData? icon;

  /// The metric's data colour, for [icon].
  final Color? tint;

  /// The chart.
  final Widget chart;

  /// Opens the metric's screen; null when it has none yet.
  final VoidCallback? onTap;

  /// The chart's height inside a tile.
  static const chartHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final chart = this.chart;
    return AppSummaryCard(
      title: title,
      icon: icon,
      tint: tint,
      value: value,
      unit: unit,
      chart: SizedBox(
        width: double.infinity,
        height: chartHeight,
        child: chart,
      ),
      footer: subtitle,
      onTap: onTap,
      semanticValue: switch (chart) {
        CardChart(:final semanticsLabel, :final semanticsValue) => [
          ?semanticsLabel,
          ?semanticsValue,
        ].join(', '),
        BulletBar(:final semanticValue) => semanticValue,
        _ => null,
      },
    );
  }
}

/// The tiles of one Progress section (Swift `AnalyticsCardGrid`): two
/// columns on a phone and up to four as the screen widens, so a tile stays
/// tile-sized on a tablet; one column at the largest text sizes, where two
/// tiles side by side cut off their titles and values. Tiles in a row
/// share its height.
class ProgressCardGrid extends StatelessWidget {
  const new({required this.children, super.key});

  /// The tiles.
  final List<Widget> children;

  /// The narrowest a tile gets before the grid drops a column.
  static const tileWidth = 220.0;

  /// The text scale from which the grid is one column, about where iOS's
  /// accessibility sizes begin.
  static const singleColumnTextScale = 1.5;

  /// Whether the text is large enough for one column.
  static bool isSingleColumn(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) >= singleColumnTextScale;

  /// How many columns fit [width]: 2 to 4, or 1 for [singleColumn].
  static int columnsFor(double width, {bool singleColumn = false}) =>
      singleColumn ? 1 : (width ~/ tileWidth).clamp(2, 4);

  @override
  Widget build(BuildContext context) {
    final singleColumn = isSingleColumn(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.maxWidth,
          singleColumn: singleColumn,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s,
          children: [
            for (var start = 0; start < children.length; start += columns)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.s,
                  children: [
                    for (var i = start; i < start + columns; i++)
                      Expanded(
                        child: i < children.length
                            ? children[i]
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
