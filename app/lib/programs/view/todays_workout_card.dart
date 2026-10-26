import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/cubit/workout_preview_cubit.dart';
import 'package:compound/programs/logic/todays_workout.dart';
import 'package:compound/programs/view/mesocycle_library_page.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/workout_history/models/workout_session_highlights.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart';

/// Today's workout on the Today tab (Swift `TodaysWorkoutCard` and the
/// Today view's workout section), as a summary card with its buttons at
/// the foot: the active mesocycle's next workout to start or skip, today's
/// rest day, or what today's finished workout came to, each named in the
/// display face. Without a plan for today it offers an empty workout;
/// after a macrocycle's last mesocycle, a repeat.
class const TodaysWorkoutCard({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProgramsCubit>().state;
    final workout = TodaysWorkout.of(state, DateTime.now());
    final today = workout.today;
    final Widget child;
    if (today == null) {
      final macrocycle = state.currentMacrocycle;
      child = macrocycle?.status == MacrocycleStatus.completed
          ? _Unscheduled(
              title: l10n.programMacrocycleComplete(macrocycle!.name),
              message: l10n.programMacrocycleCompleteMessage,
              primary: l10n.programRepeatMacrocycle,
              onPrimary: () => unawaited(_repeat(context)),
              secondary: l10n.programChooseMesocycle,
              onSecondary: () => _choose(context),
            )
          : _Unscheduled(
              title: state.activeMesocycle == null
                  ? l10n.programNoActiveMesocycle
                  : l10n.programNothingScheduled,
              message: l10n.programEmptyWorkoutMessage,
              primary: l10n.startEmptyWorkout,
              onPrimary: () {
                context.read<ActiveWorkoutCubit>().pressed(
                  'TodayView_StartEmptyWorkout_Press',
                );
                unawaited(
                  startWorkout(
                    context,
                    eventPrefix: 'TodayView_StartBlankWorkout',
                  ),
                );
              },
              secondary: state.activeMesocycle == null
                  ? l10n.programChooseMesocycle
                  : null,
              onSecondary: () => _choose(context),
            );
    } else if (workout.isRestDay) {
      child = _RestDay(workout: workout);
    } else if (workout.isCompleted) {
      child = _Completed(workout: workout, plan: today.dayPlan);
    } else {
      final slot = workout.openSlot;
      final uid = switch (context.read<AppBloc>().state) {
        AppAuthenticated(:final user) => user.uid,
        _ => null,
      };
      child = BlocProvider(
        // A new preview whenever today's workout, its week or deload change.
        key: ValueKey(
          '${slot?.id}-${workout.run?.mesocycle.id}-${workout.isDeload}',
        ),
        create: (context) {
          final preview = WorkoutPreviewCubit(
            library: context.read(),
            sessions: context.read(),
            users: context.read(),
            analytics: context.read(),
          );
          if (slot != null && uid != null) {
            unawaited(
              preview.load(
                uid,
                slot.dayPlan,
                mesocycleId: workout.run?.mesocycle.id,
                microcycleIndex: slot.cycleIndex + 1,
                isDeload: workout.isDeload,
              ),
            );
          }
          return preview;
        },
        child: _Start(workout: workout, plan: today.dayPlan),
      );
    }
    return child;
  }

  static void _choose(BuildContext context) {
    context.read<ProgramsCubit>().pressed('TodayView_ChooseProgram_Press');
    context.goNamed(MesocycleLibraryPage.name);
  }

  static Future<void> _repeat(BuildContext context) async {
    final ok = await context.read<ProgramsCubit>().succeeded(
      (c) => c.repeatMacrocycle(),
    );
    unawaited(ok ? AppHaptics.success() : AppHaptics.error());
    if (!ok && context.mounted) {
      await showFailureAlert(context, context.l10n.programRepeatFailed);
    }
  }
}

/// Starts [slot]'s workout straight into the tracker.
Future<void> _startSlot(
  BuildContext context,
  TodaysWorkout workout,
  ScheduleSlot slot,
) {
  context.read<ProgramsCubit>().pressed('TodaysWorkoutCard_Start_Pressed');
  return startWorkout(
    context,
    template: slot.dayPlan,
    eventPrefix: 'TodaysWorkoutCard_Start',
    mesocycleId: workout.run?.mesocycle.id,
    microcycleIndex: slot.cycleIndex + 1,
    isDeload: workout.isDeload,
  );
}

/// The card's overline header: what it is, in the workouts colour.
class const _Card({
  required final String value,
  final AppSummaryCardSize size = AppSummaryCardSize.large,
  final String? unit,
  final AppChip? delta,
  final Widget? chart,
  final String? footer,
  final VoidCallback? onTap,
  final Widget? actions,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AppSummaryCard(
    title: context.l10n.programTodaysWorkout,
    icon: AppSymbols.workout,
    tint: context.appColors.workouts,
    value: value,
    size: size,
    unit: unit,
    delta: delta,
    chart: chart,
    footer: footer,
    onTap: onTap,
    actions: actions,
  );
}

/// No plan for today, or a macrocycle finished: what is the case, a line
/// on it and its actions.
class const _Unscheduled({
  required final String title,
  required final String message,
  required final String primary,
  required final VoidCallback onPrimary,
  required final VoidCallback onSecondary,
  final String? secondary,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final secondary = this.secondary;
    return _Card(
      value: title,
      size: AppSummaryCardSize.regular,
      footer: message,
      actions: Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.s,
        children: [
          AppCtaButton(
            label: primary,
            size: AppCtaSize.compact,
            onPressed: onPrimary,
          ),
          if (secondary != null)
            AppCtaButton(
              label: secondary,
              size: AppCtaSize.compact,
              variant: AppCtaVariant.secondary,
              onPressed: onSecondary,
            ),
        ],
      ),
    );
  }
}

class const _RestDay({required final TodaysWorkout workout})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final next = workout.startableSlot;
    return _Card(
      value: l10n.programRestDay,
      footer: l10n.programRestDayMessage,
      actions: next == null
          ? null
          : Semantics(
              hint: l10n.programStartInsteadHint,
              child: AppCtaButton(
                label: l10n.programStartInstead(next.dayPlan.name),
                size: AppCtaSize.compact,
                variant: AppCtaVariant.secondary,
                onPressed: () => unawaited(_startSlot(context, workout, next)),
              ),
            ),
    );
  }
}

/// Today's workout, done: its name with a volt Completed, then what it
/// came to and its records. Opens the session.
class const _Completed({
  required final TodaysWorkout workout,
  required final WorkoutTemplateModel plan,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final session = workout.completedSession;
    // Done is the user's own progress: the accent, as a fill.
    final done = AppChip(
      label: l10n.programDayCompleted,
      icon: AppSymbols.success,
      selected: true,
    );
    if (session == null) {
      return _Card(
        value: plan.name,
        delta: done,
        footer: l10n.programCompletedToday,
      );
    }
    final duration = session.activeDuration;
    final volume = WorkoutText.sessionVolume(session, locale: locale);
    final figures = [
      if (duration != null) AppFormat.duration(duration),
      l10n.setCount(session.loggedSetCount),
      ?volume,
    ].join(' · ');
    final records = WorkoutSessionHighlights.personalRecords(
      session,
      priorSessions: workout.sessions,
      limit: 1 << 20,
    );
    final first = records.firstOrNull;
    return _Card(
      value: plan.name,
      delta: done,
      footer: [
        figures,
        if (first != null)
          [
            l10n.programPrCount(records.length),
            first.exerciseName,
            WorkoutText.recordDetail(l10n, first, locale: locale),
          ].join(' · '),
      ].join('\n'),
      onTap: () {
        context.read<ProgramsCubit>().pressed(
          'TodaysWorkoutCard_CompletedSession_Pressed',
        );
        context.goNamed(
          WorkoutSessionDetailPage.name,
          pathParameters: {
            WorkoutSessionDetailPage.sessionIdParameter: session.id,
          },
        );
      },
    );
  }
}

class const _Start({
  required final TodaysWorkout workout,
  required final WorkoutTemplateModel plan,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slot = workout.openSlot;
    final run = workout.run;
    final minutes = workout.estimatedMinutes;
    final subtitle = [
      if (slot != null && run != null)
        l10n.programWeekDay(
          slot.cycleIndex + 1,
          run.mesocycle.numMicrocycles < 1 ? 1 : run.mesocycle.numMicrocycles,
          slot.position + 1,
        ),
      if (minutes != null) l10n.programMinutesEstimate(minutes),
    ].join(' · ');
    final targets = _targets(context);
    // Pictures, not text: they grow with it only so far.
    final side = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: AppScaffold.largeTitleMaxTextScale)
        .scale(56);
    return _Card(
      value: plan.name,
      unit: subtitle.isEmpty
          ? l10n.exerciseCount(plan.exercises.length)
          : subtitle,
      // Wraps at large text sizes rather than overflowing.
      chart: Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.s,
        children: [
          for (final exercise in plan.exercises.take(4))
            ClipOval(
              child: SizedBox.square(
                dimension: side,
                child: ExerciseImage(exercise.exercise),
              ),
            ),
        ],
      ),
      footer: targets.isEmpty ? null : targets.join('\n'),
      onTap: () => unawaited(
        WorkoutTemplateDetailPage.open(
          context,
          plan.workoutId,
          mesocycleId: run?.mesocycle.id,
          microcycleIndex: workout.today?.cycleIndex,
          isDeload: workout.isDeload,
        ),
      ),
      actions: slot == null ? null : _Actions(workout: workout, slot: slot),
    );
  }

  /// The first four exercises with the tracker's own prefill, e.g. "Bench
  /// Press · 102.5 kg × 8": the session Start would begin.
  List<String> _targets(BuildContext context) {
    final session = context.watch<WorkoutPreviewCubit>().state;
    if (session == null) return const [];
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return [
      for (final exercise in session.exercises.take(4))
        switch (_detail(l10n, exercise, locale)) {
          final detail? => '${exercise.name} · $detail',
          null => exercise.name,
        },
    ];
  }

  static String? _detail(
    AppLocalizations l10n,
    WorkoutExerciseModel exercise,
    String locale,
  ) {
    final set = exercise.workingSets.firstOrNull;
    if (set == null) return null;
    final unit = WorkoutText.weightUnit(
      exercise.weightUnit ?? ExerciseWeightUnit.kilograms,
    );
    switch (exercise.trackingMode) {
      case TrackingMode.weightReps:
        final load = set.loadKg;
        final weight = load != null && load > 0
            ? AppFormat.weight(load, unit, locale: locale)
            : null;
        final reps = set.reps;
        return switch ((weight, reps)) {
          (final w?, final r?) => '$w × ${AppFormat.number(r, locale: locale)}',
          (null, final r?) => l10n.repCount(r),
          (final w?, null) => w,
          (null, null) => null,
        };
      case TrackingMode.repsOnly:
        return set.reps == null ? null : l10n.repCount(set.reps!);
      case TrackingMode.timeOnly:
        return set.durationSec == null
            ? null
            : AppFormat.duration(Duration(seconds: set.durationSec!));
      case TrackingMode.distanceTime:
        final meters = set.distanceMeters;
        return meters == null || meters <= 0
            ? null
            : AppFormat.distance(
                meters,
                AppDistanceUnit.kilometers,
                locale: locale,
              );
    }
  }

  static Future<void> _skip(BuildContext context, ScheduleSlot slot) async {
    final l10n = context.l10n;
    final cubit = context.read<ProgramsCubit>()
      ..pressed('TodaysWorkoutCard_Skip_Pressed');
    final confirmed = await confirmDestructive(
      context,
      title: l10n.programSkipNamed(slot.dayPlan.name),
      message: l10n.programSkipMessage,
      confirmLabel: l10n.programSkip,
    );
    if (!confirmed) return;
    final ok = await cubit.succeeded(
      (c) => c.skip(slot, eventPrefix: 'TodaysWorkoutCard'),
    );
    unawaited(ok ? AppHaptics.success() : AppHaptics.error());
    if (!ok && context.mounted) {
      await showFailureAlert(context, l10n.programSkipFailed);
    }
  }
}

/// Start (volt) and Skip, side by side; stacked at accessibility text
/// sizes, where they no longer fit across the card.
class const _Actions({
  required final TodaysWorkout workout,
  required final ScheduleSlot slot,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = AppCtaButton(
      label: l10n.startWorkout,
      size: AppCtaSize.compact,
      onPressed: () => unawaited(_startSlot(context, workout, slot)),
    );
    final skip = Semantics(
      hint: l10n.programSkipHint,
      child: AppTextButton(
        label: l10n.programSkipWorkout,
        onPressed: () => unawaited(_Start._skip(context, slot)),
      ),
    );
    final size = AppTextStyles.rowTitle.fontSize!;
    final stacked =
        MediaQuery.textScalerOf(context).scale(size) >=
        size * AppListRow.accessibilityTextScale;
    return stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.s,
            children: [start, skip],
          )
        : Row(
            spacing: AppSpacing.m,
            children: [
              Expanded(child: start),
              skip,
            ],
          );
  }
}
