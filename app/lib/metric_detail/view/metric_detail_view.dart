import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/tips/feature_tips.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

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
    this.decimals,
    this.hero = 0,
    super.key,
  });

  /// The index in [series] of the one whose average leads the chart, such
  /// as Weight Trend's trend line over the readings it is drawn from.
  final int hero;

  /// The decimal places each figure is shown to; by default none for a
  /// total and one for a reading.
  final int? decimals;

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
    final total = series.first.isTotal;
    // Stacked bars (Macros) total every series a day, as Swift's readings
    // do; a single series is just its own.
    final readings = MetricReadings(
      total
          ? [
              for (final s in series)
                if (s.isTotal) ...s.points,
            ]
          : series.first.points,
      total: total,
    );
    String value(double v) => [
      AppFormat.number(
        v,
        maxFractionDigits: decimals ?? (total ? 0 : 1),
        locale: locale,
      ),
      if (unit.isNotEmpty) unit,
    ].join(' ');
    String day(DateTime date) =>
        metricDayText(l10n, date, today, context.dateLocale);

    final latest = readings.latest;
    final highest = readings.highest;
    final lowest = readings.lowest;
    final average = readings.average;
    // The details under the chart, as grouped rows (design-language.md,
    // "Detail").
    final rows = [
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
    ];
    return ScreenTips(
      screen: 'MetricDetailView',
      tips: const [FeatureTips.metricChart],
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          MetricChartPanel(
            title: title,
            series: series,
            range: range,
            today: today,
            value: value,
            onRangeSelected: onRangeSelected,
            hero: hero,
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            AppSection(children: rows),
          ],
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
      ),
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
      ? AppFormat.date(date, style: AppDateStyle.dayMonth, locale: locale)
      : AppFormat.date(date, locale: locale);
}

/// The range picker over a metric's chart, with its header: what a
/// metric screen and an exercise's Charts tab share (Swift `ChartScreen`'s
/// chart).
class MetricChartPanel extends StatelessWidget {
  const new({
    required this.title,
    required this.series,
    required this.range,
    required this.today,
    required this.value,
    required this.onRangeSelected,
    this.ranges = MetricRange.values,
    this.hero = 0,
    super.key,
  });

  /// The index in [series] of the one whose average leads the chart.
  final int hero;

  /// The chart's name, for its accessibility summary.
  final String title;

  /// Every reading of each series.
  final List<MetricChartSeries> series;

  /// The range shown, one of [ranges].
  final MetricRange range;

  /// Today, at midnight: the chart's window ends on it.
  final DateTime today;

  /// A value as shown, with its unit.
  final String Function(double) value;

  /// Called with the range the user picks.
  final ValueChanged<MetricRange> onRangeSelected;

  /// The ranges offered.
  final List<MetricRange> ranges;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RangePicker(range: range, ranges: ranges, onSelected: onRangeSelected),
        const SizedBox(height: AppSpacing.l),
        _Chart(
          title: title,
          series: series,
          range: range,
          today: today,
          value: value,
          hero: hero,
        ),
      ],
    );
  }
}

class _RangePicker extends StatelessWidget {
  const new({
    required this.range,
    required this.ranges,
    required this.onSelected,
  });

  final MetricRange range;
  final List<MetricRange> ranges;
  final ValueChanged<MetricRange> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSegmentedControl<MetricRange>(
      segments: [
        for (final range in ranges)
          AppSegment(
            value: range,
            label: switch (range) {
              MetricRange.week => l10n.chartRangeWeek,
              MetricRange.month => l10n.chartRangeMonth,
              MetricRange.sixMonths => l10n.chartRangeSixMonths,
              MetricRange.year => l10n.chartRangeYear,
            },
            semanticLabel: switch (range) {
              MetricRange.week => l10n.chartRangeWeekName,
              MetricRange.month => l10n.chartRangeMonthName,
              MetricRange.sixMonths => l10n.chartRangeSixMonthsName,
              MetricRange.year => l10n.chartRangeYearName,
            },
          ),
      ],
      selected: range,
      onChanged: onSelected,
    );
  }
}

/// The header (each series' average over the window, and its dates) and
/// the plot, read to a screen reader as one summary, then a bucket at a
/// time. Flinging the plot pages to the window before or after, which
/// screen readers get as actions; pressing and holding shows the bucket
/// under the finger in a callout over the header (Swift QuickCharts'
/// scrolling, selection and `chartCallout`); pinching zooms into the
/// window.
/// Windows stay rolling, as #98 set them: a page is the range's length
/// earlier.
class _Chart extends StatefulWidget {
  const new({
    required this.title,
    required this.series,
    required this.range,
    required this.today,
    required this.value,
    required this.hero,
  });

  final int hero;
  final String title;
  final List<MetricChartSeries> series;
  final MetricRange range;
  final DateTime today;
  final String Function(double) value;

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> {
  /// How many windows back from today's.
  int _page = 0;

  /// The bucket under a held finger.
  DateTime? _selected;

  @override
  void didUpdateWidget(_Chart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range) {
      _page = 0;
      _selected = null;
    }
  }

  /// The last day of the window [page] windows back.
  DateTime _endOf(int page) => DateTime(
    widget.today.year,
    widget.today.month,
    widget.today.day - page * widget.range.days,
  );

  /// Whether a window further back holds anything.
  bool get _hasOlder {
    final start = widget.range.start(_endOf(_page));
    return widget.series.any(
      (s) => s.points.any((p) => p.date.isBefore(start)),
    );
  }

  void _move(int pages) {
    final page = _page + pages;
    if (page < 0 || (pages > 0 && !_hasOlder)) return;
    setState(() {
      _page = page;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final series = widget.series;
    final range = widget.range;
    final value = widget.value;
    final shownEnd = _endOf(_page);
    final start = range.start(shownEnd);
    final end = DateTime(shownEnd.year, shownEnd.month, shownEnd.day + 1);
    final visible = [
      for (final s in series)
        if (s.points.isNotEmpty)
          s.withPoints(range.visible(s.points, shownEnd, total: s.isTotal)),
    ];
    // A total's header is its daily average, over the days in the window
    // that have one; a reading's, the average of what is plotted.
    double? averageIn(MetricChartSeries s, DateTime windowEnd) {
      final shown = range.visible(s.points, windowEnd);
      if (shown.isEmpty) return null;
      if (!s.isTotal) return MetricReadings(shown).average;
      final first = range.start(windowEnd);
      final last = DateTime(windowEnd.year, windowEnd.month, windowEnd.day + 1);
      return MetricReadings([
        for (final p in s.points)
          if (!p.date.isBefore(first) && p.date.isBefore(last)) p,
      ], total: true).average;
    }

    final averages = [
      for (final s in series)
        if (averageIn(s, shownEnd) case final average?)
          (series: s, average: average),
    ];
    String dates(DateTime date) =>
        AppFormat.date(date, locale: context.dateLocale);
    final from = dates(start);
    final to = dates(shownEnd);
    final summary = l10n.chartSemanticSummary(
      widget.title,
      from,
      to,
      averages.isEmpty
          ? l10n.chartNoDataInRange
          : [
              for (final a in averages)
                l10n.chartSemanticSeries(a.series.label, value(a.average)),
            ].join(' '),
    );
    final secondary = AppTextStyles.rowDetail.secondary(context);
    final selected = _selected;
    // The hero: the first series' average over the window, with its change
    // from the window before; any other series under it, smaller.
    final lead = series[widget.hero];
    final primary = averages.where((a) => a.series == lead).firstOrNull;
    final previous = primary == null
        ? null
        : averageIn(primary.series, _endOf(_page + 1));
    final header = [
      _Hero(
        series: lead,
        figure: primary == null ? null : value(primary.average),
        change: primary == null || previous == null
            ? null
            : (
                text: value((primary.average - previous).abs()),
                sign: (primary.average - previous).sign,
                zero: value(0),
                days: range.days,
              ),
        keyed: series.length > 1,
        caption: l10n.metricHeaderDates(
          lead.isTotal ? l10n.metricDailyAverage : l10n.metricAverage,
          from,
          to,
        ),
      ),
      for (final a in averages)
        if (a != primary)
          _SeriesLine(series: a.series, value: value(a.average)),
    ];
    // What a bucket holds: one row per series, as the callout shows it
    // and a screen reader reads it.
    List<ChartCalloutRow> rowsAt(DateTime bucket) => [
      for (final s in visible)
        if (s.points.where((p) => p.date == bucket).firstOrNull
            case final point?)
          (
            name: s.label,
            color: s.color,
            mark: s.mark,
            value: value(point.value),
          ),
    ];
    return Semantics(
      container: true,
      label: summary,
      customSemanticsActions: {
        if (_hasOlder)
          CustomSemanticsAction(label: l10n.chartPreviousPeriod): () =>
              _move(1),
        if (_page > 0)
          CustomSemanticsAction(label: l10n.chartNextPeriod): () => _move(-1),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          // Hidden under the callout while a bucket is picked, keeping its
          // room so nothing moves (Swift's `RangeHeader`). The summary
          // already says it.
          ExcludeSemantics(
            child: Opacity(
              opacity: selected == null ? 1 : 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.s,
                children: header,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          // An empty window still pages, so the chart stays under its
          // message.
          // The gestures have nothing on screen to show them.
          AppTip(
            id: FeatureTips.metricChart,
            title: l10n.tipMetricChartTitle,
            message: l10n.tipMetricChartMessage,
            child: Stack(
              children: [
                CartesianChart(
                  interactive: true,
                  data: ChartData(
                    series: [
                      for (final s in visible)
                        ChartSeries(
                          label: s.label,
                          color: s.color,
                          mark: s.mark,
                          points: [
                            for (final p in s.points) (x: p.date, y: p.value),
                          ],
                        ),
                    ],
                    start: start,
                    end: end,
                    bucketDays: switch (range) {
                      MetricRange.week || MetricRange.month => 1,
                      MetricRange.sixMonths => 7,
                      MetricRange.year => 365 / 12,
                    },
                    // Bars stand on zero; readings fit closely.
                    yFit: visible.any((s) => s.isBar)
                        ? ChartYFit.zero
                        : ChartYFit.tight,
                  ),
                  selected: selected,
                  onSelected: (date) => setState(() => _selected = date),
                  // The chart's -1 is the window before, this one's 1.
                  onPage: (direction) => _move(-direction),
                  bucketLabel: (bucket) => [
                    bucketText(range, bucket, context.dateLocale),
                    for (final row in rowsAt(bucket))
                      '${row.name}, ${row.value}',
                  ].join('. '),
                  callout: selected == null
                      ? null
                      : ChartCalloutSummary(
                          rows: rowsAt(selected),
                          footer: bucketText(
                            range,
                            selected,
                            context.dateLocale,
                          ),
                          noData: l10n.progressNoData,
                        ),
                ),
                if (averages.isEmpty)
                  // Passing touches through to the chart beneath.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Center(
                          child: Text(
                            l10n.chartNoDataInRange,
                            style: secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A bucket's dates in the callout (QuickCharts' `bucketDescription`):
/// "Sat, Sep 19" for a day, "Sep 14 – 20" for a week, "September 2026" for
/// a month.
String bucketText(MetricRange range, DateTime bucket, String locale) {
  String day(DateTime date) =>
      AppFormat.date(date, style: AppDateStyle.dayMonth, locale: locale);
  return switch (range) {
    MetricRange.week || MetricRange.month => AppFormat.date(
      bucket,
      style: AppDateStyle.weekdayDayMonth,
      locale: locale,
    ),
    MetricRange.sixMonths =>
      '${day(bucket)} – '
          '${day(DateTime(bucket.year, bucket.month, bucket.day + 6))}',
    MetricRange.year => AppFormat.date(
      bucket,
      style: AppDateStyle.monthYear,
      locale: locale,
    ),
  };
}

/// A figure and its unit, split at the last space, as [MetricChartPanel]'s
/// `value` writes them ("82.4 kg"); a figure without a unit stays whole.
(String, String?) _split(String value) {
  final split = value.lastIndexOf(' ');
  return split < 0
      ? (value, null)
      : (value.substring(0, split), value.substring(split + 1));
}

/// The chart's hero (design-language.md, "Detail"): the first series'
/// average over the window in the hero face, its change from the window
/// before as a chip, and the dates. [keyed] puts the series' swatch and
/// name over it, when other series share the chart.
class _Hero extends StatelessWidget {
  const new({
    required this.series,
    required this.figure,
    required this.change,
    required this.keyed,
    required this.caption,
  });

  final MetricChartSeries series;

  /// The average with its unit, or null for an empty window.
  final String? figure;

  /// The change from the window before: its size with the unit, its sign,
  /// zero as shown, and the window's length.
  final ({String text, double sign, String zero, int days})? change;

  final bool keyed;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (number, unit) = _split(figure ?? AppFormat.placeholder);
    final change = this.change;
    final steady = change == null || change.text == change.zero;
    return AppHeroStat(
      label: keyed ? series.label : null,
      leading: keyed
          ? ChartSwatch(mark: series.mark, color: series.color)
          : null,
      value: number,
      unit: unit,
      delta: change == null
          ? null
          : AppChip(
              label: l10n.metricChangeFromPrevious(
                steady
                    ? change.zero
                    : '${change.sign > 0 ? '+' : '−'}${change.text}',
                change.days,
              ),
              icon: steady
                  ? AppSymbols.steady
                  : change.sign > 0
                  ? AppSymbols.increase
                  : AppSymbols.reduce,
            ),
      caption: caption,
    );
  }
}

/// Another series in the header: its key and name, then its average.
class _SeriesLine extends StatelessWidget {
  const new({required this.series, required this.value});

  final MetricChartSeries series;

  /// The figure with its unit, as the screen shows values.
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    spacing: AppSpacing.s,
    children: [
      ChartSwatch(mark: series.mark, color: series.color),
      Flexible(
        child: Text(
          series.label,
          style: AppTextStyles.rowDetail.secondary(context),
        ),
      ),
      Text(value, style: AppTextStyles.metricSmall),
    ],
  );
}
