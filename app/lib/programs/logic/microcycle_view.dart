import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';

/// Where a microcycle sits against the one the user is on.
enum MicrocycleTiming { past, current, future }

/// One day of the microcycle on screen (Swift `MicrocycleItem`).
final class const MicrocycleItem({
  required final ScheduleSlot slot,
  required final MicrocycleTiming timing,

  /// The day the schedule puts on today, as Today's card gives it.
  final bool isToday = false,
}) extends Equatable {
  bool get isRest => slot.isRest;

  bool get isCompleted => slot.completedSessionId != null;

  bool get isSkipped => slot.status == SlotStatus.skipped;

  bool get isBeforeStart => slot.status == SlotStatus.beforeStart;

  /// A rest day in the microcycle under way is ticked by tapping it, and
  /// unticked the same way; one trained through stays skipped.
  bool get canToggleRest =>
      isRest &&
      timing == MicrocycleTiming.current &&
      !isSkipped &&
      !isBeforeStart;

  /// Only an open workout in the microcycle under way can be skipped.
  bool get canSkip =>
      timing == MicrocycleTiming.current &&
      !isCompleted &&
      !isSkipped &&
      !isRest;

  @override
  List<Object?> get props => [slot.id, slot.status, timing, isToday];
}

/// The microcycle on screen of a mesocycle's block
/// (`ActiveMesocyclePresenter.microcycleItems`): its days, which
/// microcycle it is and whether it is the deload or a periodised phase.
final class const MicrocycleView({
  required final List<MicrocycleItem> items,
  required final int cycleCount,

  /// The microcycle the user is on, from 0.
  required final int currentCycleIndex,

  /// The microcycle shown, from 0. A day opened from it starts on its
  /// week's targets.
  required final int displayedCycleIndex,
  required final bool isDeload,
  final PeriodisationPhase? phase,
}) extends Equatable {
  /// [run]'s microcycle [viewedCycleIndex] (from 0), or the one the user
  /// is on when null.
  factory build(
    MesocycleRun run,
    List<WorkoutSessionModel> sessions, {
    required DateTime now,
    int? viewedCycleIndex,
  }) {
    final mesocycle = run.mesocycle;
    final progress = MesocycleSchedule.progress(run, sessions, now: now);
    final current = progress.currentCycleIndex;
    final last = progress.cycles.length - 1;
    final shown = (viewedCycleIndex ?? current).clamp(0, last);
    final today = MesocycleSchedule.todayItem(run, sessions, now: now);
    final nextId = progress.next?.id;
    return MicrocycleView(
      cycleCount: progress.cycles.length,
      currentCycleIndex: current,
      displayedCycleIndex: shown,
      isDeload: MesocycleSchedule.isDeload(shown + 1, mesocycle),
      phase: MesocycleSchedule.phase(shown + 1, mesocycle),
      items: [
        for (final slot in progress.cycles[shown])
          MicrocycleItem(
            slot: slot,
            timing: shown < current
                ? MicrocycleTiming.past
                : shown == current
                ? MicrocycleTiming.current
                : MicrocycleTiming.future,
            isToday:
                today?.completedSessionId != null &&
                    slot.completedSessionId != null
                ? slot.completedSessionId == today!.completedSessionId
                : today?.completedSessionId == null && slot.id == nextId,
          ),
      ],
    );
  }

  @override
  List<Object?> get props => [
    items,
    cycleCount,
    currentCycleIndex,
    displayedCycleIndex,
    isDeload,
    phase,
  ];
}
