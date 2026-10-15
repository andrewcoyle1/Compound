import 'package:compound_models/compound_models.dart';

/// Makes a new id.
typedef NewId = String Function();

/// Sets a nullable field in a `copyWith`: absent keeps it, a function
/// returning null clears it.
typedef Nullable<T> = T? Function();

/// [WorkoutTemplateExercise] with the given parts replaced; the model has no
/// copy of its own.
extension WorkoutTemplateExerciseCopy on WorkoutTemplateExercise {
  /// This exercise with the given parts replaced.
  WorkoutTemplateExercise copyWith({
    String? id,
    List<SetTarget>? setTargets,
    bool? setRestTimers,
    Nullable<String>? notes,
    Nullable<int>? warmupSetCount,
    Nullable<int>? restSeconds,
    List<String>? substituteExerciseIds,
    Nullable<String>? supersetGroupId,
    Nullable<String>? linkUrl,
    List<MicrocycleSetTargets>? setTargetsByMicrocycle,
  }) => WorkoutTemplateExercise(
    id: id ?? this.id,
    exercise: exercise,
    setTargets: setTargets ?? this.setTargets,
    setRestTimers: setRestTimers ?? this.setRestTimers,
    notes: notes == null ? this.notes : notes(),
    warmupSetCount: warmupSetCount == null
        ? this.warmupSetCount
        : warmupSetCount(),
    restSeconds: restSeconds == null ? this.restSeconds : restSeconds(),
    substituteExerciseIds: substituteExerciseIds ?? this.substituteExerciseIds,
    supersetGroupId: supersetGroupId == null
        ? this.supersetGroupId
        : supersetGroupId(),
    linkUrl: linkUrl == null ? this.linkUrl : linkUrl(),
    setTargetsByMicrocycle:
        setTargetsByMicrocycle ?? this.setTargetsByMicrocycle,
  );
}

/// [SetTarget] with the given parts replaced.
extension SetTargetCopy on SetTarget {
  /// This target with the given parts replaced.
  SetTarget copyWith({
    String? id,
    int? setNumber,
    Nullable<int>? minReps,
    Nullable<int>? maxReps,
    Nullable<int>? rirTarget,
    SetTargetSetType? setType,
    Nullable<int>? dropCount,
    Nullable<int>? dropStepPercent,
    Nullable<int>? dropReps,
    Nullable<int>? miniSetCount,
    Nullable<int>? amrapTargetReps,
    Nullable<int>? partialReps,
    Nullable<int>? holdSeconds,
  }) => SetTarget(
    id: id ?? this.id,
    setNumber: setNumber ?? this.setNumber,
    minReps: minReps == null ? this.minReps : minReps(),
    maxReps: maxReps == null ? this.maxReps : maxReps(),
    rirTarget: rirTarget == null ? this.rirTarget : rirTarget(),
    setType: setType ?? this.setType,
    dropCount: dropCount == null ? this.dropCount : dropCount(),
    dropStepPercent: dropStepPercent == null
        ? this.dropStepPercent
        : dropStepPercent(),
    dropReps: dropReps == null ? this.dropReps : dropReps(),
    miniSetCount: miniSetCount == null ? this.miniSetCount : miniSetCount(),
    amrapTargetReps: amrapTargetReps == null
        ? this.amrapTargetReps
        : amrapTargetReps(),
    partialReps: partialReps == null ? this.partialReps : partialReps(),
    holdSeconds: holdSeconds == null ? this.holdSeconds : holdSeconds(),
  );

  /// How much lighter each drop is, in per cent: 20 when unset
  /// (`SetTarget.dropStep`).
  int get dropStep => dropStepPercent ?? 20;
}

/// Whether two Firestore-shaped values are equal all the way down, as two
/// documents would be.
bool sameDocument(Object? a, Object? b) => switch ((a, b)) {
  (final Map<String, Object?> a, final Map<String, Object?> b) =>
    a.length == b.length &&
        a.keys.every(
          (key) => b.containsKey(key) && sameDocument(a[key], b[key]),
        ),
  (final List<Object?> a, final List<Object?> b) =>
    a.length == b.length &&
        [for (var i = 0; i < a.length; i++) i]
            .every((i) => sameDocument(a[i], b[i])),
  _ => a == b,
};

/// The workout editor's rules: building a template, the exercise list's
/// supersets and order (`DefineWorkoutRules.swift`), the set targets
/// (`SetTargetPresenter`) and their plan (`SetTargetPlan.swift`,
/// `SetPlanDetailPresenter`), and how they vary by week
/// (`WeeklyTargetsPresenter`). The words are the app's.
abstract final class WorkoutEditorRules {
  // MARK: - New exercises

  /// The range a new template exercise starts with (`SetTarget
  /// .defaultRepRange`).
  static const defaultMinReps = 8;

  /// The top of [defaultMinReps]'s range.
  static const defaultMaxReps = 12;

  /// A new exercise's first set: a standard set of 8–12 reps
  /// (`SetTarget.standard`).
  static SetTarget standardTarget(int setNumber, {required NewId newId}) =>
      SetTarget(
        id: newId(),
        setNumber: setNumber,
        minReps: defaultMinReps,
        maxReps: defaultMaxReps,
      );

  /// [exercise] as a template exercise: one standard set, no rest timers
  /// (`WorkoutTemplateExercise(exercise:setRestTimers: false)`).
  static WorkoutTemplateExercise templateExercise(
    ExerciseModel exercise, {
    required NewId newId,
  }) => WorkoutTemplateExercise(
    id: newId(),
    exercise: exercise,
    setTargets: [standardTarget(1, newId: newId)],
    setRestTimers: false,
  );

  /// [exercises] with [picked] added after them, leaving out any exercise
  /// already there (`ExercisesPickerPresenter.onSavePressed`).
  static List<WorkoutTemplateExercise> addingPicked(
    List<WorkoutTemplateExercise> exercises,
    List<ExerciseModel> picked, {
    required NewId newId,
  }) {
    final existing = {for (final e in exercises) e.exercise.id};
    return [
      ...exercises,
      for (final exercise in picked)
        if (existing.add(exercise.id)) templateExercise(exercise, newId: newId),
    ];
  }

  // MARK: - The wizard

  /// The gym a workout is built for without asking: the edited template's,
  /// while it still exists, else the only gym there is
  /// (`NameWorkoutPresenter.gymWithoutAsking`).
  static GymProfileModel? gymWithoutAsking(
    WorkoutTemplateModel? template,
    List<GymProfileModel> gyms,
  ) {
    final kept = gyms
        .where((gym) => template != null && gym.id == template.gymProfileId)
        .firstOrNull;
    return kept ?? (gyms.length == 1 ? gyms.single : null);
  }

  /// The template the wizard saves: [existing] changed in place, keeping its
  /// id, author, description, picture and creation date, or a new one by
  /// [uid] (`DefineWorkoutWrapperPresenter.onConfirmPressed`).
  static WorkoutTemplateModel savedTemplate({
    required WorkoutTemplateModel? existing,
    required String uid,
    required String name,
    required String gymProfileId,
    required List<WorkoutTemplateExercise> exercises,
    required DateTime now,
    required NewId newId,
  }) => WorkoutTemplateModel(
    workoutId: existing?.workoutId ?? newId(),
    authorId: existing?.authorId ?? uid,
    name: name,
    description: existing?.description,
    gymProfileId: gymProfileId,
    imageUrl: existing?.imageUrl,
    dateCreated: existing?.dateCreated ?? now,
    dateModified: now,
    exercises: exercises,
  );

  // MARK: - Supersets

  /// The workout as it is worked: an exercise on its own is a block of one,
  /// and a superset one block of its members where its first member is.
  /// Exercise ids, in list order.
  static List<List<String>> blocks(List<WorkoutTemplateExercise> exercises) {
    final blocks = <List<String>>[];
    final blockByGroup = <String, int>{};
    for (final exercise in exercises) {
      final group = exercise.supersetGroupId;
      final index = group == null ? null : blockByGroup[group];
      if (index != null) {
        blocks[index].add(exercise.id);
        continue;
      }
      if (group != null) blockByGroup[group] = blocks.length;
      blocks.add([exercise.id]);
    }
    return blocks;
  }

  /// The chosen exercises as one superset under [groupId], gathered where
  /// the first of them is. Fewer than two chosen changes nothing. A chosen
  /// exercise leaves the superset it was in, and a superset left with one
  /// member is dissolved.
  static List<WorkoutTemplateExercise> grouping(
    Set<String> ids,
    List<WorkoutTemplateExercise> exercises, {
    required String groupId,
  }) {
    if (exercises.where((e) => ids.contains(e.id)).length < 2) {
      return exercises;
    }
    return _gathered(
      dissolvingLoneGroups([
        for (final e in exercises)
          if (ids.contains(e.id))
            e.copyWith(supersetGroupId: () => groupId)
          else
            e,
      ]),
    );
  }

  /// [id] out of its superset; a superset left with one member is
  /// dissolved.
  static List<WorkoutTemplateExercise> removingFromSuperset(
    String id,
    List<WorkoutTemplateExercise> exercises,
  ) => dissolvingLoneGroups([
    for (final e in exercises)
      if (e.id == id) e.copyWith(supersetGroupId: () => null) else e,
  ]);

  /// A superset of one goes back to being an exercise on its own.
  static List<WorkoutTemplateExercise> dissolvingLoneGroups(
    List<WorkoutTemplateExercise> exercises,
  ) {
    final counts = <String, int>{};
    for (final group in exercises.map((e) => e.supersetGroupId).nonNulls) {
      counts[group] = (counts[group] ?? 0) + 1;
    }
    return [
      for (final e in exercises)
        switch (e.supersetGroupId) {
          final group? when counts[group]! < 2 => e.copyWith(
            supersetGroupId: () => null,
          ),
          _ => e,
        },
    ];
  }

  static List<WorkoutTemplateExercise> _gathered(
    List<WorkoutTemplateExercise> exercises,
  ) {
    final byId = <String, WorkoutTemplateExercise>{};
    for (final e in exercises) {
      byId.putIfAbsent(e.id, () => e);
    }
    return [
      for (final block in blocks(exercises))
        for (final id in block) byId[id]!,
    ];
  }

  /// "A", "B"… per superset by first appearance, then numbers past Z.
  static Map<String, String> supersetLetters(
    List<WorkoutTemplateExercise> exercises,
  ) {
    final letters = <String, String>{};
    for (final block in blocks(exercises)) {
      if (block.length < 2) continue;
      final group = exercises
          .firstWhere((e) => e.id == block.first)
          .supersetGroupId!;
      final index = letters.length;
      letters[group] = index < 26
          ? String.fromCharCode(65 + index)
          : '${index + 1}';
    }
    return letters;
  }

  // MARK: - Reordering

  /// SwiftUI's `move(fromOffsets:toOffset:)`, [destination] counted before
  /// the move, keeping each superset together: a member moved within its
  /// own superset changes places inside it; moved anywhere else, it takes
  /// its superset along. Nothing lands inside another superset: a drop
  /// there goes before it moving up and after it moving down.
  static List<WorkoutTemplateExercise> moving(
    List<WorkoutTemplateExercise> exercises,
    Set<int> source,
    int destination,
  ) {
    if (source.length == 1) {
      final run = _run(exercises[source.single].supersetGroupId, exercises);
      if (run != null && destination >= run.$1 && destination <= run.$2 + 1) {
        return _move(exercises, source, destination);
      }
    }
    final movingGroups = {
      for (final index in source) ?exercises[index].supersetGroupId,
    };
    final moving = {
      for (var i = 0; i < exercises.length; i++)
        if (source.contains(i) ||
            movingGroups.contains(exercises[i].supersetGroupId))
          i,
    };
    var target = destination;
    if (target > 0 && target < exercises.length) {
      final group = exercises[target].supersetGroupId;
      final run = _run(group, exercises);
      if (group != null &&
          !movingGroups.contains(group) &&
          exercises[target - 1].supersetGroupId == group &&
          run != null) {
        target = (moving.reduce((a, b) => a < b ? a : b)) < target
            ? run.$2 + 1
            : run.$1;
      }
    }
    return _move(exercises, moving, target);
  }

  static List<T> _move<T>(List<T> items, Set<int> source, int destination) {
    final moved = [
      for (var i = 0; i < items.length; i++)
        if (source.contains(i)) items[i],
    ];
    final before = [
      for (var i = 0; i < destination && i < items.length; i++)
        if (!source.contains(i)) items[i],
    ];
    final after = [
      for (var i = destination; i < items.length; i++)
        if (!source.contains(i)) items[i],
    ];
    return [...before, ...moved, ...after];
  }

  /// The first and last index of [group]'s members when they sit together.
  static (int, int)? _run(
    String? group,
    List<WorkoutTemplateExercise> exercises,
  ) {
    if (group == null) return null;
    final indices = [
      for (var i = 0; i < exercises.length; i++)
        if (exercises[i].supersetGroupId == group) i,
    ];
    if (indices.length < 2 ||
        indices.length != indices.last - indices.first + 1) {
      return null;
    }
    return (indices.first, indices.last);
  }

  // MARK: - Set targets

  /// [targets] with a set added that asks for what the last one did: the
  /// same range and reps in reserve (`SetTargetPresenter.onAddSetPressed`).
  static List<SetTarget> addingSet(
    List<SetTarget> targets, {
    required NewId newId,
  }) {
    final last = targets.lastOrNull;
    return [
      ...targets,
      SetTarget(
        id: newId(),
        setNumber: targets.length + 1,
        minReps: last == null ? defaultMinReps : last.minReps,
        maxReps: last == null ? defaultMaxReps : last.maxReps,
        rirTarget: last?.rirTarget,
      ),
    ];
  }

  /// [targets] without [id], numbered again from 1.
  static List<SetTarget> deletingSet(List<SetTarget> targets, String id) => [
    for (final (index, target) in targets.where((t) => t.id != id).indexed)
      target.copyWith(setNumber: index + 1),
  ];

  /// A minimum typed above its maximum swapped with it, which is what was
  /// meant (`SetTargetPresenter.onSavePressed`).
  static List<SetTarget> orderedRanges(List<SetTarget> targets) => [
    for (final target in targets)
      switch ((target.minReps, target.maxReps)) {
        (final min?, final max?) when min > max => target.copyWith(
          minReps: () => max,
          maxReps: () => min,
        ),
        _ => target,
      },
  ];

  /// A typed rep count: at least 1, or none. A target of 0 reps would be
  /// prescribed and then progressed.
  static int? typedReps(String text) => switch (int.tryParse(text.trim())) {
    final reps? => reps < 1 ? 1 : reps,
    null => null,
  };

  /// The reps in reserve a set can aim for (`EffortScale.rirChoices`).
  static const rirChoices = [0, 1, 2, 3, 4, 5, 6];

  // MARK: - A set's plan

  /// The kinds the editor offers, in its picker's order; `failure` is read
  /// as [SetTargetSetType.amrap].
  static const List<SetTargetSetType> kinds = [
    SetTargetSetType.standard,
    SetTargetSetType.amrap,
    SetTargetSetType.myo,
    SetTargetSetType.restPause,
    SetTargetSetType.cluster,
    SetTargetSetType.drop,
    SetTargetSetType.partials,
    SetTargetSetType.stretch,
    SetTargetSetType.hold,
  ];

  /// How much lighter each drop can be, in per cent.
  static const dropSteps = [10, 20, 25, 30];

  /// The drops a drop set can plan.
  static const dropCountRange = (1, 5);

  /// The mini-sets a myo-rep, rest-pause or cluster set can plan.
  static const miniSetCountRange = (1, 6);

  /// How long a stretch or hold can last, in seconds.
  static const holdSecondsChoices = [15, 20, 30, 45, 60];

  /// A stretch or hold's time when the kind is chosen.
  static const defaultHoldSeconds = 30;

  /// The kinds that plan mini-sets.
  static const Set<SetTargetSetType> miniSetKinds = {
    SetTargetSetType.myo,
    SetTargetSetType.restPause,
    SetTargetSetType.cluster,
  };

  /// The kind shown: a failure set from before AMRAP existed is AMRAP.
  static SetTargetSetType shownKind(SetTargetSetType type) =>
      type == SetTargetSetType.failure ? SetTargetSetType.amrap : type;

  /// [target] made [type], with a plan to start from so the line under the
  /// set and the session made from it agree from the first tap; null when
  /// it is that kind already (`SetPlanDetailPresenter.setType`).
  static SetTarget? withKind(SetTarget target, SetTargetSetType type) {
    if (type == shownKind(target.setType)) return null;
    final changed = target.copyWith(setType: type);
    return planned(switch (type) {
      SetTargetSetType.drop => changed.copyWith(
        dropCount: () => target.dropCount ?? 2,
      ),
      SetTargetSetType.myo ||
      SetTargetSetType.restPause ||
      SetTargetSetType.cluster => changed.copyWith(
        miniSetCount: () => target.miniSetCount ?? 3,
      ),
      SetTargetSetType.amrap || SetTargetSetType.failure => changed.copyWith(
        amrapTargetReps: () =>
            target.amrapTargetReps ?? target.minReps ?? target.maxReps,
      ),
      SetTargetSetType.stretch || SetTargetSetType.hold => changed.copyWith(
        holdSeconds: () => target.holdSeconds ?? defaultHoldSeconds,
      ),
      SetTargetSetType.standard || SetTargetSetType.partials => changed,
    });
  }

  /// [target] as written after any plan edit: a legacy failure set becomes
  /// AMRAP.
  static SetTarget planned(SetTarget target) =>
      target.setType == SetTargetSetType.failure
      ? target.copyWith(setType: SetTargetSetType.amrap)
      : target;

  /// A typed count of reps: whole, from 1 to 999, or none.
  static int? plannedReps(double? value) {
    if (value == null || !value.isFinite || value < 1 || value > 999) {
      return null;
    }
    return value.round();
  }

  /// The hold times, [current] among them.
  static List<int> holdChoices(int current) =>
      ({...holdSecondsChoices, current}.toList()..sort());

  /// To failure (null) first, then 1 to 10 partial reps, [current] among
  /// them.
  static List<int?> partialRepsChoices(int? current) => [
    null,
    ...({for (var i = 1; i <= 10; i++) i, ?current}.toList()..sort()),
  ];

  // MARK: - The exercise's plan

  /// Automatic (null), then a fixed count of warm-ups.
  static const warmupSetChoices = <int?>[null, 0, 1, 2, 3, 4];

  /// Automatic (null), then 15 s to 10 min in 15 s steps.
  static final restSecondsChoices = <int?>[
    null,
    for (var seconds = 15; seconds <= 600; seconds += 15) seconds,
  ];

  /// [choices] with [value] among them, so an imported 5 warm-ups or 50 s
  /// rest still shows as chosen.
  static List<int?> choices(List<int?> choices, int? value) {
    if (value == null || choices.contains(value)) return choices;
    return [
      null,
      ...([...choices.nonNulls, value]..sort()),
    ];
  }

  /// The link as saved: trimmed, and only an `http` or `https` address
  /// with a host. Null for anything else.
  static String? validatedLink(String text) {
    final trimmed = text.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      return null;
    }
    return uri.host.isEmpty ? null : trimmed;
  }

  // MARK: - Weekly variation

  /// The weeks a variation can start on: week 1 is the exercise's own
  /// targets.
  static const firstVariationWeek = 2;

  /// The last week a variation can start on.
  static const lastVariationWeek = 52;

  /// Each stretch of microcycles [overrides] cover with its set count, as
  /// "Week 1: 2 sets · Weeks 2–8: 3 sets · From week 9: 4 sets" reads; a
  /// null `through` runs on. Null when nothing varies.
  static List<({int from, int? through, int sets})>? variationSegments(
    List<SetTarget> base,
    List<MicrocycleSetTargets> overrides,
  ) {
    if (overrides.isEmpty) return null;
    final sorted = [...overrides]
      ..sort((a, b) => a.fromMicrocycle.compareTo(b.fromMicrocycle));
    return [
      if (sorted.first.fromMicrocycle > 1)
        (from: 1, through: sorted.first.fromMicrocycle - 1, sets: base.length),
      for (final (index, override) in sorted.indexed)
        (
          from: override.fromMicrocycle,
          through: index + 1 < sorted.length
              ? sorted[index + 1].fromMicrocycle - 1
              : null,
          sets: override.setTargets.length,
        ),
    ];
  }

  /// The week a new variation starts on: the week after the last (week 2
  /// for the first), else the first week still free; null when every week
  /// is taken.
  static int? nextVariationWeek(Iterable<int> weeks) {
    final last = weeks.fold(1, (a, b) => a > b ? a : b);
    final candidate = last + 1 < firstVariationWeek
        ? firstVariationWeek
        : last + 1;
    if (candidate <= lastVariationWeek) return candidate;
    for (var week = firstVariationWeek; week <= lastVariationWeek; week++) {
      if (!weeks.contains(week)) return week;
    }
    return null;
  }

  /// Whether a variation on [week] can step by [delta]: it stays in 2–52
  /// and never lands on a week in [others].
  static bool canStepVariation(int week, int delta, Iterable<int> others) {
    final next = week + delta;
    return next >= firstVariationWeek &&
        next <= lastVariationWeek &&
        !others.contains(next);
  }
}
