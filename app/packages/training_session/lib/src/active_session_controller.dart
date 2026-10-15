/// The workout under way, as a controller with no UI
/// (`WorkoutTrackerPresenter` and its extensions, less what only a screen
/// does): logging, editing and correcting sets, undo, the exercises and
/// supersets, the rest and the pause, and finishing or discarding. The
/// rules it applies are `training_rules`'; this keeps the state, keeps it on
/// the device, and says what changed.
///
/// Words (titles, toasts, spoken labels) are the app's: the controller
/// returns the decisions they are worded from.
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:compound_models/compound_models.dart' as m;
import 'package:flutter/foundation.dart' show immutable;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/src/active_session_store.dart';
import 'package:training_session/src/library_exercise.dart';
import 'package:training_session/src/mapping.dart';
import 'package:training_session/src/model_copies.dart';
import 'package:training_session/src/session_builder.dart';
import 'package:training_session/src/session_history.dart';
import 'package:training_session/src/session_load.dart';
import 'package:training_session/src/weight_stepper.dart';

part 'active_session_undo.dart';

/// What the controller reads from the rest of the app.
class const TrackerEnvironment({
  /// The signed-in user, who authors new sets and exercises.
  required final String authorId,
  required final m.WorkoutSettings settings,

  /// The exercise library, for each exercise's type, assistance and
  /// equipment.
  final List<m.ExerciseModel> library = const [],

  /// The gym the workout is at: the template's, else the favourite.
  final m.GymProfileModel? gym,

  /// The user's units per exercise, by exercise (template) id.
  final Map<String, UnitPreference> unitPreferences = const {},

  /// The rest set on an exercise everywhere, by exercise (template) id
  /// (`ExerciseSettingsModel.restDurationOverride`).
  final Map<String, int> restOverrides = const {},

  /// The user's sessions, for last time and smart progression.
  final SessionHistory history = const SessionHistory([]),
});

/// Why a set could not be logged, or how it went.
class const LogResult({
  /// What stops the set being logged; `null` when it was.
  final r.SetProblem? problem,

  /// The rest the log started; `null` for none.
  final int? restSeconds,
});

/// What the correction bar offers for the set logged last
/// (`SetCorrection`, less its words).
class const SetCorrection({
  required final String exerciseId,
  required final String setId,
  required final bool correctsReps,
  required final bool canRemoveRep,
  required final bool showsRir,
  required final int? selectedRir,
});

/// The workout under way. Every change is kept on the device: within
/// [saveDebounce] of the last one, at once for a logged set, and on
/// [flush].
class ActiveSessionController {
  /// Carries on [state] (a new session, or one [ActiveSessionStore.load]
  /// found).
  new({
    required ActiveSessionState state,
    required TrackerEnvironment environment,
    required this._store,
    this._clock = DateTime.now,
    this._newId = newUuid,
    this._onSaveError,
  }) : _environment = environment,
       _session = state.session,
       _card = state.cardExerciseId,
       _restEnd = state.restEnd,
       _restStartedAt = state.restStartedAt,
       _pausedAt = state.pausedAt,
       _pausedSeconds = state.pausedSeconds,
       _customRestSeconds = {...state.customRestSeconds},
       _baseline = {...state.progressionBaseline},
       _acknowledged = {...state.acknowledgedNoteTemplateIds},
       _lastSeen = state.lastSeenSetCompletion {
    if (!environment.settings.addSmartWarmUps) _dropOpenWarmUps();
    // Before anything the user does, so an edited set can be told from a
    // filled-in one; a resumed workout keeps the baseline it began with.
    if (_baseline.isEmpty) _captureBaseline(_session.exercises);
    final card = _exercise(_card);
    if (card == null ||
        r.ActiveWorkout.currentSet(rulesExercise(card)) == null) {
      _card =
          (_firstIncomplete(_session.exercises) ??
                  _session.exercises.firstOrNull)
              ?.id;
    }
    _loadHistory(null);
  }

  /// The workout kept in [store], carried on; `null` when none is. A rest
  /// that ran out while the app was gone is ended once, keeping its start
  /// (`HKWorkoutManager.restoreAfterLaunch`).
  static Future<ActiveSessionController?> resume({
    required ActiveSessionStore store,
    required TrackerEnvironment environment,
    DateTime Function() clock = DateTime.now,
    IdGenerator newId = newUuid,
    void Function(Object error, StackTrace stackTrace)? onSaveError,
  }) async {
    final state = await store.load();
    if (state == null) return null;
    final controller = ActiveSessionController(
      state: state,
      environment: environment,
      store: store,
      clock: clock,
      newId: newId,
      onSaveError: onSaveError,
    );
    switch (r.RestRestore.plan(
      restEnd: state.restEnd,
      restStartedAt: state.restStartedAt,
      now: clock(),
    )) {
      case r.RestRestoreEnded():
        controller.restEnded();
      case r.RestRestoreRunning() || r.RestRestoreNone():
        break;
    }
    return controller;
  }

  /// How long a change waits before it is kept, so a burst of keystrokes is
  /// one write (`WorkoutSavePath.debounce`).
  static const saveDebounce = Duration(milliseconds: 300);

  /// What the rest's +15s adds.
  static const restAdjustmentSeconds = 15;

  /// An hour with nothing logged asks whether the workout is still on
  /// (`IdleWorkoutReminder.threshold`).
  static const idleThreshold = Duration(hours: 1);

  TrackerEnvironment _environment;
  final ActiveSessionStore _store;
  final DateTime Function() _clock;
  final IdGenerator _newId;
  final void Function(Object error, StackTrace stackTrace)? _onSaveError;

  m.WorkoutSessionModel _session;
  String? _card;
  DateTime? _restEnd;
  DateTime? _restStartedAt;
  DateTime? _pausedAt;
  double _pausedSeconds;
  final Map<String, int> _customRestSeconds;
  final Map<String, r.SuggestedSet> _baseline;
  final Set<String> _acknowledged;
  DateTime? _lastSeen;

  final Map<String, m.WorkoutExerciseModel?> _previous = {};
  final Map<String, r.ProgressionSuggestion> _suggestions = {};

  /// The set being typed into, as it was before the first keystroke.
  m.WorkoutSetModel? _pendingEdit;
  bool _isDone = false;
  Timer? _scheduledSave;
  Future<void> _writes = Future.value();
  final _undo = _UndoStack();

  // MARK: - State

  /// The session as it stands.
  m.WorkoutSessionModel get session => _session;

  /// Everything kept on the device, as [ActiveSessionStore] keeps it.
  ActiveSessionState get state => ActiveSessionState(
    session: _session,
    cardExerciseId: _card,
    restEnd: _restEnd,
    restStartedAt: _restStartedAt,
    pausedAt: _pausedAt,
    pausedSeconds: _pausedSeconds,
    customRestSeconds: Map.unmodifiable(_customRestSeconds),
    progressionBaseline: Map.unmodifiable(_baseline),
    acknowledgedNoteTemplateIds: Set.unmodifiable(_acknowledged),
    lastSeenSetCompletion: _lastSeen,
  );

  TrackerEnvironment get environment => _environment;

  /// A changed environment: settings edited, the gym loaded. Exercises'
  /// last time and suggestions are read again.
  set environment(TrackerEnvironment environment) {
    _environment = environment;
    _loadHistory(null);
  }

  /// Finished or discarded: nothing more is kept.
  bool get isDone => _isDone;

  /// Changes not yet kept.
  bool get hasUnsavedChanges => _scheduledSave != null;

  /// Completes once every write started so far has landed.
  Future<void> get saved => _writes;

  m.WorkoutSettings get _settings => _environment.settings;

  r.WorkoutSettings get _rules => rulesSettings(_settings);

  // MARK: - The card

  /// The exercise on the card: the one opened, else the first with sets
  /// left, else the last.
  m.WorkoutExerciseModel? get currentExercise =>
      _exercise(_card) ??
      _firstIncomplete(_session.exercises) ??
      _session.exercises.lastOrNull;

  /// Where [currentExercise] is in the workout.
  int get currentExerciseIndex {
    final index = _session.exercises.indexWhere(
      (e) => e.id == currentExercise?.id,
    );
    return index < 0 ? 0 : index;
  }

  /// Opens [exerciseId] on the card.
  void selectExercise(String exerciseId) {
    if (_exercise(exerciseId) == null) return;
    _card = exerciseId;
    _scheduleSave();
  }

  /// What the button at the foot of the screen does with no rest running
  /// (`ActiveWorkout.primaryAction`).
  r.ActiveWorkoutAction? get primaryAction =>
      r.ActiveWorkout.primaryAction(_rulesExercises, currentExercise?.id);

  /// The button's action at [now], with the rest and the pause
  /// (`ActiveWorkout.slotAction`).
  r.SlotAction? slotAction(DateTime now) => r.ActiveWorkout.slotAction(
    primary: primaryAction,
    restEnd: _restEnd,
    isPaused: isPaused,
    now: now,
  );

  /// Logs the next set, opens the next exercise, or answers
  /// [r.FinishAction] for the caller to confirm the finish.
  r.ActiveWorkoutAction? pressPrimary() {
    final action = primaryAction;
    switch (action) {
      case r.LogSetAction(:final setId):
        logSet(setId);
      case r.NextExerciseAction(:final exerciseId):
        selectExercise(exerciseId);
      case r.FinishAction() || null:
        break;
    }
    return action;
  }

  /// The exercise strip, block by block (`ActiveWorkout.stripProgress`).
  List<r.StripItem> get strip =>
      r.ActiveWorkout.stripProgress(_rulesExercises, currentExercise?.id);

  // MARK: - Logging

  /// Logs [setId] (`WorkoutTrackerPresenter.logSet`): checks it, stamps it,
  /// keeps it at once, moves the card, starts the rest and re-suggests what
  /// is left. `null` when the set is missing or already logged.
  LogResult? logSet(String setId, {int? customRestSeconds}) {
    final exercise = _exerciseHolding(setId);
    if (exercise == null || _isDone) return null;
    final outcome = r.ActiveWorkout.log(
      setId,
      rulesSession(_session),
      settings: _rules,
      context: _restContext(exercise),
      now: _clock(),
      customRestSeconds: customRestSeconds ?? _customRestSeconds[setId],
      isAssisted: _library(exercise)?.isAssisted ?? false,
    );
    if (outcome == null) return null;
    if (outcome.problem != null) return LogResult(problem: outcome.problem);
    final logged = modelSet(
      outcome.session.exercises
          .firstWhere((e) => e.id == exercise.id)
          .sets
          .firstWhere((s) => s.id == setId),
      original: exercise.sets.firstWhere((s) => s.id == setId),
      now: _clock(),
    );
    _updateSet(exercise.id, logged, flushIfLogged: false);
    final rest = outcome.restSeconds;
    if (_settings.useRestTimers && rest != null) startRest(rest);
    _applyLiveProgression(logged, exercise.id);
    // A logged set, with the rest it started, is the change worth not
    // waiting for.
    flush();
    return LogResult(restSeconds: rest);
  }

  /// Writes [updated] over its set at once, carrying an edit onto its open
  /// siblings when Propagate Changes is on; a set newly logged moves the
  /// card and is kept at once (`updateSet`).
  void updateSet(String exerciseId, m.WorkoutSetModel updated) =>
      _updateSet(exerciseId, updated, flushIfLogged: true);

  void _updateSet(
    String exerciseId,
    m.WorkoutSetModel updated, {
    required bool flushIfLogged,
  }) {
    _recordCompletionUndo(exerciseId, updated);
    _commitPendingEdit(sparing: updated.id);
    final exercise = _exercise(exerciseId);
    final before = exercise?.sets.where((s) => s.id == updated.id).firstOrNull;
    if (exercise == null || before == null) return;
    final isLogged = before.completedAt == null && updated.completedAt != null;
    var sets = [
      for (final set in exercise.sets)
        if (set.id == updated.id) updated else set,
    ];
    if (_settings.propagateChanges) {
      sets = modelSets(
        r.ActiveWorkout.propagate(
          edit: rulesSet(updated),
          original: rulesSet(before),
          sets: sets.map(rulesSet).toList(),
        ),
        originals: sets,
        now: _clock(),
      );
    }
    _replaceExercise(
      exercise.copyWith(sets: sets),
      flush: isLogged && flushIfLogged,
    );
    if (isLogged) _moveFocus(afterLogging: updated.id);
  }

  /// A keystroke in a set's fields: [typed] replaces the set as it is, its
  /// completion aside, which only [logSet] and [unlog] change. The edit is
  /// carried onto the set's siblings once it is over ([commitEdit]), from
  /// what the set held before the first key.
  void editSet(m.WorkoutSetModel typed) {
    final exercise = _exerciseHolding(typed.id);
    if (exercise == null) return;
    final before = exercise.sets.firstWhere((s) => s.id == typed.id);
    final set = typed.copyWith(completedAt: before.completedAt);
    _replaceExercise(
      exercise.copyWith(
        sets: [
          for (final s in exercise.sets)
            if (s.id == set.id) set else s,
        ],
      ),
    );
    if (!_settings.propagateChanges ||
        (before.weightKg == set.weightKg && before.reps == set.reps) ||
        _pendingEdit?.id == before.id) {
      return;
    }
    _commitPendingEdit(sparing: before.id);
    _pendingEdit = before;
  }

  /// Ends the edit being typed (the keyboard hid): it carries onto its
  /// siblings.
  void commitEdit() => _commitPendingEdit();

  void _commitPendingEdit({String? sparing}) {
    final original = _pendingEdit;
    _pendingEdit = null;
    if (original == null || !_settings.propagateChanges) return;
    final exercise = _exerciseHolding(original.id);
    if (exercise == null) return;
    final edit = exercise.sets.firstWhere((s) => s.id == original.id);
    final propagated = modelSets(
      r.ActiveWorkout.propagate(
        edit: rulesSet(edit),
        original: rulesSet(original),
        sets: exercise.sets.map(rulesSet).toList(),
      ),
      originals: exercise.sets,
      now: _clock(),
    );
    final sets = [
      for (final (index, set) in propagated.indexed)
        if (set.id == sparing) exercise.sets[index] else set,
    ];
    if (_sameFigures(sets, exercise.sets)) return;
    _replaceExercise(exercise.copyWith(sets: sets));
  }

  static bool _sameFigures(
    List<m.WorkoutSetModel> a,
    List<m.WorkoutSetModel> b,
  ) => [for (var i = 0; i < a.length; i++) i]
      .every((i) => a[i].weightKg == b[i].weightKg && a[i].reps == b[i].reps);

  /// Un-logs [setId] and calls off the rest it started.
  void unlog(String setId) {
    final exercise = _exerciseHolding(setId);
    final set = _loggedSet(setId);
    if (exercise == null || set == null) return;
    updateSet(exercise.id, set.copyWith(completedAt: null));
  }

  /// A tap on a row's circle: logs an open set, un-logs a logged one.
  LogResult? toggleSet(String setId) {
    if (_loggedSet(setId) != null) {
      unlog(setId);
      return null;
    }
    return logSet(setId);
  }

  // MARK: - Correction

  /// The correction bar for the set logged last on [exerciseId], or `null`
  /// with nothing to correct there.
  SetCorrection? correction(String exerciseId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null) return null;
    final setId = r.ActiveWorkout.correctionTarget(
      rulesExercise(exercise),
      r.ActiveWorkout.latestCompletedSet(_rulesExercises),
    );
    final set = exercise.sets.where((s) => s.id == setId).firstOrNull;
    if (set == null) return null;
    final countsReps =
        exercise.trackingMode == m.TrackingMode.weightReps ||
        exercise.trackingMode == m.TrackingMode.repsOnly;
    return SetCorrection(
      exerciseId: exercise.id,
      setId: set.id,
      correctsReps: countsReps && set.reps != null,
      canRemoveRep: (set.reps ?? 0) > 1,
      showsRir: countsReps && _settings.rirTracking,
      selectedRir: r.ActiveWorkout.rirChipForRpe(set.rpe),
    );
  }

  /// The bar over the log button: the set logged last, while the rest it
  /// started runs.
  SetCorrection? restCorrection(DateTime now) {
    if (slotAction(now) is! r.SlotSkipRest) return null;
    final latest = r.ActiveWorkout.latestCompletedSet(_rulesExercises);
    final exercise = latest == null ? null : _exerciseHolding(latest.id);
    return exercise == null ? null : correction(exercise.id);
  }

  /// A rep off or on a logged set, never below one; what is left is
  /// suggested again. Taps on one set undo together.
  void correctReps(String setId, int delta) {
    final set = _loggedSet(setId);
    final exercise = _exerciseHolding(setId);
    final reps = set?.reps;
    if (set == null || exercise == null || reps == null) return;
    final corrected = math.max(1, reps + delta);
    if (corrected == reps) return;
    _registerRepsUndo(set, exercise.id);
    final updated = set.copyWith(reps: corrected);
    updateSet(exercise.id, updated);
    _applyLiveProgression(updated, exercise.id);
  }

  /// Reps in reserve on a logged set, kept as RPE; the chip already chosen
  /// clears it.
  void setRir(String setId, int chip) {
    final set = _loggedSet(setId);
    final exercise = _exerciseHolding(setId);
    if (set == null || exercise == null) return;
    final rpe = r.ActiveWorkout.rpeForRirChip(chip);
    updateSet(exercise.id, set.copyWith(rpe: set.rpe == rpe ? null : rpe));
  }

  // MARK: - Sets

  /// One more set on [exerciseId] (two rows when its sides are split).
  void addSet(String exerciseId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null) return;
    _replaceExercise(
      addingSet(
        exercise,
        authorId: _environment.authorId,
        now: _clock(),
        newId: _newId,
      ),
    );
  }

  /// Deletes [setId] with its pair and their sub-rows; Undo puts them back.
  void deleteSet(String setId) {
    final exercise = _exerciseHolding(setId);
    if (exercise == null) return;
    final removed = r.ActiveWorkout.idsRemovedByDeleting(
      setId,
      exercise.sets.map(rulesSet).toList(),
    ).toSet();
    final restore = [
      for (final (offset, set) in exercise.sets.indexed)
        if (removed.contains(set.id)) (offset: offset, set: set),
    ];
    _register(const UndoName(UndoKind.deleteSet), () {
      final current = _exercise(exercise.id);
      if (current == null) return;
      final sets = [...current.sets];
      for (final (:offset, :set) in restore) {
        if (sets.any((s) => s.id == set.id)) continue;
        sets.insert(math.min(offset, sets.length), set);
      }
      _replaceExercise(current.copyWith(sets: sets));
    });
    _replaceExercise(
      exercise.copyWith(
        sets: [
          for (final set in exercise.sets)
            if (!removed.contains(set.id)) set,
        ],
      ),
    );
  }

  /// Makes [setId] (and its pair) [choice]: sub-rows the new type has no use
  /// for go, and a drop or myo set left with none gets its first.
  void setSetType(String setId, r.SetTypeChoice choice) {
    final exercise = _exerciseHolding(setId);
    if (exercise == null) return;
    final set = exercise.sets.firstWhere((s) => s.id == setId);
    _replaceRulesSets(
      exercise,
      r.ActiveWorkout.applying(
        choice,
        setId,
        exercise.sets.map(rulesSet).toList(),
        firstSubSetId: _newId(),
        dropWeightKg: _dropWeightKg(set, exercise),
      ),
    );
  }

  /// A drop (20 % lighter, on a weight the equipment makes) or a mini-set
  /// (at the set's weight) after [setId] and any it has.
  void addSubSet(String setId, r.SubSetKind kind) {
    final exercise = _exerciseHolding(setId);
    if (exercise == null) return;
    final parent = exercise.sets.firstWhere((s) => s.id == setId);
    _replaceRulesSets(
      exercise,
      r.ActiveWorkout.addingSubSet(
        kind,
        setId,
        exercise.sets.map(rulesSet).toList(),
        id: _newId(),
        weightKg: kind == r.SubSetKind.drop
            ? _dropWeightKg(parent, exercise)
            : parent.weightKg,
      ),
    );
  }

  /// [exerciseId]'s `both` rows as a left and a right row each.
  void splitSides(String exerciseId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null) return;
    _replaceRulesSets(
      exercise,
      r.splittingSides(exercise.sets.map(rulesSet).toList(), _newId),
    );
  }

  /// [exerciseId]'s left and right rows as one `both` row each.
  void joinSides(String exerciseId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null) return;
    _replaceRulesSets(
      exercise,
      r.joiningSides(exercise.sets.map(rulesSet).toList()),
    );
  }

  /// A rest set by hand on [setId]'s row, or cleared.
  void setCustomRest(String setId, int? seconds) {
    if (seconds == null) {
      _customRestSeconds.remove(setId);
    } else {
      _customRestSeconds[setId] = seconds;
    }
    _scheduleSave();
  }

  /// The steps [exerciseId]'s weight moves by on the keyboard: its equipment
  /// in the workout's gym, in its unit, mirrored for assistance.
  r.WeightStep weightStep(String exerciseId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null) return r.WeightStep.fallback(r.WeightUnit.kilograms);
    final step = WeightStepper.stepsForExercise(
      exercise,
      _environment.gym,
      _weightUnit(exercise).rules,
    );
    final library = _library(exercise);
    return library != null && library.isAssisted
        ? step.assisted(bodyweightOnly: library.isBodyweight)
        : step;
  }

  double? _dropWeightKg(
    m.WorkoutSetModel parent,
    m.WorkoutExerciseModel exercise,
  ) {
    final unit = _weightUnit(exercise).rules;
    return r.ActiveWorkout.dropWeightKg(
      parent.weightKg,
      WeightStepper.stepsForExercise(exercise, _environment.gym, unit),
      unit,
    );
  }

  m.ExerciseWeightUnit _weightUnit(m.WorkoutExerciseModel exercise) =>
      exercise.weightUnit ??
      _environment.unitPreferences[exercise.templateId]?.weightUnit ??
      m.ExerciseWeightUnit.kilograms;

  // MARK: - Notes

  /// The session's note; blank clears it.
  void setWorkoutNotes(String notes) {
    final trimmed = notes.trim();
    _setSession(_session.copyWith(notes: trimmed.isEmpty ? null : trimmed));
  }

  /// An exercise's note for this session; blank clears it.
  void setExerciseNotes(String exerciseId, String notes) {
    final exercise = _exercise(exerciseId);
    if (exercise == null) return;
    final trimmed = notes.trim();
    _replaceExercise(
      exercise.copyWith(notes: trimmed.isEmpty ? null : trimmed),
    );
  }

  /// The progression note on [templateId] was dismissed for this workout.
  void acknowledgeProgressionNote(String templateId) {
    _acknowledged.add(templateId);
    _scheduleSave();
  }

  // MARK: - Exercises

  /// Exercises picked part-way through, set up as the workout's own were;
  /// the card stays where it was, or takes the first when there was none.
  void addExercises(List<m.WorkoutTemplateExercise> templates) {
    if (templates.isEmpty) return;
    final start = _session.exercises.length;
    final added = [
      for (final (offset, template) in templates.indexed)
        addedExercise(
          template,
          authorId: _environment.authorId,
          index: start + offset + 1,
          now: _clock(),
          gym: _environment.gym,
          preference: _environment.unitPreferences[template.exercise.id],
          newId: _newId,
        ),
    ];
    final card = currentExercise?.id ?? added.first.id;
    _setExercises([..._session.exercises, ...added]);
    _focusCard(card);
    _captureBaseline(added);
    _loadHistory(added);
  }

  /// Takes [exerciseId] out: a superset partner left alone is no longer
  /// one, and a card on it moves to the next exercise in order with sets
  /// left.
  void deleteExercise(String exerciseId) {
    final index = _session.exercises.indexWhere((e) => e.id == exerciseId);
    if (index < 0) return;
    final removed = _session.exercises[index];
    var updated = [..._session.exercises]..removeAt(index);
    final group = removed.supersetGroupId;
    if (group != null) {
      final partners = updated.where((e) => e.supersetGroupId == group);
      if (partners.length == 1) {
        final partner = partners.single;
        updated = [
          for (final e in updated)
            if (e.id == partner.id) e.copyWith(supersetGroupId: null) else e,
        ];
      }
    }
    updated = _reindexed(updated);
    var card = currentExercise?.id;
    if (card == exerciseId) {
      card =
          (updated.skip(index).where((e) => !isComplete(e)).firstOrNull ??
                  updated.where((e) => !isComplete(e)).firstOrNull)
              ?.id;
    }
    _setExercises(updated);
    _focusCard(card);
  }

  /// [exerciseId] joins the superset [groupId], or leaves its own.
  void setSupersetGroup(String exerciseId, String? groupId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null) return;
    _replaceExercise(exercise.copyWith(supersetGroupId: groupId));
  }

  /// A set more for every member of a superset, as one round.
  void addRound(List<String> memberIds) {
    _setExercises([
      for (final e in _session.exercises)
        if (memberIds.contains(e.id))
          addingSet(
            e,
            authorId: _environment.authorId,
            now: _clock(),
            newId: _newId,
          )
        else
          e,
    ]);
  }

  /// A superset split back into exercises on their own.
  void removeSuperset(List<String> memberIds) => _setExercises([
    for (final e in _session.exercises)
      if (memberIds.contains(e.id)) e.copyWith(supersetGroupId: null) else e,
  ]);

  /// True when [exercise] has sets and every one is logged.
  bool isComplete(m.WorkoutExerciseModel exercise) =>
      exercise.sets.isNotEmpty &&
      exercise.sets.every((set) => set.completedAt != null);

  /// Whether [exerciseId] can be put off: sets left, and something else
  /// could go first.
  bool canDoLater(String exerciseId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null || isComplete(exercise)) return false;
    final group = _movingGroup(exerciseId).map((e) => e.id).toSet();
    return _session.exercises.any(
      (e) => !group.contains(e.id) && !isComplete(e),
    );
  }

  /// A busy machine: [exerciseId], with its superset, to the end; put off
  /// from the card, the card moves to the next exercise with sets left.
  void doLater(String exerciseId) {
    final group = _movingGroup(exerciseId);
    final ids = group.map((e) => e.id).toSet();
    final wasOnCard = ids.contains(currentExercise?.id);
    _move(group, _session.exercises.where((e) => !ids.contains(e.id)).length);
    if (!wasOnCard) return;
    final next = _session.exercises
        .where((e) => !ids.contains(e.id) && !isComplete(e))
        .firstOrNull;
    if (next != null) _card = next.id;
  }

  /// [exerciseId], with its superset, straight after the card's block.
  void doNext(String exerciseId) {
    final group = _movingGroup(exerciseId);
    final ids = group.map((e) => e.id).toSet();
    final others = _session.exercises.where((e) => !ids.contains(e.id));
    final current = _movingGroup(currentExercise?.id ?? '')
        .map((e) => e.id)
        .toSet();
    _move(
      group,
      others.toList().lastIndexWhere((e) => current.contains(e.id)) + 1,
    );
  }

  /// The block whose first exercise is [blockId] moved to [index] among the
  /// blocks, as one; the card stays on its exercise.
  void moveBlock(String blockId, int index) {
    final moved = r.ActiveWorkout.movingBlock(blockId, index, _rulesExercises);
    final byId = {for (final e in _session.exercises) e.id: e};
    final updated = [for (final e in moved) byId[e.id]!];
    if (updated.map((e) => e.id).join() ==
        _session.exercises.map((e) => e.id).join()) {
      return;
    }
    _reorder(updated);
  }

  /// [exerciseId] swapped for [replacement]: logged sets stay where they
  /// were done, and the replacement follows with the sets still open on
  /// the equipment the session chooses; the card moves to it.
  void swapExercise(String exerciseId, m.ExerciseModel replacement) {
    final index = _session.exercises.indexWhere((e) => e.id == exerciseId);
    if (index < 0) return;
    final swap = swapping(
      _session.exercises[index],
      replacement: replacement,
      authorId: _environment.authorId,
      now: _clock(),
      newId: _newId,
    );
    final fresh = takingLoad(
      swap.replacement,
      exercise: replacement,
      gym: _environment.gym,
      preference: _environment.unitPreferences[replacement.id],
    );
    final exercises = [..._session.exercises];
    if (swap.kept case final kept?) {
      exercises
        ..[index] = kept
        ..insert(index + 1, fresh);
    } else {
      exercises[index] = fresh;
    }
    _setExercises(_reindexed(exercises));
    _card = fresh.id;
    _loadHistory(null);
  }

  /// [exerciseId] on another of its variations: its unit again, its open
  /// sets on weights the new equipment makes, and last time and the
  /// suggestion read on the new kind of load.
  void chooseVariation(String exerciseId, String variationId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null || exercise.chosenVariationId == variationId) return;
    final refitted = refittingLoad(
      exercise.copyWith(chosenVariationId: variationId),
      library: _library(exercise),
      gym: _environment.gym,
      preference: _environment.unitPreferences[exercise.templateId],
    );
    _replaceExercise(refitted);
    _loadHistory([refitted]);
  }

  List<m.WorkoutExerciseModel> _movingGroup(String exerciseId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null) return [];
    final group = exercise.supersetGroupId;
    if (group == null) return [exercise];
    return _session.exercises.where((e) => e.supersetGroupId == group).toList();
  }

  void _move(List<m.WorkoutExerciseModel> group, int index) {
    final ids = group.map((e) => e.id).toSet();
    final updated =
        _session.exercises.where((e) => !ids.contains(e.id)).toList()
          ..insertAll(
            math.min(index, _session.exercises.length - group.length),
            group,
          );
    _reorder(updated);
  }

  void _reorder(List<m.WorkoutExerciseModel> updated) {
    final card = currentExercise?.id;
    _setExercises(_reindexed(updated));
    if (card != null && _exercise(card) != null) _card = card;
  }

  static List<m.WorkoutExerciseModel> _reindexed(
    List<m.WorkoutExerciseModel> exercises,
  ) => [
    for (final (index, exercise) in exercises.indexed)
      exercise.copyWith(index: index + 1),
  ];

  void _focusCard(String? exerciseId) =>
      _card = _exercise(exerciseId) == null ? null : exerciseId;

  // MARK: - Rest

  /// When the running rest ends; `null` with none.
  DateTime? get restEnd => _restEnd;

  /// When the last rest began, kept after it ran out.
  DateTime? get restStartedAt => _restStartedAt;

  /// Starts a rest of [seconds] now; one running is replaced.
  void startRest(int seconds) {
    final now = _clock();
    _restStartedAt = now;
    _restEnd = now.add(Duration(seconds: math.max(0, seconds)));
    _scheduleSave();
  }

  /// +15s on the running rest, restarted from now for what is left.
  void addRestTime() {
    final now = _clock();
    final end = _restEnd;
    if (end == null) return;
    final remaining =
        (end.difference(now).inMicroseconds / Duration.microsecondsPerSecond)
            .ceil() +
        restAdjustmentSeconds;
    startRest(math.max(1, remaining));
  }

  /// Skip Rest: the rest is called off and over.
  void skipRest() {
    _cancelRest();
    _focusWhenRestEnds();
    _scheduleSave();
  }

  /// The rest ran out on its own: its start is kept, so its row reads Ready
  /// until the next set, and a card left on a finished exercise moves on.
  void restEnded() {
    _restEnd = null;
    _focusWhenRestEnds();
    _scheduleSave();
  }

  /// Where the inline rest timer sits in [exerciseId]'s table, or `null` to
  /// leave it out.
  r.RestAnchor? restAnchor(String exerciseId) {
    final exercise = _exercise(exerciseId);
    if (exercise == null || (_restEnd == null && _restStartedAt == null)) {
      return null;
    }
    return r.ActiveWorkout.restAnchor(
      rulesExercise(exercise),
      restedSet: r.ActiveWorkout.latestCompletedSet(_rulesExercises),
      restStartedAt: _restStartedAt,
    );
  }

  void _cancelRest() {
    _restEnd = null;
    _restStartedAt = null;
  }

  void _focusWhenRestEnds() {
    final target = r.ActiveWorkout.focusWhenRestEnds(
      currentExercise?.id,
      _rulesExercises,
      _rules,
    );
    if (target != null) _card = target;
  }

  int? _restAfterLogging(
    m.WorkoutSetModel set,
    m.WorkoutExerciseModel exercise,
  ) => r.RestDurationRules.restAfterCompleting(
    rulesSet(set),
    rulesExercise(exercise),
    _rulesExercises,
    _rules,
    _restContext(exercise),
    customRestSeconds: _customRestSeconds[set.id],
  );

  r.RestContext _restContext(m.WorkoutExerciseModel exercise) => r.RestContext(
    restOverrideSeconds: _environment.restOverrides[exercise.templateId],
    exerciseType: _library(exercise)?.type?.rules,
    planRestSeconds: exercise.restSeconds,
  );

  // MARK: - Pause

  /// Paused: the clock stands still.
  bool get isPaused => _pausedAt != null;

  /// Pauses a running workout, or resumes a paused one.
  void togglePause() {
    final now = _clock();
    final pausedAt = _pausedAt;
    if (pausedAt == null) {
      _pausedAt = now;
    } else {
      _pausedSeconds += math.max(0, _seconds(pausedAt, now));
      _pausedAt = null;
    }
    _scheduleSave();
  }

  /// Seconds spent paused up to [at], a pause under way included.
  double pausedSeconds(DateTime at) =>
      _pausedSeconds +
      (_pausedAt == null ? 0 : math.max(0, _seconds(_pausedAt!, at)));

  /// The workout clock at [at], paused time left out.
  Duration elapsed(DateTime at) => Duration(
    microseconds: math
        .max(
          0,
          (_seconds(_session.dateCreated, at) - pausedSeconds(at)) *
              Duration.microsecondsPerSecond,
        )
        .round(),
  );

  static double _seconds(DateTime from, DateTime to) =>
      to.difference(from).inMicroseconds / Duration.microsecondsPerSecond;

  // MARK: - Still training?

  /// When the last set was logged, if nothing has happened for an hour
  /// since it (or since the screen last looked): ask whether the workout is
  /// still on. Asking counts as looking, so it is asked once.
  DateTime? stillTrainingPrompt(DateTime now) {
    if (_isDone) return null;
    final last = r.ActiveWorkout.latestCompletedSet(_rulesExercises)
        ?.completedAt;
    if (last == null) return null;
    final seen = _lastSeen;
    final activity = seen != null && seen.isAfter(last) ? seen : last;
    if (now.difference(activity) < idleThreshold) return null;
    _lastSeen = now;
    _scheduleSave();
    return last;
  }

  // MARK: - Last time and smart progression

  /// What [exercise] was last time, for its Prev column.
  m.WorkoutExerciseModel? previousExercise(m.WorkoutExerciseModel exercise) =>
      _previous[_historyKey(exercise)];

  /// Smart progression's suggestion for [exercise].
  r.ProgressionSuggestion? suggestion(m.WorkoutExerciseModel exercise) =>
      _suggestions[_historyKey(exercise)];

  String _historyKey(m.WorkoutExerciseModel exercise) =>
      r.historyKeyFor(exercise.templateId, _session.occurrenceOf(exercise));

  /// Last time and the suggestions for [exercises] (all of them with `null`),
  /// keeping what is held for the others.
  void _loadHistory(List<m.WorkoutExerciseModel>? exercises) {
    final templateIds = exercises?.map((e) => e.templateId).toSet();
    // Every appearance of a narrowed exercise, so each keeps its occurrence.
    final narrowed = [
      for (final e in _session.exercises)
        if (templateIds == null || templateIds.contains(e.templateId)) e,
    ];
    final history = _environment.history;
    _previous.addAll(
      history.previousExercises(
        session: _session,
        exercises: narrowed,
        scope: _settings.previousWorkoutReference,
      ),
    );
    final suggestions = history.suggestions(
      contexts: [
        for (final e in narrowed)
          sessionContext(
            e,
            library: _library(e),
            gym: _environment.gym,
            preferredUnit: _preferredUnit(e),
            occurrence: _session.occurrenceOf(e),
          ),
      ],
      workoutTemplateId: _session.workoutTemplateId,
      mesocycleId: _session.mesocycleId,
      settings: _settings,
    );
    _suggestions.addAll(
      _session.isDeload ?? false
          ? _deloaded(suggestions, narrowed)
          : suggestions,
    );
  }

  /// A deload week's suggestions at the deload's weight.
  Map<String, r.ProgressionSuggestion> _deloaded(
    Map<String, r.ProgressionSuggestion> suggestions,
    List<m.WorkoutExerciseModel> exercises,
  ) => {
    ...suggestions,
    for (final e in exercises)
      if (suggestions[_historyKey(e)] case final suggestion?)
        _historyKey(e): r.ProgressionSuggestion(suggestion.rationale, [
          for (final set in suggestion.sets)
            r.SuggestedSet(
              weightKg: switch (set.weightKg) {
                final weight? => r.MesocycleDeload.lighterWeight(
                  weight,
                  _roundingRule(e).round,
                ),
                null => null,
              },
              reps: set.reps,
              durationSec: set.durationSec,
              distanceMeters: set.distanceMeters,
              targetReps: set.targetReps,
            ),
        ]),
  };

  m.ExerciseWeightUnit? _preferredUnit(m.WorkoutExerciseModel exercise) =>
      exercise.weightUnit ??
      _environment.unitPreferences[exercise.templateId]?.weightUnit;

  r.WeightRoundingRule _roundingRule(m.WorkoutExerciseModel exercise) =>
      weightRoundingRule(
        exercise: _library(exercise),
        gym: _environment.gym,
        preferredUnit: _preferredUnit(exercise),
        resistanceEquipment: exercise.activeVariation?.resistanceEquipment,
      );

  void _captureBaseline(List<m.WorkoutExerciseModel> exercises) {
    for (final exercise in exercises) {
      for (final set in exercise.sets) {
        if (set.isWarmup) continue;
        _baseline[set.id] = r.SuggestedSet(
          weightKg: set.weightKg,
          reps: set.reps,
        );
      }
    }
  }

  /// Re-suggests the sets of [exerciseId] still to come from [completed],
  /// with Apply In Session on: only sets asked for the same as it, and only
  /// those still holding what was filled in (`applyLiveProgression`).
  void _applyLiveProgression(m.WorkoutSetModel completed, String exerciseId) {
    final exercise = _exercise(exerciseId);
    if (!_settings.smartProgressionApplyInSession ||
        exercise == null ||
        exercise.trackingMode != m.TrackingMode.weightReps ||
        completed.parentSetId != null) {
      return;
    }
    final working = exercise.sets
        .where((s) => !s.isWarmup && s.parentSetId == null)
        .toList();
    final position = working.indexWhere((s) => s.id == completed.id);
    if (position < 0) return;
    // A set's number counts a left/right pair once, as targets do.
    int setNumber(int index) => math.max(
      working.take(index + 1).where((s) => s.side != m.SetSide.right).length -
          1,
      0,
    );
    m.SetTarget? target(int index) {
      final targets = exercise.setTargets;
      if (targets.isEmpty) return null;
      final number = setNumber(index);
      return number < targets.length ? targets[number] : targets.last;
    }

    final ask = target(position);
    final remaining = [
      for (var i = position + 1; i < working.length; i++)
        if (working[i].completedAt == null && _sameAsk(target(i), ask))
          working[i],
    ];
    if (remaining.isEmpty) return;
    final adjusted = r.ProgressionEngine.adjustRemaining(
      completed: rulesSet(completed),
      target: ask == null ? null : rulesTarget(ask),
      remaining: remaining.map(rulesSet).toList(),
      mode: r.TrackingMode.weightReps,
      rounding: progressionRounding(_roundingRule(exercise)),
      exerciseType: _library(exercise)?.type?.rules,
    );
    final changes = <String, m.WorkoutSetModel>{};
    for (final (offset, suggestion) in adjusted.indexed) {
      final set = remaining[offset];
      final baseline = _baseline[set.id];
      // Only what the engine itself put there may be rewritten.
      if (suggestion == null ||
          baseline?.weightKg != set.weightKg ||
          baseline?.reps != set.reps) {
        continue;
      }
      final changed = set.copyWith(
        weightKg: suggestion.weightKg ?? set.weightKg,
        reps: suggestion.reps ?? set.reps,
      );
      changes[set.id] = changed;
      _baseline[set.id] = r.SuggestedSet(
        weightKg: changed.weightKg,
        reps: changed.reps,
      );
    }
    if (changes.isEmpty) return;
    _replaceExercise(
      exercise.copyWith(
        sets: [for (final set in exercise.sets) changes[set.id] ?? set],
      ),
    );
  }

  static bool _sameAsk(m.SetTarget? a, m.SetTarget? b) =>
      a?.setType == b?.setType &&
      a?.minReps == b?.minReps &&
      a?.maxReps == b?.maxReps &&
      a?.rirTarget == b?.rirTarget;

  // MARK: - Finishing

  /// Whether anything was logged: finishing without is asked about first.
  bool get hasLoggedSet => _session.exercises.any(
    (e) => e.sets.any((set) => set.completedAt != null),
  );

  /// Something to finish, all of it logged: Finish is offered at the
  /// bottom as well.
  bool get canQuickFinish {
    final sets = _session.exercises.expand((e) => e.sets);
    return sets.isNotEmpty && sets.every((set) => set.completedAt != null);
  }

  /// Ends the workout [at] (now, or the last set's time for "Finish at"):
  /// paused time recorded, only logged sets kept, each stamped with its unit
  /// and load count. The finished session is kept on the device until it
  /// is saved (`WorkoutFinisher` clears it), so a failed save can be tried
  /// again after a relaunch.
  Future<m.WorkoutSessionModel> finish({DateTime? at}) async {
    if (_isDone) return _session;
    _commitPendingEdit();
    final end = at ?? _clock();
    final paused = pausedSeconds(end);
    _session = _session.copyWith(
      endedAt: end,
      dateModified: end,
      pausedSeconds: paused > 0 ? paused : null,
      exercises: [
        for (final exercise in _session.exercises)
          () {
            final rules = rulesExercise(exercise);
            return exercise.copyWith(
              sets: modelSets(
                [
                  for (final set in rules.sets)
                    if (set.completedAt != null) rules.stamping(set),
                ],
                originals: exercise.sets,
                now: end,
              ),
            );
          }(),
      ],
    );
    _cancelRest();
    _pausedAt = null;
    _write(force: true);
    _isDone = true;
    await _writes;
    return _session;
  }

  /// Throws the workout away: nothing waiting is kept, and the device
  /// forgets it.
  Future<void> discard() async {
    _isDone = true;
    _scheduledSave?.cancel();
    _scheduledSave = null;
    await _writes;
    await _store.clear();
  }

  // MARK: - Undo

  /// Whether there is something to undo, and its name.
  UndoName? get undoName => _undo.undoName;

  /// Whether there is something to redo, and its name.
  UndoName? get redoName => _undo.redoName;

  /// Undoes the last log, un-log, delete or run of reps taps.
  void undo() => _undo.undo();

  /// Redoes what [undo] undid.
  void redo() => _undo.redo();

  /// Forgets every undo, as when the screen goes.
  void clearUndo() => _undo.clear();

  void _register(UndoName name, void Function() action) =>
      _undo.register(name, action);

  void _recordCompletionUndo(String exerciseId, m.WorkoutSetModel updated) {
    final exercise = _exercise(exerciseId);
    final current = exercise?.sets.where((s) => s.id == updated.id).firstOrNull;
    if (exercise == null || current == null) return;
    final expected = updated.completedAt;
    final restored = current.completedAt;
    if ((expected == null) == (restored == null)) return;
    final label = r.ActiveWorkout.setNumberLabel(
      rulesSet(updated),
      rulesExercise(exercise),
    );
    _register(
      UndoName(
        expected == null ? UndoKind.unlogSet : UndoKind.logSet,
        setLabel: label,
      ),
      () {
        final set = _exercise(exerciseId)?.sets
            .where((s) => s.id == updated.id)
            .firstOrNull;
        if (set == null || set.completedAt != expected) return;
        if (restored == null) {
          unlog(set.id);
        } else {
          updateSet(exerciseId, set.copyWith(completedAt: restored));
        }
      },
    );
  }

  void _registerRepsUndo(m.WorkoutSetModel original, String exerciseId) {
    if (_undo.coalescingRepsSetId == original.id &&
        _undo.undoName?.kind == UndoKind.changeReps) {
      return;
    }
    _register(const UndoName(UndoKind.changeReps), () {
      final set = _loggedSet(original.id);
      if (set == null || set.completedAt != original.completedAt) return;
      final restored = set.copyWith(reps: original.reps);
      updateSet(exerciseId, restored);
      _applyLiveProgression(restored, exerciseId);
    });
    _undo.coalescingRepsSetId = original.id;
  }

  // MARK: - Session writes

  List<r.WorkoutExercise> get _rulesExercises =>
      _session.exercises.map(rulesExercise).toList();

  m.WorkoutExerciseModel? _exercise(String? id) =>
      _session.exercises.where((e) => e.id == id).firstOrNull;

  m.WorkoutExerciseModel? _exerciseHolding(String setId) => _session.exercises
      .where((e) => e.sets.any((s) => s.id == setId))
      .firstOrNull;

  m.WorkoutSetModel? _loggedSet(String setId) =>
      _exerciseHolding(setId)?.sets
          .where((s) => s.id == setId && s.completedAt != null)
          .firstOrNull;

  m.ExerciseModel? _library(m.WorkoutExerciseModel exercise) => _environment
      .library
      .where((e) => e.id == exercise.templateId)
      .firstOrNull;

  static m.WorkoutExerciseModel? _firstIncomplete(
    List<m.WorkoutExerciseModel> exercises,
  ) => exercises
      .where(
        (e) => e.sets.isNotEmpty && e.sets.any((s) => s.completedAt == null),
      )
      .firstOrNull;

  void _dropOpenWarmUps() {
    var changed = false;
    final exercises = [
      for (final exercise in _session.exercises)
        if (exercise.sets.any((s) => s.isWarmup && s.completedAt == null))
          () {
            changed = true;
            final kept = exercise.sets.where(
              (s) => !s.isWarmup || s.completedAt != null,
            );
            return exercise.copyWith(
              sets: [
                for (final (index, set) in kept.indexed)
                  set.copyWith(index: index + 1),
              ],
            );
          }()
        else
          exercise,
    ];
    if (changed) _setExercises(exercises);
  }

  void _replaceRulesSets(
    m.WorkoutExerciseModel exercise,
    List<r.WorkoutSet> sets,
  ) => _replaceExercise(
    exercise.copyWith(
      sets: modelSets(sets, originals: exercise.sets, now: _clock()),
    ),
  );

  void _replaceExercise(m.WorkoutExerciseModel updated, {bool flush = false}) =>
      _setExercises([
        for (final e in _session.exercises)
          if (e.id == updated.id) updated else e,
      ], flush: flush);

  void _setExercises(
    List<m.WorkoutExerciseModel> exercises, {
    bool flush = false,
  }) => _setSession(
    _session.copyWith(exercises: exercises, dateModified: _clock()),
    flush: flush,
  );

  /// Every change to the session comes here: a rest that followed a set now
  /// undone or gone is called off, and the change is kept.
  void _setSession(m.WorkoutSessionModel next, {bool flush = false}) {
    final before = _session;
    _session = next;
    final hadRest = _restEnd != null || _restStartedAt != null;
    final rested = r.ActiveWorkout.latestCompletedSet(
      before.exercises.map(rulesExercise).toList(),
    );
    if (hadRest && rested != null) {
      final now = _exerciseHolding(rested.id)?.sets
          .firstWhere((s) => s.id == rested.id);
      if (now == null || now.completedAt == null) _cancelRest();
    }
    _lastSeen = _clock();
    _scheduleSave();
    if (flush) this.flush();
  }

  void _moveFocus({required String afterLogging}) {
    final exercise = _exerciseHolding(afterLogging);
    if (exercise == null) return;
    final set = exercise.sets.firstWhere((s) => s.id == afterLogging);
    final target = r.ActiveWorkout.focusAfterLogging(
      afterLogging,
      _rulesExercises,
      settings: _rules,
      restFollows:
          _settings.useRestTimers && _restAfterLogging(set, exercise) != null,
    );
    if (target != null) _card = target;
  }

  // MARK: - Keeping it on the device

  void _scheduleSave() {
    if (_isDone) return;
    _scheduledSave?.cancel();
    _scheduledSave = Timer(saveDebounce, _write);
  }

  /// Commits the edit being typed and keeps the session now, when waiting
  /// could lose it: the app leaving the foreground, minimising.
  void flush() {
    if (_isDone) return;
    _commitPendingEdit();
    _write();
  }

  /// Keeps the state now, when anything is waiting (or [force]).
  void _write({bool force = false}) {
    final scheduled = _scheduledSave;
    if (scheduled == null && !force) return;
    scheduled?.cancel();
    _scheduledSave = null;
    final state = this.state;
    _writes = _writes.then(
      (_) => _store.save(state).catchError(_onSaveError ?? _logSaveError),
    );
  }

  static void _logSaveError(Object error, StackTrace stackTrace) =>
      developer.log(
        'Could not keep the active session',
        name: 'training_session',
        error: error,
        stackTrace: stackTrace,
      );
}
