part of 'session_edit_cubit.dart';

/// What went wrong, for the screen to say.
enum SessionEditNotice {
  /// "Unable to Save Workout": the edit could not be saved.
  saveFailed,

  /// "Unable to Save Workout": a start time or duration could not be saved.
  timingSaveFailed,

  /// "Unable to Delete Workout".
  deleteFailed,

  /// "Unable to Log Set", with [SessionEditState.logProblem].
  logProblem,

  /// "Unable to Save Note": the exercise note could not be saved.
  exerciseNoteFailed,

  /// "Unable to Save Gym": the plate calculator's bar and plates.
  gymSaveFailed,
}

/// A finished workout as the detail screen shows it, and its editing.
final class const SessionEditState({
  /// The workout shown: as edited while [isEditing].
  required final WorkoutSessionModel session,

  /// The signed-in user wrote it, and so may edit or delete it.
  final bool isAuthor = false,

  /// Edit mode is on.
  final bool isEditing = false,

  /// The edited workout differs from what was last saved.
  final bool hasUnsavedChanges = false,

  /// Save Changes is being written.
  final bool isSaving = false,

  /// The workout was deleted; the screen leaves.
  final bool isDeleted = false,

  /// The last failure, moved on by [noticeId].
  final SessionEditNotice? notice,

  /// Why the last set could not be logged.
  final r.SetProblem? logProblem,

  /// Moves with every [notice].
  final int noticeId = 0,

  /// Moves with every successful save, for the screen's success haptic.
  final int savedId = 0,

  /// While editing, each exercise with its units, steps and note, as the
  /// set table reads them.
  final List<TrackerExercise> members = const [],

  /// The keypad, open on one of the sets.
  final SetKeypad? keypad,

  /// Whether the weight keypad shows the bar and plates being loaded.
  final bool showsPlates = true,

  /// The gym the workout loads from: its own, else the usual one.
  final GymProfileModel? gym,

  /// The gyms and exercises the equipment sheet names equipment from.
  final List<GymProfileModel> gyms = const [],
  final List<ExerciseModel> library = const [],

  /// The user's workout settings, for Targets and the effort chips.
  final WorkoutSettings? settings,
}) extends Equatable {
  /// A copy with what is given; [keypad] replaces the open keypad.
  SessionEditState copyWith({
    WorkoutSessionModel? session,
    bool? isEditing,
    bool? hasUnsavedChanges,
    bool? isSaving,
    bool? isDeleted,
    int? savedId,
    List<TrackerExercise>? members,
    SetKeypad? Function()? keypad,
    bool? showsPlates,
    GymProfileModel? gym,
    List<GymProfileModel>? gyms,
    List<ExerciseModel>? library,
    WorkoutSettings? settings,
  }) => SessionEditState(
    session: session ?? this.session,
    isAuthor: isAuthor,
    isEditing: isEditing ?? this.isEditing,
    hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    isSaving: isSaving ?? this.isSaving,
    isDeleted: isDeleted ?? this.isDeleted,
    notice: notice,
    logProblem: logProblem,
    noticeId: noticeId,
    savedId: savedId ?? this.savedId,
    members: members ?? this.members,
    keypad: keypad == null ? this.keypad : keypad(),
    showsPlates: showsPlates ?? this.showsPlates,
    gym: gym ?? this.gym,
    gyms: gyms ?? this.gyms,
    library: library ?? this.library,
    settings: settings ?? this.settings,
  );

  SessionEditState withNotice(
    SessionEditNotice notice, {
    r.SetProblem? problem,
  }) => SessionEditState(
    session: session,
    isAuthor: isAuthor,
    isEditing: isEditing,
    hasUnsavedChanges: hasUnsavedChanges,
    isSaving: isSaving,
    isDeleted: isDeleted,
    notice: notice,
    logProblem: problem,
    noticeId: noticeId + 1,
    savedId: savedId,
    members: members,
    keypad: keypad,
    showsPlates: showsPlates,
    gym: gym,
    gyms: gyms,
    library: library,
    settings: settings,
  );

  @override
  List<Object?> get props => [
    // The models have no equality of their own.
    firestoreToTaggedJson(session.toFirestore()).toString(),
    isAuthor,
    isEditing,
    hasUnsavedChanges,
    isSaving,
    isDeleted,
    notice,
    logProblem,
    noticeId,
    savedId,
    members,
    keypad,
    showsPlates,
    gym,
    gyms,
    library,
    settings,
  ];

  /// The drops and mini-sets deleting [setId] would take with it.
  ({int drops, int minis}) subSetsRemovedBy(String setId) =>
      _holding(setId)?.subSetsRemovedBy(setId) ?? (drops: 0, minis: 0);

  /// The logged rows making [setId] [choice] would delete.
  int loggedRowsLostBy(String setId, r.SetTypeChoice choice) =>
      _holding(setId)?.loggedRowsLostBy(setId, choice) ?? 0;

  /// [exerciseId] as the set table reads it.
  TrackerExercise? member(String exerciseId) =>
      members.where((m) => m.exercise.id == exerciseId).firstOrNull;

  /// The plate calculator for the keypad's set.
  PlateCalculatorSetup? get plateCalculatorSetup {
    final keypad = this.keypad;
    if (keypad == null) return null;
    final exercise = member(keypad.exerciseId)?.exercise;
    return PlateCalculatorSetup.forSet(
      gym,
      exercise,
      exercise?.sets.where((s) => s.id == keypad.setId).firstOrNull,
    );
  }

  /// The equipment sheet for [exerciseId].
  EquipmentSheetSetup? equipmentSetup(String exerciseId) =>
      switch (member(exerciseId)) {
        final member? => EquipmentSheetSetup(
          exercise: member.exercise,
          library: library,
          gyms: gyms,
          gym: gym,
        ),
        null => null,
      };

  /// [exerciseId] as the library has it; `null` for one it no longer
  /// holds, which offers no Targets or Exercise Settings, as in Swift.
  ExerciseModel? libraryModel(String exerciseId) =>
      switch (member(exerciseId)) {
        final member? =>
          library.where((e) => e.id == member.exercise.templateId).firstOrNull,
        null => null,
      };

  /// Whether swapping [exerciseId] for [replacement] asks first: logged
  /// sets cannot move to an exercise measured differently ("Discard Logged
  /// Sets?", `onSwapPressed`).
  bool asksBeforeSwapping(String exerciseId, ExerciseModel replacement) =>
      switch (member(exerciseId)?.exercise) {
        final exercise? =>
          exercise.sets.any((s) => s.completedAt != null) &&
              !measuresAlike(exercise, replacement),
        null => false,
      };

  WorkoutExerciseModel? _holding(String setId) => session.exercises
      .where((e) => e.sets.any((s) => s.id == setId))
      .firstOrNull;
}
