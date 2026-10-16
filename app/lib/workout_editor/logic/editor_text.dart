import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The workout editor's words (`SetTargetPlan.swift`,
/// `SetTargetPlan+Exercise.swift`, `DefineWorkoutRules.planSummary`), kept
/// apart from the screens so they are tested rather than eyeballed.
class const EditorText(final AppLocalizations l10n, {final String? locale}) {
  /// A kind of set as it reads in the picker and on the chip.
  String kindTitle(SetTargetSetType type) => switch (type) {
    SetTargetSetType.standard => l10n.editorKindStandard,
    SetTargetSetType.failure ||
    SetTargetSetType.amrap => l10n.editorKindFailure,
    SetTargetSetType.myo => l10n.editorKindMyo,
    SetTargetSetType.restPause => l10n.editorKindRestPause,
    SetTargetSetType.cluster => l10n.editorKindCluster,
    SetTargetSetType.drop => l10n.editorKindDrop,
    SetTargetSetType.partials => l10n.editorKindPartials,
    SetTargetSetType.stretch => l10n.editorKindStretch,
    SetTargetSetType.hold => l10n.editorKindHold,
  };

  /// The chip after the set number: the kind, and a failure set's target
  /// as "Failure 8+". A standard set has none.
  String? chip(SetTarget target) => switch (target.setType) {
    SetTargetSetType.standard => null,
    SetTargetSetType.failure ||
    SetTargetSetType.amrap => switch (target.amrapTargetReps) {
      final reps? => l10n.editorFailureChip(reps),
      null => kindTitle(target.setType),
    },
    _ => kindTitle(target.setType),
  };

  /// "−20%", a drop's step.
  String dropStepTitle(int percent) =>
      '−${AppFormat.percent(percent / 100, locale: locale)}';

  /// The line under a planned set: "8 reps, then −20% ×2 to failure", "As
  /// many as possible, target 8", "3 mini-sets, 15 s breath", "8 reps, then
  /// a 30 s hold". Null for a standard set.
  String? summary(SetTarget target, WorkoutSettings settings) {
    switch (target.setType) {
      case SetTargetSetType.standard:
        return null;
      case SetTargetSetType.failure || SetTargetSetType.amrap:
        return switch (target.amrapTargetReps) {
          final reps? => l10n.editorAmrapTarget(reps),
          null => l10n.editorAmrap,
        };
      case SetTargetSetType.drop:
        final reps = _reps(target);
        final count = target.dropCount ?? 0;
        if (count <= 0) return reps;
        final steps = '${dropStepTitle(target.dropStep)} ×$count';
        final drops = switch (target.dropReps) {
          final each? => '$steps, ${l10n.editorEach(l10n.repCount(each))}',
          null => '$steps ${l10n.editorToFailure}',
        };
        return reps == null ? drops : l10n.editorThen(reps, drops);
      case SetTargetSetType.myo ||
          SetTargetSetType.restPause ||
          SetTargetSetType.cluster:
        final count = target.miniSetCount ?? 0;
        if (count <= 0) return _reps(target);
        return l10n.editorBreath(
          l10n.editorMiniSets(count),
          l10n.editorSeconds(intraSetRest(settings, target.setType)),
        );
      case SetTargetSetType.partials:
        return _then(switch (target.partialReps) {
          final reps? => l10n.editorPartials(reps),
          null => l10n.editorPartialsToFailure,
        }, target);
      case SetTargetSetType.stretch:
        return switch (target.holdSeconds) {
          final seconds? => _then(l10n.editorStretch(seconds), target),
          null => _reps(target),
        };
      case SetTargetSetType.hold:
        return switch (target.holdSeconds) {
          final seconds? => _then(l10n.editorHold(seconds), target),
          null => _reps(target),
        };
    }
  }

  /// The breath within a myo-rep, rest-pause or cluster set
  /// (`WorkoutSettings.intraSetRest(for:)`).
  static int intraSetRest(
    WorkoutSettings settings,
    SetTargetSetType type,
  ) => switch (type) {
    SetTargetSetType.restPause =>
      settings.intraSetRestPauseSeconds ?? settings.intraSetRestSeconds ?? 20,
    SetTargetSetType.cluster =>
      settings.intraSetRestClusterSeconds ?? settings.intraSetRestSeconds ?? 15,
    _ => settings.intraSetRestMyoSeconds ?? settings.intraSetRestSeconds ?? 15,
  };

  String _then(String piece, SetTarget target) => switch (_reps(target)) {
    final reps? => l10n.editorThen(reps, piece),
    null => piece,
  };

  /// "8 reps", "8–12 reps", or null when the set plans no reps.
  String? _reps(SetTarget target) => switch ((target.minReps, target.maxReps)) {
    (final min?, final max?) when min != max => l10n.editorRepRange(
      AppFormat.repRange(
        min < max ? min : max,
        min < max ? max : min,
        locale: locale,
      ),
    ),
    (final reps?, _) || (null, final reps?) => l10n.repCount(reps),
    (null, null) => null,
  };

  /// "Week 3", "Weeks 2–8", or "From week 9" for the last, which runs on.
  String weeksTitle(int from, int? through) {
    if (through == null) return l10n.editorFromWeek(from);
    return from >= through
        ? l10n.editorWeek(from)
        : l10n.editorWeeks(from, through);
  }

  /// "Week 1: 2 sets · From week 2: 3 sets", or that nothing varies.
  String variationSummary(
    List<SetTarget> base,
    List<MicrocycleSetTargets> overrides,
  ) {
    final segments = WorkoutEditorRules.variationSegments(base, overrides);
    if (segments == null) return l10n.editorSameEveryWeek;
    return [
      for (final segment in segments)
        l10n.editorSegment(
          weeksTitle(segment.from, segment.through),
          l10n.setCount(segment.sets),
        ),
    ].join(' · ');
  }

  /// "3 warm-ups · 2:00 rest · 2 alternatives · notes · link · varies by
  /// week", only the parts the plan sets; null when it sets none.
  String? planSummary(WorkoutTemplateExercise exercise) {
    final parts = [
      if (exercise.warmupSetCount case final count?) l10n.warmupCount(count),
      if (exercise.restSeconds case final rest? when rest > 0)
        l10n.editorRestPart(restTitle(rest)),
      if (exercise.substituteExerciseIds.isNotEmpty)
        l10n.editorAlternatives(exercise.substituteExerciseIds.length),
      if (exercise.notes?.trim().isNotEmpty ?? false) l10n.editorNotesPart,
      if (exercise.linkUrl != null) l10n.editorLinkPart,
      if (exercise.setTargetsByMicrocycle.isNotEmpty) l10n.editorVariesByWeek,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// A rest as "1:30", or Automatic.
  String restTitle(int? seconds) => seconds == null
      ? l10n.editorAutomatic
      : AppFormat.duration(Duration(seconds: seconds));

  /// A warm-up count, or Automatic.
  String warmupTitle(int? count) =>
      count == null ? l10n.editorAutomatic : '$count';

  /// The reps in reserve a set aims for, "0" to "6+", or a dash.
  static String rirText(int? rir) => switch (rir) {
    null => AppFormat.placeholder,
    >= 6 => '6+',
    final rir => '$rir',
  };
}
