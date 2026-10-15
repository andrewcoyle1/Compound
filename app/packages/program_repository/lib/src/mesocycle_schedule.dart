import 'package:compound_models/compound_models.dart';

/// Where a mesocycle's microcycle runs in the periodised block: the first
/// third builds size, the second strength, the last power.
enum PeriodisationPhase {
  /// The first third.
  hypertrophy,

  /// The second third.
  strength,

  /// The last third.
  power,
}

/// Whether [a] and [b] fall on the same local calendar day.
bool sameLocalDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// The block being followed (`MesocycleSchedule.Run`): its mesocycle, when
/// it started, the slots skipped, and the microcycle (from 0) the user
/// joined at; nothing is scheduled before it.
class const MesocycleRun({
  required final Mesocycle mesocycle,
  required final DateTime startedAt,
  final List<CycleSkip> skips = const [],
  final int firstMicrocycleIndex = 0,
}) {
  /// Creates a [MesocycleRun].
  this;
}

/// What became of a slot (`MesocycleSchedule.SlotState`).
enum SlotStatus {
  /// Still to do.
  open,

  /// Done by a session.
  done,

  /// Skipped, or a rest day trained through.
  skipped,

  /// In a microcycle before the one the user joined at.
  beforeStart,
}

/// One day of one microcycle (`MesocycleSchedule.Slot`).
class const ScheduleSlot({
  /// The microcycle, from 0.
  required final int cycleIndex,

  /// The day's place in the mesocycle's list, from 0; a mesocycle may list
  /// the same plan twice.
  required final int position,
  required final WorkoutTemplateModel dayPlan,
  final SlotStatus status = SlotStatus.open,

  /// The session that did it, when [status] is done.
  final String? completedSessionId,

  /// When it was done.
  final DateTime? completedAt,
}) {
  /// Creates a [ScheduleSlot].
  this;

  /// `"<cycle>-<position>-<plan id>"`, as Swift names it.
  String get id => '$cycleIndex-$position-${dayPlan.workoutId}';

  /// A day plan with no exercises is a rest day.
  bool get isRest => dayPlan.exercises.isEmpty;

  /// A workout still to do.
  bool get isOpenWorkout => !isRest && status == SlotStatus.open;

  ScheduleSlot _with(
    SlotStatus status, {
    String? sessionId,
    DateTime? completedAt,
  }) => ScheduleSlot(
    cycleIndex: cycleIndex,
    position: position,
    dayPlan: dayPlan,
    status: status,
    completedSessionId: sessionId,
    completedAt: completedAt,
  );
}

/// Every microcycle's slots (`MesocycleSchedule.Progress`).
class const ScheduleProgress(
  /// One list per microcycle, in order.
  final List<List<ScheduleSlot>> cycles,
) {
  /// Creates a [ScheduleProgress].
  this;

  /// The lowest microcycle with a workout still open; the last one once
  /// the block is done.
  int get currentCycleIndex {
    final index = cycles.indexWhere(
      (slots) => slots.any((slot) => slot.isOpenWorkout),
    );
    return index >= 0 ? index : (cycles.length - 1).clamp(0, cycles.length);
  }

  /// The next workout to do.
  ScheduleSlot? get next {
    for (final slots in cycles) {
      for (final slot in slots) {
        if (slot.isOpenWorkout) return slot;
      }
    }
    return null;
  }

  /// Whether every workout is done or skipped.
  bool get isMesocycleComplete => next == null;
}

/// Today's entry for the Today card and the schedule
/// (`MicrocycleWorkoutTemplateModelItem`).
class const ScheduledDay({
  required final WorkoutTemplateModel dayPlan,

  /// The session that did it, rest days included.
  final String? completedSessionId,

  /// Its microcycle, from 1; null when a rest is not placed yet.
  final int? cycleIndex,
}) {
  /// Creates a [ScheduledDay].
  this;

  /// Whether it is done.
  bool get isCompleted => completedSessionId != null;
}

/// Where the user is in a block (`MesocycleSchedule.swift`): a queue, not a
/// calendar. Today's workout is the next one not yet done since the block
/// started, so a missed day pushes everything back; each finished session
/// fills its own plan's slot in the lowest microcycle where it is still
/// open; a rest day is done once a rest session for it arrives, and
/// skipped once a workout after it is done without it.
abstract final class MesocycleSchedule {
  /// The epoch: the start of a block followed from before plans
  /// ([legacyRun]).
  static final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// Whether the microcycle numbered [cycleIndex] (from 1) is
  /// [mesocycle]'s deload.
  static bool isDeload(int cycleIndex, Mesocycle mesocycle) =>
      switch (mesocycle.deload) {
        DeloadType.none => false,
        DeloadType.start => cycleIndex == 1,
        DeloadType.end => cycleIndex == mesocycle.numMicrocycles,
      };

  /// The phase of the microcycle numbered [cycleIndex] (from 1), or null
  /// without periodisation (`ActiveMesocyclePresenter
  /// .currentPeriodisationPhase`). Each third is at least one microcycle.
  static PeriodisationPhase? phase(int cycleIndex, Mesocycle mesocycle) {
    if (!mesocycle.periodisation) return null;
    final count = mesocycle.numMicrocycles < 1 ? 1 : mesocycle.numMicrocycles;
    final third = count ~/ 3 < 1 ? 1 : count ~/ 3;
    if (cycleIndex <= third) return PeriodisationPhase.hypertrophy;
    if (cycleIndex <= third * 2) return PeriodisationPhase.strength;
    return PeriodisationPhase.power;
  }

  /// The block to schedule [mesocycle] from: [macrocycle]'s current one
  /// when it is this mesocycle, else as an account from before plans
  /// follows it (`MacrocycleManager.run(for:)`).
  static MesocycleRun runFor(
    Mesocycle mesocycle, {
    required Macrocycle? macrocycle,
    required List<WorkoutSessionModel> sessions,
  }) {
    if (macrocycle != null && _currentMesocycleId(macrocycle) == mesocycle.id) {
      return MesocycleRun(
        mesocycle: mesocycle,
        startedAt: macrocycle.mesocycleStartedAt,
        skips: [
          for (final skip in macrocycle.skips)
            if (skip.mesocycleIndex == macrocycle.mesocycleIndex) skip,
        ],
        firstMicrocycleIndex: macrocycle.startMicrocycleIndex ?? 0,
      );
    }
    return legacyRun(mesocycle, sessions);
  }

  static String? _currentMesocycleId(Macrocycle macrocycle) =>
      macrocycle.mesocycleIndex >= 0 &&
          macrocycle.mesocycleIndex < macrocycle.mesocycleIds.length
      ? macrocycle.mesocycleIds[macrocycle.mesocycleIndex]
      : null;

  /// Where an account from before plans was: just after the last full pass
  /// through the block, counting every session it ever had.
  static MesocycleRun legacyRun(
    Mesocycle mesocycle,
    List<WorkoutSessionModel> sessions,
  ) {
    var startedAt = epoch;
    while (true) {
      final progress = MesocycleSchedule.progress(
        MesocycleRun(mesocycle: mesocycle, startedAt: startedAt),
        sessions,
        now: startedAt,
      );
      if (!progress.isMesocycleComplete) break;
      DateTime? finishedAt;
      for (final slots in progress.cycles) {
        for (final slot in slots) {
          final at = slot.completedAt;
          if (slot.isRest || at == null) continue;
          if (finishedAt == null || at.isAfter(finishedAt)) finishedAt = at;
        }
      }
      if (finishedAt == null) break;
      startedAt = finishedAt.add(const Duration(milliseconds: 1));
    }
    return MesocycleRun(mesocycle: mesocycle, startedAt: startedAt);
  }

  /// Every microcycle's slots for [run], from [sessions], as of [now].
  static ScheduleProgress progress(
    MesocycleRun run,
    List<WorkoutSessionModel> sessions, {
    required DateTime now,
  }) {
    final plans = run.mesocycle.workoutTemplates;
    final count = run.mesocycle.numMicrocycles < 1
        ? 1
        : run.mesocycle.numMicrocycles;
    final cycles = [
      for (var cycle = 0; cycle < count; cycle++)
        [
          for (final (position, plan) in plans.indexed)
            ScheduleSlot(
              cycleIndex: cycle,
              position: position,
              dayPlan: plan,
              status:
                  cycle < run.firstMicrocycleIndex && plan.exercises.isNotEmpty
                  ? SlotStatus.beforeStart
                  : SlotStatus.open,
            ),
        ],
    ];

    for (final skip in run.skips) {
      if (skip.cycleIndex < 0 || skip.cycleIndex >= cycles.length) continue;
      final slots = cycles[skip.cycleIndex];
      if (skip.position < 0 ||
          skip.position >= slots.length ||
          slots[skip.position].dayPlan.workoutId != skip.templateId) {
        continue;
      }
      slots[skip.position] = slots[skip.position]._with(SlotStatus.skipped);
    }

    for (final (session, endedAt) in _counted(sessions, run)) {
      final found = _firstOpenSlot(session, cycles);
      if (found == null) continue;
      final (cycle, position) = found;
      cycles[cycle][position] = cycles[cycle][position]._with(
        SlotStatus.done,
        sessionId: session.id,
        completedAt: endedAt,
      );
    }
    _fillRestDays(cycles, run, sessions, now);
    return ScheduleProgress(cycles);
  }

  /// Each rest session fills the first open rest day with its plan after
  /// the workout done before it; then an open rest day with a workout done
  /// after it was trained through.
  static void _fillRestDays(
    List<List<ScheduleSlot>> cycles,
    MesocycleRun run,
    List<WorkoutSessionModel> sessions,
    DateTime now,
  ) {
    final slots = [for (final cycle in cycles) ...cycle];
    final rests = _stableSorted([
      for (final session in sessions)
        if (session.isRestDay &&
            session.deletedAt == null &&
            session.mesocycleId == run.mesocycle.id &&
            !session.dateCreated.isBefore(run.startedAt) &&
            !session.dateCreated.isAfter(now))
          session,
    ], (session) => session.dateCreated);

    for (final rest in rests) {
      int? anchor;
      for (final (index, slot) in slots.indexed) {
        final at = slot.completedAt;
        if (slot.isRest || at == null || !at.isBefore(rest.dateCreated)) {
          continue;
        }
        if (anchor == null || slots[anchor].completedAt!.isBefore(at)) {
          anchor = index;
        }
      }
      for (
        var index = anchor == null ? 0 : anchor + 1;
        index < slots.length;
        index++
      ) {
        final slot = slots[index];
        if (slot.isRest &&
            slot.status == SlotStatus.open &&
            slot.dayPlan.workoutId == rest.workoutTemplateId) {
          slots[index] = slot._with(
            SlotStatus.done,
            sessionId: rest.id,
            completedAt: rest.dateCreated,
          );
          break;
        }
      }
    }

    var workoutDoneLater = false;
    for (var index = slots.length - 1; index >= 0; index--) {
      final slot = slots[index];
      if (!slot.isRest) {
        workoutDoneLater = workoutDoneLater || slot.completedSessionId != null;
      } else if (slot.status == SlotStatus.open &&
          workoutDoneLater &&
          slot.cycleIndex >= run.firstMicrocycleIndex) {
        slots[index] = slot._with(SlotStatus.skipped);
      }
    }

    final width = cycles.first.length;
    for (var cycle = 0; cycle < cycles.length; cycle++) {
      cycles[cycle] = slots.sublist(cycle * width, (cycle + 1) * width);
    }
  }

  /// Today's entry: the workout finished today if there is one, a rest day
  /// the mesocycle pre-completed for today, or else the next workout. Null
  /// without a run, or once the block is finished. [sameDay] compares
  /// calendar days, the device's local ones by default.
  static ScheduledDay? todayItem(
    MesocycleRun? run,
    List<WorkoutSessionModel> sessions, {
    required DateTime now,
    bool Function(DateTime, DateTime) sameDay = sameLocalDay,
  }) {
    if (run == null || run.mesocycle.workoutTemplates.isEmpty) return null;
    final progress = MesocycleSchedule.progress(run, sessions, now: now);

    ScheduleSlot? doneToday;
    for (final slots in progress.cycles) {
      for (final slot in slots) {
        final at = slot.completedAt;
        if (slot.status != SlotStatus.done || at == null || !sameDay(at, now)) {
          continue;
        }
        // A workout over a rest day ticked the same day: what was trained.
        if (doneToday == null ||
            _rank(doneToday) < _rank(slot) ||
            (_rank(doneToday) == _rank(slot) &&
                doneToday.completedAt!.isBefore(at))) {
          doneToday = slot;
        }
      }
    }
    if (doneToday != null) {
      return ScheduledDay(
        dayPlan: doneToday.dayPlan,
        completedSessionId: doneToday.completedSessionId,
        cycleIndex: doneToday.cycleIndex + 1,
      );
    }

    final restToday = sessions
        .where(
          (session) =>
              session.isRestDay &&
              session.deletedAt == null &&
              session.mesocycleId == run.mesocycle.id &&
              sameDay(session.dateCreated, now),
        )
        .firstOrNull;
    final restPlan = run.mesocycle.workoutTemplates
        .where((plan) => plan.workoutId == restToday?.workoutTemplateId)
        .firstOrNull;
    if (restToday != null && restPlan != null) {
      // Pre-logged for later today, so not ticked yet: its microcycle is
      // where it will tick.
      final later = restToday.dateCreated.isAfter(now)
          ? restToday.dateCreated
          : now;
      final ticked = MesocycleSchedule.progress(run, sessions, now: later)
          .cycles
          .expand((slots) => slots)
          .where((slot) => slot.completedSessionId == restToday.id)
          .firstOrNull;
      return ScheduledDay(
        dayPlan: restPlan,
        completedSessionId: restToday.id,
        cycleIndex: ticked == null ? null : ticked.cycleIndex + 1,
      );
    }

    final next = progress.next;
    if (next == null) return null;
    return ScheduledDay(dayPlan: next.dayPlan, cycleIndex: next.cycleIndex + 1);
  }

  static int _rank(ScheduleSlot slot) => slot.isRest ? 0 : 1;

  /// The block's finished workouts since it started, oldest first. A
  /// session from before mesocycles carried ids matches by the day's name.
  static List<(WorkoutSessionModel, DateTime)> _counted(
    List<WorkoutSessionModel> sessions,
    MesocycleRun run,
  ) {
    final names = {
      for (final plan in run.mesocycle.workoutTemplates) plan.name,
    };
    return _stableSorted([
      for (final session in sessions)
        if (session.endedAt case final endedAt?
            when !endedAt.isBefore(run.startedAt) &&
                !session.isRestDay &&
                session.deletedAt == null &&
                (session.mesocycleId == run.mesocycle.id ||
                    (session.mesocycleId == null &&
                        names.contains(session.name))))
          (session, endedAt),
    ], (entry) => entry.$2);
  }

  /// The lowest microcycle where [session]'s own day is still open.
  static (int, int)? _firstOpenSlot(
    WorkoutSessionModel session,
    List<List<ScheduleSlot>> cycles,
  ) {
    for (final (cycle, slots) in cycles.indexed) {
      final match = slots.indexWhere(
        (slot) =>
            slot.isOpenWorkout &&
            (session.workoutTemplateId != null
                ? slot.dayPlan.workoutId == session.workoutTemplateId
                : slot.dayPlan.name == session.name),
      );
      if (match >= 0) return (cycle, match);
    }
    return null;
  }

  /// [items] by [key], equal keys kept in their order.
  static List<T> _stableSorted<T>(List<T> items, DateTime Function(T) key) {
    final indexed = [...items.indexed]
      ..sort((a, b) {
        final byKey = key(a.$2).compareTo(key(b.$2));
        return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
      });
    return [for (final (_, item) in indexed) item];
  }
}
