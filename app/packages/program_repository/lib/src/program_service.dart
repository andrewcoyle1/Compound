import 'package:compound_models/compound_models.dart';
import 'package:program_repository/src/macrocycle_rules.dart';
import 'package:program_repository/src/mesocycle_schedule.dart';
import 'package:program_repository/src/program_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// Called with a Swift `MacrocycleMan_*` event name and its parameters.
typedef ProgramEventReporter = void Function(
  String name,
  Map<String, Object> parameters,
);

/// Runs the user's program across the repositories, in the order the Swift
/// app writes (`MacrocycleManager` and its `CoreInteractor` extension):
/// starting, editing and deleting macrocycles, skipping a day, ticking a
/// rest day, moving on when a mesocycle is done and repeating a finished
/// macrocycle. Each method reads what it needs (Firestore answers from its
/// cache) and writes through the repositories, which complete once the
/// write is on the device.
class ProgramService {
  /// Creates a [ProgramService]. `now` and `newId` are the clock and the
  /// id maker; [onEvent] receives the macrocycle events Swift's manager
  /// tracks.
  new({
    required this._programs,
    required this._users,
    required this._sessions,
    this._now = DateTime.now,
    this._newId = newDocumentId,
    ProgramEventReporter? onEvent,
  }) : _onEvent = onEvent ?? _ignore;

  final ProgramRepository _programs;
  final UserRepository _users;
  final WorkoutSessionRepository _sessions;
  final DateTime Function() _now;
  final String Function() _newId;
  final ProgramEventReporter _onEvent;

  static void _ignore(String _, Map<String, Object> _) {}

  Future<List<Macrocycle>> _macrocycles(String uid) =>
      _programs.watchMacrocycles(uid).first;

  /// The mesocycle the profile follows, if it is one of [uid]'s.
  Future<Mesocycle?> _activeMesocycle(String uid) async {
    final id = (await _users.watchUser(uid).first)?.submittedActiveMesocycleId;
    return (await _programs.watchMesocycles(uid).first)
        .where((mesocycle) => mesocycle.id == id)
        .firstOrNull;
  }

  Future<void> _follow(String uid, String mesocycleId) =>
      _users.updateUserFields(uid, [
        UserField.submittedActiveMesocycleId(mesocycleId),
      ]);

  /// Follows [macrocycle] from [mesocycleIndex] and [microcycleIndex] (both
  /// from 0), ends whichever was followed, and points the profile at its
  /// mesocycle (`CoreInteractor.startMacrocycle`). Returns it started,
  /// from [at] (now when left out).
  Future<Macrocycle> startMacrocycle(
    String uid,
    Macrocycle macrocycle, {
    int mesocycleIndex = 0,
    int microcycleIndex = 0,
    DateTime? at,
  }) async {
    final now = at ?? _now();
    for (final other in await _macrocycles(uid)) {
      if (other.id == macrocycle.id || !isRunning(other)) continue;
      await _programs.saveMacrocycle(
        other.copyWith(
          dateModified: now,
          startMicrocycleIndex: other.startMicrocycleIndex,
          status: MacrocycleStatus.ended,
        ),
      );
    }
    final started = macrocycle.started(
      now,
      mesocycleIndex: mesocycleIndex,
      microcycleIndex: microcycleIndex,
    );
    await _programs.saveMacrocycle(started);
    _onEvent('MacrocycleMan_Start', started.eventParameters);
    if (started.currentMesocycleId case final id?) await _follow(uid, id);
    return started;
  }

  /// Saves edits to [edited] ([editedMacrocycle]), and when it is followed
  /// points the profile at the mesocycle it is now on
  /// (`CoreInteractor.saveMacrocycle`).
  Future<void> saveMacrocycle(String uid, Macrocycle edited) async {
    final previous = (await _macrocycles(uid))
        .where((stored) => stored.id == edited.id)
        .firstOrNull;
    final updated = editedMacrocycle(edited, previous: previous, now: _now());
    await _programs.saveMacrocycle(updated);
    final id = updated.currentMesocycleId;
    if (updated.status != MacrocycleStatus.active || id == null) return;
    final user = await _users.watchUser(uid).first;
    if (user?.submittedActiveMesocycleId != id) await _follow(uid, id);
  }

  /// Saves [mesocycle] and follows it as a macrocycle of one
  /// (`MesocycleDesignPresenter.activateMesocycle` and
  /// `CoreInteractor.setActiveMesocycle`). The mesocycle already under way
  /// in the followed macrocycle keeps its progress: only the profile is
  /// pointed at it.
  Future<void> activateMesocycle(String uid, Mesocycle mesocycle) async {
    await _programs.saveMesocycle(mesocycle);
    final current = runningMacrocycle(await _macrocycles(uid));
    if (current != null &&
        current.status == MacrocycleStatus.active &&
        current.currentMesocycleId == mesocycle.id) {
      await _follow(uid, mesocycle.id);
      return;
    }
    final now = _now();
    await startMacrocycle(
      uid,
      at: now,
      Macrocycle(
        id: _newId(),
        authorId: uid,
        name: mesocycle.name,
        mesocycleIds: [mesocycle.id],
        status: MacrocycleStatus.notStarted,
        mesocycleStartedAt: now,
        dateCreated: now,
        dateModified: now,
      ),
    );
  }

  /// Run once per sign-in (`migrateActiveMesocycleToMacrocycleIfNeeded`):
  /// an account from before macrocycles gets one of its active mesocycle,
  /// starting where the old schedule had it, then a mesocycle finished
  /// elsewhere moves on. Failures are ignored, as Swift's `try?` does.
  Future<void> migrateIfNeeded(String uid) async {
    try {
      await _currentCreatingIfNeeded(uid);
    } on Object catch (_) {}
    try {
      await advanceIfMesocycleComplete(uid);
    } on Object catch (_) {}
  }

  /// Deletes the macrocycle [id]; its mesocycles are kept.
  Future<void> deleteMacrocycle(String uid, String id) =>
      _programs.deleteMacrocycle(uid, id);

  /// Deletes the mesocycle [id].
  Future<void> deleteMesocycle(String uid, String id) =>
      _programs.deleteMesocycle(uid, id);

  /// Skips [slot] in the current mesocycle, then moves on if that was the
  /// last open workout (`CoreInteractor.skipScheduledWorkout`). An account
  /// from before macrocycles first gets one of its active mesocycle,
  /// starting where the old schedule had it.
  Future<void> skip(String uid, ScheduleSlot slot) async {
    final macrocycle = await _currentCreatingIfNeeded(uid);
    final updated = macrocycle.skipping(slot, _now());
    await _programs.saveMacrocycle(updated);
    _onEvent('MacrocycleMan_Skip', updated.eventParameters);
    await advanceIfMesocycleComplete(uid);
  }

  Future<Macrocycle> _currentCreatingIfNeeded(String uid) async {
    final current = runningMacrocycle(await _macrocycles(uid));
    if (current != null) return current;
    final mesocycle = await _activeMesocycle(uid);
    if (mesocycle == null) throw StateError('No active mesocycle');
    final sessions = await _sessions.watchSessions(uid).first;
    final startedAt = MesocycleSchedule.legacyRun(
      mesocycle,
      sessions,
    ).startedAt;
    return await startMacrocycle(
      uid,
      at: startedAt,
      Macrocycle(
        id: _newId(),
        authorId: uid,
        name: mesocycle.name,
        mesocycleIds: [mesocycle.id],
        status: MacrocycleStatus.notStarted,
        mesocycleStartedAt: startedAt,
        dateCreated: startedAt,
        dateModified: startedAt,
      ),
    );
  }

  /// Moves the followed macrocycle on when its mesocycle has nothing left
  /// open, and points the profile at the next mesocycle
  /// (`advanceMacrocycleIfMesocycleComplete`). [sessions] are the user's,
  /// read when left out.
  Future<void> advanceIfMesocycleComplete(
    String uid, {
    List<WorkoutSessionModel>? sessions,
  }) async {
    final macrocycle = runningMacrocycle(await _macrocycles(uid));
    final mesocycle = await _activeMesocycle(uid);
    if (macrocycle == null ||
        mesocycle == null ||
        macrocycle.status != MacrocycleStatus.active) {
      return;
    }
    final all = sessions ?? await _sessions.watchSessions(uid).first;
    final now = _now();
    final progress = MesocycleSchedule.progress(
      MesocycleSchedule.runFor(
        mesocycle,
        macrocycle: macrocycle,
        sessions: all,
      ),
      all,
      now: now,
    );
    if (!progress.isMesocycleComplete) return;
    final advanced = macrocycle.advanced(now);
    await _programs.saveMacrocycle(advanced);
    final completed = advanced.status == MacrocycleStatus.completed;
    _onEvent(
      completed ? 'MacrocycleMan_Complete' : 'MacrocycleMan_AdvanceMesocycle',
      advanced.eventParameters,
    );
    if (!completed) await _follow(uid, advanced.currentMesocycleId!);
  }

  /// Runs the followed macrocycle again from its first mesocycle
  /// (`CoreInteractor.repeatCurrentMacrocycle`).
  Future<void> repeatCurrent(String uid) async {
    final current = runningMacrocycle(await _macrocycles(uid));
    final first = current?.mesocycleIds.firstOrNull;
    if (current == null || first == null) return;
    final repeated = current.started(_now());
    await _programs.saveMacrocycle(repeated);
    _onEvent('MacrocycleMan_Repeat', repeated.eventParameters);
    await _follow(uid, first);
  }

  /// Ticks the rest day [slot] of [mesocycleId] as taken now, or unticks
  /// it (`ActiveMesocyclePresenter.onRestDayPressed`). A rest pre-logged
  /// for a later day is moved to now rather than duplicated.
  Future<void> toggleRestDay(
    String uid,
    ScheduleSlot slot, {
    required String mesocycleId,
  }) async {
    if (slot.completedSessionId case final id?) {
      await _sessions.deleteSession(uid, id);
      return;
    }
    final now = _now();
    final preLogged = (await _sessions.watchSessions(uid).first)
        .where(
          (session) =>
              session.isRestDay &&
              session.deletedAt == null &&
              session.mesocycleId == mesocycleId &&
              session.workoutTemplateId == slot.dayPlan.workoutId &&
              session.dateCreated.isAfter(now),
        )
        .firstOrNull;
    await _sessions.saveSession(
      uid,
      _restSession(
        id: preLogged?.id ?? _newId(),
        uid: uid,
        plan: slot.dayPlan,
        mesocycleId: mesocycleId,
        date: now,
        now: now,
      ),
    );
  }

  WorkoutSessionModel _restSession({
    required String id,
    required String uid,
    required WorkoutTemplateModel plan,
    required String mesocycleId,
    required DateTime date,
    required DateTime now,
  }) => WorkoutSessionModel(
    id: id,
    authorId: uid,
    name: plan.name,
    workoutTemplateId: plan.workoutId,
    mesocycleId: mesocycleId,
    dateCreated: date,
    dateModified: now,
    endedAt: date,
    exercises: const [],
    isRestDay: true,
  );

  /// What finishing [session] does to the program (`finishWorkout`): the
  /// rest days after its day are pre-logged on the days that follow, any
  /// rest logged today is removed (it was trained through), and once
  /// [saved], the macrocycle moves on if the mesocycle is done.
  Future<void> workoutFinished(
    String uid,
    WorkoutSessionModel session, {
    required bool saved,
  }) async {
    final mesocycle = await _activeMesocycle(uid);
    final sessions = await _sessions.watchSessions(uid).first;
    final templateId = session.workoutTemplateId;
    if (mesocycle != null &&
        mesocycle.id == session.mesocycleId &&
        templateId != null) {
      await _preCompleteRestDays(uid, session, templateId, mesocycle, sessions);
    }
    if (!saved) return;
    await advanceIfMesocycleComplete(
      uid,
      sessions: [
        for (final other in sessions)
          if (other.id != session.id) other,
        session,
      ],
    );
  }

  Future<void> _preCompleteRestDays(
    String uid,
    WorkoutSessionModel session,
    String templateId,
    Mesocycle mesocycle,
    List<WorkoutSessionModel> sessions,
  ) async {
    final now = _now();
    final local = now.toLocal();
    for (final rest in sessions) {
      if (rest.isRestDay &&
          rest.mesocycleId == mesocycle.id &&
          sameLocalDay(rest.dateCreated, now)) {
        await _sessions.deleteSession(uid, rest.id);
      }
    }
    final plans = mesocycle.workoutTemplates;
    final index = plans.indexWhere((plan) => plan.workoutId == templateId);
    if (index < 0) return;
    for (
      var next = index + 1, offset = 1;
      next < plans.length && plans[next].exercises.isEmpty;
      next++, offset++
    ) {
      final plan = plans[next];
      final date = DateTime(local.year, local.month, local.day + offset);
      final exists = sessions.any(
        (other) =>
            other.isRestDay &&
            other.workoutTemplateId == plan.workoutId &&
            sameLocalDay(other.dateCreated, date),
      );
      if (exists) continue;
      await _sessions.saveSession(
        uid,
        _restSession(
          id: _newId(),
          uid: session.authorId,
          plan: plan,
          mesocycleId: mesocycle.id,
          date: date,
          now: now,
        ),
      );
    }
  }
}
