import 'dart:async';
import 'dart:convert';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart'
    show TrackerExercise;
import 'package:compound/workout_tracker/cubit/equipment_sheet_cubit.dart'
    show EquipmentSheetSetup;
import 'package:compound/workout_tracker/cubit/keypad_editing.dart';
import 'package:compound/workout_tracker/cubit/plate_calculator_cubit.dart'
    show PlateCalculatorSetup;
import 'package:compound/workout_tracker/logic/set_changes.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound/workout_tracker/view/set_table.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';
import 'package:device_store/device_store.dart';
import 'package:equatable/equatable.dart';
import 'package:strava_repository/strava_repository.dart' show StravaRepository;
import 'package:training_library_repository/training_library_repository.dart'
    show GymEditorRules, PrebuiltCatalogue, TrainingLibraryRepository;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart' show UserRepository;
import 'package:workout_session_repository/workout_session_repository.dart'
    show WorkoutSessionRepository;

part 'session_edit_state.dart';

/// Editing a finished workout (Swift `WorkoutSessionDetailPresenter`'s edit
/// mode, timing and delete, with `ExerciseTrackerPresenter` and the set
/// rows its editor shows): only its author edits. Sets and exercises are
/// changed through `training_session`'s [ActiveSessionController] with the
/// tracker's rules, but no rest runs and nothing propagates, as Swift's
/// editor rows bind straight to the session. The set table is the
/// tracker's ([SetTableActions]), keypad and all.
///
/// Start Time and Duration save from their sheets, and the exercise note
/// (kept on the exercise, not the workout) as it is written; everything
/// else waits for Save Changes. A save writes only what editing changes
/// ([WorkoutSessionRepository.updateEditedSession]) and is sent to Strava
/// when the workout is there. After a save or a delete the reminder's copy
/// of the streak is brought up to date.
class SessionEditCubit extends Cubit<SessionEditState>
    with KeypadEditing
    implements SetTableActions {
  new({
    required WorkoutSessionModel session,
    required this._sessions,
    required this._users,
    required this._analytics,
    required this._uid,
    this._library,
    this._strava,
    UnitPreferenceStore? units,
    DeviceStore? device,
    this._clock = DateTime.now,
    this._newId = newDocumentId,
  }) : _saved = session,
       _units = units ?? UnitPreferenceStore(),
       _device = device ?? InMemoryDeviceStore(),
       super(
         SessionEditState(
           session: session,
           // Nobody owns a workout when no one is signed in.
           isAuthor: _uid != null && _uid == session.authorId,
           // The tracker's plates switch, kept on the device.
           showsPlates: device?.getBool(KeypadEditing.showsPlatesKey) ?? true,
         ),
       );

  final WorkoutSessionRepository _sessions;
  final UserRepository _users;
  final AnalyticsRepository _analytics;
  final String? _uid;
  final TrainingLibraryRepository? _library;
  final StravaRepository? _strava;

  /// Each exercise's units, kept on the device.
  final UnitPreferenceStore _units;

  /// The keypad's plates switch, kept on the device.
  final DeviceStore _device;
  final DateTime Function() _clock;
  final IdGenerator _newId;

  /// What was last written from this screen, or what it opened with.
  WorkoutSessionModel _saved;
  ActiveSessionController? _controller;
  List<ExerciseModel> _userExercises = const [];
  List<ExerciseSettingsModel> _exerciseSettings = const [];
  List<GymProfileModel> _gyms = const [];
  WorkoutSettings? _settings;
  UserModel? _user;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  static const _screen = 'WorkoutSessionDetailView';

  bool get _isAuthor => state.isAuthor;

  // MARK: - Edit mode

  /// Edit Workout, for the author only. What the set table reads is
  /// fetched once; the exercise notes and units follow their changes, as
  /// Exercise Settings can change them while editing.
  Future<void> enterEditMode() async {
    if (!_isAuthor || state.isEditing) return;
    final uid = _uid!;
    // Each is a nicety the editor works without.
    Future<T?> read<T>(Stream<T>? Function() stream) async {
      try {
        return await stream()?.first;
      } on Object {
        return null;
      }
    }

    final library = _library;
    _userExercises = await read(() => library?.watchUserExercises(uid)) ?? [];
    _settings = await read(() => library?.watchWorkoutSettings(uid));
    _gyms = await read(() => library?.watchGymProfiles(uid)) ?? [];
    _exerciseSettings =
        await read(() => library?.watchExerciseSettings(uid)) ?? [];
    _user = await read<UserModel?>(() => _users.watchUser(uid));
    if (isClosed) return;
    void follow<T>(Stream<T>? stream, void Function(T) onData) {
      if (stream == null) return;
      _subscriptions.add(
        stream.listen((data) {
          onData(data);
          _environmentChanged();
        }, onError: (Object _, StackTrace _) {}),
      );
    }

    follow(library?.watchExerciseSettings(uid), (d) => _exerciseSettings = d);
    follow(_units.changes, (_) {});
    _controller = _newController(state.session);
    _emitEdit(isEditing: true);
  }

  List<ExerciseModel> get _allExercises => [
    ..._userExercises,
    ...PrebuiltCatalogue.instance.exercises,
  ];

  List<GymProfileModel> get _activeGyms => [
    for (final gym in _gyms)
      if (gym.deletedAt == null) gym,
  ];

  GymProfileModel? _gym(String? id) =>
      _activeGyms.where((gym) => gym.id == id).firstOrNull;

  /// The workout's own gym, else the usual one (Swift's editor reads the
  /// favourite: `workoutGymProfile` with no workout running).
  GymProfileModel? get _workoutGym =>
      _gym(state.session.gymProfileId) ??
      _gym(_user?.submittedFavouriteGymProfileId);

  ActiveSessionController _newController(WorkoutSessionModel session) =>
      ActiveSessionController(
        state: ActiveSessionState(session: session),
        environment: _environment(session),
        store: InMemoryActiveSessionStore(),
        clock: _clock,
        newId: _newId,
      );

  TrackerEnvironment _environment(WorkoutSessionModel session) {
    final settings = _settings;
    return TrackerEnvironment(
      authorId: session.authorId,
      // The editor runs no rest and carries no edit onto other sets.
      settings: WorkoutSettings.fromFirestore({
        ...?settings?.toFirestore(),
        if (settings == null)
          ...WorkoutSettings(authorId: session.authorId).toFirestore(),
        WorkoutSettingsKeys.propagateChanges: false,
        WorkoutSettingsKeys.useRestTimers: false,
      }),
      library: _allExercises,
      gym: _workoutGym,
      unitPreferences: {
        for (final id in {
          for (final exercise in _allExercises) exercise.id,
          for (final exercise in session.exercises) exercise.templateId,
        })
          id: _preference(id),
      },
    );
  }

  void _environmentChanged() {
    final controller = _controller;
    if (controller == null || isClosed) return;
    controller.environment = _environment(controller.session);
    _emitEdit();
  }

  UnitPreference _preference(String templateId) =>
      _units.of(_uid, templateId, user: _user);

  ExerciseWeightUnit _unit(WorkoutExerciseModel exercise) =>
      exercise.weightUnit ?? _preference(exercise.templateId).weightUnit;

  DistanceUnit _distanceUnit(WorkoutExerciseModel exercise) =>
      _preference(exercise.templateId).distanceUnit;

  String? _exerciseNote(String templateId) {
    final note = _exerciseSettings
        .where((settings) => settings.id == templateId)
        .firstOrNull
        ?.note
        ?.trim();
    return note == null || note.isEmpty ? null : note;
  }

  /// The close button while editing, with nothing to throw away; with
  /// something, the screen asks first ([discardChanges]).
  void endEditing() {
    if (!state.hasUnsavedChanges) _leaveEditMode(state.session);
  }

  /// Discard Changes: the workout as last saved.
  void discardChanges() => _leaveEditMode(_saved);

  void _leaveEditMode(WorkoutSessionModel session) {
    _controller = null;
    _cancelSubscriptions();
    emit(
      state.copyWith(
        session: session,
        isEditing: false,
        hasUnsavedChanges: false,
        members: const [],
        keypad: () => null,
      ),
    );
  }

  void _cancelSubscriptions() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  /// Save Changes. Nothing changed writes nothing; a failure keeps the
  /// edit open with the work in it.
  Future<void> saveChanges({required int firstWeekday}) async {
    if (!state.isEditing || state.isSaving) return;
    _controller?.commitEdit();
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
    emit(
      state.copyWith(
        session: session,
        hasUnsavedChanges: true,
        keypad: () => null,
      ),
    );
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

  // MARK: - Notes

  /// The workout's notes; blank clears them.
  void setNotes(String notes) => _edit((c) => c.setWorkoutNotes(notes));

  /// An exercise's notes for this workout; blank clears them.
  void setExerciseNotes(String exerciseId, String notes) =>
      _edit((c) => c.setExerciseNotes(exerciseId, notes));

  /// The notes sheet's Save: [sessionNote] on this workout, kept with the
  /// edit, and [exerciseNote] on the exercise for every workout, saved now
  /// (`onNotePressed`). Only a changed note is written; a blank exercise
  /// note is written as "", so a merge cannot keep the old one.
  Future<void> saveExerciseNotes(
    String exerciseId, {
    required String sessionNote,
    required String exerciseNote,
  }) async {
    final exercise = state.member(exerciseId)?.exercise;
    final uid = _uid;
    final library = _library;
    if (exercise == null || uid == null) return;
    if ((exercise.notes ?? '') != sessionNote.trim()) {
      setExerciseNotes(exerciseId, sessionNote);
    }
    final pinned = exerciseNote.trim();
    if (library == null ||
        (_exerciseNote(exercise.templateId) ?? '') == pinned) {
      return;
    }
    final settings = ExerciseSettingsModel(
      id: exercise.templateId,
      authorId: uid,
      note: pinned,
    );
    try {
      await library.saveExerciseSettings(uid, settings);
    } on Object catch (error) {
      _track(
        'ExerciseTracker_ExerciseNote_Fail',
        parameters: {'error_description': '$error'},
        type: LogType.warning,
      );
      if (isClosed) return;
      return emit(state.withNotice(SessionEditNotice.exerciseNoteFailed));
    }
    _track('ExerciseTracker_ExerciseNote_Saved');
    // Shown at once, ahead of the stream that will bring it.
    _exerciseSettings = [
      for (final held in _exerciseSettings)
        if (held.id != settings.id) held,
      settings,
    ];
    if (isClosed) return;
    emit(state.copyWith(savedId: state.savedId + 1));
    _emitEdit();
  }

  // MARK: - Sets

  /// One more set (`ExerciseTrackerPresenter.addSet`).
  void addSet(String exerciseId) {
    _edit((c) => c.addSet(exerciseId));
    _track('SetTracker_Set_Added');
  }

  /// [set] with its figures edited.
  void updateSet(String exerciseId, WorkoutSetModel set) =>
      _edit((c) => c.updateSet(exerciseId, set));

  /// Deletes [setId] with its pair and sub-rows.
  @override
  void deleteSet(String setId) {
    _edit((c) => c.deleteSet(setId));
    _track('SetTrackerRow_SetDeleted');
  }

  /// The set type menu.
  @override
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
  @override
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

  /// The circle: a logged set is un-logged, an open one logged when it can
  /// be (`SetTrackerRowPresenter.onSetComplete`, with no rest).
  @override
  void toggleSet(String setId) => _toggle(setId, source: 'row');

  /// Whether the set was refused.
  bool _toggle(String setId, {required String source}) {
    final controller = _controller;
    final set = _set(setId);
    if (controller == null || set == null) return false;
    final exercise = _exerciseHolding(setId)!;
    final result = controller.toggleSet(setId);
    _emitEdit();
    if (result == null) return false;
    if (result.problem case final problem?) {
      emit(state.withNotice(SessionEditNotice.logProblem, problem: problem));
      return true;
    }
    _track(
      'SetTrackerRow_SetCompleted',
      parameters: {
        'source': source,
        'set_id': setId,
        'exercise_id': exercise.id,
        'use_rest_timers': false,
        'rest_duration_seconds': result.restSeconds ?? 0,
      },
    );
    return false;
  }

  /// A timed set's stopwatch stopped: the seconds held written into it. It
  /// never logs the set.
  @override
  void stopwatchStopped(String setId, int seconds) {
    final set = _set(setId);
    if (set == null) return;
    _edit(
      (c) => c
        ..editSet(set.copyWith(durationSec: seconds))
        ..commitEdit(),
    );
  }

  // MARK: - Exercises

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

  /// Superset…: [exerciseId] paired with [partnerId], joining the
  /// partner's group (a circuit) or starting one with it
  /// (`onSupersetPressed`).
  void pairSuperset(String exerciseId, String partnerId) {
    final exercise = _exercise(exerciseId);
    final partner = _exercise(partnerId);
    if (exercise == null || partner == null || exerciseId == partnerId) return;
    if (exercise.supersetGroupId != null) return;
    _edit((c) {
      if (partner.supersetGroupId case final group?) {
        return c.setSupersetGroup(exerciseId, group);
      }
      final group = _newId();
      c
        ..setSupersetGroup(exerciseId, group)
        ..setSupersetGroup(partnerId, group);
    });
  }

  /// Remove Superset or Circuit: [exerciseId] leaves its group, and a
  /// partner left on its own leaves too, as one exercise is no superset.
  void leaveSuperset(String exerciseId) {
    final group = _exercise(exerciseId)?.supersetGroupId;
    if (group == null) return;
    final remaining = [
      for (final e in state.session.exercises)
        if (e.supersetGroupId == group && e.id != exerciseId) e.id,
    ];
    _edit((c) {
      c.setSupersetGroup(exerciseId, null);
      if (remaining.length == 1) c.setSupersetGroup(remaining.single, null);
    });
  }

  /// Swap opened from the exercise's chips.
  void swapOpened() => _track('SetTracker_Swap_Opened');

  /// [exerciseId] swapped in place for [replacement]
  /// (`ExerciseTrackerPresenter.swap`): its logged sets kept when
  /// [keepLoggedSets], which the screen asks about first when they cannot
  /// move ([SessionEditState.asksBeforeSwapping]).
  void swapExercise(
    String exerciseId,
    ExerciseModel replacement, {
    required bool keepLoggedSets,
  }) {
    if (state.keypad?.exerciseId == exerciseId) dismissKeypad();
    _edit(
      (c) => c.swapInPlace(
        exerciseId,
        replacement,
        keepLoggedSets: keepLoggedSets,
      ),
    );
  }

  /// Targets opened from the exercise's chips.
  void targetsOpened() => _track('SetTracker_Targets_Opened');

  /// [exerciseId]'s targets for this workout.
  void setTargets(String exerciseId, List<SetTarget> targets) =>
      _edit((c) => c.setTargets(exerciseId, targets));

  /// Exercise Settings opened from the exercise's More menu.
  void exerciseSettingsOpened() => _track('SetTracker_ExerciseSettings_Opened');

  /// Equipment opened from the exercise's chips.
  void equipmentOpened() => _track('SetTracker_Equipment_Opened');

  /// Another variation chosen in the equipment sheet: the exercise's unit
  /// and open sets refitted to it.
  void chooseVariation(String exerciseId, String variationId) =>
      _edit((c) => c.chooseVariation(exerciseId, variationId));

  /// A variation's equipment was edited and the gym saved as [gym]: the
  /// exercise refitted on it straight away.
  void gymEdited(String exerciseId, GymProfileModel gym) {
    final controller = _controller;
    if (controller == null) return;
    _gymChanged(gym);
    _edit((c) => c.refit(exerciseId));
  }

  /// [gym] in place of the one held, ahead of the stream that would bring
  /// it.
  void _gymChanged(GymProfileModel gym) {
    _gyms = [
      for (final held in _gyms)
        if (held.id == gym.id) gym else held,
      if (!_gyms.any((held) => held.id == gym.id)) gym,
    ];
    final controller = _controller;
    if (controller != null) {
      controller.environment = _environment(controller.session);
    }
  }

  // MARK: - Units

  /// The weight heading's menu: [unit] for [exerciseId] everywhere from
  /// now on, its open sets converted when [convert].
  @override
  void changeWeightUnit(
    String exerciseId,
    ExerciseWeightUnit unit, {
    required bool convert,
  }) {
    final exercise = _exercise(exerciseId);
    if (_controller == null || exercise == null) return;
    dismissKeypad();
    _units.setWeightUnit(_uid, exercise.templateId, unit, user: _user);
    _edit((c) => c.setWeightUnit(exerciseId, unit, convert: convert));
    if (!convert) {
      _track('SetTracker_Unit_Changed', parameters: {'unit': unit.value});
    }
  }

  /// The distance heading's menu: [unit] for [exerciseId] everywhere from
  /// now on, its open sets converted when [convert].
  @override
  void changeDistanceUnit(
    String exerciseId,
    DistanceUnit unit, {
    required bool convert,
  }) {
    final exercise = _exercise(exerciseId);
    if (_controller == null || exercise == null) return;
    dismissKeypad();
    if (convert) _edit((c) => c.convertDistances(exerciseId, unit));
    _units.setDistanceUnit(_uid, exercise.templateId, unit, user: _user);
    _track('SetTracker_Unit_Changed', parameters: {'unit': unit.name});
    _environmentChanged();
  }

  // MARK: - Keypad (`KeypadEditing`, shared with the tracker)

  @override
  ActiveSessionController? get keypadController => _controller;

  @override
  SetKeypad? get openKeypadState => state.keypad;

  @override
  bool get showsPlatesNow => state.showsPlates;

  @override
  DeviceStore get keypadDevice => _device;

  @override
  WorkoutExerciseModel? keypadExercise(String exerciseId) =>
      _exercise(exerciseId);

  @override
  WorkoutExerciseModel? keypadExerciseHolding(String setId) =>
      _exerciseHolding(setId);

  @override
  WorkoutSetModel? keypadSet(String setId) => _set(setId);

  @override
  ExerciseWeightUnit keypadUnit(WorkoutExerciseModel exercise) =>
      _unit(exercise);

  @override
  DistanceUnit keypadDistanceUnit(WorkoutExerciseModel exercise) =>
      _distanceUnit(exercise);

  /// The editor plays no selection haptic.
  @override
  void emitKeypadEdit({
    SetKeypad? Function()? keypad,
    bool selection = false,
  }) => _emitEdit(keypad: keypad);

  @override
  void emitShowsPlates({required bool showsPlates}) =>
      emit(state.copyWith(showsPlates: showsPlates));

  @override
  bool logFromKeypad(String setId) => _toggle(setId, source: 'keypad');

  /// The loading bar opened the plate calculator.
  @override
  void plateCalculatorOpened() =>
      _track('SetTrackerRow_PlateCalculator_Opened');

  /// Done in the plate calculator: only the bar chosen and the plates on go
  /// onto the gym as it now is, which the keypad steps on at once.
  @override
  Future<void> saveGymLoading(GymProfileModel edited) async {
    final library = _library;
    if (library == null) return;
    final current = state.gym;
    final gym = current != null && current.id == edited.id
        ? GymEditorRules.takingLoading(current, edited)
        : edited;
    _gymChanged(gym);
    _emitEdit();
    try {
      await library.saveGymProfile(gym);
    } on Object {
      if (isClosed) return;
      return emit(state.withNotice(SessionEditNotice.gymSaveFailed));
    }
    if (isClosed) return;
    emit(state.copyWith(savedId: state.savedId + 1));
  }

  // MARK: - Emitting

  void _edit(void Function(ActiveSessionController controller) change) {
    final controller = _controller;
    if (controller == null) return;
    change(controller);
    _emitEdit();
  }

  /// The edit as the controller now has it; [keypad] replaces the open
  /// keypad, which otherwise stays while its set does.
  void _emitEdit({SetKeypad? Function()? keypad, bool? isEditing}) {
    final controller = _controller;
    if (controller == null || isClosed) return;
    controller.flush();
    final session = controller.session;
    var nextKeypad = keypadClosed ? null : state.keypad;
    keypadClosed = false;
    if (keypad != null) nextKeypad = keypad();
    if (nextKeypad != null &&
        !session.exercises.any(
          (e) => e.sets.any((s) => s.id == nextKeypad!.setId),
        )) {
      nextKeypad = null;
    }
    emit(
      state.copyWith(
        session: session,
        isEditing: isEditing,
        hasUnsavedChanges: !_same(session, _saved),
        members: [
          for (final exercise in session.exercises)
            TrackerExercise(
              exercise: exercise,
              previous: null,
              weightStep: controller.weightStep(exercise.id),
              weightUnit: _unit(exercise),
              distanceUnit: _distanceUnit(exercise),
              restAnchor: null,
              exerciseNote: _exerciseNote(exercise.templateId),
            ),
        ],
        keypad: () => nextKeypad,
        gym: _workoutGym,
        gyms: _activeGyms,
        library: _allExercises,
        settings: _settings,
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

  @override
  Future<void> close() {
    _cancelSubscriptions();
    return super.close();
  }
}
