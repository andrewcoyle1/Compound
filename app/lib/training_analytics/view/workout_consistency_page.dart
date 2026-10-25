import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/training_analytics/bloc/training_analytics_bloc.dart';
import 'package:compound/training_analytics/view/training_analytics_widgets.dart';
import 'package:compound/training_analytics/view/training_metric_pages.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:go_router/go_router.dart';

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
    return AppScaffold(
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
                graded: true,
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

/// A contribution grid ([HeatGrid], Swift QuickCharts' `ContributionChart`):
/// a week per column, its days down the rows from [firstWeekday] with their
/// initials, back to the week of the first of [dates] (or as far as fills
/// the width) and scrolled to this week, with each month named over the
/// column it starts in.
///
/// A day's shade is how many of [dates] fall on it. When [graded], each
/// entry is a level, up to the most on any one day and at most
/// [gradedLevels] - 1, with a legend beneath; otherwise any entry fills the
/// day.
///
/// The header counts the days logged and the dates the grid covers;
/// pressing and holding a day rings it and shows its count and date
/// instead. A screen reader hears [semanticsLabel], then each week.
class ContributionGrid extends StatefulWidget {
  const new({
    required this.dates,
    required this.today,
    required this.firstWeekday,
    required this.color,
    required this.semanticsLabel,
    this.countText,
    this.graded = false,
    super.key,
  });

  /// When each entry happened.
  final List<DateTime> dates;

  /// Today, at midnight.
  final DateTime today;

  /// The week's first day, as an ISO weekday (1 = Monday).
  final int firstWeekday;

  /// The fullest shade.
  final Color color;

  /// What the grid shows, for a screen reader.
  final String semanticsLabel;

  /// A day's entries as the readout says them, such as "2 workouts";
  /// without it a day with any reads "Logged".
  final String Function(int count)? countText;

  /// Whether a day with more entries is a fuller shade.
  final bool graded;

  /// The most shades a graded grid takes, counting empty: one each for
  /// none to three entries, and the fullest for four or more.
  static const gradedLevels = 5;

  @override
  State<ContributionGrid> createState() => _ContributionGridState();
}

class _ContributionGridState extends State<ContributionGrid> {
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final counts = <DateTime, int>{};
    for (final date in widget.dates) {
      final local = date.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    final today = widget.today;
    final most = counts.values.fold(0, math.max);
    final levels = widget.graded
        ? math.min(most, ContributionGrid.gradedLevels - 1) + 1
        : 2;
    String date(DateTime day) =>
        AppFormat.date(day, locale: context.dateLocale);
    String countOf(int count) =>
        widget.countText?.call(count) ?? l10n.calendarLogged;
    final selected = _selected;
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          HeatGrid(
            days: counts,
            today: today,
            firstWeekday: widget.firstWeekday,
            levels: levels,
            color: widget.color,
            selected: selected,
            onSelected: (day) => setState(() => _selected = day),
            callout: selected == null
                ? null
                : ChartCalloutSummary(
                    rows: [
                      if (counts[selected] case final count?)
                        (
                          name: null,
                          color: null,
                          mark: null,
                          value: countOf(count),
                        ),
                    ],
                    footer: AppFormat.date(
                      selected,
                      style: AppDateStyle.weekdayMedium,
                      locale: context.dateLocale,
                    ),
                    noData: l10n.progressNoData,
                  ),
            header: (first) {
              final span =
                  DateTime.utc(today.year, today.month, today.day)
                      .difference(
                        DateTime.utc(first.year, first.month, first.day),
                      )
                      .inDays +
                  1;
              final daysLogged = counts.keys
                  .where((d) => !d.isBefore(first) && !d.isAfter(today))
                  .length;
              // Hidden under the callout while a day is picked, keeping
              // its room so nothing moves.
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 2 * AppSpacing.xs + AppSpacing.s,
                ),
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: selected == null ? 1 : 0,
                    // The screen's hero: the days logged, loudest.
                    child: AppHeroStat(
                      value: AppFormat.number(daysLogged, locale: locale),
                      unit: l10n.contributionOfDays(span),
                      caption: l10n.contributionDaysLogged(
                        '${date(first)} – ${date(today)}',
                      ),
                    ),
                  ),
                ),
              );
            },
            weekLabel: (start) {
              final week = [
                for (var day = 0; day < DateTime.daysPerWeek; day++)
                  counts[DateTime(start.year, start.month, start.day + day)],
              ].nonNulls;
              return l10n.heatGridWeek(
                date(start),
                widget.countText?.call(week.fold(0, (a, b) => a + b)) ??
                    l10n.heatGridDaysLogged(week.length),
              );
            },
          ),
          if (widget.graded)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: HeatGridLegend(
                levels: levels,
                color: widget.color,
                less: l10n.heatGridLess,
                more: l10n.heatGridMore,
              ),
            ),
        ],
      ),
    );
  }
}
