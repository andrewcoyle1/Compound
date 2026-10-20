import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';

/// How the expenditure prior picks its equation (Swift
/// `ExpenditureEstimationMethod`).
enum ExpenditureEstimationMethod implements FirestoreEnum {
  /// `standard`: the equation chosen.
  standard('standard'),

  /// `bodyFatAware`: Cunningham when a body fat reading is logged.
  bodyFatAware('bodyFatAware');

  new(this.value);

  @override
  final String value;
}

/// The resting-rate equation (Swift `BMREquation`).
enum BmrEquation implements FirestoreEnum {
  /// `mifflinStJeor`.
  mifflinStJeor('mifflinStJeor'),

  /// `harrisBenedict`.
  harrisBenedict('harrisBenedict'),

  /// Cunningham 1980, stored as `katchMcArdle`: the equation it replaced
  /// keeps its raw value, so older builds still decode it.
  cunningham('katchMcArdle');

  new(this.value);

  @override
  final String value;
}

/// Whether the expenditure estimate adapts (Swift
/// `ExpenditureCalculationMode`).
enum ExpenditureCalculationMode implements FirestoreEnum {
  /// `dynamic`: the filter runs.
  dynamic('dynamic'),

  /// `fixed`: the formula figure holds.
  fixed('fixed');

  new(this.value);

  @override
  final String value;
}

/// The expenditure algorithm (Swift `ExpenditureAlgorithmVersion`).
enum ExpenditureAlgorithmVersion implements FirestoreEnum {
  /// `v1`, the only one.
  version1('v1');

  new(this.value);

  @override
  final String value;
}

/// Field names of
/// `users/{uid}/nutrition_strategy_settings/nutrition_strategy_settings`,
/// exactly as the Swift `CodingKeys` spell them.
abstract final class NutritionStrategySettingsKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `check_in_weekday`.
  static const checkInWeekday = 'check_in_weekday';

  /// `fast_check_in`.
  static const fastCheckIn = 'fast_check_in';

  /// `partial_logging_enabled`.
  static const partialLoggingEnabled = 'partial_logging_enabled';

  /// `weigh_in_enabled`.
  static const weighInEnabled = 'weigh_in_enabled';

  /// `fasting_enabled`.
  static const fastingEnabled = 'fasting_enabled';

  /// `logging_break_enabled`.
  static const loggingBreakEnabled = 'logging_break_enabled';

  /// `estimation_method`.
  static const estimationMethod = 'estimation_method';

  /// `calculation_start_date`.
  static const calculationStartDate = 'calculation_start_date';

  /// `bmr_equation`.
  static const bmrEquation = 'bmr_equation';

  /// `calculation_mode`.
  static const calculationMode = 'calculation_mode';

  /// `algorithm_version`.
  static const algorithmVersion = 'algorithm_version';

  /// `step_informed_updates`.
  static const stepInformedUpdates = 'step_informed_updates';

  /// `predictive_goal_adjustments`.
  static const predictiveGoalAdjustments = 'predictive_goal_adjustments';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    checkInWeekday,
    fastCheckIn,
    partialLoggingEnabled,
    weighInEnabled,
    fastingEnabled,
    loggingBreakEnabled,
    estimationMethod,
    calculationStartDate,
    bmrEquation,
    calculationMode,
    algorithmVersion,
    stepInformedUpdates,
    predictiveGoalAdjustments,
  ];
}

/// The Strategy and Expenditure settings (Swift
/// `NutritionStrategySettings`), one document per user. The defaults are
/// Swift's, which the app uses when the user has no document.
class const NutritionStrategySettings({
  /// The owner.
  required final String authorId,

  /// The document id, always `nutrition_strategy_settings`.
  final String id = 'nutrition_strategy_settings',

  /// The check-in day, as a calendar weekday: 1 is Sunday, 2 Monday.
  final int checkInWeekday = 2,

  /// Skip the introduction and ask only about suspicious days.
  final bool fastCheckIn = false,

  /// The check-in asks which days were partly logged.
  final bool partialLoggingEnabled = true,

  /// The check-in asks for a weigh-in when none is recent.
  final bool weighInEnabled = true,

  /// The check-in asks which unlogged days were fasts.
  final bool fastingEnabled = true,

  /// The check-in offers a break from logging.
  final bool loggingBreakEnabled = true,

  /// How the prior picks its equation.
  final ExpenditureEstimationMethod estimationMethod =
      ExpenditureEstimationMethod.standard,

  /// Samples before this day are ignored; null means all of them.
  final DateTime? calculationStartDate,

  /// The resting-rate equation.
  final BmrEquation bmrEquation = BmrEquation.mifflinStJeor,

  /// Whether the estimate adapts.
  final ExpenditureCalculationMode calculationMode =
      ExpenditureCalculationMode.dynamic,

  /// The algorithm.
  final ExpenditureAlgorithmVersion algorithmVersion =
      ExpenditureAlgorithmVersion.version1,

  /// The step nowcast.
  final bool stepInformedUpdates = false,

  /// No longer read; kept so the document round-trips.
  final bool predictiveGoalAdjustments = true,
}) {
  /// Creates a [NutritionStrategySettings].
  this;

  /// Decodes as Swift's synthesized decoder does: **every field but
  /// `calculation_start_date` is required**, the defaults above
  /// notwithstanding, and an unknown enum value throws. A null
  /// `calculation_start_date` reads as absent; a whole-number double reads
  /// as an int.
  factory fromFirestore(Map<String, Object?> data) => NutritionStrategySettings(
    id: data[NutritionStrategySettingsKeys.id]! as String,
    authorId: data[NutritionStrategySettingsKeys.authorId]! as String,
    checkInWeekday: readInt(data[NutritionStrategySettingsKeys.checkInWeekday]),
    fastCheckIn: data[NutritionStrategySettingsKeys.fastCheckIn]! as bool,
    partialLoggingEnabled:
        data[NutritionStrategySettingsKeys.partialLoggingEnabled]! as bool,
    weighInEnabled: data[NutritionStrategySettingsKeys.weighInEnabled]! as bool,
    fastingEnabled: data[NutritionStrategySettingsKeys.fastingEnabled]! as bool,
    loggingBreakEnabled:
        data[NutritionStrategySettingsKeys.loggingBreakEnabled]! as bool,
    estimationMethod: enumFromValue(
      ExpenditureEstimationMethod.values,
      data[NutritionStrategySettingsKeys.estimationMethod]! as String,
    ),
    calculationStartDate:
        data[NutritionStrategySettingsKeys.calculationStartDate] as DateTime?,
    bmrEquation: enumFromValue(
      BmrEquation.values,
      data[NutritionStrategySettingsKeys.bmrEquation]! as String,
    ),
    calculationMode: enumFromValue(
      ExpenditureCalculationMode.values,
      data[NutritionStrategySettingsKeys.calculationMode]! as String,
    ),
    algorithmVersion: enumFromValue(
      ExpenditureAlgorithmVersion.values,
      data[NutritionStrategySettingsKeys.algorithmVersion]! as String,
    ),
    stepInformedUpdates:
        data[NutritionStrategySettingsKeys.stepInformedUpdates]! as bool,
    predictiveGoalAdjustments:
        data[NutritionStrategySettingsKeys.predictiveGoalAdjustments]! as bool,
  );

  /// The Firestore-shaped map Swift writes: a null `calculation_start_date`
  /// is left out.
  Map<String, Object?> toFirestore() => {
    NutritionStrategySettingsKeys.id: id,
    NutritionStrategySettingsKeys.authorId: authorId,
    NutritionStrategySettingsKeys.checkInWeekday: checkInWeekday,
    NutritionStrategySettingsKeys.fastCheckIn: fastCheckIn,
    NutritionStrategySettingsKeys.partialLoggingEnabled: partialLoggingEnabled,
    NutritionStrategySettingsKeys.weighInEnabled: weighInEnabled,
    NutritionStrategySettingsKeys.fastingEnabled: fastingEnabled,
    NutritionStrategySettingsKeys.loggingBreakEnabled: loggingBreakEnabled,
    NutritionStrategySettingsKeys.estimationMethod: estimationMethod.value,
    NutritionStrategySettingsKeys.calculationStartDate: ?calculationStartDate,
    NutritionStrategySettingsKeys.bmrEquation: bmrEquation.value,
    NutritionStrategySettingsKeys.calculationMode: calculationMode.value,
    NutritionStrategySettingsKeys.algorithmVersion: algorithmVersion.value,
    NutritionStrategySettingsKeys.stepInformedUpdates: stepInformedUpdates,
    NutritionStrategySettingsKeys.predictiveGoalAdjustments:
        predictiveGoalAdjustments,
  };
}
