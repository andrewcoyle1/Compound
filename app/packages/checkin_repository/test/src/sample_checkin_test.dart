import 'package:checkin_repository/checkin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uid = 'mock_user_123';
  final now = DateTime(2026, 10, 14, 15, 30);

  test("the staging data makes this week's check-in due", () async {
    final repository = InMemoryCheckInRepository(
      settings: [sampleStrategySettings(uid: uid)],
      records: [sampleCheckInRecord(uid: uid, now: now)],
      loggingBreaks: [sampleLoggingBreak(uid: uid, now: now)],
      annotations: sampleDayAnnotations(uid: uid, now: now),
    );
    final inputs = ExpenditureInputs(
      now: now,
      settings: await repository.watchStrategySettings(uid).first,
      checkInRecord: await repository.watchCheckInRecord(uid).first,
      loggingBreak: await repository.watchLoggingBreak(uid).first,
      annotations: await repository.watchDayAnnotations(uid).first,
    );

    expect(inputs.checkInState, CheckInState.due);
    expect(inputs.openLoggingBreak, isNull);
    expect(inputs.checkInRecord!.lastCompletedWeekStart, DateTime(2026, 10, 5));
    expect(inputs.checkInRecord!.lastSkippedWeekStart, DateTime(2026, 9, 28));
    expect(inputs.settings.stepInformedUpdates, isTrue);
    expect(inputs.annotations.single.dayKey, '2026-10-11');
    expect(inputs.annotations.single.isPartiallyLogged, isTrue);
    expect(inputs.loggingBreak!.startDate, DateTime(2026, 9, 2, 9, 30));
    expect(inputs.loggingBreak!.endDate, DateTime(2026, 9, 9, 20));
  });
}
