import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/notifications/notification_copy.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show PrebuiltCatalogue, TrainingLibraryRepository;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart' show UserRepository;
import 'package:workout_session_repository/workout_session_repository.dart'
    show WorkoutSessionRepository;

part 'active_workout_state.dart';

/// The workout under way, for the whole app: started from a template or
/// empty, carried on after a relaunch from the device, logged on the
/// tracker, and finished or discarded (`WorkoutTrackerPresenter`). The rules
/// and the device copy are `training_session`'s [ActiveSessionController];
/// this wraps it, reads what it needs from the repositories, and reports
/// what the user did with the Swift app's event names. It also keeps the
/// workout's notifications in step: the rest-over notification
/// (`RestOverNotifying`), "Still training?" (`IdleWorkoutReminder`) and, on
/// Android, the ongoing notification that stands in for the Live Activity.
class ActiveWorkoutCubit extends Cubit<ActiveWorkoutState> {
  new({
    required this._sessions,
    required this._users,
    required this._library,
    required this._analytics,
    required this._store,
    required this._notifications,
    AppNotificationCopy? copy,
    this._clock = DateTime.now,
    this._newId = newUuid,
    this._backoff = RetryBackoff.workoutSave,
    this._wait = _delay,
  }) : _strings = copy ?? AppNotificationCopy(),
       super(const ActiveWorkoutState());

  final WorkoutSessionRepository _sessions;
  final UserRepository _users;
  final TrainingLibraryRepository _library;
  final AnalyticsRepository _analytics;
  final ActiveSessionStore _store;
  final NotificationsRepository _notifications;
  final AppNotificationCopy _strings;
  final DateTime Function() _clock;
  final IdGenerator _newId;
  final RetryBackoff _backoff;
  final Future<void> Function(Duration) _wait;

  static Future<void> _delay(Duration duration) =>
      Future<void>.delayed(duration);

  String? _uid;
  ActiveSessionController? _controller;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  WorkoutSettings? _settings;
  List<ExerciseSettingsModel> _exerciseSettings = const [];
  List<GymProfileModel> _gyms = const [];
  List<ExerciseModel> _userExercises = const [];
  List<WorkoutSessionModel> _history = const [];
  UserModel? _user;
  PrivateUserSettings? _private;

  Timer? _restTimer;
  Timer? _graceTimer;
  DateTime? _graceEnd;
  r.SlotAction? _lastSlot;
  DateTime? _slotChangedAt;

  // MARK: - The user

  /// Follows [uid]'s library, settings and sessions, and carries on the
  /// workout kept on the device when it is theirs.
  Future<void> userChanged(String? uid) async {
    if (uid == _uid) return;
    _uid = uid;
    _cancelTimers();
    _controller?.flush();
    if (_controller != null) _endNotifications();
    _controller = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _settings = null;
    _exerciseSettings = const [];
    _gyms = const [];
    _userExercises = const [];
    _history = const [];
    _user = null;
    _private = null;
    if (uid == null) return emit(const ActiveWorkoutState());
    emit(const ActiveWorkoutState(status: ActiveWorkoutStatus.loading));
    // Each is a nicety the tracker works without: one that cannot be read
    // leaves its defaults.
    void follow<T>(Stream<T> Function() stream, void Function(T) onData) {
      try {
        _subscriptions.add(
          stream().listen((data) {
            onData(data);
            _environmentChanged();
          }, onError: (Object _, StackTrace _) {}),
        );
      } on Object {
        return;
      }
    }

    follow(() => _library.watchWorkoutSettings(uid), (d) => _settings = d);
    follow(
      () => _library.watchExerciseSettings(uid),
      (d) => _exerciseSettings = d,
    );
    follow(() => _library.watchGymProfiles(uid), (d) => _gyms = d);
    follow(() => _library.watchUserExercises(uid), (d) => _userExercises = d);
    follow(() => _sessions.watchSessions(uid), (d) => _history = d);
    follow(() => _users.watchUser(uid), (d) => _user = d);
    follow(() => _users.watchPrivateSettings(uid), (d) => _private = d);
    await _resume(uid);
  }

  Future<void> _resume(String uid) async {
    ActiveSessionController? controller;
    try {
      controller = await ActiveSessionController.resume(
        store: _store,
        environment: _environment(null),
        clock: _clock,
        newId: _newId,
        onSaveError: _onSaveError,
      );
    } on Object {
      controller = null;
    }
    if (isClosed || _uid != uid) return;
    // A workout someone else left on this device is not theirs to carry on.
    if (controller == null || controller.session.authorId != uid) {
      // An ongoing notification a killed process left behind.
      _notify(_notifications.clearOngoingWorkout);
      return emit(const ActiveWorkoutState());
    }
    _controller = controller..environment = _environment(controller.session);
    _restChanged();
    _emitTracker();
  }

  void _environmentChanged() {
    final controller = _controller;
    if (controller == null || isClosed) return;
    controller.environment = _environment(controller.session);
    _emitTracker();
  }

  WorkoutSettings get _workoutSettings =>
      _settings ?? WorkoutSettings(authorId: _uid ?? '');

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

  GymProfileModel? get _favouriteGym =>
      _gym(_user?.submittedFavouriteGymProfileId);

  TrackerEnvironment _environment(WorkoutSessionModel? session) =>
      TrackerEnvironment(
        authorId: _uid ?? '',
        settings: _workoutSettings,
        library: _allExercises,
        gym: _gym(session?.gymProfileId) ?? _favouriteGym,
        restOverrides: {
          for (final settings in _exerciseSettings)
            settings.id: ?settings.restDurationOverride,
        },
        history: SessionHistory(_history),
      );

  String? _exerciseNote(String templateId) {
    final note = _exerciseSettings
        .where((settings) => settings.id == templateId)
        .firstOrNull
        ?.note
        ?.trim();
    return note == null || note.isEmpty ? null : note;
  }

  // MARK: - Starting

  /// Records a press that leads to a start, by its Swift event name.
  void pressed(String eventName) => _track(eventName);

  /// Starts [template]'s workout, prefilled (`plannedSession`), or an empty
  /// one, in place of any under way. [eventPrefix] names the screen's
  /// `_Start`, `_Success` and `_Fail` events.
  Future<void> start({
    required String eventPrefix,
    WorkoutTemplateModel? template,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    _track('${eventPrefix}_Start');
    try {
      final now = _clock();
      final session = template == null
          ? emptySession(authorId: uid, now: now, newId: _newId)
          : plannedSession(
              authorId: uid,
              template: template,
              library: _allExercises,
              history: SessionHistory(_history),
              settings: _workoutSettings,
              gyms: _activeGyms,
              workoutGym: _favouriteGym,
              now: now,
              newId: _newId,
            );
      _cancelTimers();
      if (_controller != null) _endNotifications();
      await _controller?.discard();
      final initial = ActiveSessionState(session: session);
      await _store.save(initial);
      if (isClosed || _uid != uid) return;
      _controller = ActiveSessionController(
        state: initial,
        environment: _environment(session),
        store: _store,
        clock: _clock,
        newId: _newId,
        onSaveError: _onSaveError,
      );
      _lastSlot = null;
      _slotChangedAt = null;
      _track('${eventPrefix}_Success');
      _emitTracker();
    } on Object catch (error) {
      _track(
        '${eventPrefix}_Fail',
        parameters: {'error_description': '$error'},
        type: LogType.severe,
      );
      _emitEffect(const StartFailedEffect());
    }
  }

  // MARK: - The screen

  void appeared() => _track('WorkoutTrackerView_Appear');

  void disappeared() => _track('WorkoutTrackerView_Disappear');

  /// The chevron: the workout carries on behind the tabs.
  void minimized() {
    _track('WorkoutTracker_Minimized');
    _closeKeypad();
    _controller?.flush();
    if (_controller != null) _emitTracker();
  }

  /// Keeps the workout now: the app is leaving the foreground.
  void flush() => _controller?.flush();

  /// Opens [exerciseId]'s block on the card (the strip, Next).
  void selectExercise(String exerciseId) {
    final controller = _controller;
    if (controller == null) return;
    _closeKeypad();
    controller.selectExercise(exerciseId);
    _track('WorkoutTracker_Exercise_Selected');
    _emitTracker();
  }

  /// The button at the foot of the screen. A tap in the 0.4 s after its
  /// action changed, or in a finished rest's grace, is dropped: it was
  /// aimed at what the button was a moment ago. Finish is the screen's to
  /// confirm, so it does nothing here.
  void pressPrimary() {
    final now = _clock();
    if (_controller == null ||
        !r.ActiveWorkout.acceptsTap(_slotChangedAt, now) ||
        state.isInGraceAt(now)) {
      return;
    }
    switch (state.slotAt(now)) {
      case r.SlotLog(:final setId):
        _log(setId, source: 'log_button');
      case r.SlotNext(:final exerciseId):
        selectExercise(exerciseId);
      case r.SlotSkipRest():
        skipRest();
      case r.SlotResume():
        togglePause();
      case r.SlotFinish() || null:
        break;
    }
  }

  // MARK: - Sets

  /// A tap on a row's circle: logs an open set, un-logs a logged one.
  void toggleSet(String setId) {
    final controller = _controller;
    final set = state.set(setId);
    if (controller == null || set == null) return;
    if (set.completedAt == null) return _log(setId, source: 'row');
    controller.unlog(setId);
    _restChanged();
    _emitTracker(effect: const SelectionEffect());
  }

  /// The one way a set is logged: checked, stamped, kept, the rest started
  /// and what is left re-suggested (`WorkoutTrackerPresenter.logSet`).
  void _log(String setId, {required String source}) {
    final controller = _controller;
    final exercise = state.exerciseHolding(setId);
    if (controller == null || exercise == null) return;
    final result = controller.logSet(setId);
    if (result == null) return;
    if (result.problem case final problem?) {
      return _emitTracker(effect: LogRefusedEffect(problem));
    }
    _track(
      'SetTrackerRow_SetCompleted',
      parameters: {
        'source': source,
        'set_id': setId,
        'exercise_id': exercise.id,
        'use_rest_timers': _workoutSettings.useRestTimers,
        'rest_duration_seconds': result.restSeconds ?? 0,
      },
    );
    _restChanged();
    _emitTracker(
      effect: SetLoggedEffect(
        exercise.id,
        setId,
        allComplete: controller.canQuickFinish,
      ),
    );
  }

  /// One more set on [exerciseId].
  void addSet(String exerciseId) {
    _controller?.addSet(exerciseId);
    _track('SetTracker_Set_Added');
    _emitTracker();
  }

  /// A set more for every member of a superset, as one round.
  void addRound(List<String> memberIds) {
    _controller?.addRound(memberIds);
    _track('WorkoutTracker_Round_Added');
    _emitTracker();
  }

  /// Deletes [setId] with its pair and sub-rows; [undo] puts them back.
  void deleteSet(String setId) {
    final controller = _controller;
    if (controller == null) return;
    if (state.keypad?.setId == setId) _closeKeypad();
    controller.deleteSet(setId);
    _track('SetTrackerRow_SetDeleted');
    _restChanged();
    _emitTracker(effect: const SetDeletedEffect());
  }

  // MARK: - Correction

  /// A rep off or on the set just logged.
  void correctReps(String setId, int delta) {
    _controller?.correctReps(setId, delta);
    _track('WorkoutTracker_Correction_Reps', parameters: {'delta': delta});
    _emitTracker(effect: const SelectionEffect());
  }

  /// Reps in reserve on the set just logged; the chip chosen clears it.
  void setRir(String setId, int chip) {
    _controller?.setRir(setId, chip);
    _track('WorkoutTracker_Correction_RIR', parameters: {'rir': chip});
    _emitTracker(effect: const SelectionEffect());
  }

  /// Undoes the last log, un-log, delete or run of reps taps.
  void undo() {
    final controller = _controller;
    if (controller == null || controller.undoName == null) return;
    controller.undo();
    _track('WorkoutTracker_Correction_Undo');
    _restChanged();
    _emitTracker(effect: const SelectionEffect());
  }

  // MARK: - Rest and pause

  void skipRest() {
    _controller?.skipRest();
    _track('WorkoutTracker_Rest_Skipped');
    _restChanged();
    _emitTracker();
  }

  /// +15s on the running rest.
  void addRestTime() {
    _controller?.addRestTime();
    _track(
      'WorkoutTracker_Rest_Extended',
      parameters: {'seconds': ActiveSessionController.restAdjustmentSeconds},
    );
    _restChanged();
    _emitTracker(effect: const SelectionEffect());
  }

  void togglePause() {
    final controller = _controller;
    if (controller == null) return;
    controller.togglePause();
    _track(
      controller.isPaused
          ? 'WorkoutTracker_Workout_Paused'
          : 'WorkoutTracker_Workout_Resumed',
    );
    _emitTracker();
  }

  /// Re-arms the timer that ends the rest when it runs out.
  void _restChanged() {
    _restTimer?.cancel();
    _restTimer = null;
    final end = _controller?.restEnd;
    _restOverChanged(end);
    if (end == null) return;
    final left = end.difference(_clock());
    _restTimer = Timer(left.isNegative ? Duration.zero : left, () {
      final controller = _controller;
      if (controller == null || controller.restEnd != end) return;
      controller.restEnded();
      _restRanOut(end);
      _graceEnd = end.add(r.ActiveWorkout.restDoneGrace);
      _graceTimer?.cancel();
      _graceTimer = Timer(r.ActiveWorkout.restDoneGrace, () {
        _graceEnd = null;
        if (_controller != null && !isClosed) _emitTracker();
      });
      _emitTracker(effect: const RestOverEffect());
    });
  }

  void _cancelTimers() {
    _restTimer?.cancel();
    _graceTimer?.cancel();
    _restTimer = null;
    _graceTimer = null;
    _graceEnd = null;
  }

  // MARK: - Exercises

  /// Exercises picked part-way through, each with one standard set in the
  /// default rep range (`WorkoutTemplateExercise(exercise:)`).
  void addExercises(List<ExerciseModel> exercises) {
    final controller = _controller;
    if (controller == null || exercises.isEmpty) return;
    controller.addExercises([
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
    ]);
    _track(
      'WorkoutTracker_Exercises_Added',
      parameters: {'count': exercises.length},
    );
    _emitTracker();
  }

  void deleteExercise(String exerciseId) {
    final controller = _controller;
    if (controller == null) return;
    if (state.keypad?.exerciseId == exerciseId) _closeKeypad();
    controller.deleteExercise(exerciseId);
    _track('WorkoutTracker_Exercise_Deleted');
    _restChanged();
    _emitTracker();
  }

  // MARK: - Notes

  /// The workout's note; blank clears it.
  void setWorkoutNotes(String notes) {
    final controller = _controller;
    if (controller == null) return;
    if ((controller.session.notes ?? '') == notes.trim()) return;
    controller.setWorkoutNotes(notes);
    _track('WorkoutTracker_WorkoutNotes_Saved');
    _emitTracker(effect: const SavedEffect());
  }

  /// [exerciseId]'s notes: [sessionNote] on this workout only, and
  /// [exerciseNote] on the exercise for every workout
  /// (`ExerciseSettingsModel.note`). Only a changed note is written.
  Future<void> saveExerciseNotes(
    String exerciseId, {
    required String sessionNote,
    required String exerciseNote,
  }) async {
    final controller = _controller;
    final uid = _uid;
    final exercise = state.exercise(exerciseId);
    if (controller == null || uid == null || exercise == null) return;
    if ((exercise.notes ?? '') != sessionNote.trim()) {
      controller.setExerciseNotes(exerciseId, sessionNote);
      _track('WorkoutTracker_ExerciseNotes_Saved');
    }
    final pinned = exerciseNote.trim();
    if ((_exerciseNote(exercise.templateId) ?? '') != pinned) {
      try {
        // A blank note is written as "", not left out: a merge would keep
        // the old note (see swift-findings.md). Both apps read "" as none.
        await _library.saveExerciseSettings(
          uid,
          ExerciseSettingsModel(
            id: exercise.templateId,
            authorId: uid,
            note: pinned,
          ),
        );
        _track('ExerciseTracker_ExerciseNote_Saved');
      } on Object catch (error) {
        _track(
          'ExerciseTracker_ExerciseNote_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.warning,
        );
      }
    }
    if (_controller != null && !isClosed) {
      _emitTracker(effect: const SavedEffect());
    }
  }

  // MARK: - Keypad

  /// Opens the keypad on [field] of [setId].
  void openKeypad(String setId, SetField field) {
    final controller = _controller;
    final exercise = state.exerciseHolding(setId);
    final set = state.set(setId);
    if (controller == null || exercise == null || set == null) return;
    if (state.keypad?.setId != setId) controller.commitEdit();
    _emitTracker(
      keypad: () => SetKeypad.open(
        exerciseId: exercise.id,
        set: set,
        field: field,
        fields: SetField.of(set, exercise.trackingMode),
        unit: _unit(exercise),
      ),
    );
  }

  /// A digit or the decimal point.
  void keypadKey(String key) =>
      _keypadEdit((keypad, set, unit) => keypad.type(key, set, unit));

  void keypadBackspace() =>
      _keypadEdit((keypad, set, unit) => keypad.backspace(set, unit));

  /// − or +: the next weight the equipment makes.
  void keypadStep({required bool up}) {
    final keypad = state.keypad;
    final controller = _controller;
    if (keypad == null || controller == null) return;
    final exercise = state.exercise(keypad.exerciseId);
    final set = state.set(keypad.setId);
    if (exercise == null || set == null) return;
    final unit = _unit(exercise).rules;
    final step = controller.weightStep(exercise.id);
    final current = switch (set.weightKg) {
      final kg? => r.convertWeight(kg, unit),
      null => null,
    };
    final value = up ? step.next(current) : step.previous(current);
    if (value == null) return;
    _keypadSet(set.copyWith(weightKg: r.convertWeightToKg(value, unit)));
  }

  /// A reps chip: last set's, the target's least or most.
  void keypadReps(int reps) {
    final set = state.keypad == null ? null : state.set(state.keypad!.setId);
    if (set == null) return;
    _keypadSet(set.copyWith(reps: reps));
  }

  /// Reps in reserve, kept as RPE; the chip chosen clears it.
  void keypadRir(int rir) {
    final set = state.keypad == null ? null : state.set(state.keypad!.setId);
    if (set == null) return;
    final rpe = r.EffortScale.rpeFromRir(rir);
    final selected = set.rpe == null ? null : r.EffortScale.rirChoice(set.rpe!);
    _keypadSet(set.copyWith(rpe: selected == rir ? null : rpe));
  }

  /// Next →: the row's next field.
  void keypadNext() {
    final keypad = state.keypad;
    final next = keypad?.nextField;
    final set = keypad == null ? null : state.set(keypad.setId);
    final exercise = keypad == null ? null : state.exercise(keypad.exerciseId);
    if (keypad == null || next == null || set == null || exercise == null) {
      return;
    }
    _emitTracker(keypad: () => keypad.moved(next, set, _unit(exercise)));
  }

  /// ✓ on the row's last field: logs the set and closes; a logged set only
  /// closes, and one that cannot be logged yet stays open.
  void keypadDone() {
    final keypad = state.keypad;
    final set = keypad == null ? null : state.set(keypad.setId);
    if (keypad == null || set == null) return;
    if (set.completedAt == null) {
      final before = state.effectId;
      _log(keypad.setId, source: 'keypad');
      if (state.effectId != before && state.effect is LogRefusedEffect) return;
    }
    closeKeypad();
  }

  /// Hides the keypad; the edit carries onto the set's open siblings.
  void closeKeypad() {
    if (state.keypad == null) return;
    _closeKeypad();
    _emitTracker();
  }

  void _closeKeypad() {
    _controller?.commitEdit();
    _keypadClosed = true;
  }

  bool _keypadClosed = false;

  void _keypadEdit(
    (SetKeypad, WorkoutSetModel)? Function(
      SetKeypad keypad,
      WorkoutSetModel set,
      ExerciseWeightUnit unit,
    )
    edit,
  ) {
    final keypad = state.keypad;
    final controller = _controller;
    if (keypad == null || controller == null) return;
    final exercise = state.exercise(keypad.exerciseId);
    final set = state.set(keypad.setId);
    if (exercise == null || set == null) return;
    final result = edit(keypad, set, _unit(exercise));
    if (result == null) return;
    controller.editSet(result.$2);
    _emitTracker(keypad: () => result.$1);
  }

  void _keypadSet(WorkoutSetModel set) {
    final keypad = state.keypad;
    final controller = _controller;
    final exercise = keypad == null ? null : state.exercise(keypad.exerciseId);
    if (keypad == null || controller == null || exercise == null) return;
    controller.editSet(set);
    _emitTracker(
      keypad: () => keypad.showing(set, _unit(exercise)),
      effect: const SelectionEffect(),
    );
  }

  ExerciseWeightUnit _unit(WorkoutExerciseModel exercise) =>
      exercise.weightUnit ?? ExerciseWeightUnit.kilograms;

  // MARK: - Finishing

  void finishPressed() => _track('WorkoutTracker_Finish_Pressed');

  void discardPressed() => _track('WorkoutTracker_Discard_Pressed');

  /// Ends the workout now and stores it (`WorkoutFinisher`): the summary
  /// opens at once, while the save, its retries and the streak run here,
  /// where they outlive the tracker. A save that fails leaves the workout
  /// on the device to resume. Weeks start on [firstWeekday] (ISO).
  Future<void> finish({required int firstWeekday, DateTime? at}) async {
    final controller = _controller;
    final uid = _uid;
    if (controller == null || uid == null) return;
    _controller = null;
    _cancelTimers();
    _endNotifications();
    final session = await controller.finish(at: at);
    if (isClosed) return;
    emit(ActiveWorkoutState(finishedSession: session));
    _track(
      'finish_workout_debug',
      parameters: {
        'session_id': session.id,
        'template_id': session.workoutTemplateId ?? 'nil',
        'plan_id': session.mesocycleId ?? 'nil',
      },
      type: LogType.info,
    );
    _track('WorkoutTrackerView_FinishWorkout_Start');
    var retried = false;
    final result =
        await WorkoutFinisher(
          sessions: _sessions,
          users: _users,
          store: _store,
          backoff: _backoff,
          wait: _wait,
          clock: _clock,
        ).finish(
          session,
          history: _history,
          weeklySessionGoal: _user?.weeklySessionGoal,
          privateSettings: _private,
          firstWeekday: firstWeekday,
          currentUid: () => _uid,
          onProgress: (progress) {
            if (progress == SaveProgress.retrying) retried = true;
            if (isClosed) return;
            emit(
              _copy(saveNotice: progress, saveNoticeId: state.saveNoticeId + 1),
            );
          },
        );
    if (result.saved) {
      _track('Workout_Finished', parameters: _finishedParameters(session));
      _track('WorkoutTrackerView_FinishWorkout_Success');
      return;
    }
    final reason = _uid != session.authorId
        ? 'signed_out'
        : retried
        ? 'retries_exhausted'
        : 'permanent';
    _track(
      'WorkoutTrackerView_FinishWorkout_Fail',
      parameters: {'reason': reason},
      type: LogType.severe,
    );
    // Still on the device: offered again to resume.
    if (!isClosed && _uid == uid && _controller == null) await _resume(uid);
  }

  static Map<String, Object?> _finishedParameters(
    WorkoutSessionModel session,
  ) => {
    'exercise_count': session.exercises.length,
    'completed_set_count': session.exercises.fold<int>(
      0,
      (sum, e) => sum + e.sets.where((s) => s.completedAt != null).length,
    ),
    'duration_minutes': session.activeDuration?.inMinutes ?? 0,
    'from_template': session.workoutTemplateId != null,
    'from_plan': session.mesocycleId != null,
    'is_rest_day': session.isRestDay,
  };

  /// The summary is open; it is not opened again.
  void summaryShown() {
    if (state.finishedSession == null) return;
    emit(_copy(clearFinished: true));
  }

  /// Throws the workout away; the device forgets it.
  Future<void> discard() async {
    final controller = _controller;
    if (controller == null) return;
    _track('WorkoutTrackerView_DiscardWorkout_Start');
    _controller = null;
    _cancelTimers();
    _endNotifications();
    try {
      await controller.discard();
      _track('WorkoutTrackerView_DiscardWorkout_Success');
    } on Object catch (error) {
      _track(
        'WorkoutTrackerView_DiscardWorkout_Fail',
        parameters: {'error_description': '$error'},
        type: LogType.warning,
      );
    }
    if (!isClosed) emit(const ActiveWorkoutState());
  }

  // MARK: - State

  void _emitEffect(TrackerEffect effect) =>
      emit(_copy(effect: effect, effectId: state.effectId + 1));

  /// [state] with only the given parts changed.
  ActiveWorkoutState _copy({
    TrackerEffect? effect,
    int? effectId,
    SaveProgress? saveNotice,
    int? saveNoticeId,
    bool clearFinished = false,
  }) => ActiveWorkoutState(
    status: state.status,
    session: state.session,
    currentExerciseId: state.currentExerciseId,
    card: state.card,
    supersetLetter: state.supersetLetter,
    blockRows: state.blockRows,
    primaryAction: state.primaryAction,
    strip: state.strip,
    restEnd: state.restEnd,
    restStartedAt: state.restStartedAt,
    graceEnd: state.graceEnd,
    pausedAt: state.pausedAt,
    pausedSeconds: state.pausedSeconds,
    correction: state.correction,
    undoName: state.undoName,
    settings: state.settings,
    keypad: state.keypad,
    effect: effect ?? state.effect,
    effectId: effectId ?? state.effectId,
    finishedSession: clearFinished ? null : state.finishedSession,
    saveNotice: saveNotice ?? state.saveNotice,
    saveNoticeId: saveNoticeId ?? state.saveNoticeId,
  );

  /// The tracker as the controller now has it; [keypad] replaces the open
  /// keypad, which otherwise stays while its set does.
  void _emitTracker({TrackerEffect? effect, SetKeypad? Function()? keypad}) {
    final controller = _controller;
    if (controller == null || isClosed) return;
    final session = controller.session;
    final exercises = session.exercises.map(rulesExercise).toList();
    final current = controller.currentExercise;
    final block =
        r.ActiveWorkout.supersetBlock(current?.id, exercises) ??
        [?current == null ? null : rulesExercise(current)];
    final letter = block.length > 1
        ? r.ActiveWorkout.supersetLetters(
            exercises,
          )[block.first.supersetGroupId]
        : null;
    final members = [
      for (final member in block)
        ?session.exercises.where((e) => e.id == member.id).firstOrNull,
    ];
    var nextKeypad = _keypadClosed ? null : state.keypad;
    _keypadClosed = false;
    if (keypad != null) nextKeypad = keypad();
    if (nextKeypad != null &&
        !session.exercises.any(
          (e) => e.sets.any((s) => s.id == nextKeypad!.setId),
        )) {
      nextKeypad = null;
    }
    final paused = controller.state;
    final next = ActiveWorkoutState(
      status: ActiveWorkoutStatus.active,
      session: session,
      currentExerciseId: current?.id,
      card: [
        for (final member in members)
          TrackerExercise(
            exercise: member,
            previous: controller.previousExercise(member),
            weightStep: controller.weightStep(member.id),
            weightUnit: _unit(member),
            restAnchor: controller.restAnchor(member.id),
            exerciseNote: _exerciseNote(member.templateId),
          ),
      ],
      supersetLetter: letter,
      blockRows: letter == null
          ? const []
          : r.ActiveWorkout.blockRows(block, letter),
      primaryAction: controller.primaryAction,
      strip: controller.strip,
      restEnd: controller.restEnd,
      restStartedAt: controller.restStartedAt,
      graceEnd: _graceEnd,
      pausedAt: paused.pausedAt,
      pausedSeconds: paused.pausedSeconds,
      // The set logged last anywhere, on its own exercise
      // (`restCorrection`): the screen shows it while the rest runs,
      // whichever card is open.
      correction: switch (r.ActiveWorkout.latestCompletedSet(exercises)) {
        final latest? =>
          session.exercises
              .where((e) => e.sets.any((s) => s.id == latest.id))
              .map((e) => controller.correction(e.id))
              .firstOrNull,
        null => null,
      },
      undoName: controller.undoName,
      settings: _workoutSettings,
      keypad: nextKeypad,
      effect: effect ?? state.effect,
      effectId: effect == null ? state.effectId : state.effectId + 1,
      saveNotice: state.saveNotice,
      saveNoticeId: state.saveNoticeId,
    );
    final now = _clock();
    final slot = next.slotAt(now);
    if (slot != _lastSlot) {
      if (_lastSlot != null) _slotChangedAt = now;
      _lastSlot = slot;
    }
    emit(next);
    _workoutNotificationsChanged(next);
  }

  // MARK: - Notifications

  /// The notification calls, one at a time in order, as Swift's
  /// `enqueueRestAlert`: a rest scheduled and skipped at once must end
  /// withdrawn, whichever platform call is slower.
  /// Started by the first call, so it runs in the zone the work does.
  Future<void>? _notificationQueue;

  void _notify(Future<void> Function() work) =>
      _notificationQueue = _notificationQueue?.then((_) => work()) ?? work();

  /// Completes once every notification call so far has; for tests.
  Future<void> get notificationsSettled =>
      _notificationQueue ?? Future<void>.value();

  DateTime? _scheduledRestEnd;
  DateTime? _idleAnchor;
  OngoingWorkout? _ongoing;
  bool _alertOngoing = false;
  DateTime? _lastSeenActivity;

  /// Every rest started or moved (a set logged, +15s) schedules the
  /// rest-over notification under its one id, replacing the last; every rest
  /// called off (skip, un-log) withdraws it. With the ongoing notification
  /// showing, it is due [RestOverAlert.standInDelay] late, standing in for an
  /// app that was not running when the rest ran out.
  void _restOverChanged(DateTime? end) {
    if (end == _scheduledRestEnd) return;
    _scheduledRestEnd = end;
    if (end == null) {
      return _notify(() => _notifications.cancel(LocalReminderKind.restOver));
    }
    final reminder = LocalReminders.restOver(
      at: RestOverAlert.notificationDate(
        restEnd: end,
        showingLiveActivity: _ongoing != null,
      ),
      body: _nextLine(),
      sound: _workoutSettings.restTimerPlaySound,
    );
    _notify(() => _notifications.schedule(reminder));
  }

  /// The app's timer saw the rest run out (`HKWorkoutManager.endRest`): on
  /// time with the ongoing notification showing, that alerts and the
  /// stand-in is withdrawn; late, the notification has already said it.
  void _restRanOut(DateTime end) {
    _scheduledRestEnd = null;
    final sound = _workoutSettings.restTimerPlaySound;
    final channel = RestOverAlert.channel(
      showingLiveActivity: _ongoing != null,
      lateBy: _clock().difference(end),
      sound: sound,
    );
    if (channel == RestOverAlert.notification) return;
    _notify(() => _notifications.cancel(LocalReminderKind.restOver));
    _alertOngoing = channel == RestOverAlert.liveActivity;
  }

  /// "Next: Bench Press, 60 kg × 8": the first open set from the current
  /// exercise on, wrapping (`exerciseIndexWithWorkLeft`); null when nothing
  /// is left.
  String? _nextLine() {
    final controller = _controller;
    if (controller == null) return null;
    final exercises = controller.session.exercises;
    final start = exercises.indexWhere(
      (e) => e.id == controller.currentExercise?.id,
    );
    final from = start < 0 ? 0 : start;
    for (final exercise in [...exercises.skip(from), ...exercises.take(from)]) {
      final set = exercise.sets.where((s) => s.completedAt == null).firstOrNull;
      if (set == null || exercise.name.isEmpty) continue;
      final l10n = _strings.l10n;
      final figures = TrackerText.figures(
        l10n,
        set,
        exercise.trackingMode,
        _unit(exercise),
        locale: l10n.localeName,
      );
      return figures == null
          ? l10n.notifRestOverNext(exercise.name)
          : l10n.notifRestOverNextTarget(exercise.name, figures);
    }
    return null;
  }

  static DateTime? _lastLog(WorkoutSessionModel session) => session.exercises
      .expand((exercise) => exercise.sets)
      .map((set) => set.completedAt)
      .nonNulls
      .fold<DateTime?>(
        null,
        (latest, at) => latest == null || at.isAfter(latest) ? at : latest,
      );

  /// "Still training?" follows the last logged set
  /// (`WorkoutSessionManager.rescheduleIdleReminder`), and the ongoing
  /// notification follows the tracker: the workout's name, what is next,
  /// and a clock counting down the rest or up from the start.
  void _workoutNotificationsChanged(ActiveWorkoutState state) {
    final session = state.session!;
    final lastLog = _lastLog(session);
    if (lastLog != null && lastLog != _idleAnchor) {
      _idleAnchor = lastLog;
      final reminder = LocalReminders.idleWorkout(
        lastLog: lastLog,
        now: _clock(),
      );
      if (reminder != null) _notify(() => _notifications.schedule(reminder));
    }
    if (!_notifications.showsOngoingWorkout ||
        !(_workoutSettings.showOnLockScreen ?? true)) {
      return _clearOngoing();
    }
    final restEnd = state.restEnd;
    final alert = _alertOngoing;
    _alertOngoing = false;
    final next = _nextLine();
    final ongoing = OngoingWorkout(
      title: session.name,
      body: alert ? next ?? _strings.l10n.notifRestOverFallback : next,
      clock:
          restEnd ??
          (state.pausedAt == null
              ? session.dateCreated.add(
                  Duration(microseconds: (state.pausedSeconds * 1e6).round()),
                )
              : null),
      countsDown: restEnd != null,
      alert: alert,
    );
    if (ongoing == _ongoing) return;
    _ongoing = ongoing;
    _notify(() => _notifications.showOngoingWorkout(ongoing));
  }

  void _clearOngoing() {
    if (_ongoing == null) return;
    _ongoing = null;
    _notify(_notifications.clearOngoingWorkout);
  }

  /// The workout is over (finished, discarded, replaced or signed out of):
  /// nothing about it is left to announce.
  void _endNotifications() {
    _scheduledRestEnd = null;
    _idleAnchor = null;
    _alertOngoing = false;
    _lastSeenActivity = null;
    _notify(() async {
      await _notifications.cancel(LocalReminderKind.restOver);
      await _notifications.cancel(LocalReminderKind.idleWorkout);
    });
    _clearOngoing();
  }

  /// On the tracker's appearing and each return to the app: an hour since
  /// the last set (or since last asked) asks whether the workout is still
  /// going (`askIfStillTraining`). Asked once per return; Keep Going waits
  /// another hour.
  void checkStillTraining() {
    final controller = _controller;
    if (controller == null) return;
    final lastSet = _lastLog(controller.session);
    if (lastSet == null) return;
    final now = _clock();
    final seen = _lastSeenActivity;
    final lastActivity = seen != null && seen.isAfter(lastSet) ? seen : lastSet;
    if (!IdleWorkout.isIdle(lastActivity: lastActivity, now: now)) return;
    _lastSeenActivity = now;
    _emitTracker(effect: StillTrainingEffect(lastSet));
  }

  void _onSaveError(Object error, StackTrace _) => _track(
    'WorkoutTrackerView_SaveProgress_Fail',
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
  Future<void> close() async {
    _cancelTimers();
    _controller?.flush();
    // Not awaited: a stream's cancel may never complete (a widget test's
    // fake clock), and nothing waits on it.
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    await super.close();
  }
}
