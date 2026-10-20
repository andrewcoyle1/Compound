import 'package:compound_models/compound_models.dart';

/// The weekly check-in's data for the signed-in user: the strategy settings
/// (Swift `NutritionStrategySettingsManager`) and what the check-in writes
/// (Swift `NutritionStrategyManager`).
///
/// Every write merges, as Swift's `saveDocument` (`setData(merge: true)`)
/// does, so a field this app does not know survives. Where Swift's merge
/// would keep a value the user cleared, the field is deleted instead (see
/// [saveStrategySettings] and [startLoggingBreak]).
abstract interface class CheckInRepository {
  /// The settings at
  /// `users/{uid}/nutrition_strategy_settings/nutrition_strategy_settings`,
  /// or Swift's defaults when there is no document or it cannot be read
  /// (`NutritionStrategySettingsManager.swift:15-17`).
  Stream<NutritionStrategySettings> watchStrategySettings(String uid);

  /// Saves [settings] whole to `users/{settings.authorId}/…`, merged
  /// (`NutritionStrategySettingsManager.swift:42-44`). A new user's defaults
  /// are saved the same way (`:30-36`). A null `calculationStartDate` deletes
  /// the stored one: Swift's merge keeps it, so "Clear" on the Expenditure
  /// screen never reaches Firestore there.
  Future<void> saveStrategySettings(NutritionStrategySettings settings);

  /// Every annotation at `users/{uid}/nutrition_day_annotations`, in day
  /// order; one that cannot be read is skipped.
  Stream<List<NutritionDayAnnotation>> watchDayAnnotations(String uid);

  /// Saves each of [annotations] under `users/{uid}/…/{dayKey}`, merged,
  /// replacing what the day had; an empty one deletes the day's document
  /// instead (`NutritionStrategyManager.swift:80-99`). All in one batch.
  Future<void> saveDayAnnotations(
    String uid,
    List<NutritionDayAnnotation> annotations,
  );

  /// The break at `users/{uid}/logging_break/logging_break`, open or ended,
  /// or null when there is none or it cannot be read.
  Stream<LoggingBreak?> watchLoggingBreak(String uid);

  /// Starts an open-ended break at [startDate]
  /// (`NutritionStrategyManager.swift:109-114`). An earlier break's
  /// `end_date` is deleted: Swift's merge keeps it, so a second break there
  /// reads as already ended.
  Future<void> startLoggingBreak(String uid, DateTime startDate);

  /// Ends the open break at [endDate]; with no open break, does nothing
  /// (`NutritionStrategyManager.swift:117-121`).
  Future<void> endLoggingBreak(String uid, DateTime endDate);

  /// The record at `users/{uid}/check_in_record/check_in_record`, or null
  /// when there is none or it cannot be read.
  Stream<CheckInRecord?> watchCheckInRecord(String uid);

  /// Records the check-in for the week starting [weekStart] as completed,
  /// creating the record the first time
  /// (`NutritionStrategyManager.swift:125-143`). Only that field is merged,
  /// so a record not yet read cannot overwrite the other.
  Future<void> markCheckInCompleted(String uid, DateTime weekStart);

  /// As [markCheckInCompleted], for a skipped week.
  Future<void> markCheckInSkipped(String uid, DateTime weekStart);
}
