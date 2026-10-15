import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/library_enums.dart';

/// Field names of a [WorkoutSettings], exactly as the Swift `CodingKeys`
/// spell them.
abstract final class WorkoutSettingsKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `previous_workout_reference`.
  static const previousWorkoutReference = 'previous_workout_reference';

  /// `propagate_changes`.
  static const propagateChanges = 'propagate_changes';

  /// `rir_tracking`.
  static const rirTracking = 'rir_tracking';

  /// `superset_auto_scroll`.
  static const supersetAutoScroll = 'superset_auto_scroll';

  /// `exercise_auto_next`.
  static const exerciseAutoNext = 'exercise_auto_next';

  /// `keep_alive`.
  static const keepAlive = 'keep_alive';

  /// `show_workout_timer`.
  static const showWorkoutTimer = 'show_workout_timer';

  /// `show_bodyweight_contribution`.
  static const showBodyweightContribution = 'show_bodyweight_contribution';

  /// `show_on_lock_screen`.
  static const showOnLockScreen = 'show_on_lock_screen';

  /// `set_planning`.
  static const setPlanning = 'set_planning';

  /// `add_smart_warm_ups`.
  static const addSmartWarmUps = 'add_smart_warm_ups';

  /// `smart_progression_apply_in_session`.
  static const smartProgressionApplyInSession =
      'smart_progression_apply_in_session';

  /// `smart_progression_initial_log_fill`.
  static const smartProgressionInitialLogFill =
      'smart_progression_initial_log_fill';

  /// `smart_progression_adjustment_mode`.
  static const smartProgressionAdjustmentMode =
      'smart_progression_adjustment_mode';

  /// `amrap_raises_target`.
  static const amrapRaisesTarget = 'amrap_raises_target';

  /// `amrap_adds_weight_at_target`.
  static const amrapAddsWeightAtTarget = 'amrap_adds_weight_at_target';

  /// `amrap_adds_weight`.
  static const amrapAddsWeight = 'amrap_adds_weight';

  /// `use_rest_timers`.
  static const useRestTimers = 'use_rest_timers';

  /// `rest_after_last_warm_up`.
  static const restAfterLastWarmUp = 'rest_after_last_warm_up';

  /// `rest_between_exercises`.
  static const restBetweenExercises = 'rest_between_exercises';

  /// `rest_between_side_sets`.
  static const restBetweenSideSets = 'rest_between_side_sets';

  /// `superset_transition_rest_seconds`.
  static const supersetTransitionRestSeconds =
      'superset_transition_rest_seconds';

  /// `intra_set_rest_seconds`.
  static const intraSetRestSeconds = 'intra_set_rest_seconds';

  /// `intra_set_rest_myo_seconds`.
  static const intraSetRestMyoSeconds = 'intra_set_rest_myo_seconds';

  /// `intra_set_rest_pause_seconds`.
  static const intraSetRestPauseSeconds = 'intra_set_rest_pause_seconds';

  /// `intra_set_rest_cluster_seconds`.
  static const intraSetRestClusterSeconds = 'intra_set_rest_cluster_seconds';

  /// `rest_timer_play_sound`.
  static const restTimerPlaySound = 'rest_timer_play_sound';

  /// `rest_timer_vibrate`.
  static const restTimerVibrate = 'rest_timer_vibrate';

  /// `warm_up_rest_scaling`.
  static const warmUpRestScaling = 'warm_up_rest_scaling';

  /// `between_exercises_rest_scaling`.
  static const betweenExercisesRestScaling = 'between_exercises_rest_scaling';

  /// `side_set_rest_scaling`.
  static const sideSetRestScaling = 'side_set_rest_scaling';

  /// `rest_durations_by_exercise_type`.
  static const restDurationsByExerciseType = 'rest_durations_by_exercise_type';

  /// `default_rest_duration_seconds`.
  static const defaultRestDurationSeconds = 'default_rest_duration_seconds';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    previousWorkoutReference,
    propagateChanges,
    rirTracking,
    supersetAutoScroll,
    exerciseAutoNext,
    keepAlive,
    showWorkoutTimer,
    showBodyweightContribution,
    showOnLockScreen,
    setPlanning,
    addSmartWarmUps,
    smartProgressionApplyInSession,
    smartProgressionInitialLogFill,
    smartProgressionAdjustmentMode,
    amrapRaisesTarget,
    amrapAddsWeightAtTarget,
    amrapAddsWeight,
    useRestTimers,
    restAfterLastWarmUp,
    restBetweenExercises,
    restBetweenSideSets,
    supersetTransitionRestSeconds,
    intraSetRestSeconds,
    intraSetRestMyoSeconds,
    intraSetRestPauseSeconds,
    intraSetRestClusterSeconds,
    restTimerPlaySound,
    restTimerVibrate,
    warmUpRestScaling,
    betweenExercisesRestScaling,
    sideSetRestScaling,
    restDurationsByExerciseType,
    defaultRestDurationSeconds,
  ];
}

/// The user's workout settings, at
/// `users/{uid}/workout_settings/workout_settings` (Swift `WorkoutSettings`).
/// The defaults are Swift's, which apply when there is no document.
class const WorkoutSettings({
  /// The user.
  required final String authorId,

  /// The document id, always `workout_settings`.
  final String id = 'workout_settings',

  /// Which past session previous values come from.
  final PreviousWorkoutReferenceOption previousWorkoutReference =
      PreviousWorkoutReferenceOption.sameWorkout,

  /// Whether a session's changes carry to its template.
  final bool propagateChanges = true,

  /// Whether sets record reps in reserve.
  final bool rirTracking = false,

  /// Whether the tracker scrolls between superset partners.
  final bool supersetAutoScroll = true,

  /// Whether the tracker moves to the next exercise when one is done.
  final bool exerciseAutoNext = true,

  /// Whether the screen stays on during a workout.
  final bool keepAlive = true,

  /// Whether the workout's elapsed time shows.
  final bool showWorkoutTimer = true,

  /// Whether body weight shows in a set's load.
  final bool showBodyweightContribution = false,

  /// The Live Activity; null, as saved before the setting, reads as on.
  final bool? showOnLockScreen,

  /// The set plan; null reads as off.
  final bool? setPlanning,

  /// Whether warm-up sets are added.
  final bool addSmartWarmUps = true,

  /// Whether progression adjusts sets mid-session.
  final bool smartProgressionApplyInSession = false,

  /// What a new session's sets are filled with.
  final InitialLogFillOption smartProgressionInitialLogFill =
      InitialLogFillOption.smartProgression,

  /// Whether progression adds weight or reps first.
  final ProgressionAdjustmentMode smartProgressionAdjustmentMode =
      ProgressionAdjustmentMode.weightFirst,

  /// Whether a beaten AMRAP target rises; null reads as on.
  final bool? amrapRaisesTarget,

  /// The AMRAP target at which weight is added instead; null reads as
  /// 12. Older builds stored the largest 64-bit integer for never.
  final int? amrapAddsWeightAtTarget,

  /// Whether reaching that target adds weight; null reads as on, unless
  /// [amrapAddsWeightAtTarget] holds the older builds' never.
  final bool? amrapAddsWeight,

  /// Whether rest timers run.
  final bool useRestTimers = true,

  /// Whether a rest follows the last warm-up set.
  final bool restAfterLastWarmUp = true,

  /// Whether a rest follows an exercise's last set.
  final bool restBetweenExercises = true,

  /// Whether a rest separates the two sides of a set.
  final bool restBetweenSideSets = false,

  /// The rest between superset partners, in seconds; null is none.
  final int? supersetTransitionRestSeconds,

  /// The breath within a myo-rep, rest-pause or cluster set, in seconds;
  /// the fallback for the three below. Null reads as 15.
  final int? intraSetRestSeconds,

  /// The breath within a myo-rep set, in seconds.
  final int? intraSetRestMyoSeconds,

  /// The breath within a rest-pause set, in seconds.
  final int? intraSetRestPauseSeconds,

  /// The breath within a cluster set, in seconds.
  final int? intraSetRestClusterSeconds,

  /// Whether a finished rest plays a sound.
  final bool restTimerPlaySound = true,

  /// Whether a finished rest vibrates.
  final bool restTimerVibrate = true,

  /// The share of the rest a warm-up set gets.
  final double warmUpRestScaling = 0.75,

  /// The share of the rest between exercises.
  final double betweenExercisesRestScaling = 1,

  /// The share of the rest between sides.
  final double sideSetRestScaling = 0.5,

  /// Rest in seconds by `ExerciseType` value.
  final Map<String, int> restDurationsByExerciseType = const {},

  /// The rest in seconds when nothing else sets one.
  final int defaultRestDurationSeconds = 90,
}) {
  /// Creates a [WorkoutSettings].
  this;

  /// Decodes as Swift's synthesized decoder does: every field but the
  /// optional ones is required, so a document missing one does not decode.
  /// A field an older build wrote and this one no longer has is ignored.
  factory fromFirestore(Map<String, Object?> data) => WorkoutSettings(
    id: data[WorkoutSettingsKeys.id]! as String,
    authorId: data[WorkoutSettingsKeys.authorId]! as String,
    previousWorkoutReference: enumFromValue(
      PreviousWorkoutReferenceOption.values,
      data[WorkoutSettingsKeys.previousWorkoutReference]! as String,
    ),
    propagateChanges: data[WorkoutSettingsKeys.propagateChanges]! as bool,
    rirTracking: data[WorkoutSettingsKeys.rirTracking]! as bool,
    supersetAutoScroll: data[WorkoutSettingsKeys.supersetAutoScroll]! as bool,
    exerciseAutoNext: data[WorkoutSettingsKeys.exerciseAutoNext]! as bool,
    keepAlive: data[WorkoutSettingsKeys.keepAlive]! as bool,
    showWorkoutTimer: data[WorkoutSettingsKeys.showWorkoutTimer]! as bool,
    showBodyweightContribution:
        data[WorkoutSettingsKeys.showBodyweightContribution]! as bool,
    showOnLockScreen: data[WorkoutSettingsKeys.showOnLockScreen] as bool?,
    setPlanning: data[WorkoutSettingsKeys.setPlanning] as bool?,
    addSmartWarmUps: data[WorkoutSettingsKeys.addSmartWarmUps]! as bool,
    smartProgressionApplyInSession:
        data[WorkoutSettingsKeys.smartProgressionApplyInSession]! as bool,
    smartProgressionInitialLogFill: enumFromValue(
      InitialLogFillOption.values,
      data[WorkoutSettingsKeys.smartProgressionInitialLogFill]! as String,
    ),
    smartProgressionAdjustmentMode: enumFromValue(
      ProgressionAdjustmentMode.values,
      data[WorkoutSettingsKeys.smartProgressionAdjustmentMode]! as String,
    ),
    amrapRaisesTarget: data[WorkoutSettingsKeys.amrapRaisesTarget] as bool?,
    amrapAddsWeightAtTarget: readOptionalInt(
      data[WorkoutSettingsKeys.amrapAddsWeightAtTarget],
    ),
    amrapAddsWeight: data[WorkoutSettingsKeys.amrapAddsWeight] as bool?,
    useRestTimers: data[WorkoutSettingsKeys.useRestTimers]! as bool,
    restAfterLastWarmUp: data[WorkoutSettingsKeys.restAfterLastWarmUp]! as bool,
    restBetweenExercises:
        data[WorkoutSettingsKeys.restBetweenExercises]! as bool,
    restBetweenSideSets: data[WorkoutSettingsKeys.restBetweenSideSets]! as bool,
    supersetTransitionRestSeconds: readOptionalInt(
      data[WorkoutSettingsKeys.supersetTransitionRestSeconds],
    ),
    intraSetRestSeconds: readOptionalInt(
      data[WorkoutSettingsKeys.intraSetRestSeconds],
    ),
    intraSetRestMyoSeconds: readOptionalInt(
      data[WorkoutSettingsKeys.intraSetRestMyoSeconds],
    ),
    intraSetRestPauseSeconds: readOptionalInt(
      data[WorkoutSettingsKeys.intraSetRestPauseSeconds],
    ),
    intraSetRestClusterSeconds: readOptionalInt(
      data[WorkoutSettingsKeys.intraSetRestClusterSeconds],
    ),
    restTimerPlaySound: data[WorkoutSettingsKeys.restTimerPlaySound]! as bool,
    restTimerVibrate: data[WorkoutSettingsKeys.restTimerVibrate]! as bool,
    warmUpRestScaling: readDouble(data[WorkoutSettingsKeys.warmUpRestScaling]),
    betweenExercisesRestScaling: readDouble(
      data[WorkoutSettingsKeys.betweenExercisesRestScaling],
    ),
    sideSetRestScaling: readDouble(
      data[WorkoutSettingsKeys.sideSetRestScaling],
    ),
    restDurationsByExerciseType: readMap(
      data[WorkoutSettingsKeys.restDurationsByExerciseType],
    ).map((type, seconds) => MapEntry(type, readInt(seconds))),
    defaultRestDurationSeconds: readInt(
      data[WorkoutSettingsKeys.defaultRestDurationSeconds],
    ),
  );

  /// The Firestore-shaped map Swift writes, a null field left out.
  Map<String, Object?> toFirestore() => {
    WorkoutSettingsKeys.id: id,
    WorkoutSettingsKeys.authorId: authorId,
    WorkoutSettingsKeys.previousWorkoutReference:
        previousWorkoutReference.value,
    WorkoutSettingsKeys.propagateChanges: propagateChanges,
    WorkoutSettingsKeys.rirTracking: rirTracking,
    WorkoutSettingsKeys.supersetAutoScroll: supersetAutoScroll,
    WorkoutSettingsKeys.exerciseAutoNext: exerciseAutoNext,
    WorkoutSettingsKeys.keepAlive: keepAlive,
    WorkoutSettingsKeys.showWorkoutTimer: showWorkoutTimer,
    WorkoutSettingsKeys.showBodyweightContribution: showBodyweightContribution,
    WorkoutSettingsKeys.showOnLockScreen: ?showOnLockScreen,
    WorkoutSettingsKeys.setPlanning: ?setPlanning,
    WorkoutSettingsKeys.addSmartWarmUps: addSmartWarmUps,
    WorkoutSettingsKeys.smartProgressionApplyInSession:
        smartProgressionApplyInSession,
    WorkoutSettingsKeys.smartProgressionInitialLogFill:
        smartProgressionInitialLogFill.value,
    WorkoutSettingsKeys.smartProgressionAdjustmentMode:
        smartProgressionAdjustmentMode.value,
    WorkoutSettingsKeys.amrapRaisesTarget: ?amrapRaisesTarget,
    WorkoutSettingsKeys.amrapAddsWeightAtTarget: ?amrapAddsWeightAtTarget,
    WorkoutSettingsKeys.amrapAddsWeight: ?amrapAddsWeight,
    WorkoutSettingsKeys.useRestTimers: useRestTimers,
    WorkoutSettingsKeys.restAfterLastWarmUp: restAfterLastWarmUp,
    WorkoutSettingsKeys.restBetweenExercises: restBetweenExercises,
    WorkoutSettingsKeys.restBetweenSideSets: restBetweenSideSets,
    WorkoutSettingsKeys.supersetTransitionRestSeconds:
        ?supersetTransitionRestSeconds,
    WorkoutSettingsKeys.intraSetRestSeconds: ?intraSetRestSeconds,
    WorkoutSettingsKeys.intraSetRestMyoSeconds: ?intraSetRestMyoSeconds,
    WorkoutSettingsKeys.intraSetRestPauseSeconds: ?intraSetRestPauseSeconds,
    WorkoutSettingsKeys.intraSetRestClusterSeconds: ?intraSetRestClusterSeconds,
    WorkoutSettingsKeys.restTimerPlaySound: restTimerPlaySound,
    WorkoutSettingsKeys.restTimerVibrate: restTimerVibrate,
    WorkoutSettingsKeys.warmUpRestScaling: warmUpRestScaling,
    WorkoutSettingsKeys.betweenExercisesRestScaling:
        betweenExercisesRestScaling,
    WorkoutSettingsKeys.sideSetRestScaling: sideSetRestScaling,
    WorkoutSettingsKeys.restDurationsByExerciseType:
        restDurationsByExerciseType,
    WorkoutSettingsKeys.defaultRestDurationSeconds: defaultRestDurationSeconds,
  };
}
