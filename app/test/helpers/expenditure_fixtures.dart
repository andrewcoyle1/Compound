import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

/// Thursday 15 October 2026, 1pm: this week's check-in is due for the
/// staging user.
final stagingNow = DateTime(2026, 10, 15, 13);

/// The staging flavor's repositories, seeded as `main_staging.dart` seeds
/// them: two months of eating and weigh-ins that calibrate the engine, a
/// plan a fortnight old it proposes lowering, and this week's check-in due.
class StagingData {
  new({
    DateTime? now,
    List<MealLogModel>? meals,
    List<BodyMeasurementEntry>? measurements,
    NutritionStrategySettings? settings,
    List<CheckInRecord>? records,
    List<LoggingBreak>? loggingBreaks,
    CheckInRepository? checkIns,
    bool withPlan = true,
  }) : now = now ?? stagingNow {
    final at = this.now;
    users = InMemoryUserRepository(users: {uid: sampleUser(now: at)});
    nutrition = InMemoryNutritionRepository(
      meals:
          meals ??
          [
            ...sampleMealLogs(uid: uid, now: at),
            ...sampleMealHistory(uid: uid, now: at),
          ],
      dietPlan: withPlan ? sampleDietPlan(uid: uid, now: at) : null,
    );
    body = InMemoryBodyRepository(
      measurements: measurements ?? sampleBodyMeasurements(uid: uid, now: at),
      steps: sampleSteps(uid: uid, now: at),
      goals: [sampleWeightGoal(uid: uid, now: at)],
    );
    this.checkIns =
        checkIns ??
        InMemoryCheckInRepository(
          settings: [settings ?? sampleStrategySettings(uid: uid)],
          annotations: sampleDayAnnotations(uid: uid, now: at),
          loggingBreaks:
              loggingBreaks ?? [sampleLoggingBreak(uid: uid, now: at)],
          records: records ?? [sampleCheckInRecord(uid: uid, now: at)],
        );
    programs = InMemoryProgramRepository(mesocycles: sampleMesocycles(now: at));
  }

  static const String uid = sampleUserId;

  final DateTime now;
  late final InMemoryUserRepository users;
  late final InMemoryNutritionRepository nutrition;
  late final InMemoryBodyRepository body;
  late final CheckInRepository checkIns;
  late final InMemoryProgramRepository programs;
}
