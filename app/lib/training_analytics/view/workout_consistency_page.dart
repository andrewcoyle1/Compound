import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/training_analytics/bloc/training_analytics_bloc.dart';
import 'package:compound/training_analytics/view/training_analytics_widgets.dart';
import 'package:compound/training_analytics/view/training_metric_pages.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Every finished workout on a contribution grid, a week a column (Swift
/// `WorkoutConsistencyView`). Opened from the Progress tab's Workouts
/// habit card.
class WorkoutConsistencyPage extends StatelessWidget {
  const new({this.allData = false, super.key});

  /// The path under the Progress tab.
  static const path = 'workout-consistency';

  /// The route name, and its All Recorded Data's.
  static const name = 'workoutConsistency';
  static const dataName = 'workoutConsistencyData';

  /// Whether to show every entry instead of the grid.
  final bool allData;

  @override
  Widget build(BuildContext context) => TrainingAnalyticsProvider(
    screen: TrainingAnalyticsScreen.workoutConsistency,
    child: _WorkoutConsistencyView(allData: allData),
  );
}

class _WorkoutConsistencyView extends StatelessWidget {
  const new({required this.allData});

  final bool allData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          allData ? l10n.metricAllRecordedData : l10n.progressWorkouts,
        ),
        actions: [if (!allData) const StartWorkoutButton()],
      ),
      body: TrainingAnalyticsBody(
        title: l10n.progressWorkouts,
        loaded: (state) {
          final metric = workoutsMetric(
            context,
            state,
            color: context.appColors.habits,
          );
          if (state.workouts.isEmpty) {
            return AnalyticsMessage(
              title: metric.title,
              message: metric.emptyMessage,
              offersWorkout: true,
            );
          }
          if (allData) {
            return MetricAllDataView(
              title: metric.title,
              unit: metric.unit,
              entries: metric.points.reversed.toList(),
              valueText: metric.entryText,
            );
          }
          final firstDay = firstDayOfWeekIndex(context);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              ContributionGrid(
                dates: [for (final w in state.workouts) w.date],
                today: state.today,
                firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay,
                color: context.appColors.habits,
                semanticsLabel: l10n.workoutGridLabel(state.workouts.length),
                countText: l10n.workoutGridLabel,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                children: [
                  AppListRowButton(
                    title: l10n.metricShowAllData,
                    onPressed: () =>
                        context.goNamed(WorkoutConsistencyPage.dataName),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A contribution grid (Swift QuickCharts' `ContributionChart` with a goal
/// of one): a week per column, its days down the rows from [firstWeekday]
/// with their initials, back to the week of the first of [dates] (or as far
/// as fills the width) and scrolled to this week, with each month named
/// over the column it starts in. A day with any of [dates] is filled.
///
/// The header counts the days logged and the dates covered; pressing and
/// holding a day rings it and shows its count and date instead.
class ContributionGrid extends StatefulWidget {
  const new({
    required this.dates,
    required this.today,
    required this.firstWeekday,
    required this.color,
    required this.semanticsLabel,
    this.countText,
    super.key,
  });

  /// When each entry happened.
  final List<DateTime> dates;

  /// Today, at midnight.
  final DateTime today;

  /// The week's first day, as an ISO weekday (1 = Monday).
  final int firstWeekday;

  /// The filled squares' colour.
  final Color color;

  /// What the grid shows, for a screen reader.
  final String semanticsLabel;

  /// A day's entries as the readout says them, such as "2 workouts";
  /// without it a day with any reads "Logged".
  final String Function(int count)? countText;

  static const _cell = 18.0;
  static const _gap = 3.0;
  static const double _step = _cell + _gap;

  @override
  State<ContributionGrid> createState() => _ContributionGridState();
}

class _ContributionGridState extends State<ContributionGrid> {
  DateTime? _selected;

  DateTime _weekStart(DateTime date) {
    final offset = (date.weekday - widget.firstWeekday + 7) % 7;
    return DateTime(date.year, date.month, date.day - offset);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final labelStyle = AppTextStyles.label.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final counts = <DateTime, int>{};
    for (final date in widget.dates) {
      final local = date.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    final today = widget.today;
    final last = _weekStart(today);
    final firstLogged = _weekStart(
      counts.keys.reduce((a, b) => a.isBefore(b) ? a : b),
    );
    final logged = (last.difference(firstLogged).inDays / 7).round() + 1;
    final monthRow = textScaler.scale(labelStyle.fontSize ?? 12) * 1.4;
    final weekdays = [
      for (var row = 0; row < 7; row++)
        DateFormat.EEEEE(locale).format(
          // 4 January 2021 was a Monday.
          DateTime(2021, 1, 3 + ((widget.firstWeekday - 1 + row) % 7 + 1)),
        ),
    ];
    return Semantics(
      label: widget.semanticsLabel,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final letters = weekdays
                .map(
                  (w) => (TextPainter(
                    text: TextSpan(text: w, style: labelStyle),
                    textDirection: TextDirection.ltr,
                    textScaler: textScaler,
                  )..layout()).width,
                )
                .reduce(math.max);
            final lettersWidth = letters + AppSpacing.s;
            // At least as many weeks as fill the width, as GitHub's grid.
            final weeks = math.max(
              logged,
              ((constraints.maxWidth - lettersWidth + ContributionGrid._gap) /
                      ContributionGrid._step)
                  .floor(),
            );
            final first = DateTime(
              last.year,
              last.month,
              last.day - 7 * (weeks - 1),
            );
            final span = today.difference(first).inDays + 1;
            final daysLogged = counts.keys
                .where((d) => !d.isBefore(first) && !d.isAfter(today))
                .length;
            final selected = _selected;
            final dates = DateFormat.yMMMd(locale);
            final header = selected == null
                ? [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: AppFormat.number(daysLogged, locale: locale),
                            style: AppTextStyles.metric,
                          ),
                          TextSpan(text: ' ${l10n.contributionOfDays(span)}'),
                        ],
                      ),
                      style: AppTextStyles.rowDetail.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      l10n.contributionDaysLogged(
                        '${dates.format(first)} – ${dates.format(today)}',
                      ),
                      style: labelStyle,
                    ),
                  ]
                : [
                    Text(switch (counts[selected] ?? 0) {
                      0 => l10n.progressNoData,
                      final count =>
                        widget.countText?.call(count) ?? l10n.calendarLogged,
                    }, style: AppTextStyles.metric),
                    Text(
                      DateFormat.yMMMEd(locale).format(selected),
                      style: labelStyle,
                    ),
                  ];

            DateTime? dayAt(Offset position) {
              final week = (position.dx / ContributionGrid._step).floor();
              final row = ((position.dy - monthRow) / ContributionGrid._step)
                  .floor();
              if (week < 0 || week >= weeks || row < 0 || row > 6) return null;
              final day = DateTime(
                first.year,
                first.month,
                first.day + week * 7 + row,
              );
              return day.isAfter(today) ? null : day;
            }

            void pick(Offset position) {
              final day = dayAt(position);
              if (day != _selected) setState(() => _selected = day);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xs,
              children: [
                ...header,
                const SizedBox(height: AppSpacing.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: monthRow),
                      child: SizedBox(
                        width: lettersWidth,
                        child: Column(
                          children: [
                            for (final w in weekdays)
                              SizedBox(
                                height: ContributionGrid._step,
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    w,
                                    style: labelStyle,
                                    textScaler: TextScaler.noScaling,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: GestureDetector(
                          onLongPressStart: (d) => pick(d.localPosition),
                          onLongPressMoveUpdate: (d) => pick(d.localPosition),
                          onLongPressEnd: (_) =>
                              setState(() => _selected = null),
                          child: SizedBox(
                            width:
                                weeks * ContributionGrid._step -
                                ContributionGrid._gap,
                            height:
                                monthRow +
                                7 * ContributionGrid._step -
                                ContributionGrid._gap,
                            child: CustomPaint(
                              painter: _GridPainter(
                                weeks: weeks,
                                first: first,
                                today: today,
                                days: counts.keys.toSet(),
                                color: widget.color,
                                top: monthRow,
                                selected: selected,
                                ringColor: scheme.onSurface,
                                labelStyle: labelStyle,
                                textScaler: textScaler,
                                locale: locale,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  new({
    required this.weeks,
    required this.first,
    required this.today,
    required this.days,
    required this.color,
    required this.top,
    required this.selected,
    required this.ringColor,
    required this.labelStyle,
    required this.textScaler,
    required this.locale,
  });

  final int weeks;
  final DateTime first;
  final DateTime today;
  final Set<DateTime> days;
  final Color color;

  /// The height of the month names over the squares.
  final double top;
  final DateTime? selected;
  final Color ringColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final String locale;

  @override
  void paint(Canvas canvas, Size size) {
    const step = ContributionGrid._step;
    const cell = ContributionGrid._cell;
    final filled = Paint()..color = color;
    final blank = Paint()..color = color.withValues(alpha: 0.15);
    var lastLabelEnd = double.negativeInfinity;
    for (var week = 0; week < weeks; week++) {
      final weekStart = DateTime(first.year, first.month, first.day + week * 7);
      // A month is named over the column its first day falls in, unless
      // the name before it is still in the way.
      for (var row = 0; row < 7; row++) {
        final day = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + row,
        );
        if (day.day != 1 || day.isAfter(today)) continue;
        final label = TextPainter(
          text: TextSpan(
            text: DateFormat.MMM(locale).format(day),
            style: labelStyle,
          ),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        final x = week * step;
        if (x >= lastLabelEnd) {
          label.paint(canvas, Offset(x, 0));
          lastLabelEnd = x + label.width + AppSpacing.xs;
        }
      }
      for (var row = 0; row < 7; row++) {
        final day = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + row,
        );
        if (day.isAfter(today)) continue;
        final rect = RRect.fromLTRBR(
          week * step,
          top + row * step,
          week * step + cell,
          top + row * step + cell,
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, days.contains(day) ? filled : blank);
        if (day == selected) {
          canvas.drawRRect(
            rect.inflate(1.5),
            Paint()
              ..color = ringColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.weeks != weeks ||
      old.first != first ||
      old.today != today ||
      !setEquals(old.days, days) ||
      old.color != color ||
      old.top != top ||
      old.selected != selected ||
      old.ringColor != ringColor ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old.locale != locale;
}
