/// What a session reads off a library exercise: how it is tracked, whether
/// it is worked a side at a time or with assistance, and its picture
/// (`WorkoutSessionModel.trackingMode(for:)`, `.isPerSide`,
/// `ExerciseModel.isAssisted`, `Constants.exerciseImageName`).
library;

import 'package:compound_models/compound_models.dart';

/// The library's helpers for one exercise.
extension LibraryExercise on ExerciseModel {
  /// Weight first, then distance, then time; otherwise reps.
  TrackingMode get trackingMode {
    bool tracks(Set<TrackableExerciseMetric> metrics) =>
        trackableMetrics.any(metrics.contains);
    if (tracks(const {
      TrackableExerciseMetric.weight,
      TrackableExerciseMetric.weightPerSide,
      TrackableExerciseMetric.weightPerSidePersistent,
      TrackableExerciseMetric.weightPerSideAssistance,
    })) {
      return TrackingMode.weightReps;
    }
    if (tracks(const {
      TrackableExerciseMetric.distanceShort,
      TrackableExerciseMetric.distanceShortPerSide,
      TrackableExerciseMetric.distanceLong,
    })) {
      return TrackingMode.distanceTime;
    }
    if (tracks(const {
      TrackableExerciseMetric.duration,
      TrackableExerciseMetric.durationPerSide,
    })) {
      return TrackingMode.timeOnly;
    }
    return TrackingMode.repsOnly;
  }

  /// Worked one limb at a time. Only the reps, duration and short-distance
  /// "per side" metrics mean that; the weight ones mean plates on each end
  /// or a weight in each hand.
  bool get isPerSide => trackableMetrics.any(
    const {
      TrackableExerciseMetric.repsPerSide,
      TrackableExerciseMetric.durationPerSide,
      TrackableExerciseMetric.distanceShortPerSide,
    }.contains,
  );

  /// Tracked as assistance, so its weights are stored negative.
  bool get isAssisted => trackableMetrics.contains(
    TrackableExerciseMetric.weightPerSideAssistance,
  );

  /// Its image URL, else the bundled picture its name maps to.
  String? get sessionImageName {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) return url;
    return _exerciseImageMap[name.toLowerCase().trim()];
  }
}

const _exerciseImageMap = {
  'barbell bench press': 'BarbellBenchPress',
  'barbell incline bench press': 'BarbellInclineBenchPress',
  'barbell romanian deadlift': 'Barbell_RomanianDeadlift',
  'barbell squat': 'BarbellSquat',
  'barbell back squat': 'BarbellSquat',
  'barbell sumo deadlift': 'BarbellSumoDeadlift',
  'bulgarian split squat': 'BulgarianSplitSquat',
  'dumbbell bulgarian split squat': 'BulgarianSplitSquat',
  'cable bicep curl (straight bar)': 'CableBicepCurl_StraightBar',
  'cable biceps curl (straight bar)': 'CableBicepCurl_StraightBar',
  'cable pushdown (straight bar)': 'CablePushdown_StraightBar',
  'cable tricep pushdown (straight bar)': 'CablePushdown_StraightBar',
  'calf press on leg press': 'CalfPressOnLegPress',
  'seated calf press': 'CalfPressOnLegPress',
  'chest dip': 'ChestDip',
  'dips': 'ChestDip',
  'dumbbell incline fly': 'Dumbbell_InclineFlyChest',
  'dumbbell incline chest fly': 'Dumbbell_InclineFlyChest',
  'dumbbell bench press': 'DumbbellBenchPress',
  'dumbbell seated shoulder press': 'DumbbellSeatedShoulderPress',
  'ez barbell preacher curl': 'EZBarbell_PreacherCurl',
  'preacher curl': 'EZBarbell_PreacherCurl',
  'hack squat': 'HackSquat',
  'lat prayer (straight bar)': 'LatPrayer_StraightBar',
  'lat pulldown (straight bar)': 'LatPrayer_StraightBar',
  'lying leg curl': 'LyingLegCurl',
  'leg curl': 'LyingLegCurl',
  'overhead extension (straight bar)': 'OverheadExtensionStraightBar',
  'cable overhead tricep extension (straight bar)':
      'OverheadExtensionStraightBar',
  'reverse fly': 'ReverseFly',
  'reverse pec deck fly': 'ReverseFly',
  'seated leg extension': 'SeatedLegExtension',
  'leg extension': 'SeatedLegExtension',
  'seated row': 'SeatedRow',
  'cable seated row': 'SeatedRow',
  'machine seated row': 'SeatedRow',
  'single arm row': 'SingleArmRow',
  'dumbbell single arm row': 'SingleArmRow',
  'one arm row': 'SingleArmRow',
  'standing lateral raise (cable)': 'StandingLatRaise_Cable',
  'cable lateral raise': 'StandingLatRaise_Cable',
  't-bar row': 'TBarRow',
  't bar row': 'TBarRow',
  'cable neutral grip lat pulldown': 'CableNeutralGripLatPulldown',
  'neutral grip lat pulldown': 'CableNeutralGripLatPulldown',
  'cable overhead triceps extension': 'CableOverheadTricepsExtension',
  'cable overhead tricep extension': 'CableOverheadTricepsExtension',
  'cable standing supinated face pull': 'CableStandingSupinatedFacePull',
  'face pull (supinated)': 'CableStandingSupinatedFacePull',
  'cable face pull': 'CableStandingSupinatedFacePull',
  'lever hip thrust': 'LeverHipThrust',
  'machine hip thrust': 'LeverHipThrust',
  'lever incline hammer chest press': 'LeverInclineHammerChestPress',
  'incline hammer press': 'LeverInclineHammerChestPress',
  'lever pec deck fly (chest)': 'LeverPecDeckFlyChest',
  'pec deck': 'LeverPecDeckFlyChest',
  'lever pendulum squat': 'LeverPendulumSquat',
  'pendulum squat': 'LeverPendulumSquat',
  'weighted hammer grip pull-up on dip': 'WeightedHammerGripPullUpOnDip',
  'neutral grip pull-up': 'WeightedHammerGripPullUpOnDip',
  'hammer grip chin-up': 'WeightedHammerGripPullUpOnDip',
};
