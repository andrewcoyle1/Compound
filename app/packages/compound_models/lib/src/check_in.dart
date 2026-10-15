/// What the weekly check-in writes (Swift `NutritionStrategyManager`): the
/// record of weeks dealt with, the logging break, and the day annotations.
library;

/// Field names of `users/{uid}/check_in_record/check_in_record`, exactly as
/// the Swift `CodingKeys` spell them.
abstract final class CheckInRecordKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `last_completed_week_start`.
  static const lastCompletedWeekStart = 'last_completed_week_start';

  /// `last_skipped_week_start`.
  static const lastSkippedWeekStart = 'last_skipped_week_start';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    lastCompletedWeekStart,
    lastSkippedWeekStart,
  ];
}

/// Which weeks' check-ins were completed or skipped (Swift `CheckInRecord`),
/// one document per user. Both dates are the local midnight starting a
/// Monday-first week, not the moment of the tap.
class const CheckInRecord({
  /// The owner.
  required final String authorId,

  /// The document id, always [documentId].
  final String id = documentId,

  /// The week start of the last completed check-in.
  final DateTime? lastCompletedWeekStart,

  /// The week start of the last skipped check-in.
  final DateTime? lastSkippedWeekStart,
}) {
  /// Creates a [CheckInRecord].
  this;

  /// Decodes as Swift's synthesized decoder does: `id` and `author_id` are
  /// required; a null date reads as absent.
  factory fromFirestore(Map<String, Object?> data) => CheckInRecord(
    id: data[CheckInRecordKeys.id]! as String,
    authorId: data[CheckInRecordKeys.authorId]! as String,
    lastCompletedWeekStart:
        data[CheckInRecordKeys.lastCompletedWeekStart] as DateTime?,
    lastSkippedWeekStart:
        data[CheckInRecordKeys.lastSkippedWeekStart] as DateTime?,
  );

  /// The document id, and the collection's only document.
  static const documentId = 'check_in_record';

  /// The Firestore-shaped map Swift writes: a null date is left out.
  Map<String, Object?> toFirestore() => {
    CheckInRecordKeys.id: id,
    CheckInRecordKeys.authorId: authorId,
    CheckInRecordKeys.lastCompletedWeekStart: ?lastCompletedWeekStart,
    CheckInRecordKeys.lastSkippedWeekStart: ?lastSkippedWeekStart,
  };
}

/// Field names of `users/{uid}/logging_break/logging_break`, exactly as the
/// Swift `CodingKeys` spell them.
abstract final class LoggingBreakKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `start_date`.
  static const startDate = 'start_date';

  /// `end_date`.
  static const endDate = 'end_date';

  /// Every field, in declaration order.
  static const List<String> all = [id, authorId, startDate, endDate];
}

/// A break from logging (Swift `LoggingBreak`), one document per user: a
/// state, not a history.
class const LoggingBreak({
  /// The owner.
  required final String authorId,

  /// When it began.
  required final DateTime startDate,

  /// The document id, always [documentId].
  final String id = documentId,

  /// When it ended; null while it is open.
  final DateTime? endDate,
}) {
  /// Creates a [LoggingBreak].
  this;

  /// Decodes as Swift's synthesized decoder does: everything but `end_date`
  /// is required; a null `end_date` reads as open.
  factory fromFirestore(Map<String, Object?> data) => LoggingBreak(
    id: data[LoggingBreakKeys.id]! as String,
    authorId: data[LoggingBreakKeys.authorId]! as String,
    startDate: data[LoggingBreakKeys.startDate]! as DateTime,
    endDate: data[LoggingBreakKeys.endDate] as DateTime?,
  );

  /// The document id, and the collection's only document.
  static const documentId = 'logging_break';

  /// Open at [date]: begun by then and not ended (`LoggingBreak.isOpen`).
  bool isOpenAt(DateTime date) => endDate == null && !startDate.isAfter(date);

  /// The Firestore-shaped map Swift writes: a null `end_date` is left out.
  Map<String, Object?> toFirestore() => {
    LoggingBreakKeys.id: id,
    LoggingBreakKeys.authorId: authorId,
    LoggingBreakKeys.startDate: startDate,
    LoggingBreakKeys.endDate: ?endDate,
  };
}

/// Field names of `users/{uid}/nutrition_day_annotations/{day_key}`, exactly
/// as the Swift `CodingKeys` spell them. There is no `id` field: the
/// document id is the day key.
abstract final class NutritionDayAnnotationKeys {
  /// `day_key`.
  static const dayKey = 'day_key';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `is_partially_logged`.
  static const isPartiallyLogged = 'is_partially_logged';

  /// `is_fasting_day`.
  static const isFastingDay = 'is_fasting_day';

  /// `date_modified`.
  static const dateModified = 'date_modified';

  /// Every field, in declaration order.
  static const List<String> all = [
    dayKey,
    authorId,
    isPartiallyLogged,
    isFastingDay,
    dateModified,
  ];
}

/// What the user said about one day (Swift `NutritionDayAnnotation`): its
/// intake is incomplete, or it was a fast. Stored under its [dayKey], so a
/// second annotation for a day replaces the first.
class const NutritionDayAnnotation({
  /// `YYYY-MM-DD`, as `MealLogModel.dayKey`; also the document id.
  required final String dayKey,

  /// The owner.
  required final String authorId,

  /// When it was last saved.
  required final DateTime dateModified,

  /// The day's intake is incomplete.
  final bool isPartiallyLogged = false,

  /// The user ate nothing or next to nothing on purpose.
  final bool isFastingDay = false,
}) {
  /// Creates a [NutritionDayAnnotation].
  this;

  /// Decodes as Swift's synthesized decoder does: every field is required.
  factory fromFirestore(Map<String, Object?> data) => NutritionDayAnnotation(
    dayKey: data[NutritionDayAnnotationKeys.dayKey]! as String,
    authorId: data[NutritionDayAnnotationKeys.authorId]! as String,
    isPartiallyLogged:
        data[NutritionDayAnnotationKeys.isPartiallyLogged]! as bool,
    isFastingDay: data[NutritionDayAnnotationKeys.isFastingDay]! as bool,
    dateModified: data[NutritionDayAnnotationKeys.dateModified]! as DateTime,
  );

  /// Says nothing, which is the same as no annotation: saving one deletes
  /// the day's document instead.
  bool get isEmpty => !isPartiallyLogged && !isFastingDay;

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    NutritionDayAnnotationKeys.dayKey: dayKey,
    NutritionDayAnnotationKeys.authorId: authorId,
    NutritionDayAnnotationKeys.isPartiallyLogged: isPartiallyLogged,
    NutritionDayAnnotationKeys.isFastingDay: isFastingDay,
    NutritionDayAnnotationKeys.dateModified: dateModified,
  };
}
