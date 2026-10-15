import 'package:compound_models/compound_models.dart';
import 'package:program_repository/src/mesocycle_schedule.dart';

/// Where a macrocycle is and how it moves on (Swift `Macrocycle`'s
/// methods).
extension MacrocycleRules on Macrocycle {
  /// The mesocycle being followed, or null when the index is out of range.
  String? get currentMesocycleId =>
      mesocycleIndex >= 0 && mesocycleIndex < mesocycleIds.length
      ? mesocycleIds[mesocycleIndex]
      : null;

  /// Whether the current mesocycle is the last.
  bool get isLastMesocycle => mesocycleIndex >= mesocycleIds.length - 1;

  /// The analytics parameters Swift sends with every macrocycle event.
  Map<String, Object> get eventParameters => {
    'macrocycle_id': id,
    'macrocycle_mesocycle_count': mesocycleIds.length,
    'macrocycle_mesocycle_index': mesocycleIndex,
    'macrocycle_status': status.value,
    'macrocycle_iteration': iteration,
  };

  /// A copy with the given parts replaced. [startMicrocycleIndex] is set
  /// as given, null included.
  Macrocycle copyWith({
    required DateTime dateModified,
    required int? startMicrocycleIndex,
    String? name,
    List<String>? mesocycleIds,
    MacrocycleStatus? status,
    int? mesocycleIndex,
    DateTime? mesocycleStartedAt,
    List<CycleSkip>? skips,
    int? iteration,
  }) => Macrocycle(
    id: id,
    authorId: authorId,
    name: name ?? this.name,
    mesocycleIds: mesocycleIds ?? this.mesocycleIds,
    status: status ?? this.status,
    mesocycleIndex: mesocycleIndex ?? this.mesocycleIndex,
    mesocycleStartedAt: mesocycleStartedAt ?? this.mesocycleStartedAt,
    startMicrocycleIndex: startMicrocycleIndex,
    skips: skips ?? this.skips,
    iteration: iteration ?? this.iteration,
    dateCreated: dateCreated,
    dateModified: dateModified,
  );

  /// The next mesocycle from its first microcycle, or, after the last,
  /// the macrocycle completed.
  Macrocycle advanced(DateTime now) => isLastMesocycle
      ? copyWith(
          dateModified: now,
          startMicrocycleIndex: startMicrocycleIndex,
          status: MacrocycleStatus.completed,
        )
      : copyWith(
          dateModified: now,
          startMicrocycleIndex: null,
          mesocycleIndex: mesocycleIndex + 1,
          mesocycleStartedAt: now,
        );

  /// Followed from [mesocycleIndex] and [microcycleIndex] (both from 0)
  /// with no history counted; the microcycles before count as done. A
  /// macrocycle started before begins another iteration.
  Macrocycle started(
    DateTime now, {
    int mesocycleIndex = 0,
    int microcycleIndex = 0,
  }) => copyWith(
    dateModified: now,
    startMicrocycleIndex: microcycleIndex > 0 ? microcycleIndex : null,
    iteration: status == MacrocycleStatus.notStarted
        ? iteration
        : iteration + 1,
    status: MacrocycleStatus.active,
    mesocycleIndex: mesocycleIndex.clamp(
      0,
      mesocycleIds.isEmpty ? 0 : mesocycleIds.length - 1,
    ),
    mesocycleStartedAt: now,
    skips: const [],
  );

  /// [slot] skipped in the current mesocycle.
  Macrocycle skipping(ScheduleSlot slot, DateTime now) => copyWith(
    dateModified: now,
    startMicrocycleIndex: startMicrocycleIndex,
    skips: [
      ...skips,
      CycleSkip(
        mesocycleIndex: mesocycleIndex,
        cycleIndex: slot.cycleIndex,
        position: slot.position,
        templateId: slot.dayPlan.workoutId,
        date: now,
      ),
    ],
  );
}

/// [edited], stamped [now], as `CoreInteractor.saveMacrocycle` saves it
/// over [previous] (the stored copy): when it is followed and its
/// mesocycles were reordered, it stays on the mesocycle the user is doing;
/// when that one was removed, it stays at the same place, started afresh.
Macrocycle editedMacrocycle(
  Macrocycle edited, {
  required Macrocycle? previous,
  required DateTime now,
}) {
  final followedId = previous?.currentMesocycleId;
  if (edited.status != MacrocycleStatus.active || followedId == null) {
    return edited.copyWith(
      dateModified: now,
      startMicrocycleIndex: edited.startMicrocycleIndex,
    );
  }
  final index = edited.mesocycleIds.indexOf(followedId);
  if (index >= 0) {
    return edited.copyWith(
      dateModified: now,
      startMicrocycleIndex: edited.startMicrocycleIndex,
      mesocycleIndex: index,
    );
  }
  return edited.copyWith(
    dateModified: now,
    startMicrocycleIndex: null,
    mesocycleIndex: edited.mesocycleIndex.clamp(
      0,
      edited.mesocycleIds.isEmpty ? 0 : edited.mesocycleIds.length - 1,
    ),
    mesocycleStartedAt: now,
  );
}
