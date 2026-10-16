import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/notifications/notification_copy.dart';
import 'package:compound/review/review_moment.dart';
import 'package:compound/social/logic/circle_week.dart';
import 'package:compound/workout_tracker/cubit/equipment_sheet_cubit.dart';
import 'package:compound/workout_tracker/cubit/keypad_editing.dart';
import 'package:compound/workout_tracker/cubit/plate_calculator_cubit.dart';
import 'package:compound/workout_tracker/logic/live_activity_content.dart';
import 'package:compound/workout_tracker/logic/set_changes.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound/workout_tracker/view/set_table.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_maths/compound_maths.dart' show weeklySessionGoal;
import 'package:compound_models/compound_models.dart';
import 'package:device_store/device_store.dart';
import 'package:equatable/equatable.dart';
import 'package:health_repository/health_repository.dart'
    show HealthRepository, HealthScope;
import 'package:notifications_repository/notifications_repository.dart';
import 'package:program_repository/program_repository.dart' show ProgramService;
import 'package:strava_repository/strava_repository.dart' show StravaRepository;
import 'package:training_library_repository/training_library_repository.dart'
    show GymEditorRules, PrebuiltCatalogue, TrainingLibraryRepository;
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
/// (`RestOverNotifying`), "Still training?" (`IdleWorkoutReminder`), and the
/// workout under way outside the app: Android's ongoing notification and
/// iOS's Live Activity, whose buttons it answers
/// ([handleLiveActivityAction]).
class ActiveWorkoutCubit extends Cubit<ActiveWorkoutState>
    with KeypadEditing
    implements SetTableActions {
  new({
    required this._sessions,
    required this._users,
    required this._library,
    required this._analytics,
    required this._store,
    required this._notifications,
    LiveActivityRepository? liveActivity,
    AppNotificationCopy? copy,
    UnitPreferenceStore? units,
    DeviceStore? device,
    this._clock = DateTime.now,
    this._newId = newUuid,
    this._backoff = RetryBackoff.workoutSave,
    this._wait = _delay,
    this._programs,
    this._health,
    this._strava,
    this._reviews,
  }) : _liveActivity = liveActivity ?? FakeLiveActivityRepository(),
       _strings = copy ?? AppNotificationCopy(),
       _units = units ?? UnitPreferenceStore(),
       _device = device ?? InMemoryDeviceStore(),
       super(const ActiveWorkoutState());

  final WorkoutSessionRepository _sessions;
  final UserRepository _users;
  final TrainingLibraryRepository _library;
  final AnalyticsRepository _analytics;
  final ActiveSessionStore _store;
  final NotificationsRepository _notifications;

  /// The Live Activity (iOS).
  final LiveActivityRepository _liveActivity;
  final AppNotificationCopy _strings;

  /// Where the workout under way shows outside the app, each where the
  /// platform has it.
  List<OngoingWorkoutSurface> get _surfaces => [_notifications, _liveActivity];

  /// Each exercise's units, kept on the device.
  final UnitPreferenceStore _units;

  /// The keypad's plates switch, kept on the device.
  final DeviceStore _device;
  final DateTime Function() _clock;
  final IdGenerator _newId;
  final RetryBackoff _backoff;
  final Future<void> Function(Duration) _wait;

  /// What finishing a workout does to the program; nothing without one.
  final ProgramService? _programs;

  /// Where a finished workout is saved as a strength training workout;
  /// nowhere without one.
  final HealthRepository? _health;

  /// Where a finished workout is uploaded once connected; nowhere without
  /// one.
  final StravaRepository? _strava;

  /// Asks for a rating after the workout that meets the week's goal; never
  /// without one.
  final ReviewPrompter? _reviews;

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
    follow(() => _units.changes, (_) {});
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
        unitPreferences: _unitPreferences(session),
        restOverrides: {
          for (final settings in _exerciseSettings)
            settings.id: ?settings.restDurationOverride,
        },
        history: SessionHistory(_history),
      );

  /// Every exercise's units, the library's and [session]'s, so one never
  /// chosen reads the profile's units rather than kilograms.
  ///
  /// ponytail: a map over the whole library, rebuilt on each change; give
  /// `TrackerEnvironment` a fallback preference if the library grows large.
  Map<String, UnitPreference> _unitPreferences(WorkoutSessionModel? session) =>
      {
        for (final id in {
          for (final exercise in _allExercises) exercise.id,
          for (final exercise in session?.exercises ?? <WorkoutExerciseModel>[])
            exercise.templateId,
        })
          id: _preference(id),
      };

  UnitPreference _preference(String templateId) =>
      _units.of(_uid, templateId, user: _user);

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

  /// The session [template] starts (`plannedSession`): prefilled as the
  /// tracker prefills it, on [microcycleIndex]'s targets (from 1) of
  /// [mesocycleId], and cut to a deload's when [isDeload]
  /// (`startWorkout(for:in:microcycleIndex:isDeloadCycle:)`); null when
  /// signed out.
  WorkoutSessionModel? _plan(
    WorkoutTemplateModel template, {
    String? mesocycleId,
    int? microcycleIndex,
    bool isDeload = false,
  }) {
    final uid = _uid;
    if (uid == null) return null;
    final now = _clock();
    final session = plannedSession(
      authorId: uid,
      template: template,
      library: _allExercises,
      history: SessionHistory(_history),
      settings: _workoutSettings,
      gyms: _activeGyms,
      workoutGym: _favouriteGym,
      now: now,
      newId: _newId,
      mesocycleId: mesocycleId,
      microcycleIndex: microcycleIndex,
      unitPreferences: _unitPreferences(null),
    );
    return isDeload
        ? deloadedSession(
            session,
            library: _allExercises,
            gym: _gym(session.gymProfileId) ?? _favouriteGym,
            now: now,
          )
        : session;
  }

  /// Starts [template]'s workout, prefilled ([_plan]), or an empty one, in
  /// place of any under way. [eventPrefix] names the screen's `_Start`,
  /// `_Success` and `_Fail` events.
  Future<void> start({
    required String eventPrefix,
    WorkoutTemplateModel? template,
    String? mesocycleId,
    int? microcycleIndex,
    bool isDeload = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    _track('${eventPrefix}_Start');
    try {
      final now = _clock();
      final session = template == null
          ? emptySession(authorId: uid, now: now, newId: _newId)
          : _plan(
              template,
              mesocycleId: mesocycleId,
              microcycleIndex: microcycleIndex,
              isDeload: isDeload,
            )!;
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
      unawaited(_askHealthForWorkouts());
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
    dismissKeypad();
    _controller?.flush();
    if (_controller != null) _emitTracker();
  }

  /// Keeps the workout now: the app is leaving the foreground.
  void flush() => _controller?.flush();

  /// Opens [exerciseId]'s block on the card (the strip, Next).
  void selectExercise(String exerciseId) {
    final controller = _controller;
    if (controller == null) return;
    dismissKeypad();
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
  @override
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
  @override
  void deleteSet(String setId) {
    final controller = _controller;
    if (controller == null) return;
    if (state.keypad?.setId == setId) dismissKeypad();
    controller.deleteSet(setId);
    _track('SetTrackerRow_SetDeleted');
    _restChanged();
    _emitTracker(effect: const SetDeletedEffect());
  }

  // MARK: - Set editing

  /// The set number's menu: [setId] (and its pair) made [choice]. Sub-rows
  /// the new type has no use for go, and a drop or myo set gets its first.
  @override
  void setSetType(String setId, r.SetTypeChoice choice) {
    final controller = _controller;
    final set = state.set(setId);
    if (controller == null || set == null) return;
    if (r.typeChoiceOf(rulesSet(set)) == choice) return;
    controller.setSetType(setId, choice);
    _track(
      'SetTrackerRow_SetTypeChanged',
      parameters: {'set_type': choice.eventValue},
    );
    _restChanged();
    _emitTracker(effect: const SelectionEffect());
  }

  /// A drop (20 % lighter, on a weight the equipment makes) or a mini-set
  /// (at the set's weight) under [setId], after any it has.
  @override
  void addSubSet(String setId, r.SubSetKind kind) {
    final controller = _controller;
    if (controller == null || state.set(setId) == null) return;
    controller.addSubSet(setId, kind);
    _track(
      'SetTrackerRow_SubSetAdded',
      parameters: {'kind': kind == r.SubSetKind.drop ? 'drop' : 'mini'},
    );
    _emitTracker(effect: const SelectionEffect());
  }

  /// Split L/R: each side logged as its own row, or both as one again.
  void toggleSides(String exerciseId) {
    final controller = _controller;
    final exercise = state.exercise(exerciseId);
    if (controller == null || exercise == null) return;
    final splitting = !rulesExercise(exercise).isSplit;
    if (splitting) {
      controller.splitSides(exerciseId);
    } else {
      controller.joinSides(exerciseId);
    }
    _track('SetTracker_Sides_Split', parameters: {'split': splitting});
    _emitTracker(effect: const SelectionEffect());
  }

  /// The rest picker's Save: [seconds] for [setId] alone; `null` (both
  /// wheels at zero) clears it.
  void setCustomRest(String setId, int? seconds) {
    final controller = _controller;
    if (controller == null) return;
    controller.setCustomRest(setId, seconds);
    _track(
      'SetTrackerRow_RestChanged',
      parameters: {'seconds': seconds ?? 0, 'cleared': seconds == null},
    );
    _emitTracker();
  }

  /// A timed set's stopwatch stopped: the seconds held written into it. It
  /// never logs the set.
  @override
  void stopwatchStopped(String setId, int seconds) {
    final controller = _controller;
    final set = state.set(setId);
    if (controller == null || set == null) return;
    controller
      ..editSet(set.copyWith(durationSec: seconds))
      ..commitEdit();
    _emitTracker();
  }

  /// A tap on Last: last time's figures copied into [setId]
  /// (`onFillFromPrevious`). Not on a logged set, where a stray tap would
  /// overwrite what was recorded.
  void fillFromPrevious(String setId) {
    final controller = _controller;
    final exercise = state.exerciseHolding(setId);
    final set = state.set(setId);
    if (controller == null || exercise == null || set == null) return;
    if (set.completedAt != null) return;
    final previous = controller.previousExercise(exercise);
    final last = previous == null
        ? null
        : r.ActiveWorkout.lastSet(
            rulesSet(set),
            rulesExercise(exercise),
            rulesExercise(previous),
          );
    if (last == null) return;
    final filled = r.ActiveWorkout.fillingFromPrevious(
      rulesSet(set),
      last,
      exercise.trackingMode.rules,
    );
    controller
      ..editSet(modelSet(filled, original: set, now: _clock()))
      ..commitEdit();
    _track('SetTrackerRow_SetFilled', parameters: {'source': 'last'});
    _emitTracker(effect: const SelectionEffect());
  }

  /// The progression note tapped: read, so it goes for this exercise for
  /// the rest of the workout.
  void acknowledgeProgressionNote() {
    final controller = _controller;
    final exercise = controller?.currentExercise;
    if (controller == null || exercise == null) return;
    controller.acknowledgeProgressionNote(exercise.templateId);
    _track('WorkoutTracker_ProgressionNote_Acknowledged');
    _emitTracker();
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

  /// Skip Rest on the bar over the tabs (`TrainingAccessoryPresenter`).
  void skipRestFromBar() {
    if (_controller == null) return;
    _track('TrainingAccessory_SkipRest');
    _controller!.skipRest();
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
    if (state.keypad?.exerciseId == exerciseId) dismissKeypad();
    controller.deleteExercise(exerciseId);
    _track('WorkoutTracker_Exercise_Deleted');
    _restChanged();
    _emitTracker();
  }

  /// A busy machine: [exerciseId], with its superset, to the end; the card
  /// moves on when it was on it (`onDoLaterPressed`).
  void doLater(String exerciseId) =>
      _moved(() => _controller?.doLater(exerciseId), later: true);

  /// [exerciseId], with its superset, straight after the card's block
  /// (`onDoNextPressed`).
  void doNext(String exerciseId) =>
      _moved(() => _controller?.doNext(exerciseId), later: false);

  void _moved(void Function() move, {required bool later}) {
    if (_controller == null) return;
    move();
    _track(
      'WorkoutTracker_Exercise_Moved',
      parameters: {'to': later ? 'later' : 'next'},
    );
    _emitTracker(effect: const SelectionEffect());
  }

  /// The strip's Move Earlier or Move Later: the block [blockId] to
  /// [index] among the blocks, its new place announced
  /// (`onStripItemMoved`).
  void moveBlock(String blockId, int index) {
    final controller = _controller;
    if (controller == null) return;
    final from = controller.strip.indexWhere((item) => item.id == blockId);
    controller.moveBlock(blockId, index);
    final strip = controller.strip;
    final to = strip.indexWhere((item) => item.id == blockId);
    if (to == from) return;
    _track(
      'WorkoutTracker_Exercise_Reordered',
      parameters: {'from': from, 'to': index},
    );
    _emitTracker(effect: BlockMovedEffect(to + 1, strip.length));
  }

  /// Swap opened from the exercise's menu.
  void swapOpened() => _track('SetTracker_Swap_Opened');

  /// [exerciseId] swapped for [replacement] (`insertSwappedExercise`): its
  /// logged sets stay with it, and the replacement follows with the sets
  /// still open; the card moves to it.
  void swapExercise(String exerciseId, ExerciseModel replacement) {
    final controller = _controller;
    final exercise = state.exercise(exerciseId);
    if (controller == null || exercise == null) return;
    if (state.keypad?.exerciseId == exerciseId) dismissKeypad();
    final kept = exercise.sets.any((s) => s.completedAt != null);
    controller.swapExercise(exerciseId, replacement);
    _track(
      'WorkoutTracker_Exercise_Swapped',
      parameters: {'kept_logged_sets': kept},
    );
    _emitTracker(effect: const SavedEffect());
  }

  /// Targets opened from the exercise's menu.
  void targetsOpened() => _track('SetTracker_Targets_Opened');

  /// [exerciseId]'s targets for this workout, from Targets.
  void setTargets(String exerciseId, List<SetTarget> targets) {
    _controller?.setTargets(exerciseId, targets);
    _emitTracker();
  }

  /// Exercise Settings opened from the exercise's menu.
  void exerciseSettingsOpened() => _track('SetTracker_ExerciseSettings_Opened');

  /// The weight heading's menu: [unit] for [exerciseId] everywhere from
  /// now on, its open sets converted when [convert] (`updateWeightUnit`,
  /// `convertAndRoundWeights`). The keypad closes on the old unit.
  @override
  void changeWeightUnit(
    String exerciseId,
    ExerciseWeightUnit unit, {
    required bool convert,
  }) {
    final controller = _controller;
    final exercise = state.exercise(exerciseId);
    if (controller == null || exercise == null) return;
    dismissKeypad();
    _units.setWeightUnit(_uid, exercise.templateId, unit, user: _user);
    controller.setWeightUnit(exerciseId, unit, convert: convert);
    if (!convert) {
      _track('SetTracker_Unit_Changed', parameters: {'unit': unit.value});
    }
    _emitTracker(effect: const SelectionEffect());
  }

  /// The distance heading's menu: [unit] for [exerciseId] everywhere from
  /// now on, its open sets converted when [convert]
  /// (`updateDistanceUnit`, `convertAndRoundDistances`).
  @override
  void changeDistanceUnit(
    String exerciseId,
    DistanceUnit unit, {
    required bool convert,
  }) {
    final controller = _controller;
    final exercise = state.exercise(exerciseId);
    if (controller == null || exercise == null) return;
    dismissKeypad();
    if (convert) controller.convertDistances(exerciseId, unit);
    _units.setDistanceUnit(_uid, exercise.templateId, unit, user: _user);
    _track('SetTracker_Unit_Changed', parameters: {'unit': unit.name});
    _emitTracker(effect: const SelectionEffect());
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

  // MARK: - Keypad (`KeypadEditing`)

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
      state.exercise(exerciseId);

  @override
  WorkoutExerciseModel? keypadExerciseHolding(String setId) =>
      state.exerciseHolding(setId);

  @override
  WorkoutSetModel? keypadSet(String setId) => state.set(setId);

  @override
  ExerciseWeightUnit keypadUnit(WorkoutExerciseModel exercise) =>
      _unit(exercise);

  @override
  DistanceUnit keypadDistanceUnit(WorkoutExerciseModel exercise) =>
      _distanceUnit(exercise);

  @override
  void emitKeypadEdit({
    SetKeypad? Function()? keypad,
    bool selection = false,
  }) => _emitTracker(
    keypad: keypad,
    effect: selection ? const SelectionEffect() : null,
  );

  @override
  void emitShowsPlates({required bool showsPlates}) =>
      emit(_copy(showsPlates: showsPlates));

  @override
  bool logFromKeypad(String setId) {
    final before = state.effectId;
    _log(setId, source: 'keypad');
    return state.effectId != before && state.effect is LogRefusedEffect;
  }

  /// Why smart progression changed [exercise]'s numbers, if it did.
  static r.ProgressionReason? _progressionReason(
    ActiveSessionController controller,
    WorkoutExerciseModel exercise,
  ) {
    final previous = controller.previousExercise(exercise);
    return r.ActiveWorkout.progressionReason(
      suggestion: controller.suggestion(exercise),
      last: previous == null ? null : rulesExercise(previous),
      planned: rulesExercise(exercise),
    );
  }

  ExerciseWeightUnit _unit(WorkoutExerciseModel exercise) =>
      exercise.weightUnit ?? _preference(exercise.templateId).weightUnit;

  DistanceUnit _distanceUnit(WorkoutExerciseModel exercise) =>
      _preference(exercise.templateId).distanceUnit;

  // MARK: - Loading and equipment

  /// The loading bar opened the plate calculator.
  @override
  void plateCalculatorOpened() =>
      _track('SetTrackerRow_PlateCalculator_Opened');

  /// Done in the plate calculator: only what it changes, the bar chosen
  /// and the plates on, goes onto the gym as it now is, which the keypad
  /// steps on at once while the save runs.
  @override
  Future<void> saveGymLoading(GymProfileModel edited) async {
    final current = state.gym;
    final gym = current != null && current.id == edited.id
        ? GymEditorRules.takingLoading(current, edited)
        : edited;
    _gymChanged(gym);
    _emitTracker();
    try {
      await _library.saveGymProfile(gym);
    } on Object {
      return _emitTracker(effect: const GymSaveFailedEffect());
    }
    _emitTracker(effect: const SavedEffect());
  }

  /// The exercise menu's Equipment opened its sheet.
  void equipmentOpened() => _track('SetTracker_Equipment_Opened');

  /// Another variation chosen in the equipment sheet: the exercise's unit
  /// and open sets refitted to it.
  void chooseVariation(String exerciseId, String variationId) {
    final controller = _controller;
    if (controller == null) return;
    controller.chooseVariation(exerciseId, variationId);
    _emitTracker(effect: const SelectionEffect());
  }

  /// A variation's equipment was edited and the gym saved as [gym]: the
  /// exercise refitted on it straight away.
  void gymEdited(String exerciseId, GymProfileModel gym) {
    final controller = _controller;
    if (controller == null) return;
    _gymChanged(gym);
    controller.refit(exerciseId);
    _emitTracker();
  }

  /// [gym] in place of the one held, ahead of the stream that will bring
  /// it, so the tracker reads it now.
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

  // MARK: - Finishing

  void finishPressed() => _track('WorkoutTracker_Finish_Pressed');

  void discardPressed() => _track('WorkoutTracker_Discard_Pressed');

  /// Workout Settings opened from the menu.
  void workoutSettingsOpened() =>
      _track('WorkoutTracker_WorkoutSettings_Opened');

  /// Gym Settings opened from the menu.
  void gymSettingsOpened() => _track('WorkoutTracker_GymSettings_Opened');

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
    final session = await controller.finish(at: at);
    _endNotifications(finished: session);
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
          // Each attempt that fails, as Swift's `saveFinishedWorkout`.
          onAttemptFailed: (error, {required isTransient}) => _track(
            'finish_workout_save_error',
            parameters: {'error': '$error', 'is_transient': isTransient},
            type: LogType.severe,
          ),
          onProgress: (progress) {
            if (progress == SaveProgress.retrying) retried = true;
            if (isClosed) return;
            emit(
              _copy(saveNotice: progress, saveNoticeId: state.saveNoticeId + 1),
            );
          },
        );
    await _programFinished(uid, session, saved: result.saved);
    if (result.saved) {
      _track('Workout_Finished', parameters: _finishedParameters(session));
      _track('WorkoutTrackerView_FinishWorkout_Success');
      await _askForReview(session, firstWeekday: firstWeekday);
      await _exportToHealth(session);
      // Last, because Strava is polled until it has made the activity.
      // Only a saved workout: one that failed to save would be on Strava
      // and nowhere in Compound.
      await _queueForStrava(session);
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

  /// The workout that reaches the week's goal earns a rating request
  /// (`requestReviewIfEarned(.workoutFinished)`), counted with this
  /// session as Swift's `sessionsIncludingThis`. Best-effort.
  Future<void> _askForReview(
    WorkoutSessionModel session, {
    required int firstWeekday,
  }) async {
    final user = _user;
    final reviews = _reviews;
    if (user == null || reviews == null) return;
    final sessions = [
      for (final s in _history)
        if (s.id != session.id) s,
      session,
    ];
    try {
      await reviews.requestIfEarned(
        ReviewWorkoutFinished(
          sessionsThisWeek: CircleWeek.sessionsInWeek(
            user.userId,
            _clock(),
            sessions,
            firstWeekday % 7,
          ).length,
          weeklyGoal: weeklySessionGoal(user.weeklySessionGoal),
        ),
      );
    } on Object {
      // The store's prompt is a nicety; nothing is lost without it.
    }
  }

  /// Asks for Health's workout access as the workout starts, as Swift asks
  /// before each HealthKit workout session. A refusal is only noted.
  Future<void> _askHealthForWorkouts() async {
    final health = _health;
    if (health == null || !await health.isAvailable()) return;
    if (!await health.requestAuthorization(HealthScope.workouts)) {
      _track(
        'WorkoutTrackerView_HealthKitAuthorisation_Fail',
        type: LogType.warning,
      );
    }
  }

  /// Saves the finished workout to Health when it may write workouts
  /// (Swift ends its HealthKit workout session). Best-effort.
  Future<void> _exportToHealth(WorkoutSessionModel session) async {
    final health = _health;
    if (health == null ||
        !await health.isAvailable() ||
        await health.needsWorkoutAuthorization()) {
      return;
    }
    await health.exportWorkout(session);
  }

  /// Queues the finished workout for Strava and sends the queue, when
  /// connected. Upload failures are the repository's to report; this only
  /// guards against the queue's own storage failing.
  Future<void> _queueForStrava(WorkoutSessionModel session) async {
    try {
      await _strava?.queueUpload(session);
    } on Object catch (error) {
      _track(
        'strava_upload_error',
        parameters: {'error': '$error'},
        type: LogType.warning,
      );
    }
  }

  /// The rest days after the workout, and moving the program on
  /// (`preCompleteConsecutiveRestDays`, `advanceMacrocycle`). Best-effort,
  /// as in Swift: the next finish or skip tries again.
  Future<void> _programFinished(
    String uid,
    WorkoutSessionModel session, {
    required bool saved,
  }) async {
    try {
      await _programs?.workoutFinished(uid, session, saved: saved);
    } on Object catch (error) {
      _track(
        'finish_workout_plan_advance_error',
        parameters: {'error': '$error'},
        type: LogType.warning,
      );
    }
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
    bool? showsPlates,
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
    gym: state.gym,
    showsPlates: showsPlates ?? state.showsPlates,
    library: state.library,
    gyms: state.gyms,
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
    var nextKeypad = keypadClosed ? null : state.keypad;
    keypadClosed = false;
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
            distanceUnit: _distanceUnit(member),
            canDoLater: controller.canDoLater(member.id),
            progressionReason: member.id == current?.id
                ? _progressionReason(controller, member)
                : null,
            showsProgressionNote:
                member.id == current?.id &&
                !paused.acknowledgedNoteTemplateIds.contains(
                  member.templateId,
                ) &&
                rulesExercise(member).loggedSetCount == 0,
            restAnchor: controller.restAnchor(member.id),
            exerciseNote: _exerciseNote(member.templateId),
            restPicker: {
              for (final set in member.sets)
                set.id: controller.restPickerSeconds(set.id),
            },
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
      gym: _gym(session.gymProfileId) ?? _favouriteGym,
      showsPlates: keptShowsPlates,
      library: _allExercises,
      gyms: _activeGyms,
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
        distanceUnit: _distanceUnit(exercise),
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
    final surfaces = [
      for (final surface in _surfaces)
        if (surface.showsOngoingWorkout) surface,
    ];
    if (surfaces.isEmpty || !(_workoutSettings.showOnLockScreen ?? true)) {
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
      sessionId: session.id,
      activity: _liveActivity.showsOngoingWorkout
          ? liveActivityState(
              session: session,
              isActive: state.pausedAt == null,
              currentExerciseIndex: _controller!.currentExerciseIndex,
              now: _clock(),
              restEnd: restEnd,
              weightUnit: _unit,
              distanceUnit: _distanceUnit,
              plansSets: _workoutSettings.setPlanning ?? false,
            )
          : null,
    );
    if (ongoing == _ongoing) return;
    _ongoing = ongoing;
    for (final surface in surfaces) {
      _notify(() => surface.showOngoingWorkout(ongoing));
    }
  }

  /// With [summary], a finished workout's Live Activity shows it a while.
  void _clearOngoing({OngoingWorkoutSummary? summary}) {
    if (_ongoing == null) return;
    _ongoing = null;
    for (final surface in _surfaces) {
      _notify(() => surface.clearOngoingWorkout(summary: summary));
    }
  }

  /// The workout is over (finished, discarded, replaced or signed out of):
  /// nothing about it is left to announce, but the Live Activity of a
  /// [finished] one shows its summary.
  void _endNotifications({WorkoutSessionModel? finished}) {
    _scheduledRestEnd = null;
    _idleAnchor = null;
    _alertOngoing = false;
    _notify(() async {
      await _notifications.cancel(LocalReminderKind.restOver);
      await _notifications.cancel(LocalReminderKind.idleWorkout);
    });
    final volume = finished?.loggedVolumeKg ?? 0;
    _clearOngoing(
      summary: finished == null
          ? null
          : OngoingWorkoutSummary(
              duration: finished.activeDuration,
              completedSetsCount: finished.loggedSetCount,
              volumeKg: volume > 0 ? volume : null,
            ),
    );
  }

  // MARK: - The Live Activity's buttons

  /// A button on the Live Activity (`AppLiveActivityIntentHandler`), done
  /// as the tracker does it, and complete once the activity shows it. A tap
  /// that launched the app waits a little for the workout to be carried on.
  /// Finish ends the week on [firstWeekday] (ISO).
  Future<void> handleLiveActivityAction(
    LiveActivityAction action, {
    required int firstWeekday,
  }) async {
    if (_controller == null) {
      await stream
          .firstWhere((state) => state.isActive)
          .timeout(liveActivityWait, onTimeout: () => state);
    }
    final controller = _controller;
    if (controller == null || isClosed) return;
    final restEnd = controller.restEnd;
    final resting = restEnd != null && restEnd.isAfter(_clock());
    switch (action) {
      case CompleteSetAction(:final setId):
        if (state.set(setId)?.completedAt == null) {
          _log(setId, source: 'live_activity');
        }
      // Only during the rest after a set, as on the activity.
      case AdjustLastSetRepsAction(:final setId, :final delta) when resting:
        correctReps(setId, delta);
      case AdjustRestAction() when resting:
        addRestTime();
      case SkipRestAction():
        skipRest();
      case CompleteWorkoutAction():
        await finish(firstWeekday: firstWeekday);
      case AdjustLastSetRepsAction() || AdjustRestAction():
        break;
    }
    await notificationsSettled;
  }

  /// How long a tap that launched the app waits for the workout.
  static const liveActivityWait = Duration(seconds: 8);

  /// On the tracker's appearing and each return to the app: an hour since
  /// the last set (or since last asked) asks whether the workout is still
  /// going (`askIfStillTraining`). Asked once per return; Keep Going waits
  /// another hour.
  void checkStillTraining() {
    // The controller keeps when it last looked with the workout, so a
    // relaunch does not ask again (Swift's `lastSeenSetCompletion`).
    final lastSet = _controller?.stillTrainingPrompt(_clock());
    if (lastSet == null) return;
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
