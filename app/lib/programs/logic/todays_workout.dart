import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:program_repository/program_repository.dart';

/// What Today's workout card shows (Swift `TodaysWorkoutCardPresenter`):
/// today's entry of the active mesocycle's queue, and what Start, Skip and
/// the card itself act on.
final class const TodaysWorkout({
  /// Today's entry; null with no mesocycle or a finished block.
  required final ScheduledDay? today,
  required final MesocycleRun? run,
  required final ScheduleProgress? progress,
  required final List<WorkoutSessionModel> sessions,
}) {
  factory of(ProgramsState state, DateTime now) {
    final run = state.activeRun;
    return TodaysWorkout(
      today: MesocycleSchedule.todayItem(run, state.sessions, now: now),
      run: run,
      progress: run == null
          ? null
          : MesocycleSchedule.progress(run, state.sessions, now: now),
      sessions: state.sessions,
    );
  }

  /// Minutes per working set, rest included, for a workout never done.
  static const minutesPerWorkingSet = 2.5;

  bool get isRestDay => today?.dayPlan.exercises.isEmpty ?? false;

  bool get isCompleted => today?.isCompleted ?? false;

  /// Today's workout when it is the next open slot: not a rest day and not
  /// already done. Only it can be skipped.
  ScheduleSlot? get openSlot {
    final today = this.today;
    final next = progress?.next;
    if (today == null || today.isCompleted || isRestDay || next == null) {
      return null;
    }
    return next.dayPlan.workoutId == today.dayPlan.workoutId ? next : null;
  }

  /// What Start begins: today's workout, or on a rest day the next one.
  ScheduleSlot? get startableSlot => isRestDay ? progress?.next : openSlot;

  /// Whether [startableSlot] falls in the deload microcycle.
  bool get isDeload => switch ((startableSlot, run)) {
    (final slot?, final run?) => MesocycleSchedule.isDeload(
      slot.cycleIndex + 1,
      run.mesocycle,
    ),
    _ => false,
  };

  /// The finished session behind today's workout, once it has synced.
  WorkoutSessionModel? get completedSession {
    final id = today?.completedSessionId;
    if (isRestDay || id == null) return null;
    return sessions.where((session) => session.id == id).firstOrNull;
  }

  /// The median active time of the last five times [template] was done;
  /// with none, its working sets at [minutesPerWorkingSet] each.
  static Duration estimatedDuration(
    WorkoutTemplateModel template,
    List<WorkoutSessionModel> history,
  ) {
    final recent = [
      for (final session in history)
        if (session.workoutTemplateId == template.workoutId &&
            session.deletedAt == null &&
            !session.isRestDay)
          session,
    ]..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    final durations = [
      for (final session in recent.take(5))
        if (session.activeDuration case final d? when d > Duration.zero) d,
    ]..sort();
    if (durations.isNotEmpty) return durations[durations.length ~/ 2];
    final sets = template.exercises.fold<int>(
      0,
      (sum, e) => sum + (e.setTargets.isEmpty ? 1 : e.setTargets.length),
    );
    return Duration(seconds: (sets * minutesPerWorkingSet * 60).round());
  }

  /// The estimate in minutes, to the nearest five and at least five; null
  /// when there is nothing to estimate.
  int? get estimatedMinutes {
    final template = openSlot?.dayPlan;
    if (template == null) return null;
    final seconds = estimatedDuration(template, sessions).inSeconds;
    if (seconds <= 0) return null;
    final minutes = (seconds / 300).round() * 5;
    return minutes < 5 ? 5 : minutes;
  }
}
