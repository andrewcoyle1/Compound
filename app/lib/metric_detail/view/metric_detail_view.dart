import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/metric_detail/view/metric_chart.dart';
import 'package:compound/widgets/chart_callout.dart';
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
    super.key,
  });

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
    // Latest under the chart, and the rest one tap away in a sheet
    // (QuickCharts' Show More), so the chart keeps the screen.
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        MetricChartPanel(
          title: title,
          series: series,
          range: range,
          today: today,
          value: value,
          onRangeSelected: onRangeSelected,
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          AppSection(children: [rows.first]),
          if (rows.length > 1)
            Center(
              child: AppTextButton(
                label: l10n.metricShowMoreData(title),
                onPressed: () => showAppSheet<void>(
                  context: context,
                  size: AppSheetSize.compact,
                  builder: (_) => ListView(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    children: [AppSection(header: title, children: rows)],
                  ),
                ),
              ),
            ),
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
    super.key,
  });

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
/// the plot, read to a screen reader as one summary. Swiping pages to the
/// window before or after, which screen readers get as actions; pressing
/// and holding shows the bucket under the finger in a callout over the
/// header (Swift QuickCharts' scrolling, selection and `chartCallout`).
/// Windows stay rolling, as #98 set them: a page is the range's length
/// earlier.
class _Chart extends StatefulWidget {
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
    final scheme = Theme.of(context).colorScheme;
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
    final averages = [
      for (final s in series)
        if (range.visible(s.points, shownEnd) case final shown
            when shown.isNotEmpty)
          (
            series: s,
            average: s.isTotal
                ? MetricReadings([
                    for (final p in s.points)
                      if (!p.date.isBefore(start) && p.date.isBefore(end)) p,
                  ], total: true).average!
                : MetricReadings(shown).average!,
          ),
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
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final selected = _selected;
    // Swift's chart header: each series' name in its colour over its
    // figure, then what the figure is and the dates.
    final header = [
      for (final a in averages)
        _SeriesLine(series: a.series, value: value(a.average)),
      Text(
        l10n.metricHeaderDates(
          series.first.isTotal ? l10n.metricDailyAverage : l10n.metricAverage,
          from,
          to,
        ),
        style: secondary,
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
      child: ExcludeSemantics(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity == 0) return;
            // A swipe towards the end of the line shows the window before.
            _move((velocity > 0) != rtl ? 1 : -1);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xs,
            children: [
              // Hidden under the callout while a bucket is picked, keeping
              // its room so nothing moves (Swift's `RangeHeader`).
              Opacity(
                opacity: selected == null ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: header,
                ),
              ),
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
                  selected: selected,
                  onSelected: (date) => setState(() => _selected = date),
                  callout: selected == null
                      ? null
                      : ChartCalloutSummary(
                          rows: [
                            for (final s in visible)
                              if (s.points
                                      .where((p) => p.date == selected)
                                      .firstOrNull
                                  case final point?)
                                (
                                  name: s.label,
                                  color: s.color,
                                  value: value(point.value),
                                ),
                          ],
                          footer: bucketText(
                            range,
                            selected,
                            context.dateLocale,
                          ),
                          noData: l10n.progressNoData,
                        ),
                ),
            ],
          ),
        ),
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

/// One series in the header: its key and name in its colour, over its
/// figure with the unit set small.
class _SeriesLine extends StatelessWidget {
  const new({required this.series, required this.value});

  final MetricChartSeries series;

  /// The figure with its unit, as the screen shows values.
  final String value;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    // The unit is the last word, when there is one.
    final split = value.lastIndexOf(' ');
    final (figure, unit) = split < 0
        ? (value, null)
        : (value.substring(0, split), value.substring(split));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: AppSpacing.s,
          children: [
            _Swatch(series: series),
            Flexible(
              child: Text(
                series.label,
                style: AppTextStyles.rowDetail.copyWith(color: series.color),
              ),
            ),
          ],
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: figure, style: AppTextStyles.metricLarge),
              if (unit != null)
                TextSpan(
                  text: unit,
                  style: AppTextStyles.rowDetail.copyWith(color: secondary),
                ),
            ],
          ),
        ),
      ],
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
