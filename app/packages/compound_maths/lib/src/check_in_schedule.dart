/// When the weekly check-in is due (`CheckInSchedule.swift`,
/// `docs/specs/weekly-check-in.md` §4).
library;

import 'package:compound_maths/src/day_key.dart';
import 'package:compound_maths/src/expenditure_samples.dart';

/// Whether this week's check-in is waiting (`CheckInState`). When [due], it is
/// for the week starting `checkInWeekStart(today)`.
enum CheckInState {
  /// Done or skipped this week, or its day has not come.
  notDue,
  due,

  /// Logging is paused.
  inBreak,
}

/// The Monday of [dayKey]'s ISO week, whatever weekday the user's calendar
/// starts on.
String checkInWeekStart(String dayKey) =>
    addDays(dayKey, 1 - isoWeekday(dayKey));

/// Days from Monday for a calendar weekday (1 = Sunday, as the settings store
/// it): Monday 0, Sunday 6.
int dayOffsetInWeek(int weekday) => ((weekday - 2) % 7 + 7) % 7;

/// The state of [today]'s week (`CheckInSchedule.state`). Due from
/// [checkInWeekday] (1 = Sunday) through Sunday unless that week was
/// completed or skipped; an open-ended [loggingBreak] that has begun holds it.
CheckInState checkInState({
  required String today,
  required int checkInWeekday,
  String? lastCompletedWeekStart,
  String? lastSkippedWeekStart,
  LoggingBreak? loggingBreak,
}) {
  if (loggingBreak != null &&
      loggingBreak.endDay == null &&
      loggingBreak.startDay.compareTo(today) <= 0) {
    return CheckInState.inBreak;
  }
  if (isoWeekday(today) - 1 < dayOffsetInWeek(checkInWeekday)) {
    return CheckInState.notDue;
  }
  final weekStart = checkInWeekStart(today);
  for (final done in [lastCompletedWeekStart, lastSkippedWeekStart]) {
    if (done != null && done.compareTo(weekStart) >= 0) {
      return CheckInState.notDue;
    }
  }
  return CheckInState.due;
}
