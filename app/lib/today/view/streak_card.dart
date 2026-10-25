import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show dayKeyOf;
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound_maths/compound_maths.dart';

/// The weekly streak on Today (Swift `WorkoutStreakCard`), as a summary
/// card: weeks in a row with the weekly goal met, this week's badge, a
/// mark for each day of the week, and this week's count, the best run and
/// the total in the footer.
class StreakCard extends StatelessWidget {
  const new({
    required this.streak,
    required this.weekDays,
    required this.workoutDays,
    required this.totalWorkouts,
    required this.today,
    super.key,
  });

  /// The streak.
  final WeeklyStreak streak;

  /// This week's seven days, from its first.
  final List<DateTime> weekDays;

  /// The keys of this week's days with a workout.
  final Set<String> workoutDays;

  /// Every finished workout.
  final int totalWorkouts;

  /// Now.
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    return AppSummaryCard(
      title: l10n.streakTitle,
      icon: AppSymbols.streak,
      tint: colors.workouts,
      trailing: MethodInfoButton(MethodInfo.weeklySessionGoal(l10n)),
      value: AppFormat.number(streak.weeks),
      unit: l10n.streakWeeksUnit(streak.weeks),
      // This week's goal met is the user's own progress: the accent.
      delta: switch (streak.state) {
        StreakState.met => AppChip(
          label: l10n.streakGoalMet,
          icon: AppSymbols.success,
          selected: true,
        ),
        StreakState.atRisk => AppChip(
          label: l10n.streakAtRisk,
          icon: AppSymbols.warning,
          tint: colors.warning,
        ),
        _ => null,
      },
      chart: Row(
        children: [
          for (final day in weekDays)
            Expanded(
              child: _Day(
                day: day,
                hasWorkout: workoutDays.contains(dayKeyOf(day)),
                isToday: dayKeyOf(day) == dayKeyOf(today),
                isFuture: day.isAfter(today),
              ),
            ),
        ],
      ),
      footer: [
        l10n.streakThisWeek(streak.sessionsThisWeek, streak.goal),
        l10n.streakRecord(l10n.streakWeeks(streak.best), totalWorkouts),
      ].join(' · '),
    );
  }
}

/// One day of the week: its letter over a done mark when a workout was
/// logged, an empty circle when not: in the text colour today, faint in
/// the future.
class _Day extends StatelessWidget {
  const new({
    required this.day,
    required this.hasWorkout,
    required this.isToday,
    required this.isFuture,
  });

  final DateTime day;
  final bool hasWorkout;
  final bool isToday;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Column(
      spacing: AppSpacing.xs,
      children: [
        Text(
          AppFormat.date(
            day,
            style: AppDateStyle.weekdayInitial,
            locale: context.dateLocale,
          ),
          style: isToday
              ? AppTextStyles.label.semibold
              : AppTextStyles.label.secondary(context),
        ),
        if (hasWorkout)
          const AppDoneMark(size: AppIconSize.small)
        else
          Icon(
            AppSymbols.choiceUnselected,
            size: AppIconSize.small.of(context),
            color: isToday
                ? scheme.onSurface
                : isFuture
                ? colors.separator
                : colors.tertiaryLabel,
          ),
      ],
    );
  }
}
