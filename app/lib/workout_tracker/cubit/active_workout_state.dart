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

  /// What each row's rest picker opens on, by set id.
  final Map<String, int> restPicker = const {},
}) extends Equatable {
  @override
  List<Object?> get props => [
    exercise,
    previous,
    weightStep,
    weightUnit,
    restAnchor,
    exerciseNote,
    restPicker,
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

/// The bar or plates chosen in the plate calculator could not be saved to
/// the gym: the error haptic and an alert.
final class GymSaveFailedEffect extends TrackerEffect {
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

  /// Whether the weight keypad shows the bar and plates being loaded; its
  /// plates key switches it (`setKeyboard.showsPlates`).
  final bool showsPlates = true,

  /// The exercises and gyms the equipment sheet names equipment from.
  final List<ExerciseModel> library = const [],
  final List<GymProfileModel> gyms = const [],
}) extends Equatable {
  /// The plate calculator for the keypad's set, on its exercise's bar or
  /// plate-loaded machine in the workout's gym, plates on or not. `null`
  /// with no gym, no keypad or no such equipment.
  PlateCalculatorSetup? get plateCalculatorSetup {
    final keypad = this.keypad;
    final gym = this.gym;
    final exercise = keypad == null ? null : this.exercise(keypad.exerciseId);
    final set = keypad == null ? null : this.set(keypad.setId);
    if (gym == null || exercise == null || set == null) return null;
    final unit = exercise.weightUnit ?? ExerciseWeightUnit.kilograms;
    final equipment = exercise.activeVariation?.resistanceEquipment
        .where(
          (ref) =>
              WeightStepper.steps([ref], gym, unit.rules).baseWeight != null,
        )
        .firstOrNull;
    if (equipment == null) return null;
    double inUnit(double kg) => r.convertWeight(kg, unit.rules);
    return PlateCalculatorSetup(
      gym: gym,
      equipment: equipment,
      unit: unit,
      total: switch (set.weightKg) {
        final kg? => (inUnit(kg) * 1000).roundToDouble() / 1000,
        null => null,
      },
      machineBase: inUnit(set.machineBaseKg ?? 0),
    );
  }

  /// How many logged rows making [setId] [choice] would delete: sub-rows
  /// the new type has no use for (`onSetTypeSelected`).
  int loggedRowsLostBy(String setId, r.SetTypeChoice choice) {
    final exercise = exerciseHolding(setId);
    if (exercise == null) return 0;
    final kept = {
      for (final row in r.ActiveWorkout.applying(
        choice,
        setId,
        exercise.sets.map(rulesSet).toList(),
        firstSubSetId: '',
        dropWeightKg: null,
      ))
        row.id,
    };
    return exercise.sets
        .where((s) => s.completedAt != null && !kept.contains(s.id))
        .length;
  }

  /// The drops and mini-sets deleting [setId] would take with it.
  ({int drops, int minis}) subSetsRemovedBy(String setId) {
    final exercise = exerciseHolding(setId);
    if (exercise == null) return (drops: 0, minis: 0);
    return r.ActiveWorkout.subSetsRemovedByDeleting(
      setId,
      exercise.sets.map(rulesSet).toList(),
    );
  }

  /// The equipment sheet for [exerciseId]: its variations and the workout's
  /// gym.
  EquipmentSheetSetup? equipmentSetup(String exerciseId) =>
      switch (exercise(exerciseId)) {
        final exercise? => EquipmentSheetSetup(
          exercise: exercise,
          library: library,
          gyms: gyms,
          gym: gym,
        ),
        null => null,
      };

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
    showsPlates,
    library,
    gyms,
  ];
}
