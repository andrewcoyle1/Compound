import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/today/bloc/today_bloc.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound/today/view/day_checklist_card.dart';
import 'package:compound/today/view/streak_card.dart';
import 'package:compound/today/view/today_text.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The Today tab (Swift `TodayView`): getting started, the day's
/// checklist, the evening protein reminder and the weekly streak. Weigh-ins
/// can be logged from it. Logging meals and workouts, the check-in, today's
/// planned workout, the weekly review and friends who trained come with the
/// milestones that build them.
class TodayPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    // The locale's first day of the week (0 = Sunday), as the Nutrition
    // calendar uses; ISO counts Sunday as 7.
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return BlocProvider(
      create: (context) => TodayBloc(
        workoutSessionRepository: context.read<WorkoutSessionRepository>(),
        nutritionRepository: context.read<NutritionRepository>(),
        bodyRepository: context.read<BodyRepository>(),
        userRepository: context.read<UserRepository>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
        firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay,
      )..add(const TodaySubscriptionRequested()),
      child: const TodayView(),
    );
  }
}

class TodayView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<TodayBloc>().state;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabToday),
        actions: const [ProfileButton()],
      ),
      body: switch (state.status) {
        TodayStatus.loading => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        TodayStatus.failure => const _LoadFailure(),
        TodayStatus.loaded => _Day(state: state),
      },
    );
  }
}

class _Day extends StatelessWidget {
  const new({required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final starter = state.starterSteps;
    final gap = state.proteinGapGrams;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          if (starter.isNotEmpty) ...[
            AppSection(
              header: l10n.todayGetStarted(
                StarterStep.values.length - starter.length,
                StarterStep.values.length,
              ),
              children: [
                for (final step in starter)
                  if (step == StarterStep.firstWeighIn)
                    AppListRowButton(
                      title: TodayText.starter(l10n, step),
                      icon: TodayText.starterIcon(step),
                      onPressed: () => context.pushNamed(LogWeightPage.name),
                    )
                  else
                    AppListRow(
                      title: TodayText.starter(l10n, step),
                      icon: TodayText.starterIcon(step),
                    ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          DayChecklistCard(
            checklist: state.checklist,
            stepGoal: state.stepGoal,
            unit: state.usesPounds
                ? AppWeightUnit.pounds
                : AppWeightUnit.kilograms,
          ),
          if (gap != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppSection(
              children: [
                AppListRow(
                  title: l10n.todayProteinGap(AppFormat.grams(gap)),
                  icon: AppSymbols.protein,
                  tint: context.appColors.protein,
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          StreakCard(
            streak: state.streak,
            weekDays: state.weekDays,
            workoutDays: state.workoutDaysThisWeek,
            totalWorkouts: state.totalWorkouts,
            today: state.now,
          ),
        ],
      ),
    );
  }
}

/// The day could not be read: the Today glyph and a line saying so.
class _LoadFailure extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s,
          children: [
            Icon(
              AppSymbols.today,
              size: AppIconSize.hero.of(context),
              color: secondary,
            ),
            Text(
              context.l10n.todayLoadFailure,
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
