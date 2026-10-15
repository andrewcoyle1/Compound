import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/training_analytics/bloc/training_analytics_bloc.dart';
import 'package:compound/training_analytics/view/training_analytics_widgets.dart';
import 'package:compound/training_analytics/view/training_metric_pages.dart';
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
          final firstDay = MaterialLocalizations.of(context)
              .firstDayOfWeekIndex;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              ContributionGrid(
                dates: [for (final w in state.workouts) w.date],
                today: state.today,
                firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay,
                color: context.appColors.habits,
                semanticsLabel: l10n.workoutGridLabel(state.workouts.length),
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
/// of one): a week per column, its days down the rows from [firstWeekday],
/// back to the week of the first of [dates] (or as far as fills the width)
/// and scrolled to this week. A day with any of [dates] is filled.
///
/// ponytail: no month labels and no press-and-hold callout; add them if
/// the grid needs reading by date.
class ContributionGrid extends StatelessWidget {
  const new({
    required this.dates,
    required this.today,
    required this.firstWeekday,
    required this.color,
    required this.semanticsLabel,
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

  static const _cell = 18.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    DateTime weekStart(DateTime date) {
      final offset = (date.weekday - firstWeekday + 7) % 7;
      return DateTime(date.year, date.month, date.day - offset);
    }

    final days = {
      for (final date in dates)
        DateTime(date.toLocal().year, date.toLocal().month, date.toLocal().day),
    };
    final last = weekStart(today);
    final firstLogged = weekStart(days.reduce((a, b) => a.isBefore(b) ? a : b));
    final logged = (last.difference(firstLogged).inDays / 7).round() + 1;
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // At least as many weeks as fill the width, as GitHub's grid.
            const step = _cell + _gap;
            final weeks = math.max(
              logged,
              ((constraints.maxWidth + _gap) / step).floor(),
            );
            final first = DateTime(
              last.year,
              last.month,
              last.day - 7 * (weeks - 1),
            );
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: SizedBox(
                width: weeks * step - _gap,
                height: 7 * step - _gap,
                child: CustomPaint(
                  painter: _GridPainter(
                    weeks: weeks,
                    first: first,
                    today: today,
                    days: days,
                    color: color,
                  ),
                ),
              ),
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
  });

  final int weeks;
  final DateTime first;
  final DateTime today;
  final Set<DateTime> days;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const step = ContributionGrid._cell + ContributionGrid._gap;
    final filled = Paint()..color = color;
    final blank = Paint()..color = color.withValues(alpha: 0.15);
    for (var week = 0; week < weeks; week++) {
      for (var row = 0; row < 7; row++) {
        final day = DateTime(
          first.year,
          first.month,
          first.day + week * 7 + row,
        );
        if (day.isAfter(today)) continue;
        canvas.drawRRect(
          RRect.fromLTRBR(
            week * step,
            row * step,
            week * step + ContributionGrid._cell,
            row * step + ContributionGrid._cell,
            const Radius.circular(3),
          ),
          days.contains(day) ? filled : blank,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.weeks != weeks ||
      old.first != first ||
      old.today != today ||
      old.days != days ||
      old.color != color;
}
