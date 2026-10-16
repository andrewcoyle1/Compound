import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/programs/logic/todays_workout.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/today/bloc/today_bloc.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound/today/view/day_checklist_card.dart';
import 'package:compound/today/view/streak_card.dart';
import 'package:compound/today/view/today_text.dart';
import 'package:compound/weekly_review/weekly_review.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The Today tab (Swift `TodayView`): getting started, the day's
/// checklist, the weekly check-in's card, the evening protein reminder,
/// today's workout from the active mesocycle, last week's review and the
/// weekly streak, and the people followed who trained today. Weigh-ins can
/// be logged from it, and the step goal chosen.
class TodayPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    // The locale's first day of the week (0 = Sunday), as the Nutrition
    // calendar uses; ISO counts Sunday as 7.
    final firstDay = firstDayOfWeekIndex(context);
    return BlocProvider(
      create: (context) => TodayBloc(
        workoutSessionRepository: context.read<WorkoutSessionRepository>(),
        nutritionRepository: context.read<NutritionRepository>(),
        bodyRepository: context.read<BodyRepository>(),
        userRepository: context.read<UserRepository>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        checkInRepository: context.read<CheckInRepository>(),
        uid: state.user.uid,
        firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay,
        store: context.read<DeviceStore>(),
      )..add(const TodaySubscriptionRequested()),
      // Health only hands over new steps when asked: asked on each visit.
      child: OnAppear(
        onAppear: () => unawaited(context.read<HealthCubit>().importSteps()),
        child: const TodayView(),
      ),
    );
  }
}

class TodayView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<TodayBloc>().state;
    return MultiBlocListener(
      listeners: [
        BlocListener<TodayBloc, TodayState>(
          listenWhen: (previous, current) =>
              previous.skipFailures != current.skipFailures,
          listener: (context, _) =>
              unawaited(showFailureAlert(context, l10n.checkInSkipFailed)),
        ),
        BlocListener<TodayBloc, TodayState>(
          listenWhen: (previous, current) =>
              previous.stepGoalSaves != current.stepGoalSaves ||
              previous.dayCompletions != current.dayCompletions,
          listener: (context, _) =>
              unawaited(HapticFeedback.successNotification()),
        ),
        BlocListener<TodayBloc, TodayState>(
          listenWhen: (previous, current) =>
              previous.stepGoalFailures != current.stepGoalFailures,
          listener: (context, _) =>
              unawaited(showFailureAlert(context, l10n.todayStepGoalFailed)),
        ),
        BlocListener<HealthCubit, HealthState>(
          listenWhen: (previous, current) =>
              current.stepsAccessFailures > previous.stepsAccessFailures,
          listener: (context, _) => unawaited(showStepsAccessFailed(context)),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tabToday),
          actions: const [AskCoachButton(CoachContext.today), ProfileButton()],
        ),
        body: switch (state.status) {
          TodayStatus.loading => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          TodayStatus.failure => const _LoadFailure(),
          TodayStatus.loaded => _Day(state: state),
        },
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const new({required this.state});

  final TodayState state;

  /// What tapping a getting-started step does, or null for a step that is
  /// only a reminder (`TodayPresenter.onStarterStepPressed`).
  static VoidCallback? _starterAction(BuildContext context, StarterStep step) =>
      switch (step) {
        StarterStep.firstWeighIn => () => unawaited(
          context.pushNamed(LogWeightPage.name),
        ),
        StarterStep.appleHealth => () => unawaited(
          context.read<HealthCubit>().connectPressed(),
        ),
        StarterStep.strava => () => unawaited(
          context.pushNamed(IntegrationsPage.name),
        ),
        StarterStep.firstWorkout || StarterStep.firstMeal => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (stravaAvailable, stravaConnected) = context
        .select<StravaCubit, (bool, bool)>(
          (cubit) => (cubit.state.available, cubit.state.isConnected),
        );
    final starter = [
      ...state.starterSteps,
      if (stravaAvailable && !stravaConnected) StarterStep.strava,
    ];
    final starterTotal = StarterStep.values.length - (stravaAvailable ? 0 : 1);
    final gap = state.proteinGapGrams;
    final programs = context.watch<ProgramsCubit>().state;
    final workout = programs.status == ProgramsStatus.loaded
        ? TodaysWorkout.of(programs, state.now)
        : null;
    final checklist = state.checklistWith(planned: workout?.today?.dayPlan);
    final circle = context.watch<CircleBloc>().state;
    final pulse = TodayText.socialPulse(
      l10n,
      namesTrainedToday(
        sessions: circle.followingSessions,
        following: circle.visibleFollowing,
        now: state.now,
      ),
    );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          if (starter.isNotEmpty) ...[
            AppSection(
              header: l10n.todayGetStarted(
                starterTotal - starter.length,
                starterTotal,
              ),
              children: [
                for (final step in starter)
                  if (_starterAction(context, step) case final action?)
                    AppListRowButton(
                      title: TodayText.starter(
                        l10n,
                        step,
                        appleHealth: isAppleHealth(context),
                      ),
                      icon: TodayText.starterIcon(step),
                      onPressed: action,
                    )
                  else
                    AppListRow(
                      title: TodayText.starter(
                        l10n,
                        step,
                        appleHealth: isAppleHealth(context),
                      ),
                      icon: TodayText.starterIcon(step),
                    ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          // Complete only once the schedule is known, so a planned workout
          // still to come can't be missed.
          _DayCompleteWatcher(
            itemCount: checklist.items.length,
            isComplete:
                checklist.isComplete &&
                programs.status != ProgramsStatus.loading,
          ),
          DayChecklistCard(
            checklist: checklist,
            stepGoal: state.stepGoal,
            unit: state.usesPounds
                ? AppWeightUnit.pounds
                : AppWeightUnit.kilograms,
            workout: workout,
            onItemPressed: (item) =>
                context.read<TodayBloc>().add(TodayChecklistItemPressed(item)),
            onStepGoalSelected: (goal) =>
                context.read<TodayBloc>().add(TodayStepGoalSelected(goal)),
          ),
          if (state.dueCheckInWeekStart case final weekStart?) ...[
            const SizedBox(height: AppSpacing.xl),
            DecisionCard(
              title: l10n.checkInReadyTitle,
              message: l10n.checkInReadyMessage,
              primary: l10n.checkInStart,
              onPrimary: () {
                context.read<TodayBloc>().add(const TodayCheckInStarted());
                unawaited(CheckInPage.show(context, weekStart));
              },
              secondary: l10n.checkInSkipWeek,
              onSecondary: () =>
                  context.read<TodayBloc>().add(const TodayCheckInSkipped()),
            ),
          ],
          // Swift's order: the workout before the evening protein.
          const SizedBox(height: AppSpacing.xl),
          const TodaysWorkoutCard(),
          if (gap != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppSection(
              children: [
                AppListRow(
                  title: l10n.todayProteinGap(AppFormat.grams(gap)),
                  icon: AppSymbols.protein,
                  tint: context.appColors.protein,
                  accessory: AppListRowCustom(
                    AskCoachButton(
                      CoachContext(
                        kind: CoachContextKind.nutritionDay,
                        date: localDayKey(DateTime.now()),
                        title: l10n.coachTodaysFood,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (state.showsWeeklyReviewCard) ...[
            const SizedBox(height: AppSpacing.xl),
            AppSection(
              children: [
                AppListRowButton(
                  title: l10n.weeklyReviewReady,
                  icon: AppSymbols.weeklyReview,
                  onPressed: () {
                    context.read<TodayBloc>().add(
                      const TodayWeeklyReviewOpened(),
                    );
                    context.goNamed(WeeklyReviewPage.name);
                  },
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
          if (pulse != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppSection(
              children: [
                AppListRowButton(
                  title: pulse,
                  icon: AppSymbols.friends,
                  onPressed: () {
                    context.read<TodayBloc>().add(
                      const TodaySocialPulsePressed(),
                    );
                    context.go(AppTab.social.path);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tells the bloc each time the checklist turns complete, and on arrival
/// when it already is; the bloc marks the day once
/// (`TodayView.onChange(of: checklist.isComplete, initial: true)`).
class _DayCompleteWatcher extends StatefulWidget {
  const new({required this.itemCount, required this.isComplete});

  final int itemCount;
  final bool isComplete;

  @override
  State<_DayCompleteWatcher> createState() => _DayCompleteWatcherState();
}

class _DayCompleteWatcherState extends State<_DayCompleteWatcher> {
  @override
  void initState() {
    super.initState();
    _tell();
  }

  @override
  void didUpdateWidget(_DayCompleteWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isComplete) _tell();
  }

  void _tell() {
    if (widget.isComplete) {
      context.read<TodayBloc>().add(TodayDayCompleted(widget.itemCount));
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
