import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// The tracker's words, worded from the decisions `training_rules` makes
/// (`ActiveWorkout.logTitle`, `figures`, `SetValidation`).
abstract final class TrackerText {
  /// A set's place in its table: "W", "2", "1L", or "↳" for a drop or
  /// mini-set.
  static String badge(
    AppLocalizations l10n,
    WorkoutSetModel set,
    WorkoutExerciseModel exercise,
  ) {
    if (set.isWarmup) return l10n.trackerWarmupBadge;
    if (set.parentSetId != null) return '↳';
    return r.ActiveWorkout.setNumberLabel(
      rulesSet(set),
      rulesExercise(exercise),
    );
  }

  /// "100 kg × 8", "12 reps", "1:30", "400 m · 1:30"; null until the set
  /// holds its figures.
  static String? figures(
    AppLocalizations l10n,
    WorkoutSetModel set,
    TrackingMode mode,
    ExerciseWeightUnit unit, {
    String? locale,
    DistanceUnit distanceUnit = DistanceUnit.meters,
  }) {
    final duration = set.durationSec == null
        ? null
        : AppFormat.duration(Duration(seconds: set.durationSec!));
    switch (mode) {
      case TrackingMode.weightReps:
        final reps = set.reps;
        if (reps == null) return null;
        final load = set.loadKg;
        if (load == null || load == 0) return l10n.repCount(reps);
        final weight = AppFormat.weight(
          load,
          WorkoutText.weightUnit(unit),
          maxFractionDigits: 2,
          locale: locale,
        );
        return '$weight × ${AppFormat.number(reps, locale: locale)}';
      case TrackingMode.repsOnly:
        return set.reps == null ? null : l10n.repCount(set.reps!);
      case TrackingMode.timeOnly:
        return duration;
      case TrackingMode.distanceTime:
        final meters = set.distanceMeters;
        if (meters == null || duration == null) return null;
        return '${distanceText(meters, distanceUnit, locale)} · $duration';
    }
  }

  /// "400 m", "3.38 mi": [meters] in [unit].
  static String distanceText(double meters, DistanceUnit unit, String? locale) {
    final value = AppFormat.number(
      unit.fromMeters(meters),
      maxFractionDigits: 2,
      locale: locale,
    );
    return '$value ${distanceSymbol(unit)}';
  }

  /// "m", "mi".
  static String distanceSymbol(DistanceUnit unit) => switch (unit) {
    DistanceUnit.meters => 'm',
    DistanceUnit.miles => 'mi',
  };

  /// The log button's words for [set]: "Log set 2 · 100 kg × 8".
  static String logTitle(
    AppLocalizations l10n,
    WorkoutSetModel set,
    WorkoutExerciseModel exercise, {
    String? locale,
  }) {
    final name = switch (set) {
      WorkoutSetModel(isWarmup: true) => l10n.trackerLogWarmup,
      WorkoutSetModel(parentSetId: final _?, kind: SetKind.drop) =>
        l10n.trackerLogDrop,
      WorkoutSetModel(parentSetId: null, kind: SetKind.amrap) =>
        l10n.trackerLogFailure,
      _ => l10n.trackerLogSet(badge(l10n, set, exercise)),
    };
    final figures = TrackerText.figures(
      l10n,
      set,
      exercise.trackingMode,
      exercise.weightUnit ?? ExerciseWeightUnit.kilograms,
      locale: locale,
    );
    return [name, ?figures].join(' · ');
  }

  /// Why a set could not be logged.
  static String problem(AppLocalizations l10n, r.SetProblem problem) =>
      switch (problem) {
        r.SetProblem.noReps => l10n.trackerProblemNoReps,
        r.SetProblem.noTime => l10n.trackerProblemNoTime,
        r.SetProblem.negativeWeight => l10n.trackerProblemNegativeWeight,
        r.SetProblem.noDistance => l10n.trackerProblemNoDistance,
      };

  /// What VoiceOver and TalkBack hear when a set is logged:
  /// "Set 2 logged, 100 kg × 8".
  static String logged(
    AppLocalizations l10n,
    WorkoutSetModel set,
    WorkoutExerciseModel exercise, {
    String? locale,
  }) {
    final figures = TrackerText.figures(
      l10n,
      set,
      exercise.trackingMode,
      exercise.weightUnit ?? ExerciseWeightUnit.kilograms,
      locale: locale,
    );
    return l10n.trackerSetLogged(badge(l10n, set, exercise), figures ?? '');
  }

  // MARK: - Loading

  /// A weight already in the display unit, as the loading reads it:
  /// "47.5", up to two decimals.
  static String amount(double value, {String? locale}) =>
      AppFormat.number(value, maxFractionDigits: 2, locale: locale);

  /// "kg" or "lb".
  static String unit(ExerciseWeightUnit unit) =>
      WorkoutText.weightUnit(unit).symbol;

  /// "1 × 25 · 2 × 10", heaviest first.
  static String plateCounts(r.PlateLoading loading, {String? locale}) => [
    for (final (weight, count) in loading.counts)
      '$count × ${amount(weight, locale: locale)}',
  ].join(' · ');

  /// "25 kg on each side + 20 kg bar = 70 kg", "25 kg of plates + 18 kg
  /// base = 43 kg" on a single-sleeve machine, or "Empty bar = 20 kg".
  static String plateEquation(
    AppLocalizations l10n,
    r.PlateLoading loading,
    ExerciseWeightUnit weightUnit, {
    String? locale,
  }) {
    String weight(double value) =>
        '${amount(value, locale: locale)} ${unit(weightUnit)}';
    final total = weight(loading.total);
    if (loading.perSide.isEmpty) return l10n.plateEquationEmpty(total);
    return loading.sleeves == 1
        ? l10n.plateEquationSingle(
            weight(loading.plates),
            weight(loading.base),
            total,
          )
        : l10n.plateEquationBar(
            weight(loading.plates),
            weight(loading.base),
            total,
          );
  }

  /// "Not loadable: 67.5 or 72.5 kg", the nearest totals either side.
  static String notLoadable(
    AppLocalizations l10n,
    r.NotLoadable result,
    ExerciseWeightUnit weightUnit, {
    String? locale,
  }) {
    final options = [
      for (final value in [result.below, result.above])
        if (value != null) amount(value, locale: locale),
    ];
    if (options.isEmpty) return l10n.plateNotLoadablePlates;
    return l10n.plateNotLoadableOptions(
      options.length == 1
          ? options.single
          : l10n.plateOr(options[0], options[1]),
      unit(weightUnit),
    );
  }

  /// "Pin 14 + 2 kg" for [total] on a stack with add-ons, "Pin 14 kg" when
  /// no add-on is needed; `null` for anything else.
  static String? stackSummary(
    AppLocalizations l10n,
    r.WeightStep step,
    double? total,
    ExerciseWeightUnit weightUnit, {
    String? locale,
  }) {
    final breakdown = total == null ? null : step.stack?.breakdown(total);
    if (breakdown == null) return null;
    final pin = amount(breakdown.pin, locale: locale);
    if (breakdown.addOns.isEmpty) return l10n.stackPin(pin, unit(weightUnit));
    return l10n.stackPinAddOns(
      pin,
      [for (final a in breakdown.addOns) amount(a, locale: locale)].join(' + '),
      unit(weightUnit),
    );
  }

  // MARK: - Set kinds

  /// A line of the set type menu: "Standard", "Warm-up", "Drop Set"…
  static String setType(AppLocalizations l10n, r.SetTypeChoice choice) =>
      switch (choice.kind) {
        null => l10n.trackerSetTypeWarmup,
        r.SetKind.standard => l10n.trackerSetTypeStandard,
        r.SetKind.drop => l10n.trackerSetTypeDrop,
        r.SetKind.amrap => l10n.trackerSetTypeAmrap,
        r.SetKind.myo => l10n.trackerSetTypeMyo,
        r.SetKind.restPause => l10n.trackerSetTypeRestPause,
        r.SetKind.cluster => l10n.trackerSetTypeCluster,
        r.SetKind.partials => l10n.trackerSetTypePartials,
        r.SetKind.stretch => l10n.trackerSetTypeStretch,
        r.SetKind.hold => l10n.trackerSetTypeHold,
      };

  /// A piece's own name after its set: "Partials", "Stretch", "Hold".
  static String? pieceName(AppLocalizations l10n, r.SetKind kind) =>
      switch (kind) {
        r.SetKind.partials => l10n.setKindPartials,
        r.SetKind.stretch => l10n.setKindStretch,
        r.SetKind.hold => l10n.setKindHold,
        _ => null,
      };

  /// The chip under a row's number: "Drop", a piece's name or "Mini", and
  /// "Failure" or "Failure 8+" on a set to failure; `null` for the rest.
  static String? kindChip(AppLocalizations l10n, WorkoutSetModel set) {
    final rules = rulesSet(set);
    return switch (r.subSetKindOf(rules)) {
      r.SubSetKind.drop => l10n.trackerChipDrop,
      r.SubSetKind.mini => pieceName(l10n, rules.kind) ?? l10n.trackerChipMini,
      null when rules.kind == r.SetKind.amrap && !set.isWarmup =>
        switch (set.targetReps) {
          final target? => l10n.trackerChipFailureTarget(
            AppFormat.number(target),
          ),
          null => l10n.trackerChipFailure,
        },
      null => null,
    };
  }

  /// A set to failure's open reps hint at the plan's target: "8+".
  static String? targetPlaceholder(WorkoutSetModel set) {
    final rules = rulesSet(set);
    final target = set.targetReps;
    if (rules.kind != r.SetKind.amrap ||
        rules.isSubSet ||
        set.isWarmup ||
        set.reps != null ||
        target == null) {
      return null;
    }
    return '$target+';
  }

  /// The row's delete action: "Delete Drop Set", "Delete Partials"…
  static String deleteTitle(AppLocalizations l10n, WorkoutSetModel set) {
    final rules = rulesSet(set);
    return switch (r.subSetKindOf(rules)) {
      r.SubSetKind.drop => l10n.trackerDeleteDropSet,
      r.SubSetKind.mini => switch (rules.kind) {
        r.SetKind.partials => l10n.trackerDeletePartials,
        r.SetKind.stretch => l10n.trackerDeleteStretch,
        r.SetKind.hold => l10n.trackerDeleteHold,
        _ => l10n.trackerDeleteMiniSet,
      },
      null => l10n.trackerDeleteSet,
    };
  }

  /// A row's name in an alert: "Set 2", "Set 1L", "Warm-up set".
  static String setName(
    AppLocalizations l10n,
    WorkoutSetModel set,
    String badge,
  ) => set.isWarmup ? l10n.trackerWarmupSetName : l10n.trackerSetName(badge);

  /// "This also deletes its 2 drop sets.", or `null` when it takes none.
  static String? subSetsDeleted(
    AppLocalizations l10n,
    ({int drops, int minis}) removed,
  ) => switch (removed) {
    (drops: 0, minis: 0) => null,
    (:final drops, minis: 0) => l10n.trackerDeleteAlsoDrops(drops),
    (drops: 0, :final minis) => l10n.trackerDeleteAlsoMinis(minis),
    (:final drops, :final minis) => l10n.trackerDeleteAlsoBoth(drops + minis),
  };

  // MARK: - The progression note

  /// Why smart progression changed today's numbers, in a sentence: "+2.5 kg
  /// today. You hit 5 reps on every working set last time."
  /// (`ActiveWorkout.progressionReason`).
  static String progressionReason(
    AppLocalizations l10n,
    r.ProgressionReason reason,
    ExerciseWeightUnit unit, {
    String? locale,
  }) {
    switch (reason.rationale) {
      case r.Rationale.addReps:
        return l10n.trackerReasonAddReps(l10n.repCount(reason.addedReps ?? 0));
      case r.Rationale.deload:
        return l10n.trackerReasonDeload(
          signedWeight(reason.changeKg ?? 0, unit, locale: locale),
        );
      case r.Rationale.progressWeight ||
          r.Rationale.hold ||
          r.Rationale.noHistory:
        final change = signedWeight(reason.changeKg ?? 0, unit, locale: locale);
        final reps = reason.lastMinReps;
        return reps == null
            ? l10n.trackerReasonChange(change)
            : l10n.trackerReasonProgress(change, l10n.repCount(reps));
    }
  }

  /// "+2.5 kg", "−5 lb": a change in the exercise's own unit.
  static String signedWeight(
    double kilograms,
    ExerciseWeightUnit unit, {
    String? locale,
  }) {
    final text = AppFormat.weight(
      kilograms.abs(),
      WorkoutText.weightUnit(unit),
      maxFractionDigits: 2,
      locale: locale,
    );
    return kilograms < 0 ? '−$text' : '+$text';
  }

  /// The plan [exercise] opens with, for the progression note: "Set 3 is a
  /// drop set from your plan: 100 × 8, then 80 and 64 to failure, no rest
  /// between. Set 4 is to failure, target 8+." Only drops and mini-sets under
  /// a set, and failure targets; null once a working set is logged or with
  /// no plan to tell (`ActiveWorkout.planSummary`).
  static String? planSummary(
    AppLocalizations l10n,
    WorkoutExerciseModel exercise,
    ExerciseWeightUnit unit, {
    String? locale,
  }) {
    final rules = rulesExercise(exercise);
    if (rules.sets.any((s) => !s.isWarmup && s.completedAt != null)) {
      return null;
    }
    final mode = exercise.trackingMode;
    String? plain(r.WorkoutSet set) {
      final kg = set.loadKg;
      if (mode != TrackingMode.weightReps || kg == null || kg == 0) {
        return null;
      }
      return AppFormat.number(
        r.convertWeight(kg, unit.rules),
        maxFractionDigits: 1,
        locale: locale,
      );
    }

    String figures(r.WorkoutSet set) => switch ((plain(set), set.reps)) {
      (final weight?, final reps?) => '$weight × $reps',
      (final weight?, null) => weight,
      (null, final reps?) => l10n.repCount(reps),
      (null, null) => AppFormat.placeholder,
    };

    final sentences = <String>[];
    // A left/right pair is one set: its left row speaks for it.
    for (final set in rules.sets.where(
      (s) => !s.isWarmup && !s.isSubSet && s.side != r.SetSide.right,
    )) {
      final number = rules.workingSetNumber(set);
      final pieces = r.ActiveWorkout.subSets(
        set.id,
        rules.sets,
      ).where((p) => p.side == set.side).toList();
      final target = set.targetReps;
      if (set.kind == r.SetKind.amrap && target != null) {
        sentences.add(l10n.trackerPlanFailure(number, target));
        continue;
      }
      final drops = [
        for (final piece in pieces)
          if (r.subSetKindOf(piece) == r.SubSetKind.drop) piece,
      ];
      if (drops.isNotEmpty) {
        final weights = listAnd(l10n, [
          for (final drop in drops) plain(drop) ?? AppFormat.placeholder,
        ]);
        final reps = drops.first.reps;
        sentences.add(
          reps == null
              ? l10n.trackerPlanDropFailure(number, figures(set), weights)
              : l10n.trackerPlanDropReps(number, figures(set), weights, reps),
        );
        continue;
      }
      // Mini-sets are stored plain; partials, a stretch or a hold are not.
      final minis = pieces
          .where(
            (p) =>
                r.subSetKindOf(p) == r.SubSetKind.mini &&
                p.kind == r.SetKind.standard,
          )
          .length;
      if (minis > 0) {
        sentences.add(
          l10n.trackerPlanMinis(
            number,
            set.kind == r.SetKind.myo
                ? l10n.trackerMyoReps
                : setType(l10n, r.SetTypeChoice.ofKind(set.kind)),
            figures(set),
            l10n.trackerMiniSetCount(minis),
          ),
        );
      }
    }
    return sentences.isEmpty ? null : sentences.join(' ');
  }

  /// "80", "80 and 64", "80, 64, and 50".
  static String listAnd(AppLocalizations l10n, List<String> items) =>
      switch (items) {
        [final only] => only,
        [final first, final second] => l10n.trackerListAndTwo(first, second),
        _ => l10n.trackerListAndMany(
          items.sublist(0, items.length - 1).join(', '),
          items.last,
        ),
      };
}
