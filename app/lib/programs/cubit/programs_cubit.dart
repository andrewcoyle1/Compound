import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'programs_state.dart';

/// The signed-in user's programs, for the whole app (Swift's
/// `MesocycleManager`, `MacrocycleManager` and the presenters' actions on
/// them): what the Training tab, the libraries, Today's workout card and
/// the macrocycle screens read, and every change they make, reported with
/// the Swift screens' event names. Each action ends by bumping
/// `actionId`, with `actionSucceeded` saying whether it worked, so the
/// screen can say so.
class ProgramsCubit extends Cubit<ProgramsState> {
  new({
    required this._programs,
    required this._users,
    required this._sessions,
    required this._service,
    required this._setup,
    required this._analytics,
  }) : super(const ProgramsState());

  final ProgramRepository _programs;
  final UserRepository _users;
  final WorkoutSessionRepository _sessions;
  final ProgramService _service;
  final TrainingSetupService _setup;
  final AnalyticsRepository _analytics;

  String? _uid;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Follows [uid]'s programs, sessions and profile; nothing when signed
  /// out.
  void userChanged(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    emit(const ProgramsState());
    if (uid == null) return;
    List<Mesocycle>? mesocycles;
    List<Macrocycle>? macrocycles;
    List<WorkoutSessionModel>? sessions;
    var userLoaded = false;
    var activeId = state.activeMesocycleId;

    void update() {
      if (isClosed || _uid != uid) return;
      if (mesocycles == null ||
          macrocycles == null ||
          sessions == null ||
          !userLoaded) {
        return;
      }
      emit(
        state.copyWith(
          status: ProgramsStatus.loaded,
          mesocycles: mesocycles,
          macrocycles: macrocycles,
          sessions: sessions,
          activeMesocycleId: () => activeId,
        ),
      );
    }

    void fail(Object _, StackTrace _) {
      if (isClosed || _uid != uid) return;
      emit(state.copyWith(status: ProgramsStatus.failure));
    }

    _subscriptions.addAll([
      _programs.watchMesocycles(uid).listen((data) {
        mesocycles = data;
        update();
      }, onError: fail),
      _programs.watchMacrocycles(uid).listen((data) {
        macrocycles = data;
        update();
      }, onError: fail),
      _sessions.watchSessions(uid).listen((data) {
        sessions = data;
        update();
      }, onError: fail),
      _users.watchUser(uid).listen((user) {
        userLoaded = true;
        activeId = user?.submittedActiveMesocycleId;
        update();
      }, onError: fail),
    ]);
  }

  /// Runs [write] for the signed-in user between `<prefix>_Start` and
  /// `_Success` or a severe `_Fail`, then records whether it worked.
  Future<void> _run(
    String prefix,
    Future<void> Function(String uid) write, {
    Map<String, Object?>? parameters,
    bool tracksStart = true,
  }) async {
    final uid = _uid;
    var ok = false;
    if (uid != null) {
      if (tracksStart) _analytics.analytic('${prefix}_Start', parameters);
      try {
        await write(uid);
        _analytics.analytic('${prefix}_Success', parameters);
        ok = true;
      } on Object catch (error) {
        _analytics.severe('${prefix}_Fail', error, parameters);
      }
    }
    if (isClosed) return;
    emit(state.copyWith(actionId: state.actionId + 1, actionSucceeded: ok));
  }

  /// Records a press, by its Swift event name.
  void pressed(String eventName, [Map<String, Object?>? parameters]) =>
      _analytics.analytic(eventName, parameters);

  /// `<screen>_Appear`, as a screen view.
  void appeared(String screen, [Map<String, Object?>? parameters]) =>
      _analytics.appear(screen, parameters);

  /// `<screen>_Disappear`.
  void disappeared(String screen, [Map<String, Object?>? parameters]) =>
      _analytics.disappear(screen, parameters);

  /// Skips [slot] of the active mesocycle (`skipScheduledWorkout`).
  /// [eventPrefix] names the screen: `ActiveTrainingProgramView` or
  /// `TodaysWorkoutCard`.
  Future<void> skip(ScheduleSlot slot, {required String eventPrefix}) =>
      _run('${eventPrefix}_Skip', (uid) => _service.skip(uid, slot));

  /// Ticks the rest day [slot] of [mesocycleId] as taken now, or unticks it.
  Future<void> toggleRestDay(ScheduleSlot slot, String mesocycleId) => _run(
    'ActiveTrainingProgramView_ToggleRest',
    (uid) => _service.toggleRestDay(uid, slot, mesocycleId: mesocycleId),
    parameters: {'ticking': slot.completedSessionId == null},
  );

  /// Deletes [mesocycle]. [eventPrefix] names the screen:
  /// `ActiveTrainingProgramView` or `TrainingProgramLibraryView`.
  Future<void> deleteMesocycle(
    Mesocycle mesocycle, {
    required String eventPrefix,
  }) => _run(
    '${eventPrefix}_DeleteProgram',
    (uid) => _service.deleteMesocycle(uid, mesocycle.id),
  );

  /// Starts the user's own copy of the shipped [mesocycle].
  Future<void> startPrebuilt(Mesocycle mesocycle) => _run(
    'PrebuiltProgramDetailView_Start',
    (uid) => _setup.startPrebuiltMesocycle(uid, mesocycle),
    parameters: {'program_id': mesocycle.id},
  );

  /// Follows [macrocycle] from the given mesocycle and microcycle, from 0.
  Future<void> startMacrocycle(
    Macrocycle macrocycle, {
    required int mesocycleIndex,
    required int microcycleIndex,
  }) {
    _analytics.analytic('MacrocycleDetailView_Start', {
      'start_mesocycle_index': mesocycleIndex,
      'start_microcycle_index': microcycleIndex,
    });
    return _run(
      'MacrocycleDetailView_Start',
      (uid) => _service.startMacrocycle(
        uid,
        macrocycle,
        mesocycleIndex: mesocycleIndex,
        microcycleIndex: microcycleIndex,
      ),
      tracksStart: false,
    );
  }

  /// Saves edits to [macrocycle].
  Future<void> saveMacrocycle(Macrocycle macrocycle) => _run(
    'MacrocycleDetailView_Save',
    (uid) => _service.saveMacrocycle(uid, macrocycle),
  );

  /// Deletes [macrocycle]; its mesocycles are kept.
  Future<void> deleteMacrocycle(Macrocycle macrocycle) => _run(
    'MacrocycleDetailView_Delete',
    (uid) => _service.deleteMacrocycle(uid, macrocycle.id),
  );

  /// Runs the finished macrocycle again from its first mesocycle.
  Future<void> repeatMacrocycle() {
    _analytics.analytic('TodayView_RepeatPlan_Press');
    return _run(
      'TodayView_RepeatPlan',
      _service.repeatCurrent,
      tracksStart: false,
    );
  }

  @override
  Future<void> close() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    return super.close();
  }
}
