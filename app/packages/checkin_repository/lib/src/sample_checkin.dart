import 'package:checkin_repository/src/expenditure_inputs.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';

/// [uid]'s strategy settings for the staging flavor: Swift's defaults (a
/// Monday check-in with every module on, adaptive Mifflin-St Jeor), with the
/// step nowcast on, since the sample user has a month of step counts.
NutritionStrategySettings sampleStrategySettings({required String uid}) =>
    NutritionStrategySettings(authorId: uid, stepInformedUpdates: true);

/// [uid]'s check-in record at [now]: last week completed and the week
/// before skipped, so this week's check-in is due in staging. The sample
/// diet plan is a fortnight old, so those are the only weeks it has seen.
CheckInRecord sampleCheckInRecord({
  required String uid,
  required DateTime now,
}) {
  final thisWeek = maths.checkInWeekStart(localDayKey(now));
  return CheckInRecord(
    authorId: uid,
    lastCompletedWeekStart: localMidnight(maths.addDays(thisWeek, -7)),
    lastSkippedWeekStart: localMidnight(maths.addDays(thisWeek, -14)),
  );
}

/// [uid]'s last logging break, a week about six weeks before [now], long
/// since ended: the weigh-ins carry on through it, as they would.
LoggingBreak sampleLoggingBreak({required String uid, required DateTime now}) {
  final start = DateTime(now.year, now.month, now.day - 42, 9, 30);
  return LoggingBreak(
    authorId: uid,
    startDate: start,
    endDate: DateTime(start.year, start.month, start.day + 7, 20),
  );
}

/// [uid]'s day annotations at [now]: three days ago, the sample meals' "Late
/// start", marked partly logged.
List<NutritionDayAnnotation> sampleDayAnnotations({
  required String uid,
  required DateTime now,
}) {
  final day = DateTime(now.year, now.month, now.day - 3);
  return [
    NutritionDayAnnotation(
      dayKey: localDayKey(day),
      authorId: uid,
      dateModified: DateTime(now.year, now.month, now.day - 2, 8),
      isPartiallyLogged: true,
    ),
  ];
}
