part of 'programs_cubit.dart';

enum ProgramsStatus { loading, loaded, failure }

/// The signed-in user's mesocycles, macrocycles and sessions, and the
/// mesocycle their profile follows: everything the schedule is worked out
/// from.
final class const ProgramsState({
  final ProgramsStatus status = ProgramsStatus.loading,
  final List<Mesocycle> mesocycles = const [],
  final List<Macrocycle> macrocycles = const [],
  final List<WorkoutSessionModel> sessions = const [],
  final String? activeMesocycleId,

  /// Counts the actions finished; each one emits a new count.
  final int actionId = 0,

  /// Whether the last action worked.
  final bool actionSucceeded = false,
}) extends Equatable {
  /// The mesocycle followed, if it is one of the user's
  /// (`MesocycleManager.activeMesocycle`).
  Mesocycle? get activeMesocycle => mesocycles
      .where((mesocycle) => mesocycle.id == activeMesocycleId)
      .firstOrNull;

  /// The macrocycle followed, or finished and waiting on a repeat.
  Macrocycle? get currentMacrocycle => runningMacrocycle(macrocycles);

  /// The active mesocycle's block (`CoreInteractor.activeMesocycleRun`).
  MesocycleRun? get activeRun => switch (activeMesocycle) {
    final mesocycle? => MesocycleSchedule.runFor(
      mesocycle,
      macrocycle: currentMacrocycle,
      sessions: sessions,
    ),
    null => null,
  };

  /// [mesocycle]'s block: the active one's run when it is the active
  /// mesocycle, else as before plans.
  MesocycleRun runOf(Mesocycle mesocycle) => MesocycleSchedule.runFor(
    mesocycle,
    macrocycle: mesocycle.id == activeMesocycleId ? currentMacrocycle : null,
    sessions: sessions,
  );

  /// The mesocycles the user has saved but does not follow.
  List<Mesocycle> get inactiveMesocycles => [
    for (final mesocycle in mesocycles)
      if (mesocycle.id != activeMesocycleId) mesocycle,
  ];

  ProgramsState copyWith({
    ProgramsStatus? status,
    List<Mesocycle>? mesocycles,
    List<Macrocycle>? macrocycles,
    List<WorkoutSessionModel>? sessions,
    String? Function()? activeMesocycleId,
    int? actionId,
    bool? actionSucceeded,
  }) => ProgramsState(
    status: status ?? this.status,
    mesocycles: mesocycles ?? this.mesocycles,
    macrocycles: macrocycles ?? this.macrocycles,
    sessions: sessions ?? this.sessions,
    activeMesocycleId: activeMesocycleId == null
        ? this.activeMesocycleId
        : activeMesocycleId(),
    actionId: actionId ?? this.actionId,
    actionSucceeded: actionSucceeded ?? this.actionSucceeded,
  );

  @override
  List<Object?> get props => [
    status,
    mesocycles,
    macrocycles,
    sessions,
    activeMesocycleId,
    actionId,
    actionSucceeded,
  ];
}
