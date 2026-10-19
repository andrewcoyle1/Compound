import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/progress/view/progress_card.dart';
import 'package:compound/settings/dev/gallery/gallery_entry.dart';
import 'package:compound_charts/compound_charts.dart';

// Every public `compound_charts` widget. A test fails while a widget the
// package exports has no entry here.

/// [CartesianChart] in each mark, [ChartLegend] and [ChartSwatch], and
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
  final macros = [
    for (final (label, color, grams) in [
      (l10n.progressProtein, colors.protein, <double>[160, 150, 175, 168]),
      (l10n.nutritionMacroCarbs, colors.carbs, <double>[220, 260, 200, 240]),
      (l10n.nutritionMacroFat, colors.fat, <double>[70, 64, 82, 75]),
    ])
      ChartSeries(
        label: label,
        color: color,
        mark: ChartMark.bar,
        points: _days([...grams, ...grams.reversed.take(3)]),
      ),
  ];
  final weight = [
    ChartSeries(
      label: l10n.scaleWeightTitle,
      color: colors.scaleWeight,
      mark: ChartMark.dot,
      points: _days([73.1, 72.6, 72.9, 72.4, 72.5, 72.1, 72]),
    ),
    ChartSeries(
      label: l10n.weightTrendSeries,
      color: colors.expenditure,
      points: _days([72.9, 72.8, 72.7, 72.6, 72.5, 72.4, 72.3]),
    ),
  ];
  final charts = [
    for (final (caption, data) in [
      ('dots and a line, a week', _week(weight)),
      (
        'a line with point markers',
        _week([
          ChartSeries(
            label: l10n.weightTrendSeries,
            color: colors.expenditure,
            showsPoints: true,
            points: _days([72.9, 72.6, 72.7, 72.3, 72.4, 72.1, 71.9]),
          ),
        ]),
      ),
      (
        'area, a month',
        ChartData(
          start: DateTime(2026, 9, 19),
          end: DateTime(2026, 10, 19),
          series: [
            ChartSeries(
              label: l10n.progressSteps,
              color: colors.steps,
              mark: ChartMark.area,
              points: [
                for (var i = 0; i < 30; i++)
                  (
                    x: DateTime(2026, 9, 19 + i),
                    y: 8000 + 2500 * math.sin(i / 4) + i * 60,
                  ),
              ],
            ),
          ],
        ),
      ),
      ('stacked bars from zero', _week(macros, yFit: ChartYFit.zero)),
      ('empty', _week(const [])),
    ])
      (caption, data),
  ];
  return [
    galleryEntry('CartesianChart', [
      for (final (caption, data) in charts)
        galleryBlock(caption, CartesianChart(data: data)),
      for (final (caption, data) in [
        (
          'compact: a sparkline',
          _spark(weight.last.points, colors.expenditure, ChartMark.line),
        ),
        (
          'compact: a sparkline with area',
          _spark(weight.last.points, colors.expenditure, ChartMark.area),
        ),
        (
          'compact: stacked bars with a line, a day empty',
          _week([
            for (final s in macros)
              ChartSeries(
                label: s.label,
                color: s.color,
                mark: ChartMark.bar,
                // Two days logged, a day missed, two more.
                points: [
                  for (final (i, p) in s.points.take(5).indexed)
                    (x: p.x, y: i == 2 ? 0.0 : p.y),
                ],
              ),
            ChartSeries(
              label: l10n.expenditureTitle,
              color: colors.expenditure,
              points: _days([500, 520, 510, 530, 525, 515, 540]),
            ),
          ], yFit: ChartYFit.zero),
        ),
        (
          'compact: empty bars',
          _week([
            ChartSeries(
              label: l10n.progressWorkouts,
              color: colors.workouts,
              mark: ChartMark.bar,
              points: const [],
            ),
          ], yFit: ChartYFit.zero),
        ),
      ])
        galleryBlock(
          caption,
          SizedBox(
            height: ProgressCard.chartHeight,
            child: CartesianChart.compact(data: data),
          ),
        ),
      galleryBlock(
        'interactive: hold for the trackball, pinch, pan, fling, double tap',
        _Interactive(data: _week(macros, yFit: ChartYFit.zero)),
      ),
      galleryBlock(
        'morphing through the above (ChartDataTween)',
        _Morphing(data: [for (final (_, data) in charts) data]),
      ),
    ]),
    galleryEntry('ChartLegend', [
      galleryBlock('stacked bars', ChartLegend(series: macros)),
      galleryBlock('dots and a line', ChartLegend(series: weight)),
    ]),
    galleryEntry('ChartSwatch', [
      for (final mark in ChartMark.values)
        galleryInline(
          mark.name,
          ChartSwatch(mark: mark, color: colors.workouts),
        ),
    ]),
    galleryEntry('ChartCallout', [
      for (final (caption, anchor, rows) in [
        (
          'two series, centred',
          0.5,
          [
            (
              name: l10n.scaleWeightTitle,
              color: colors.scaleWeight,
              mark: ChartMark.dot,
              value: kg(82.5),
            ),
            (
              name: l10n.weightTrendSeries,
              color: colors.expenditure,
              mark: ChartMark.line,
              value: kg(82.1),
            ),
          ],
        ),
        (
          'one unnamed series, at the left edge',
          0.0,
          [(name: null, color: null, mark: null, value: l10n.calendarLogged)],
        ),
        ('no rows (noData), at the right edge', 1.0, <ChartCalloutRow>[]),
      ])
        galleryBlock(caption, _plot(anchor, summary(rows))),
    ]),
  ];
}

/// The week to 18 Oct 2026.
ChartData _week(List<ChartSeries> series, {ChartYFit yFit = ChartYFit.tight}) =>
    ChartData(
      series: series,
      start: DateTime(2026, 10, 12),
      end: DateTime(2026, 10, 19),
      yFit: yFit,
    );

/// A card's line through [points], edge to edge.
ChartData _spark(List<ChartPoint> points, Color color, ChartMark mark) =>
    ChartData(
      series: [
        ChartSeries(label: '', color: color, mark: mark, points: points),
      ],
      start: points.first.x,
      end: points.last.x,
      bucketDays: 0,
    );

/// [values] a day apart, from 12 Oct 2026.
List<ChartPoint> _days(List<double> values) => [
  for (final (i, y) in values.indexed) (x: DateTime(2026, 10, 12 + i), y: y),
];

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

/// A [CartesianChart] stepping through [data] at each press, morphing from
/// one to the next.
class _Morphing extends StatefulWidget {
  const new({required this.data});

  final List<ChartData> data;

  @override
  State<_Morphing> createState() => _MorphingState();
}

class _MorphingState extends State<_Morphing> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppSpacing.s,
    children: [
      CartesianChart(data: widget.data[_index]),
      AppChip(
        label: 'Next',
        onPressed: () =>
            setState(() => _index = (_index + 1) % widget.data.length),
      ),
    ],
  );
}

/// An interactive [CartesianChart] keeping its own trackball, with a
/// callout row per series; paging only counts.
class _Interactive extends StatefulWidget {
  const new({required this.data});

  final ChartData data;

  @override
  State<_Interactive> createState() => _InteractiveState();
}

class _InteractiveState extends State<_Interactive> {
  DateTime? _selected;
  int _page = 0;

  List<ChartCalloutRow> _rowsAt(DateTime bucket) => [
    for (final s in widget.data.series)
      if (s.points.where((p) => p.x == bucket).firstOrNull case final point?)
        (
          name: s.label,
          color: s.color,
          mark: s.mark,
          value: AppFormat.number(point.y),
        ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.s,
      children: [
        Text('Page $_page', style: AppTextStyles.label),
        CartesianChart(
          data: widget.data,
          interactive: true,
          selected: selected,
          onSelected: (date) => setState(() => _selected = date),
          onPage: (direction) => setState(() => _page += direction),
          bucketLabel: AppFormat.date,
          callout: selected == null
              ? null
              : ChartCalloutSummary(
                  rows: _rowsAt(selected),
                  footer: AppFormat.date(selected),
                  noData: '',
                ),
        ),
      ],
    );
  }
}
