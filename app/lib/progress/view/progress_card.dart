import 'package:app_ui/app_ui.dart';

/// A Progress tile (Swift `AnalyticsCard`): title and subtitle, a small
/// chart, then the headline value and its unit. With [onTap] it opens a
/// screen and shows a chevron; without, it is display only.
class ProgressCard extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.chart,
    this.unit,
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

  /// The chart.
  final Widget chart;

  /// Opens the metric's screen; null when it has none yet.
  final VoidCallback? onTap;

  /// The smallest a tile is, before larger text grows it.
  static const minHeight = 120.0;

  /// The chart's height inside a tile.
  static const chartHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    // One line while the tiles sit side by side; as many as needed once the
    // grid is one column, where a cut-off value is worse than a tall tile.
    final maxLines = ProgressCardGrid.isSingleColumn(context) ? null : 1;
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    final unit = this.unit;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTextStyles.sectionTitle,
              maxLines: maxLines,
              overflow: overflow,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(subtitle, style: AppTextStyles.label.secondary(context)),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: SizedBox(height: chartHeight, child: chart),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: AppSpacing.xs,
              children: [
                // A headline number is short; the unit takes what is left.
                // Without a unit the value is words (Energy Balance's
                // "582 kcal deficit"), which wrap.
                if (unit != null) ...[
                  Text(value, style: AppTextStyles.metricSmall),
                  Expanded(
                    child: Text(
                      unit,
                      style: AppTextStyles.label.secondary(context),
                      maxLines: maxLines,
                      overflow: overflow,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(value, style: AppTextStyles.metricSmall),
                  ),
                if (onTap != null)
                  ExcludeSemantics(
                    child: Icon(
                      AppSymbols.disclosure,
                      size: AppIconSize.small.of(context),
                      color: secondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: AppCard(
          style: AppCardStyle.tile,
          child: onTap == null
              ? content
              : InkWell(onTap: onTap, child: content),
        ),
      ),
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
