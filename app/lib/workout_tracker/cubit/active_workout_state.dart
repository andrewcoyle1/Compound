part of 'active_workout_cubit.dart';

enum ActiveWorkoutStatus {
  /// No workout under way.
  none,

  /// Looking on the device for a workout to carry on.
  loading,

  /// A workout is under way.
  active,
}

/// One exercise on the card, with what its rows read beside the session.
final class const TrackerExercise({
  required final WorkoutExerciseModel exercise,

  /// What it was last time, for the Last column.
  required final WorkoutExerciseModel? previous,

  /// The steps − and + move its weight by, in [weightUnit].
  required final r.WeightStep weightStep,
  required final ExerciseWeightUnit weightUnit,

  /// Where the inline rest timer sits in its table; `null` leaves it out.
  required final r.RestAnchor? restAnchor,

  /// The user's standing note on the exercise (every workout).
  required final String? exerciseNote,
}) extends Equatable {
  @override
  List<Object?> get props => [
    exercise,
    previous,
    weightStep,
    weightUnit,
    restAnchor,
    exerciseNote,
  ];
}

/// Something the screen does once: a haptic, an announcement, an alert.
sealed class TrackerEffect extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// A set was logged: the success haptic, and VoiceOver/TalkBack hear it.
final class const SetLoggedEffect(
  final String exerciseId,
  final String setId, {

  /// Every set is now logged, so Finish Workout is offered.
  final bool allComplete = false,
}) extends TrackerEffect {
  @override
  List<Object?> get props => [exerciseId, setId, allComplete];
}

/// The set could not be logged: the error haptic and an alert.
final class const LogRefusedEffect(final r.SetProblem problem)
    extends TrackerEffect {
  @override
  List<Object?> get props => [problem];
}

/// A set was deleted; Undo puts it back.
final class SetDeletedEffect extends TrackerEffect {
  const new();
}

/// A choice was made (a chip, a step): the selection haptic.
final class SelectionEffect extends TrackerEffect {
  const new();
}

/// Something was saved (a note): the success haptic.
final class SavedEffect extends TrackerEffect {
  const new();
}

/// The rest ran out while the tracker is up: the rest-complete sound and
/// haptic, as the settings ask (`announceRestCompletion`).
final class RestOverEffect extends TrackerEffect {
  const new();
}

/// An hour has passed since [lastSet] was logged: "Still training?", with
/// Finish as of that set or Keep Going.
final class const StillTrainingEffect(final DateTime lastSet)
    extends TrackerEffect {
  @override
  List<Object?> get props => [lastSet];
}

/// The workout could not be started.
final class StartFailedEffect extends TrackerEffect {
  const new();
}

/// The workout under way, as the tracker shows it.
final class const ActiveWorkoutState({
  final ActiveWorkoutStatus status = ActiveWorkoutStatus.none,
  final WorkoutSessionModel? session,

  /// The exercise on the card.
  final String? currentExerciseId,

  /// The card's block: the exercise, or every member of its superset.
  final List<TrackerExercise> card = const [],

  /// The card's superset letter, and its rows in rounds.
  final String? supersetLetter,
  final List<r.SupersetBlockRow> blockRows = const [],

  /// What the bottom button does with no rest running.
  final r.ActiveWorkoutAction? primaryAction,
  final List<r.StripItem> strip = const [],
  final DateTime? restEnd,
  final DateTime? restStartedAt,

  /// For a second after a rest runs out the button cannot be tapped: a tap
  /// meant for Skip Rest would log the next set.
  final DateTime? graceEnd,
  final DateTime? pausedAt,
  final double pausedSeconds = 0,

  /// The set logged last, on its own exercise, to correct while its rest
  /// runs (`WorkoutTrackerPresenter.restCorrection`).
  final SetCorrection? correction,
  final UndoName? undoName,
  final WorkoutSettings? settings,
  final SetKeypad? keypad,
  final TrackerEffect? effect,
  final int effectId = 0,

  /// The workout just finished, for the summary to open on.
  final WorkoutSessionModel? finishedSession,

  /// How saving the finished workout is going, to tell the user.
  final SaveProgress? saveNotice,
  final int saveNoticeId = 0,

  /// The gym the workout loads from, which Gym Settings opens: the
  /// session's, else the usual one.
  final GymProfileModel? gym,
}) extends Equatable {
  bool get isActive => status == ActiveWorkoutStatus.active && session != null;

  bool get isPaused => pausedAt != null;

  /// What the bottom button does at [now] (`ActiveWorkout.slotAction`).
  r.SlotAction? slotAt(DateTime now) => r.ActiveWorkout.slotAction(
    primary: primaryAction,
    restEnd: restEnd,
    isPaused: isPaused,
    now: now,
  );

  bool isInGraceAt(DateTime now) =>
      !isPaused && graceEnd != null && now.isBefore(graceEnd!);

  /// The workout clock at [now], paused time left out.
  Duration elapsedAt(DateTime now) {
    final start = session?.dateCreated;
    if (start == null) return Duration.zero;
    final pausing = pausedAt == null
        ? Duration.zero
        : now.difference(pausedAt!);
    final elapsed =
        now.difference(start) -
        Duration(microseconds: (pausedSeconds * 1e6).round()) -
        pausing;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  bool get hasLoggedSet =>
      session?.exercises.any((e) => e.sets.any((s) => s.completedAt != null)) ??
      false;

  WorkoutExerciseModel? exercise(String id) =>
      session?.exercises.where((e) => e.id == id).firstOrNull;

  WorkoutExerciseModel? exerciseHolding(String setId) => session?.exercises
      .where((e) => e.sets.any((s) => s.id == setId))
      .firstOrNull;

  WorkoutSetModel? set(String setId) =>
      exerciseHolding(setId)?.sets.firstWhere((s) => s.id == setId);

  /// The rest's full length, for its progress bar.
  Duration? get restLength => switch ((restStartedAt, restEnd)) {
    (final start?, final end?) => end.difference(start),
    _ => null,
  };

  @override
  List<Object?> get props => [
    status,
    session,
    currentExerciseId,
    card,
    supersetLetter,
    blockRows,
    primaryAction,
    strip,
    restEnd,
    restStartedAt,
    graceEnd,
    pausedAt,
    pausedSeconds,
    correction,
    undoName,
    settings,
    keypad,
    effect,
    effectId,
    finishedSession,
    saveNotice,
    saveNoticeId,
    gym,
  ];
}
