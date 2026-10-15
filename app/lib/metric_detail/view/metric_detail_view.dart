import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/metric_detail/view/metric_chart.dart';
import 'package:intl/intl.dart' show DateFormat;

/// A metric's screen body (Swift `MetricDetailView`): the range picker, the
/// average of what is on screen, the chart, the Latest, Highest, Lowest and
/// Average rows, an optional [summary], and a way to every entry. The first
/// of [series] is the readings the rows describe; the rest are derived from
/// it. A bar series is a total: its days and buckets add up, the figures are
/// whole numbers and the average is the daily average.
class MetricDetailView extends StatelessWidget {
  const new({
    required this.title,
    required this.unit,
    required this.series,
    required this.range,
    required this.today,
    required this.onRangeSelected,
    required this.onShowAllData,
    this.summary,
    super.key,
  });

  /// A section shown above Show All Data, such as Expenditure's estimate
  /// for today (Swift `summarySection`).
  final Widget? summary;

  /// The metric's name, for the chart's accessibility summary.
  final String title;

  /// The unit symbol every value is shown with, such as `kg`.
  final String unit;

  /// Every reading of each series, in [unit].
  final List<MetricChartSeries> series;

  /// The chart's range.
  final MetricRange range;

  /// Today, at midnight: the chart's window ends on it.
  final DateTime today;

  /// Called with the range the user picks.
  final ValueChanged<MetricRange> onRangeSelected;

  /// Opens every entry.
  final VoidCallback onShowAllData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final total = series.first.isBar;
    final readings = MetricReadings(series.first.points, total: total);
    String value(double v) => [
      AppFormat.number(v, maxFractionDigits: total ? 0 : 1, locale: locale),
      if (unit.isNotEmpty) unit,
    ].join(' ');
    String day(DateTime date) => metricDayText(l10n, date, today, locale);

    final latest = readings.latest;
    final highest = readings.highest;
    final lowest = readings.lowest;
    final average = readings.average;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        _RangePicker(range: range, onSelected: onRangeSelected),
        const SizedBox(height: AppSpacing.l),
        _Chart(
          title: title,
          series: series,
          range: range,
          today: today,
          value: value,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          children: [
            if (latest != null)
              AppListRow(
                title: l10n.metricLatest(day(latest.date)),
                accessory: AppListRowValue(value(latest.value)),
              ),
            // With every day alike, these would only repeat Latest.
            if (readings.hasSpread) ...[
              AppListRow(
                title: l10n.metricHighest(day(highest!.date)),
                accessory: AppListRowValue(value(highest.value)),
              ),
              AppListRow(
                title: l10n.metricLowest(day(lowest!.date)),
                accessory: AppListRowValue(value(lowest.value)),
              ),
            ],
            if (average != null)
              AppListRow(
                title: total ? l10n.metricDailyAverage : l10n.metricAverage,
                accessory: AppListRowValue(value(average)),
              ),
          ],
        ),
        if (summary case final summary?) ...[
          const SizedBox(height: AppSpacing.xl),
          summary,
        ],
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          children: [
            AppListRowButton(
              title: l10n.metricShowAllData,
              onPressed: onShowAllData,
            ),
          ],
        ),
      ],
    );
  }
}

/// "Today", "Yesterday", "12 Sep", or "12 Sep 2025" outside this year
/// (Swift `MetricChartReadings.Day.dateText`).
String metricDayText(
  AppLocalizations l10n,
  DateTime date,
  DateTime today,
  String locale,
) {
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return l10n.metricToday;
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return l10n.metricYesterday;
  }
  return date.year == today.year
      ? DateFormat.MMMd(locale).format(date)
      : DateFormat.yMMMd(locale).format(date);
}

class _RangePicker extends StatelessWidget {
  const new({required this.range, required this.onSelected});

  final MetricRange range;
  final ValueChanged<MetricRange> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<MetricRange>(
      showSelectedIcon: false,
      segments: [
        for (final range in MetricRange.values)
          ButtonSegment(
            value: range,
            label: Text(switch (range) {
              MetricRange.week => l10n.chartRangeWeek,
              MetricRange.month => l10n.chartRangeMonth,
              MetricRange.sixMonths => l10n.chartRangeSixMonths,
              MetricRange.year => l10n.chartRangeYear,
            }),
            tooltip: switch (range) {
              MetricRange.week => l10n.chartRangeWeekName,
              MetricRange.month => l10n.chartRangeMonthName,
              MetricRange.sixMonths => l10n.chartRangeSixMonthsName,
              MetricRange.year => l10n.chartRangeYearName,
            },
          ),
      ],
      selected: {range},
      onSelectionChanged: (selected) => onSelected(selected.single),
    );
  }
}

/// The header (each series' average over the range, and the dates) and
/// the plot, read to a screen reader as one summary.
class _Chart extends StatelessWidget {
  const new({
    required this.title,
    required this.series,
    required this.range,
    required this.today,
    required this.value,
  });

  final String title;
  final List<MetricChartSeries> series;
  final MetricRange range;
  final DateTime today;
  final String Function(double) value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final start = range.start(today);
    final end = DateTime(today.year, today.month, today.day + 1);
    final visible = [
      for (final s in series)
        if (s.points.isNotEmpty)
          s.withPoints(range.visible(s.points, today, total: s.isBar)),
    ];
    // A total's header is its daily average, over the days in the range
    // that have one; a reading's, the average of what is plotted.
    final averages = [
      for (final s in series)
        if (range.visible(s.points, today) case final shown
            when shown.isNotEmpty)
          (
            series: s,
            average: s.isBar
                ? MetricReadings([
                    for (final p in s.points)
                      if (!p.date.isBefore(start) && p.date.isBefore(end)) p,
                  ], total: true).average!
                : MetricReadings(shown).average!,
          ),
    ];
    final dates = DateFormat.yMMMd(locale);
    final from = dates.format(start);
    final to = dates.format(today);
    final summary = l10n.chartSemanticSummary(
      title,
      from,
      to,
      averages.isEmpty
          ? l10n.chartNoDataInRange
          : [
              for (final a in averages)
                l10n.chartSemanticSeries(a.series.label, value(a.average)),
            ].join(' '),
    );
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Semantics(
      container: true,
      label: summary,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xs,
          children: [
            Text(
              (series.first.isBar
                      ? l10n.metricDailyAverage
                      : l10n.metricAverage)
                  .toUpperCase(),
              style: AppTextStyles.label.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            for (final a in averages)
              Row(
                spacing: AppSpacing.s,
                children: [
                  Text(value(a.average), style: AppTextStyles.metric),
                  _Swatch(series: a.series),
                  Flexible(child: Text(a.series.label, style: secondary)),
                ],
              ),
            Text('$from – $to', style: secondary),
            const SizedBox(height: AppSpacing.s),
            if (averages.isEmpty)
              SizedBox(
                height: AppChartHeight.regular,
                child: Center(
                  child: Text(l10n.chartNoDataInRange, style: secondary),
                ),
              )
            else
              MetricChart(
                series: visible,
                start: start,
                end: end,
                bucketDays: switch (range) {
                  MetricRange.week || MetricRange.month => 1,
                  MetricRange.sixMonths => 7,
                  MetricRange.year => 365 / 12,
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// A series' key in the header: a dot for dots, a dash for a line, so the
/// two differ by shape as well as colour.
class _Swatch extends StatelessWidget {
  const new({required this.series});

  final MetricChartSeries series;

  @override
  Widget build(BuildContext context) {
    final size = series.isLine
        ? const Size(AppSpacing.l, AppSpacing.xs)
        : const Size.square(AppSpacing.s);
    // One width for both, so the labels line up.
    return SizedBox(
      width: AppSpacing.l,
      child: Center(
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: series.color,
            borderRadius: BorderRadius.circular(AppSpacing.xs),
          ),
        ),
      ),
    );
  }
}
