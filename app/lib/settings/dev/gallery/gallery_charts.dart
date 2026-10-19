import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/dev/gallery/gallery_entry.dart';
import 'package:compound_charts/compound_charts.dart';

// Every public `compound_charts` widget. A test fails while a widget the
// package exports has no entry here.

/// [ChartCallout] with a [ChartCalloutSummary].
List<Widget> galleryCharts(BuildContext context) {
  final l10n = context.l10n;
  final colors = context.appColors;
  final locale = context.dateLocale;
  String kg(double value) =>
      AppFormat.weight(value, AppWeightUnit.kilograms, locale: locale);
  ChartCalloutSummary summary(List<ChartCalloutRow> rows) =>
      ChartCalloutSummary(
        rows: rows,
        footer: AppFormat.date(
          DateTime(2026, 10, 18),
          style: AppDateStyle.weekdayMedium,
          locale: locale,
        ),
        noData: l10n.progressNoData,
      );
  return [
    galleryEntry('ChartCallout', [
      for (final (caption, anchor, rows) in [
        (
          'two series, centred',
          0.5,
          [
            (
              name: l10n.scaleWeightTitle,
              color: colors.scaleWeight,
              value: kg(82.5),
            ),
            (
              name: l10n.weightTrendSeries,
              color: colors.expenditure,
              value: kg(82.1),
            ),
          ],
        ),
        (
          'one unnamed series, at the left edge',
          0.0,
          [(name: null, color: null, value: l10n.calendarLogged)],
        ),
        ('no rows (noData), at the right edge', 1.0, <ChartCalloutRow>[]),
      ])
        galleryBlock(caption, _plot(anchor, summary(rows))),
    ]),
  ];
}

/// A stand-in plot with [callout] over it at [anchor] across its width, and
/// room above for the callout.
Widget _plot(double anchor, Widget callout) => Padding(
  padding: const EdgeInsets.only(top: AppChartHeight.regular),
  child: LayoutBuilder(
    builder: (context, constraints) => Stack(
      clipBehavior: Clip.none,
      children: [
        const AppCard(
          style: AppCardStyle.tile,
          child: SizedBox(
            width: double.infinity,
            height: AppChartHeight.compact,
          ),
        ),
        Positioned.fill(
          child: ChartCallout(
            anchorX: anchor * constraints.maxWidth,
            child: callout,
          ),
        ),
      ],
    ),
  ),
);
