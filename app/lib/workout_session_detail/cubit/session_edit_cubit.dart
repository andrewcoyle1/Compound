import 'dart:async';
import 'dart:convert';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:strava_repository/strava_repository.dart' show StravaRepository;
import 'package:training_library_repository/training_library_repository.dart'
    show PrebuiltCatalogue, TrainingLibraryRepository;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart' show UserRepository;
import 'package:workout_session_repository/workout_session_repository.dart'
    show WorkoutSessionRepository;

part 'session_edit_state.dart';

/// Editing a finished workout (Swift `WorkoutSessionDetailPresenter`'s edit
/// mode, timing and delete): only its author edits. Sets and exercises are
/// changed through `training_session`'s [ActiveSessionController] with the
/// tracker's rules, but no rest runs and nothing propagates, as Swift's
/// editor rows bind straight to the session. Start Time and Duration save
/// from their sheets; everything else waits for Save Changes. A save writes
/// only what editing changes ([WorkoutSessionRepository.updateEditedSession])
/// and is sent to Strava when the workout is there. After a save or a
/// delete the reminder's copy of the streak is brought up to date.
class SessionEditCubit extends Cubit<SessionEditState> {
  new({
    required WorkoutSessionModel session,
    required this._sessions,
    required this._users,
    required this._analytics,
    required this._uid,
    this._library,
    this._strava,
    this._clock = DateTime.now,
    this._newId = newUuid,
  }) : _saved = session,
       super(
         SessionEditState(
           session: session,
           // Nobody owns a workout when no one is signed in.
           isAuthor: _uid != null && _uid == session.authorId,
         ),
       );

  final WorkoutSessionRepository _sessions;
  final UserRepository _users;
  final AnalyticsRepository _analytics;
  final String? _uid;
  final TrainingLibraryRepository? _library;
  final StravaRepository? _strava;
  final DateTime Function() _clock;
  final IdGenerator _newId;

  /// What was last written from this screen, or what it opened with.
  WorkoutSessionModel _saved;
  ActiveSessionController? _controller;
  List<ExerciseModel> _userExercises = const [];

  static const _screen = 'WorkoutSessionDetailView';

  bool get _isAuthor => state.isAuthor;

  // MARK: - Edit mode

  /// Edit Workout, for the author only.
  Future<void> enterEditMode() async {
    if (!_isAuthor || state.isEditing) return;
    final uid = _uid!;
    try {
      _userExercises = await _library?.watchUserExercises(uid).first ?? [];
    } on Object {
      // The prebuilt library is enough to edit with.
    }
    if (isClosed) return;
    _controller = _newController(state.session);
    emit(state.copyWith(isEditing: true));
  }

  ActiveSessionController _newController(WorkoutSessionModel session) =>
      ActiveSessionController(
        state: ActiveSessionState(session: session),
        environment: TrackerEnvironment(
          authorId: session.authorId,
          // The editor runs no rest and carries no edit onto other sets.
          settings: WorkoutSettings(
            authorId: session.authorId,
            propagateChanges: false,
            useRestTimers: false,
          ),
          library: [..._userExercises, ...PrebuiltCatalogue.instance.exercises],
        ),
        store: InMemoryActiveSessionStore(),
        clock: _clock,
        newId: _newId,
      );

  /// The close button while editing, with nothing to throw away; with
  /// something, the screen asks first ([discardChanges]).
  void endEditing() {
    if (!state.hasUnsavedChanges) _leaveEditMode(state.session);
  }

  /// Discard Changes: the workout as last saved.
  void discardChanges() => _leaveEditMode(_saved);

  void _leaveEditMode(WorkoutSessionModel session) {
    _controller = null;
    emit(
      state.copyWith(
        session: session,
        isEditing: false,
        hasUnsavedChanges: false,
      ),
    );
  }

  /// Save Changes. Nothing changed writes nothing; a failure keeps the
  /// edit open with the work in it.
  Future<void> saveChanges({required int firstWeekday}) async {
    if (!state.isEditing || state.isSaving) return;
    if (!state.hasUnsavedChanges) return _leaveEditMode(state.session);
    final session = state.session.copyWith(dateModified: _clock());
    emit(state.copyWith(isSaving: true));
    _track('${_screen}_SaveChanges_Start');
    try {
      await _sessions.updateEditedSession(session.authorId, session);
    } on Object catch (error) {
      _fail('${_screen}_SaveChanges_Fail', error);
      if (isClosed) return;
      return emit(
        state
            .copyWith(isSaving: false)
            .withNotice(SessionEditNotice.saveFailed),
      );
    }
    _track('${_screen}_SaveChanges_Success');
    _saved = session;
    if (isClosed) return;
    emit(state.copyWith(isSaving: false, savedId: state.savedId + 1));
    _leaveEditMode(session);
    // The description lists the sets as well as the notes, so any saved
    // edit can change it.
    unawaited(_pushToStrava(session));
    await _recordStreak(firstWeekday);
  }

  /// Best-effort: the edit is saved in Compound either way, and Strava
  /// keeps the old description.
  Future<void> _pushToStrava(WorkoutSessionModel session) async {
    try {
      await _strava?.pushEdit(session);
    } on Object catch (error) {
      _track(
        '${_screen}_StravaUpdate_Fail',
        parameters: {'error_description': '$error'},
        type: LogType.warning,
      );
    }
  }

  // MARK: - Timing

  /// Start Time's confirm: the workout moves, keeping how long it took.
  Future<void> changeStart(DateTime start, {required int firstWeekday}) {
    final session = state.session;
    final ended = session.endedAt;
    return _saveTiming(
      session.copyWith(
        dateCreated: start,
        endedAt: ended?.add(start.difference(session.dateCreated)),
        dateModified: _clock(),
      ),
      firstWeekday: firstWeekday,
    );
  }

  /// Duration's confirm, in active time: the end moves past the start by
  /// it and the time spent paused. No time at all is refused.
  Future<void> changeDuration(
    int hours,
    int minutes, {
    required int firstWeekday,
  }) async {
    final seconds = hours * 3600 + minutes * 60;
    if (seconds <= 0) return;
    final session = state.session;
    final paused = (session.pausedSeconds ?? 0).round();
    await _saveTiming(
      session.copyWith(
        endedAt: session.dateCreated.add(Duration(seconds: seconds + paused)),
        dateModified: _clock(),
      ),
      firstWeekday: firstWeekday,
    );
  }

  /// Saves at once, with whatever else is being edited: afterwards nothing
  /// is unsaved.
  Future<void> _saveTiming(
    WorkoutSessionModel session, {
    required int firstWeekday,
  }) async {
    if (!_isAuthor) return;
    if (_controller != null) _controller = _newController(session);
    emit(state.copyWith(session: session, hasUnsavedChanges: true));
    _track('${_screen}_SaveTiming_Start');
    try {
      await _sessions.updateEditedSession(session.authorId, session);
    } on Object catch (error) {
      _fail('${_screen}_SaveTiming_Fail', error);
      if (isClosed) return;
      return emit(state.withNotice(SessionEditNotice.timingSaveFailed));
    }
    _track('${_screen}_SaveTiming_Success');
    _saved = session;
    if (isClosed) return;
    emit(state.copyWith(hasUnsavedChanges: false, savedId: state.savedId + 1));
    await _recordStreak(firstWeekday);
  }

  // MARK: - Delete

  /// Delete, once confirmed. The screen leaves only once it has.
  Future<void> delete({required int firstWeekday}) async {
    if (!_isAuthor) return;
    final session = state.session;
    _track('${_screen}_DeleteSession_Start');
    try {
      await _sessions.deleteSession(session.authorId, session.id);
    } on Object catch (error) {
      _fail('${_screen}_DeleteSession_Fail', error);
      if (isClosed) return;
      return emit(state.withNotice(SessionEditNotice.deleteFailed));
    }
    _track('${_screen}_DeleteSession_Success');
    if (isClosed) return;
    emit(state.copyWith(isDeleted: true));
    await _recordStreak(firstWeekday);
  }

  // MARK: - The streak

  /// The reminder's copy of the streak (`recordWeeklyStreak`), written only
  /// when it changed. Swift refreshes it at the next launch; a moved or
  /// deleted workout can change it now. Best-effort.
  Future<void> _recordStreak(int firstWeekday) async {
    final uid = _uid!;
    try {
      final history = await _sessions.watchSessions(uid).first;
      final user = await _users.watchUser(uid).first;
      final private = await _users.watchPrivateSettings(uid).first;
      final record = StreakRecord.of(
        history,
        uid: uid,
        goal: maths.weeklySessionGoal(user?.weeklySessionGoal),
        now: _clock(),
        firstWeekday: firstWeekday,
      );
      if (!record.isRecordedIn(private)) {
        await _users.mergePrivateSettings(
          uid,
          record.settings,
          clearing: record.clearing,
        );
      }
    } on Object catch (error) {
      _track(
        '${_screen}_RecordStreak_Fail',
        parameters: {'error_description': '$error'},
        type: LogType.warning,
      );
    }
  }

  // MARK: - Editing

  /// The workout's notes; blank clears them.
  void setNotes(String notes) => _edit((c) => c.setWorkoutNotes(notes));

  /// An exercise's notes for this workout; blank clears them.
  void setExerciseNotes(String exerciseId, String notes) =>
      _edit((c) => c.setExerciseNotes(exerciseId, notes));

  /// One more set (`ExerciseTrackerPresenter.addSet`).
  void addSet(String exerciseId) {
    _edit((c) => c.addSet(exerciseId));
    _track('SetTracker_Set_Added');
  }

  /// [set] with its figures edited.
  void updateSet(String exerciseId, WorkoutSetModel set) =>
      _edit((c) => c.updateSet(exerciseId, set));

  /// Deletes [setId] with its pair and sub-rows.
  void deleteSet(String setId) {
    _edit((c) => c.deleteSet(setId));
    _track('SetTrackerRow_SetDeleted');
  }

  /// The set type menu.
  void setSetType(String setId, r.SetTypeChoice choice) {
    final set = _set(setId);
    if (set == null || r.typeChoiceOf(rulesSet(set)) == choice) return;
    _edit((c) => c.setSetType(setId, choice));
    _track(
      'SetTrackerRow_SetTypeChanged',
      parameters: {'set_type': choice.eventValue},
    );
  }

  /// Add Another Drop or Mini-Set.
  void addSubSet(String setId, r.SubSetKind kind) {
    if (_set(setId) == null) return;
    _edit((c) => c.addSubSet(setId, kind));
    _track(
      'SetTrackerRow_SubSetAdded',
      parameters: {'kind': kind == r.SubSetKind.drop ? 'drop' : 'mini'},
    );
  }

  /// Split L/R, or both sides as one again.
  void toggleSides(String exerciseId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null) return;
    final splitting = !rulesExercise(exercise).isSplit;
    _edit(
      (c) => splitting ? c.splitSides(exerciseId) : c.joinSides(exerciseId),
    );
    _track('SetTracker_Sides_Split', parameters: {'split': splitting});
  }

  /// The tick: a logged set is un-logged, an open one logged when it can
  /// be (`SetTrackerRowPresenter.onSetComplete`, with no rest).
  void toggleSet(String setId) {
    final controller = _controller;
    final set = _set(setId);
    if (controller == null || set == null) return;
    final exercise = _exerciseHolding(setId)!;
    final result = controller.toggleSet(setId);
    _changed();
    if (result == null) return;
    if (result.problem case final problem?) {
      return emit(
        state.withNotice(SessionEditNotice.logProblem, problem: problem),
      );
    }
    _track(
      'SetTrackerRow_SetCompleted',
      parameters: {
        'source': 'row',
        'set_id': setId,
        'exercise_id': exercise.id,
        'use_rest_timers': false,
        'rest_duration_seconds': result.restSeconds ?? 0,
      },
    );
  }

  /// Delete on an exercise, once confirmed.
  void deleteExercise(String exerciseId) =>
      _edit((c) => c.deleteExercise(exerciseId));

  /// Exercises picked to add, each with one set in the default rep range.
  void addExercises(List<ExerciseModel> exercises) {
    if (exercises.isEmpty) return;
    _edit(
      (c) => c.addExercises([
        for (final exercise in exercises)
          WorkoutTemplateExercise(
            id: _newId(),
            exercise: exercise,
            setTargets: [
              SetTarget(
                id: _newId(),
                setNumber: 1,
                minReps: r.SetTarget.defaultRepRangeMin,
                maxReps: r.SetTarget.defaultRepRangeMax,
              ),
            ],
            setRestTimers: false,
          ),
      ]),
    );
  }

  void _edit(void Function(ActiveSessionController controller) change) {
    final controller = _controller;
    if (controller == null) return;
    change(controller);
    _changed();
  }

  void _changed() {
    final controller = _controller!..flush();
    final session = controller.session;
    emit(
      state.copyWith(
        session: session,
        hasUnsavedChanges: !_same(session, _saved),
      ),
    );
  }

  static bool _same(WorkoutSessionModel a, WorkoutSessionModel b) =>
      jsonEncode(firestoreToTaggedJson(a.toFirestore())) ==
      jsonEncode(firestoreToTaggedJson(b.toFirestore()));

  WorkoutExerciseModel? _exercise(String id) =>
      state.session.exercises.where((e) => e.id == id).firstOrNull;

  WorkoutExerciseModel? _exerciseHolding(String setId) => state
      .session
      .exercises
      .where((e) => e.sets.any((s) => s.id == setId))
      .firstOrNull;

  WorkoutSetModel? _set(String setId) =>
      _exerciseHolding(setId)?.sets.firstWhere((s) => s.id == setId);

  void _fail(String name, Object error) => _track(
    name,
    parameters: {'error_description': '$error'},
    type: LogType.severe,
  );

  void _track(
    String name, {
    Map<String, Object?>? parameters,
    LogType type = LogType.analytic,
  }) => _analytics.trackEvent(
    AnalyticsEvent(name, parameters: parameters, type: type),
  );
}
