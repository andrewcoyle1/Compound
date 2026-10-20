import 'package:app_ui/app_ui.dart';
import 'package:compound_maths/compound_maths.dart' as maths;

/// The name of a check-in [weekday], which is 1-based and Sunday-first as
/// Swift's `Calendar` counts (Swift `checkInWeekdayName`): 1 is Sunday, 2
/// Monday. Out of range reads as Monday, as in Swift.
String weekdayName(int weekday, String locale) {
  final day = weekday >= 1 && weekday <= 7 ? weekday : 2;
  // 4 January 2026 was a Sunday.
  return AppFormat.date(
    DateTime(2026, 1, 3 + day),
    style: AppDateStyle.weekday,
    locale: locale,
  );
}

/// Where today's expenditure came from, for the line under the figure
/// (Swift `expenditureStatusText`); the words are the view's.
sealed class ExpenditureStatus {
  const new();

  factory of(maths.ExpenditureEstimate estimate) => switch (estimate.source) {
    maths.ExpenditureSource.fixed => const ExpenditureFixed(),
    maths.ExpenditureSource.prior => const ExpenditureCalibrating(),
    maths.ExpenditureSource.adaptive => ExpenditureAdaptive(
      loggedDays: estimate.loggedDays,
      windowDays: estimate.windowDays,
    ),
  };
}

/// Held by the user's choice.
final class ExpenditureFixed extends ExpenditureStatus {
  const new();
}

/// Still the profile's figure, until enough is logged.
final class ExpenditureCalibrating extends ExpenditureStatus {
  const new();

  /// Days of logging the engine waits for.
  static const int minDays = maths.ExpenditureConstants.minDays;

  /// Weigh-ins it waits for.
  static const int minWeighIns = maths.ExpenditureConstants.minWeighIns;
}

/// Learned from the log.
final class ExpenditureAdaptive extends ExpenditureStatus {
  const new({required this.loggedDays, required this.windowDays});

  final int loggedDays;
  final int windowDays;
}

/// The 80% interval once the estimate is adaptive, rounded, or null
/// (Swift `ExpenditureEstimate.likelyRange`, z = 1.28).
({int low, int high})? likelyRange(maths.ExpenditureEstimate estimate) {
  final sd = estimate.sdKcal;
  if (estimate.source != maths.ExpenditureSource.adaptive ||
      sd == null ||
      !sd.isFinite ||
      !estimate.kcal.isFinite) {
    return null;
  }
  final half = 1.28 * sd;
  return (
    low: (estimate.kcal - half).round(),
    high: (estimate.kcal + half).round(),
  );
}

/// The step nowcast in whole kcal, or null when none applied (Swift
/// `stepAdjustmentText`): shown apart from the figure so it is never taken
/// for the measurement.
int? stepAdjustment(maths.ExpenditureEstimate estimate) {
  final kcal = estimate.stepAdjustmentKcal.round();
  return kcal == 0 ? null : kcal;
}
