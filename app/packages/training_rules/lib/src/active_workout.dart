/// What the active-workout screen works out from the session: the next set,
/// the blocks a workout is worked in, where the card goes, the rest anchor,
/// logging, correcting and propagating a set, set kinds, the strip and a
/// superset's rows (`ActiveWorkout.swift` and `ActiveWorkout+*.swift`).
///
/// The words the screen shows (titles, spoken labels, the plan summary) are
/// the app's: these return the decisions they are worded from.
library;

import 'package:equatable/equatable.dart';
import 'package:training_rules/src/models.dart';
import 'package:training_rules/src/progression.dart';
import 'package:training_rules/src/rest.dart';
import 'package:training_rules/src/weight_rounding.dart';

/// Where a set stands: logged, next to log, or still to come.
enum SetRowState { done, current, upcoming }

/// Where the inline rest timer sits in an exercise's table.
sealed class RestAnchor extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Under the working set the rest follows.
final class RestBelow extends RestAnchor {
  const new(this.setId);

  final String setId;

  @override
  List<Object?> get props => [setId];
}

/// At the top of the table: the rest followed a warm-up or another exercise.
final class RestTop extends RestAnchor {
  const new();
}

/// What the button at the foot of the screen does (`ActiveWorkoutAction`).
sealed class ActiveWorkoutAction extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Log this set.
final class LogSetAction extends ActiveWorkoutAction {
  const new(this.exerciseId, this.setId);

  final String exerciseId;
  final String setId;

  @override
  List<Object?> get props => [exerciseId, setId];
}

/// Open the next exercise with anything left to log.
final class NextExerciseAction extends ActiveWorkoutAction {
  const new(this.exerciseId);

  final String exerciseId;

  @override
  List<Object?> get props => [exerciseId];
}

/// Nothing is left: finish.
final class FinishAction extends ActiveWorkoutAction {
  const new();
}

/// One set the next round offers, by exercise and set id.
typedef BlockSet = ({String exerciseId, String setId});

/// Why today's numbers differ from last time, as the figures the sentence is
/// worded from (`ActiveWorkout.progressionReason`).
class const ProgressionReason({
  required final Rationale rationale,

  /// The change in weight, kg, for `progressWeight` and `deload`.
  final double? changeKg,

  /// The fewest reps of last time's working sets, for `progressWeight`.
  final int? lastMinReps,

  /// The reps added, for `addReps`.
  final int? addedReps,
}) extends Equatable {
  @override
  List<Object?> get props => [rationale, changeKg, lastMinReps, addedReps];
}

/// The result of logging a set (`ActiveWorkout.LogOutcome`).
class const LogOutcome({
  /// The session with the set stamped, or unchanged when refused.
  required final WorkoutSession session,
  final SetProblem? problem,
  final int? restSeconds,

  /// Where the card goes next; `null` stays.
  final String? focusExerciseId,
}) extends Equatable {
  @override
  List<Object?> get props => [session, problem, restSeconds, focusExerciseId];
}

/// What a sub-row is: a drop changes the weight, a mini-set takes a breath.
enum SubSetKind { drop, mini }

/// A line of the set-number menu: a kind, or a warm-up (`SetTypeChoice`).
class const SetTypeChoice._(final SetKind? kind) extends Equatable {
  const new ofKind(SetKind kind) : this._(kind);

  static const warmup = SetTypeChoice._(null);

  bool get isWarmup => kind == null;

  /// As analytics records it.
  String get eventValue => kind?.name ?? 'warmup';

  @override
  List<Object?> get props => [kind];
}

/// The type a set's menu ticks.
SetTypeChoice typeChoiceOf(WorkoutSet set) =>
    set.isWarmup ? SetTypeChoice.warmup : SetTypeChoice.ofKind(set.kind);

/// `null` for a set of its own; a plain sub-row is a mini-set.
SubSetKind? subSetKindOf(WorkoutSet set) {
  if (!set.isSubSet) return null;
  return set.kind == SetKind.drop ? SubSetKind.drop : SubSetKind.mini;
}

/// The piece after a set, and the breath before it (`PieceHint`'s figures).
class const NextPiece({
  required final WorkoutSet piece,

  /// Its place among its parent's pieces of its kind and side, from 1.
  required final int ordinal,

  /// The breath before it; 0 is none. `null` for partials, a stretch or a
  /// hold, which follow the set with no rest.
  final int? restSeconds,
}) extends Equatable {
  @override
  List<Object?> get props => [piece, ordinal, restSeconds];
}

/// One line of a superset card's table (`SupersetBlockRow`).
class const SupersetBlockRow({
  required final String exerciseId,

  /// The set's id, or `null` for a member's logged warm-ups folded together.
  final String? setId,

  /// "B1·1", "B1·2L", "B1W"; `null` for the folded warm-ups.
  final String? badge,

  /// The last row of its round.
  final bool endsRound = false,
}) extends Equatable {
  String get id => setId ?? 'warmups-$exerciseId';

  SupersetBlockRow ending() => SupersetBlockRow(
    exerciseId: exerciseId,
    setId: setId,
    badge: badge,
    endsRound: true,
  );

  @override
  List<Object?> get props => [exerciseId, setId, badge, endsRound];
}

/// One block on the exercise strip (`ActiveWorkout.StripItem`).
class const StripItem({
  required final String id,
  required final List<String> names,
  required final List<String?> imageNames,
  required final String? supersetLetter,
  required final int doneWorkingSets,
  required final int totalWorkingSets,
  required final bool isCurrent,
}) extends Equatable {
  bool get isComplete =>
      totalWorkingSets > 0 && doneWorkingSets >= totalWorkingSets;

  double get fraction =>
      totalWorkingSets == 0 ? 0 : doneWorkingSets / totalWorkingSets;

  @override
  List<Object?> get props => [
    id,
    names,
    imageNames,
    supersetLetter,
    doneWorkingSets,
    totalWorkingSets,
    isCurrent,
  ];
}

/// The edge a card comes in from.
enum Edge { leading, trailing }

/// The unit a distance is entered in (`ExerciseDistanceUnit`).
enum DistanceUnit { meters, miles }

/// What the bottom button does at a moment (`ActiveWorkout.SlotAction`).
sealed class SlotAction extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

final class SlotLog extends SlotAction {
  const new(this.exerciseId, this.setId);

  final String exerciseId;
  final String setId;

  @override
  List<Object?> get props => [exerciseId, setId];
}

final class SlotSkipRest extends SlotAction {
  const new();
}

final class SlotNext extends SlotAction {
  const new(this.exerciseId);

  final String exerciseId;

  @override
  List<Object?> get props => [exerciseId];
}

final class SlotFinish extends SlotAction {
  const new();
}

final class SlotResume extends SlotAction {
  const new();
}

/// What the rest's owner does with a rest found after a cold launch.
sealed class RestRestore extends Equatable {
  const new();

  /// Running, ended while away, or none.
  static RestRestore plan({
    required DateTime? restEnd,
    required DateTime? restStartedAt,
    required DateTime now,
  }) {
    if (restEnd == null) return const RestRestoreNone();
    return restEnd.isAfter(now)
        ? RestRestoreRunning(restEnd, restStartedAt)
        : RestRestoreEnded(restEnd);
  }

  @override
  List<Object?> get props => [];
}

/// Still counting down: re-arm for what is left.
final class RestRestoreRunning extends RestRestore {
  const new(this.end, this.start);

  final DateTime end;
  final DateTime? start;

  @override
  List<Object?> get props => [end, start];
}

/// Ran out while the app was gone: end it once, now.
final class RestRestoreEnded extends RestRestore {
  const new(this.end);

  final DateTime end;

  @override
  List<Object?> get props => [end];
}

/// No rest was running.
final class RestRestoreNone extends RestRestore {
  const new();
}

double _seconds(DateTime from, DateTime to) =>
    to.difference(from).inMicroseconds / Duration.microsecondsPerSecond;

/// A timed hold's stopwatch, the clock passed in (`ActiveWorkout.Stopwatch`).
class Stopwatch {
  new({this.targetSeconds});

  DateTime? _startedAt;

  /// What the set was held for last time, to count down to.
  int? targetSeconds;

  DateTime? get startedAt => _startedAt;

  bool get isRunning => _startedAt != null;

  /// Starts counting from [now]; a second start changes nothing.
  void start(DateTime now) => _startedAt ??= now;

  /// Stops, answering the seconds held to the nearest second; `null` when not
  /// running or under half a second.
  int? stop(DateTime now) {
    final started = _startedAt;
    if (started == null) return null;
    _startedAt = null;
    final seconds = _seconds(started, now).round();
    return seconds > 0 ? seconds : null;
  }

  /// Whole seconds since the start; 0 when stopped.
  int elapsed(DateTime now) {
    final started = _startedAt;
    if (started == null) return 0;
    final seconds = _seconds(started, now).truncate();
    return seconds < 0 ? 0 : seconds;
  }

  /// Seconds left to the target, never below zero.
  int? remaining(DateTime now) {
    final target = targetSeconds;
    if (!isRunning || target == null) return null;
    final left = target - elapsed(now);
    return left < 0 ? 0 : left;
  }

  /// From the start to the target, for a countdown.
  (DateTime, DateTime)? get targetInterval {
    final started = _startedAt;
    final target = targetSeconds;
    if (started == null || target == null || target <= 0) return null;
    return (started, started.add(Duration(seconds: target)));
  }
}

/// The active workout's rules (`enum ActiveWorkout`).
abstract final class ActiveWorkout {
  // MARK: - Rows

  /// The first set not yet logged, warm-ups included.
  static WorkoutSet? currentSet(WorkoutExercise exercise) =>
      exercise.sets.where((s) => s.completedAt == null).firstOrNull;

  static SetRowState rowState(WorkoutSet set, WorkoutExercise exercise) {
    if (set.completedAt != null) return SetRowState.done;
    return currentSet(exercise)?.id == set.id
        ? SetRowState.current
        : SetRowState.upcoming;
  }

  // MARK: - Exercise card

  /// Why today's numbers differ from last time, or `null`: held, no history,
  /// a change rounded to nothing, or the first working set edited since.
  static ProgressionReason? progressionReason({
    required ProgressionSuggestion? suggestion,
    required WorkoutExercise? last,
    WorkoutExercise? planned,
  }) {
    if (suggestion == null || last == null || _isEdited(planned, suggestion)) {
      return null;
    }
    final lastWorking = last.sets
        .where(
          (s) =>
              !s.isWarmup && s.completedAt != null && s.side != SetSide.right,
        )
        .toList();
    final lastFirst = lastWorking.firstOrNull;
    final today = suggestion.sets.where((s) => !s.isEmpty).firstOrNull;
    if (lastFirst == null || today == null) return null;

    switch (suggestion.rationale) {
      case Rationale.progressWeight || Rationale.deload:
        final now = today.weightKg;
        final was = lastFirst.weightKg;
        if (now == null || was == null || (now - was).abs() <= 0.001) {
          return null;
        }
        final reps = lastWorking.map((s) => s.reps).nonNulls;
        return ProgressionReason(
          rationale: suggestion.rationale,
          changeKg: now - was,
          lastMinReps: suggestion.rationale == Rationale.deload || reps.isEmpty
              ? null
              : reps.reduce((a, b) => a < b ? a : b),
        );
      case Rationale.addReps:
        final now = today.reps;
        final was = lastFirst.reps;
        if (now == null || was == null || now <= was) return null;
        return ProgressionReason(
          rationale: Rationale.addReps,
          addedReps: now - was,
        );
      case Rationale.hold || Rationale.noHistory:
        return null;
    }
  }

  static bool _isEdited(
    WorkoutExercise? planned,
    ProgressionSuggestion suggestion,
  ) {
    final first = planned?.sets.where((s) => !s.isWarmup).firstOrNull;
    final suggested = suggestion.sets.firstOrNull;
    if (first == null || suggested == null) return false;
    final weight = suggested.weightKg;
    if (weight != null && ((first.weightKg ?? -1) - weight).abs() > 0.001) {
      return true;
    }
    final reps = suggested.reps;
    return reps != null && first.reps != reps;
  }

  // MARK: - Rest

  /// The set logged most recently anywhere in the workout.
  static WorkoutSet? latestCompletedSet(List<WorkoutExercise> exercises) {
    WorkoutSet? latest;
    for (final set in exercises.expand((e) => e.sets)) {
      final at = set.completedAt;
      if (at == null) continue;
      if (latest == null || at.isAfter(latest.completedAt!)) latest = set;
    }
    return latest;
  }

  /// Where the rest timer goes in [exercise]'s table, or `null` to leave it
  /// out once a set has been logged since the rest began.
  static RestAnchor? restAnchor(
    WorkoutExercise exercise, {
    required WorkoutSet? restedSet,
    required DateTime? restStartedAt,
  }) {
    final loggedAt = restedSet?.completedAt;
    if (restedSet == null || loggedAt == null) return const RestTop();
    if (restStartedAt != null && loggedAt.isAfter(restStartedAt)) return null;
    final isHere = exercise.sets.any((s) => s.id == restedSet.id);
    return isHere && !restedSet.isWarmup
        ? RestBelow(restedSet.id)
        : const RestTop();
  }

  // MARK: - Footer

  /// Log the card's next set; once its block has none, open the next block
  /// with sets left, wrapping round; once nothing is left, finish.
  static ActiveWorkoutAction? primaryAction(
    List<WorkoutExercise> exercises,
    String? currentExerciseId,
  ) {
    final order = blocks(exercises);
    final blockIndex = _blockIndex(currentExerciseId, order);
    if (blockIndex != null) {
      final block = order[blockIndex];
      final next = nextSet(
        block,
        exercises,
        startMember: block.indexOf(currentExerciseId!),
      );
      if (next != null) {
        return next.exerciseId == currentExerciseId
            ? LogSetAction(next.exerciseId, next.setId)
            : NextExerciseAction(next.exerciseId);
      }
    }
    final next = nextBlockExercise(blockIndex, order, exercises);
    if (next != null) return NextExerciseAction(next);
    return exercises.any((e) => e.sets.isNotEmpty)
        ? const FinishAction()
        : null;
  }

  // MARK: - Blocks (`ActiveWorkout+Focus.swift`)

  /// The workout as it is worked: a superset is one block placed where its
  /// first member is. Exercise ids, in workout order.
  static List<List<String>> blocks(List<WorkoutExercise> exercises) {
    final result = <List<String>>[];
    final byGroup = <String, int>{};
    for (final exercise in exercises) {
      final group = exercise.supersetGroupId;
      final index = byGroup[group];
      if (index != null) {
        result[index].add(exercise.id);
        continue;
      }
      if (group != null) byGroup[group] = result.length;
      result.add([exercise.id]);
    }
    return result;
  }

  static int? _blockIndex(String? exerciseId, List<List<String>> blocks) {
    if (exerciseId == null) return null;
    final index = blocks.indexWhere((b) => b.contains(exerciseId));
    return index < 0 ? null : index;
  }

  /// A set's round in a superset: its set number; warm-ups are round 0.
  static int round(WorkoutSet set, WorkoutExercise exercise) =>
      set.isWarmup ? 0 : exercise.workingSetNumber(set);

  /// The set a block is up to, in rounds (A1, B1, A2…): a set under way
  /// finishes its pieces first, then the earliest open round, from
  /// [startMember] on, wrapping.
  static BlockSet? nextSet(
    List<String> block,
    List<WorkoutExercise> exercises, {
    int startMember = 0,
  }) {
    final members = [
      for (final id in block) ?exercises.where((e) => e.id == id).firstOrNull,
    ];
    final open = [
      for (final member in members)
        if (currentSet(member) case final set?)
          (exercise: member, set: set, round: round(set, member)),
    ];
    for (final entry in open) {
      if (entry.set.isSubSet) {
        return (exerciseId: entry.exercise.id, setId: entry.set.id);
      }
    }
    if (open.isEmpty) return null;
    final earliest = open.map((e) => e.round).reduce((a, b) => a < b ? a : b);
    for (var offset = 0; offset < members.length; offset++) {
      final member = members[(startMember + offset) % members.length];
      for (final entry in open) {
        if (entry.exercise.id == member.id && entry.round == earliest) {
          return (exerciseId: entry.exercise.id, setId: entry.set.id);
        }
      }
    }
    return null;
  }

  /// The first exercise to open in the next block with sets left after
  /// [blockIndex], wrapping round.
  static String? nextBlockExercise(
    int? blockIndex,
    List<List<String>> blocks,
    List<WorkoutExercise> exercises,
  ) {
    final start = blockIndex == null ? 0 : blockIndex + 1;
    for (var offset = 0; offset < blocks.length; offset++) {
      final candidate = (start + offset) % blocks.length;
      if (candidate == blockIndex) continue;
      final next = nextSet(blocks[candidate], exercises);
      if (next != null) return next.exerciseId;
    }
    return null;
  }

  /// Where the card goes once [setId] is logged ([exercises] holding it), or
  /// `null` to stay: on to the next member in a superset round; stay when a
  /// rest follows the end of a block; else on to the next block.
  static String? focusAfterLogging(
    String setId,
    List<WorkoutExercise> exercises, {
    required WorkoutSettings settings,
    required bool restFollows,
  }) {
    final exercise = exercises
        .where((e) => e.sets.any((s) => s.id == setId))
        .firstOrNull;
    if (exercise == null) return null;
    final order = blocks(exercises);
    final blockIndex = _blockIndex(exercise.id, order)!;
    final block = order[blockIndex];

    if (nextSet(block, exercises) != null) {
      if (block.length <= 1 || !settings.supersetAutoScroll) return null;
      final next = nextSet(
        block,
        exercises,
        startMember: block.indexOf(exercise.id) + 1,
      );
      return next == null || next.exerciseId == exercise.id
          ? null
          : next.exerciseId;
    }
    if (restFollows || !settings.exerciseAutoNext) return null;
    return nextBlockExercise(blockIndex, order, exercises);
  }

  /// Where the card goes when a rest ends with the card on [current]: on
  /// from a finished exercise to the footer's Next.
  static String? focusWhenRestEnds(
    String? current,
    List<WorkoutExercise> exercises,
    WorkoutSettings settings,
  ) {
    if (!settings.exerciseAutoNext) return null;
    final exercise = exercises.where((e) => e.id == current).firstOrNull;
    if (exercise == null || currentSet(exercise) != null) return null;
    final action = primaryAction(exercises, current);
    return action is NextExerciseAction ? action.exerciseId : null;
  }

  // MARK: - Correction (`ActiveWorkout+Correction.swift`)

  /// The set the correction row sits under: the last logged anywhere, when
  /// it is a working set of [exercise].
  static String? correctionTarget(
    WorkoutExercise exercise,
    WorkoutSet? latestLogged,
  ) {
    if (latestLogged == null ||
        latestLogged.completedAt == null ||
        latestLogged.isWarmup ||
        !exercise.sets.any((s) => s.id == latestLogged.id)) {
      return null;
    }
    return latestLogged.id;
  }

  /// The chips, in reps in reserve; the last reads "6+".
  static const List<int> rirChips = EffortScale.rirChoices;

  /// The RPE a chip stores: 0 → 10 … 6+ → 4.
  static double rpeForRirChip(int rir) =>
      EffortScale.rpeFromRir(rir.clamp(0, rirChips.last));

  /// The chip `rpe` selects: none for a half step, 6+ for anything easier.
  static int? rirChipForRpe(double? rpe) {
    if (rpe == null) return null;
    final rir = EffortScale.rirFromRpe(rpe);
    if (rir >= rirChips.last) return rirChips.last;
    return rir >= 0 && rir == rir.roundToDouble() ? rir.toInt() : null;
  }

  /// "2", "1L": the set's number among the working sets, and its side.
  static String setNumberLabel(WorkoutSet set, WorkoutExercise exercise) =>
      '${exercise.workingSetNumber(set)}${set.side?.initial ?? ''}';

  // MARK: - Propagation (`ActiveWorkout+Propagation.swift`)

  /// [sets] with [edit]'s weight and reps carried onto the open siblings that
  /// still hold what the edited set held before the edit began ([original]),
  /// on the same side. Only from and onto open sets.
  static List<WorkoutSet> propagate({
    required WorkoutSet edit,
    required WorkoutSet original,
    required List<WorkoutSet> sets,
  }) {
    if (edit.completedAt != null) return sets;
    final weightChanged = original.weightKg != edit.weightKg;
    final repsChanged = original.reps != edit.reps;
    if (!weightChanged && !repsChanged) return sets;
    return [
      for (final sibling in sets)
        if (sibling.id == edit.id ||
            sibling.side != edit.side ||
            sibling.completedAt != null ||
            sibling.weightKg != original.weightKg ||
            sibling.reps != original.reps)
          sibling
        else
          sibling.copyWith(
            weightKg: weightChanged ? edit.weightKg : sibling.weightKg,
            reps: repsChanged ? edit.reps : sibling.reps,
          ),
    ];
  }

  // MARK: - Logging (`ActiveWorkout+Log.swift`)

  /// Logs [setId]: checks it, stamps it at [now], and works out the rest and
  /// the next focus. `null` when the set is missing or already logged.
  static LogOutcome? log(
    String setId,
    WorkoutSession session, {
    required WorkoutSettings settings,
    required RestContext context,
    required DateTime now,
    int? customRestSeconds,
    bool isAssisted = false,
  }) {
    final exercises = [...session.exercises];
    final exerciseIndex = exercises.indexWhere(
      (e) => e.sets.any((s) => s.id == setId),
    );
    if (exerciseIndex < 0) return null;
    final exercise = exercises[exerciseIndex];
    final setIndex = exercise.sets.indexWhere((s) => s.id == setId);
    final set = exercise.sets[setIndex];
    if (set.completedAt != null) return null;

    final problem = SetValidation.problem(
      set,
      exercise.trackingMode,
      isAssisted: isAssisted,
    );
    if (problem != null) return LogOutcome(session: session, problem: problem);

    final logged = exercise.stamping(set.copyWith(completedAt: now));
    final sets = [...exercise.sets]..[setIndex] = logged;
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);

    final rest = RestDurationRules.restAfterCompleting(
      logged,
      exercises[exerciseIndex],
      exercises,
      settings,
      context,
      customRestSeconds: customRestSeconds,
    );
    return LogOutcome(
      session: WorkoutSession(exercises: exercises, isDeload: session.isDeload),
      restSeconds: rest,
      focusExerciseId: focusAfterLogging(
        setId,
        exercises,
        settings: settings,
        restFollows: settings.useRestTimers && rest != null,
      ),
    );
  }

  // MARK: - Resume (`ActiveWorkout+Resume.swift`)

  /// Sets logged after [lastSeen], oldest first; nothing when never seen.
  static List<WorkoutSet> receipt(
    List<WorkoutExercise> exercises,
    DateTime? lastSeen,
  ) {
    if (lastSeen == null) return [];
    final logged = [
      for (final set in exercises.expand((e) => e.sets))
        if (set.completedAt?.isAfter(lastSeen) ?? false) set,
    ];
    // A stable sort: sets logged at one instant keep their order.
    final indexed = logged.indexed.toList()
      ..sort((a, b) {
        final order = a.$2.completedAt!.compareTo(b.$2.completedAt!);
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return [for (final (_, set) in indexed) set];
  }

  // MARK: - Reorder (`ActiveWorkout+Reorder.swift`)

  /// The workout with the block whose first exercise is [blockId] put at
  /// [index] among the other blocks, clamped; a superset moves as one.
  static List<WorkoutExercise> movingBlock(
    String blockId,
    int index,
    List<WorkoutExercise> exercises,
  ) {
    final order = blocks(exercises);
    final from = order.indexWhere((b) => b.first == blockId);
    if (from < 0) return exercises;
    final block = order.removeAt(from);
    order.insert(index.clamp(0, order.length), block);
    final byId = <String, WorkoutExercise>{};
    for (final exercise in exercises) {
      byId.putIfAbsent(exercise.id, () => exercise);
    }
    return [for (final id in order.expand((b) => b)) byId[id]!];
  }

  // MARK: - Primary slot (`ActiveWorkout+PrimarySlot.swift`)

  /// How long a naturally expired rest keeps the button disabled.
  static const restDoneGrace = Duration(seconds: 1);

  /// How long after the button's action changes a tap is ignored.
  static const slotTapLockout = Duration(milliseconds: 400);

  /// Paused, it resumes; while a rest runs, it ends it; otherwise the
  /// workout's next step.
  static SlotAction? slotAction({
    required ActiveWorkoutAction? primary,
    required DateTime? restEnd,
    required bool isPaused,
    required DateTime now,
  }) {
    if (isPaused) return const SlotResume();
    if (restEnd != null && now.isBefore(restEnd)) return const SlotSkipRest();
    return switch (primary) {
      LogSetAction(:final exerciseId, :final setId) => SlotLog(
        exerciseId,
        setId,
      ),
      NextExerciseAction(:final exerciseId) => SlotNext(exerciseId),
      FinishAction() => const SlotFinish(),
      null => null,
    };
  }

  /// True for the second after a rest ran out on its own.
  static bool isInGrace(DateTime restEnd, DateTime now) =>
      !now.isBefore(restEnd) && now.isBefore(restEnd.add(restDoneGrace));

  /// Whether a tap at [now] counts.
  static bool acceptsTap(DateTime? lastActionChangeAt, DateTime now) =>
      lastActionChangeAt == null ||
      now.difference(lastActionChangeAt) >= slotTapLockout;

  // MARK: - Strip (`ActiveWorkout+Strip.swift`)

  /// The strip, block by block, the block holding [currentExerciseId]
  /// current.
  static List<StripItem> stripProgress(
    List<WorkoutExercise> exercises,
    String? currentExerciseId,
  ) {
    final byId = <String, WorkoutExercise>{};
    for (final exercise in exercises) {
      byId.putIfAbsent(exercise.id, () => exercise);
    }
    final letters = supersetLetters(exercises);
    return [
      for (final block in blocks(exercises))
        _stripItem(
          [for (final id in block) byId[id]!],
          letters,
          block,
          currentExerciseId,
        ),
    ];
  }

  static StripItem _stripItem(
    List<WorkoutExercise> members,
    Map<String, String> letters,
    List<String> block,
    String? currentExerciseId,
  ) {
    final first = members.first;
    final working = [for (final m in members) m.workingSets];
    return StripItem(
      id: first.id,
      names: [for (final m in members) m.name],
      imageNames: [for (final m in members) m.imageName],
      supersetLetter: members.length > 1
          ? letters[first.supersetGroupId]
          : null,
      doneWorkingSets: working.fold(
        0,
        (sum, sets) => sum + fullyCompletedPairedSetCount(sets),
      ),
      totalWorkingSets: working.fold(
        0,
        (sum, sets) => sum + pairedSetCount(sets),
      ),
      isCurrent: block.contains(currentExerciseId),
    );
  }

  /// The edge the card comes in from moving from [from] to [to]: leading
  /// going back in [order], else trailing.
  static Edge entryEdge(String? from, String? to, List<List<String>> order) {
    final fromIndex = _blockIndex(from, order);
    final toIndex = _blockIndex(to, order);
    if (fromIndex == null || toIndex == null) return Edge.trailing;
    return toIndex < fromIndex ? Edge.leading : Edge.trailing;
  }

  // MARK: - Superset block (`ActiveWorkout+SupersetBlock.swift`)

  /// The members of [exerciseId]'s superset, when it has more than one.
  static List<WorkoutExercise>? supersetBlock(
    String? exerciseId,
    List<WorkoutExercise> exercises,
  ) {
    final order = blocks(exercises);
    final index = _blockIndex(exerciseId, order);
    if (index == null || order[index].length <= 1) return null;
    return [
      for (final id in order[index]) exercises.firstWhere((e) => e.id == id),
    ];
  }

  /// "A" for 0, "B" for 1…, `null` past "Z".
  static String? letter(int index) =>
      index >= 0 && index < 26 ? String.fromCharCode(65 + index) : null;

  /// Each superset's letter by group id, in workout order.
  static Map<String, String> supersetLetters(List<WorkoutExercise> exercises) {
    final letters = <String, String>{};
    for (final block in blocks(exercises)) {
      if (block.length <= 1) continue;
      final groupId = exercises
          .firstWhere((e) => e.id == block.first)
          .supersetGroupId!;
      final assigned = letter(letters.length);
      if (assigned != null) letters[groupId] = assigned;
    }
    return letters;
  }

  /// "B2": the superset's letter and the member's place in it.
  static String memberLabel(String letter, int index) => '$letter${index + 1}';

  /// The superset card's table: each member's warm-ups (logged ones folded),
  /// then the working sets in rounds, a pair together.
  static List<SupersetBlockRow> blockRows(
    List<WorkoutExercise> members,
    String letter,
  ) {
    final rows = <SupersetBlockRow>[];
    final labels = [
      for (var i = 0; i < members.length; i++) memberLabel(letter, i),
    ];
    void endRound() {
      if (rows.isNotEmpty) rows.last = rows.last.ending();
    }

    for (final (i, member) in members.indexed) {
      if (member.sets.any((s) => s.isWarmup && s.completedAt != null)) {
        rows.add(SupersetBlockRow(exerciseId: member.id));
      }
      for (final set in member.sets) {
        if (set.isWarmup && set.completedAt == null) {
          rows.add(
            SupersetBlockRow(
              exerciseId: member.id,
              setId: set.id,
              badge: '${labels[i]}W',
            ),
          );
        }
      }
    }
    endRound();

    final working = [
      for (final member in members)
        [
          for (final set in member.workingSets)
            (set: set, round: round(set, member)),
        ],
    ];
    final lastRound = working
        .expand((w) => w.map((e) => e.round))
        .fold(0, (a, b) => a > b ? a : b);
    for (var r = 1; r <= lastRound; r++) {
      for (final (i, member) in members.indexed) {
        for (final entry in working[i]) {
          if (entry.round != r) continue;
          rows.add(
            SupersetBlockRow(
              exerciseId: member.id,
              setId: entry.set.id,
              badge: '${labels[i]}·$r${entry.set.side?.initial ?? ''}',
            ),
          );
        }
      }
      endRound();
    }
    return rows;
  }

  /// The set the log button logs next on a superset's card.
  static String? nextSetId(List<WorkoutExercise> members, String? current) {
    final start = members.indexWhere((m) => m.id == current);
    return nextSet(
      [for (final m in members) m.id],
      members,
      startMember: start < 0 ? 0 : start,
    )?.setId;
  }

  /// A row's state on a superset's card: only the round's next set is
  /// current.
  static SetRowState blockRowState(
    WorkoutSet set,
    WorkoutExercise exercise, {
    required bool isNext,
  }) {
    final state = rowState(set, exercise);
    return state == SetRowState.current && !isNext
        ? SetRowState.upcoming
        : state;
  }

  /// Whether one row of headings fits every member: one tracking mode and
  /// one unit for it.
  static bool blockSharesColumns(
    List<WorkoutExercise> members,
    ({WeightUnit weight, DistanceUnit distance}) Function(WorkoutExercise)
    units,
  ) {
    final columns = {
      for (final member in members)
        switch (member.trackingMode) {
          TrackingMode.weightReps => 'w|${units(member).weight.name}',
          TrackingMode.distanceTime => 'd|${units(member).distance.name}',
          final mode => mode.name,
        },
    };
    return columns.length <= 1;
  }

  // MARK: - Set kinds (`ActiveWorkout+SetKind.swift`)

  /// The types a set's menu offers; a plan's other kind is kept at the end.
  static List<SetTypeChoice> setTypeOptions(WorkoutSet set) {
    const options = [
      SetTypeChoice.ofKind(SetKind.standard),
      SetTypeChoice.warmup,
      SetTypeChoice.ofKind(SetKind.drop),
      SetTypeChoice.ofKind(SetKind.myo),
      SetTypeChoice.ofKind(SetKind.amrap),
    ];
    final choice = typeChoiceOf(set);
    return options.contains(choice) ? options : [...options, choice];
  }

  /// Not on a sub-row, which is part of its set.
  static bool offersSetTypes(WorkoutSet set) => !set.isSubSet;

  /// Another drop belongs to a drop set.
  static bool offersDrop(WorkoutSet set) =>
      !set.isWarmup && !set.isSubSet && set.kind == SetKind.drop;

  /// A mini-set belongs to a set that rests within itself.
  static bool offersMiniSet(WorkoutSet set) =>
      !set.isWarmup && !set.isSubSet && set.kind.restsWithinTheSet;

  /// [sets] with [setId] and its pair made [choice]. Sub-rows the new type
  /// has no use for go; a drop or myo set left with none gets its first.
  static List<WorkoutSet> applying(
    SetTypeChoice choice,
    String setId,
    List<WorkoutSet> sets, {
    required String firstSubSetId,
    required double? dropWeightKg,
  }) {
    final set = sets.where((s) => s.id == setId).firstOrNull;
    if (set == null || typeChoiceOf(set) == choice) return sets;
    final family = pairedSetIds(sets, setId).toSet();
    final kind = choice.kind ?? SetKind.standard;
    final SubSetKind? subKind;
    if (choice.isWarmup) {
      subKind = null;
    } else if (kind == SetKind.drop) {
      subKind = SubSetKind.drop;
    } else if (kind.restsWithinTheSet) {
      subKind = SubSetKind.mini;
    } else {
      subKind = null;
    }

    final updated = [
      for (final row in sets)
        if (!family.contains(row.parentSetId) ||
            switch (subKind) {
              SubSetKind.drop => row.kind == SetKind.drop,
              SubSetKind.mini => row.kind == SetKind.standard,
              null => false,
            })
          if (family.contains(row.id))
            row.copyWith(isWarmup: choice.isWarmup, kind: kind)
          else
            row,
    ];
    if (subKind == null || subSets(setId, updated).isNotEmpty) return updated;
    return addingSubSet(
      subKind,
      setId,
      updated,
      id: firstSubSetId,
      weightKg: subKind == SubSetKind.drop ? dropWeightKg : set.weightKg,
    );
  }

  /// The drops and mini-sets of [parentId], in order.
  static List<WorkoutSet> subSets(String parentId, List<WorkoutSet> sets) =>
      sets.where((s) => s.parentSetId == parentId).toList();

  /// Where a new sub-row of [parentId] goes: after the set (and its pair)
  /// and their sub-rows.
  static int? subSetInsertionIndex(String parentId, List<WorkoutSet> sets) {
    final family = pairedSetIds(sets, parentId).toSet();
    if (family.isEmpty) return null;
    return sets.lastIndexWhere(
          (s) => family.contains(s.id) || family.contains(s.parentSetId),
        ) +
        1;
  }

  /// [sets] with a new drop or mini-set of [parentId], reps empty, on its
  /// side, numbered one past the highest index.
  static List<WorkoutSet> addingSubSet(
    SubSetKind subKind,
    String parentId,
    List<WorkoutSet> sets, {
    required String id,
    required double? weightKg,
  }) {
    final parent = sets.where((s) => s.id == parentId).firstOrNull;
    final position = subSetInsertionIndex(parentId, sets);
    if (parent == null || position == null) return sets;
    final highest = sets.map((s) => s.index).fold(0, (a, b) => a > b ? a : b);
    return [...sets]..insert(
      position,
      WorkoutSet(
        id: id,
        authorId: parent.authorId,
        index: highest + 1,
        weightKg: weightKg,
        side: parent.side,
        kind: subKind == SubSetKind.drop ? SetKind.drop : SetKind.standard,
        parentSetId: parent.id,
      ),
    );
  }

  /// A drop's starting weight: [percent] off its parent, to the nearest the
  /// equipment makes, and lighter than the parent. Assistance and no weight
  /// are left as they are.
  static double? dropWeightKg(
    double? parentKg,
    WeightStep step,
    WeightUnit unit, {
    int percent = 20,
  }) {
    if (parentKg == null || parentKg <= 0) return parentKg;
    final parent = convertWeight(parentKg, unit);
    var snapped = step.nearest(parent * (1 - percent / 100));
    final lighter = step.previous(parent);
    if (snapped >= parent - WeightStep.epsilon &&
        lighter != null &&
        lighter < parent - WeightStep.epsilon) {
      snapped = lighter;
    }
    return convertWeightToKg(snapped, unit);
  }

  /// A planned drop: [percent] off the piece before, on a weight [rounding]
  /// allows (the half kilogram without one), and lighter than that piece
  /// (`WorkoutSessionModel.dropWeightKg`).
  static double? plannedDropWeightKg(
    double? parentKg,
    int percent,
    WeightRoundingRule? rounding,
  ) {
    if (parentKg == null || parentKg <= 0) return parentKg;
    final target = parentKg * (1 - percent / 100);
    if (rounding == null) return (target * 2).roundToDouble() / 2;
    final rounded = rounding.round(target);
    if (rounded < parentKg - 0.001) return rounded;
    return rounding.round(parentKg - rounding.minimumIncrementKg);
  }

  /// The ids deleting [setId] removes: it, its pair, and their sub-rows.
  static List<String> idsRemovedByDeleting(
    String setId,
    List<WorkoutSet> sets,
  ) {
    final rows = pairedSetIds(sets, setId);
    final family = rows.toSet();
    return [
      ...rows,
      for (final s in sets)
        if (family.contains(s.parentSetId)) s.id,
    ];
  }

  /// How many drops and mini-sets deleting [setId] takes, a pair once.
  static ({int drops, int minis}) subSetsRemovedByDeleting(
    String setId,
    List<WorkoutSet> sets,
  ) {
    final removed = idsRemovedByDeleting(setId, sets).toSet();
    final pieces = sets.where(
      (s) =>
          removed.contains(s.id) &&
          s.isSubSet &&
          !(s.side == SetSide.right && pairedSetIds(sets, s.id).length == 2),
    );
    return (
      drops: pieces.where((s) => subSetKindOf(s) == SubSetKind.drop).length,
      minis: pieces.where((s) => subSetKindOf(s) == SubSetKind.mini).length,
    );
  }

  /// A sub-row's place among its parent's of its kind and side, from 1; 0
  /// for a set of its own.
  static int subSetOrdinal(WorkoutSet set, List<WorkoutSet> sets) {
    final parentId = set.parentSetId;
    if (parentId == null) return 0;
    final siblings = subSets(
      parentId,
      sets,
    ).where((s) => subSetKindOf(s) == subSetKindOf(set) && s.side == set.side);
    return siblings.toList().indexWhere((s) => s.id == set.id) + 1;
  }

  /// Last session's row for [set], a row of [current]: a set by its number
  /// and side among last time's sets of their own; a drop or mini-set by its
  /// parent's match, kind and place.
  static WorkoutSet? lastSet(
    WorkoutSet set,
    WorkoutExercise current,
    WorkoutExercise? last,
  ) {
    if (last == null) return null;
    final parentId = set.parentSetId;
    if (parentId == null) {
      return last
          .copyWith(sets: last.sets.where((s) => !s.isSubSet).toList())
          .matchingSet(set, current);
    }
    final parent = current.sets.where((s) => s.id == parentId).firstOrNull;
    if (parent == null || parent.isSubSet) return null;
    final lastParent = lastSet(parent, current, last);
    if (lastParent == null) return null;
    final ordinal = subSetOrdinal(set, current.sets);
    final candidates = subSets(
      lastParent.id,
      last.sets,
    ).where((s) => subSetKindOf(s) == subSetKindOf(set));
    for (final side in acceptableSides(set.side)) {
      for (final match in candidates) {
        if (match.side == side && subSetOrdinal(match, last.sets) == ordinal) {
          return match;
        }
      }
    }
    return null;
  }

  // MARK: - Pieces (`ActiveWorkout+Pieces.swift`)

  /// The next row still to log after [setId] when it is a drop or mini-set
  /// of the set, with the breath before it.
  static NextPiece? nextPiece(
    String setId,
    WorkoutExercise exercise,
    WorkoutSettings settings,
  ) {
    final position = exercise.sets.indexWhere((s) => s.id == setId);
    if (position < 0) return null;
    final next = exercise.sets
        .skip(position + 1)
        .where((s) => s.completedAt == null)
        .firstOrNull;
    if (next == null || !next.isSubSet) return null;
    final ordinal = subSetOrdinal(next, exercise.sets);
    if (next.kind == SetKind.partials || next.kind.isTimed) {
      return NextPiece(piece: next, ordinal: ordinal);
    }
    final parentKind =
        exercise.sets
            .where((s) => s.id == next.parentSetId)
            .firstOrNull
            ?.kind ??
        SetKind.standard;
    return NextPiece(
      piece: next,
      ordinal: ordinal,
      restSeconds:
          settings.intraSetRest(
            next.kind == SetKind.standard ? parentKind : next.kind,
          ) ??
          0,
    );
  }

  // MARK: - History (`ActiveWorkout+History.swift`)

  /// [exercise]'s history key, its occurrence read from [session].
  static String historyKey(WorkoutExercise exercise, WorkoutSession session) =>
      historyKeyFor(exercise.template, session.occurrence(exercise));

  /// [set] with last time's figures for the tracking mode; a weighted set
  /// with no weight last time keeps its own.
  static WorkoutSet fillingFromPrevious(
    WorkoutSet set,
    WorkoutSet previous,
    TrackingMode trackingMode,
  ) => switch (trackingMode) {
    TrackingMode.weightReps => set.copyWith(
      weightKg: previous.weightKg ?? set.weightKg,
      bands: previous.bands,
      reps: previous.reps,
    ),
    TrackingMode.repsOnly => set.copyWith(reps: previous.reps),
    TrackingMode.timeOnly => set.copyWith(durationSec: previous.durationSec),
    TrackingMode.distanceTime => set.copyWith(
      distanceMeters: previous.distanceMeters,
      durationSec: previous.durationSec,
    ),
  };

  /// [set] with a suggestion in place, leaving what it says nothing about.
  static WorkoutSet fillingFromSuggestion(
    WorkoutSet set,
    SuggestedSet suggestion,
  ) => set.copyWith(
    weightKg: suggestion.weightKg ?? set.weightKg,
    reps: suggestion.reps ?? set.reps,
    durationSec: suggestion.durationSec ?? set.durationSec,
    distanceMeters: suggestion.distanceMeters ?? set.distanceMeters,
  );
}
