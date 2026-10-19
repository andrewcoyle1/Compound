import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show dayKeyOf;
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound_maths/compound_maths.dart';

/// The weekly streak on Today (Swift `WorkoutStreakCard`): weeks in a row
/// with the weekly goal met, this week's progress and badge, a dot for each
/// day of the week, the best run and the total.
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
    final scheme = Theme.of(context).colorScheme;
    final state = streak.state;
    final accent = state == StreakState.atRisk
        ? colors.warning
        : streak.weeks > 0
        ? colors.workouts
        : scheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.l),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.streakTitle,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              MethodInfoButton(MethodInfo.weeklySessionGoal(l10n)),
            ],
          ),
        ),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.l,
              children: [
                Row(
                  spacing: AppSpacing.m,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        AppSymbols.streak,
                        size: AppIconSize.medium.of(context),
                        color: accent,
                      ),
                    ),
                    Expanded(
                      child: MergeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppSpacing.xxs,
                          children: [
                            Text(
                              l10n.streakWeeks(streak.weeks),
                              style: AppTextStyles.display.copyWith(
                                color: accent,
                              ),
                            ),
                            Text(
                              l10n.streakThisWeek(
                                streak.sessionsThisWeek,
                                streak.goal,
                              ),
                              style: AppTextStyles.rowDetail.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (state == StreakState.atRisk)
                      AppChip(
                        label: l10n.streakAtRisk,
                        icon: AppSymbols.warning,
                        tint: colors.warning,
                      )
                    else if (state == StreakState.met)
                      AppChip(
                        label: l10n.streakGoalMet,
                        icon: AppSymbols.success,
                        tint: colors.workouts,
                      ),
                  ],
                ),
                Row(
                  children: [
                    for (final day in weekDays)
                      Expanded(
                        child: _DayDot(
                          day: day,
                          hasWorkout: workoutDays.contains(dayKeyOf(day)),
                          isToday: dayKeyOf(day) == dayKeyOf(today),
                          isFuture: day.isAfter(today),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 1),
                Row(
                  children: [
                    Expanded(
                      child: AppStat(
                        value: l10n.streakWeeks(streak.best),
                        label: l10n.streakBest,
                        size: AppStatSize.small,
                      ),
                    ),
                    AppStat(
                      value: AppFormat.number(totalWorkouts),
                      label: l10n.streakTotalWorkouts,
                      size: AppStatSize.small,
                      alignment: CrossAxisAlignment.end,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One day of the week: its letter, and a dot filled when a workout was
/// logged, ringed on today, faint in the future.
class _DayDot extends StatelessWidget {
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
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final fill = hasWorkout
        ? context.appColors.workouts
        : scheme.outlineVariant.withValues(alpha: isFuture ? 0.4 : 1);
    return Semantics(
      label: AppFormat.date(
        day,
        style: AppDateStyle.weekday,
        locale: context.dateLocale,
      ),
      value: hasWorkout ? l10n.streakWorkoutLogged : l10n.streakNoWorkout,
      excludeSemantics: true,
      child: Column(
        spacing: AppSpacing.xs,
        children: [
          Text(
            AppFormat.date(
              day,
              style: AppDateStyle.weekdayInitial,
              locale: context.dateLocale,
            ),
            style:
                (isToday ? AppTextStyles.label.semibold : AppTextStyles.label)
                    .copyWith(
                      color: isToday
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: isToday && !hasWorkout
                  ? Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.35),
                      width: 1.5,
                    )
                  : null,
            ),
            child: const SizedBox.square(dimension: 10),
          ),
        ],
      ),
    );
  }
}
