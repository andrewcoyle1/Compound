import 'package:compound_models/compound_models.dart';
import 'package:training_rules/training_rules.dart'
    as rules
    show ExerciseType, RestDurationRules;

/// What the training settings screens read off a [WorkoutSettings]: Swift's
/// computed properties for the optional fields, where nil reads as a
/// default (`WorkoutSettings.swift`).
extension WorkoutSettingsReading on WorkoutSettings {
  /// The Live Activity; nil reads as on.
  bool get showsOnLockScreen => showOnLockScreen ?? true;

  /// Set Plan; nil reads as off.
  bool get plansSets => setPlanning ?? false;

  /// An AMRAP target beaten twice goes up a rep; nil reads as on.
  bool get raisesAmrapTarget => amrapRaisesTarget ?? true;

  /// The AMRAP target at which weight goes on instead; nil, and the legacy
  /// "never", read as 12.
  int get amrapWeightCeiling => switch (amrapAddsWeightAtTarget) {
    null || legacyNeverAddsWeight => 12,
    final target => target,
  };

  /// Whether reaching [amrapWeightCeiling] adds weight; nil reads as on,
  /// unless an older build saved off as the unreachable target.
  bool get addsWeightAtAmrapTarget =>
      amrapAddsWeight ?? amrapAddsWeightAtTarget != legacyNeverAddsWeight;

  /// The rest within a set of [kind], falling back to the older single
  /// rest, then the kind's own default.
  int intraSetRest(IntraSetKind kind) =>
      switch (kind) {
        IntraSetKind.myo => intraSetRestMyoSeconds,
        IntraSetKind.restPause => intraSetRestPauseSeconds,
        IntraSetKind.cluster => intraSetRestClusterSeconds,
      } ??
      intraSetRestSeconds ??
      kind.defaultSeconds;

  /// The rest after a set of [type]: the user's, else the default the
  /// tracker uses for a moderate set (`TimerDurationPresenter.duration`).
  int restDuration(ExerciseType type) =>
      restDurationsByExerciseType[type.value] ??
      rules.RestDurationRules.defaultSeconds(
        rules.ExerciseType.values.byName(type.name),
        null,
      );

  /// Builds older builds stored `Int.max` here to mean "never adds weight".
  static const legacyNeverAddsWeight = 0x7FFFFFFFFFFFFFFF;
}

/// This [WorkoutSettings] with [fields] (keys from [WorkoutSettingsKeys])
/// set; a null clears an optional field.
WorkoutSettings withFields(
  WorkoutSettings settings,
  Map<String, Object?> fields,
) => WorkoutSettings.fromFirestore({...settings.toFirestore(), ...fields});

/// The kinds of set that rest between their pieces (a drop set changes the
/// weight and goes on).
enum IntraSetKind {
  myo(WorkoutSettingsKeys.intraSetRestMyoSeconds, 15, [10, 15, 20]),
  restPause(WorkoutSettingsKeys.intraSetRestPauseSeconds, 20, [15, 20, 30]),
  cluster(WorkoutSettingsKeys.intraSetRestClusterSeconds, 15, [10, 15, 20]);

  new(this.key, this.defaultSeconds, this.options);

  /// The field it is stored in.
  final String key;

  /// The rest when nothing is stored.
  final int defaultSeconds;

  /// The rests offered: a rest-pause set rests a little longer.
  final List<int> options;
}

/// The three rest scalings, each in its own field.
enum RestScaling {
  warmUp(WorkoutSettingsKeys.warmUpRestScaling),
  betweenExercises(WorkoutSettingsKeys.betweenExercisesRestScaling),
  sideSets(WorkoutSettingsKeys.sideSetRestScaling);

  new(this.key);

  /// The field it is stored in.
  final String key;

  /// The scalings offered.
  static const options = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  /// Its value in [settings].
  double of(WorkoutSettings settings) => switch (this) {
    warmUp => settings.warmUpRestScaling,
    betweenExercises => settings.betweenExercisesRestScaling,
    sideSets => settings.sideSetRestScaling,
  };
}

/// The rests offered between superset partners; null is none.
const supersetTransitionRestOptions = <int?>[null, 15, 30];

/// The AMRAP targets the stepper can set as where weight goes on.
const ({int min, int max}) amrapCeilingRange = (min: 8, max: 20);

/// The change that sets the AMRAP target which adds weight to [target],
/// held to [amrapCeilingRange] whatever asks for it.
Map<String, Object?> amrapCeilingChange(int target) => {
  WorkoutSettingsKeys.amrapAddsWeightAtTarget: target.clamp(
    amrapCeilingRange.min,
    amrapCeilingRange.max,
  ),
};

/// One exercise's own rest, for Timer Duration's Exercise Timers.
typedef ExerciseRestOverride = ({String id, String name, int seconds});

/// The exercises in [library] with a rest override in [settings], by name;
/// an override whose exercise is gone is left out
/// (`TimerDurationPresenter.exerciseOverrides`).
List<ExerciseRestOverride> exerciseRestOverrides(
  List<ExerciseSettingsModel> settings,
  List<ExerciseModel> library,
) {
  final names = {for (final exercise in library) exercise.id: exercise.name};
  return [
    for (final setting in settings)
      if ((setting.restDurationOverride, names[setting.id]) case (
        final seconds?,
        final name?,
      ))
        (id: setting.id, name: name, seconds: seconds),
  ]..sort((a, b) => a.name.compareTo(b.name));
}

/// The exercises in [library] without an override yet, by name.
List<ExerciseModel> exercisesWithoutRestOverride(
  List<ExerciseRestOverride> overrides,
  List<ExerciseModel> library,
) {
  final overridden = {for (final override in overrides) override.id};
  return [
    for (final exercise in library)
      if (!overridden.contains(exercise.id)) exercise,
  ]..sort((a, b) => a.name.compareTo(b.name));
}
