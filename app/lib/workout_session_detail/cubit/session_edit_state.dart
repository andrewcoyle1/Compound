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
}) extends Equatable {
  SessionEditState copyWith({
    WorkoutSessionModel? session,
    bool? isEditing,
    bool? hasUnsavedChanges,
    bool? isSaving,
    bool? isDeleted,
    int? savedId,
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
  ];

  /// The drops and mini-sets deleting [setId] would take with it.
  ({int drops, int minis}) subSetsRemovedBy(String setId) =>
      _holding(setId)?.subSetsRemovedBy(setId) ?? (drops: 0, minis: 0);

  /// The logged rows making [setId] [choice] would delete.
  int loggedRowsLostBy(String setId, r.SetTypeChoice choice) =>
      _holding(setId)?.loggedRowsLostBy(setId, choice) ?? 0;

  WorkoutExerciseModel? _holding(String setId) => session.exercises
      .where((e) => e.sets.any((s) => s.id == setId))
      .firstOrNull;
}
