import 'package:checkin_repository/checkin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(InMemoryCheckInRepository, () {
    const uid = 'user-1';
    final at = DateTime.utc(2026, 10, 14, 8);

    test("serves seeded documents, and Swift's defaults without", () async {
      final subject = InMemoryCheckInRepository(
        settings: [
          const NutritionStrategySettings(authorId: uid, checkInWeekday: 5),
        ],
        annotations: [
          NutritionDayAnnotation(
            dayKey: '2026-10-12',
            authorId: uid,
            dateModified: at,
            isFastingDay: true,
          ),
        ],
        loggingBreaks: [LoggingBreak(authorId: uid, startDate: at)],
        records: [CheckInRecord(authorId: uid, lastCompletedWeekStart: at)],
      );

      expect(
        (await subject.watchStrategySettings(uid).first).checkInWeekday,
        5,
      );
      expect(
        (await subject.watchStrategySettings('other').first).toFirestore(),
        const NutritionStrategySettings(authorId: 'other').toFirestore(),
      );
      expect(
        (await subject.watchDayAnnotations(uid).first).single.isFastingDay,
        isTrue,
      );
      expect(await subject.watchDayAnnotations('other').first, isEmpty);
      expect((await subject.watchLoggingBreak(uid).first)!.startDate, at);
      expect(await subject.watchLoggingBreak('other').first, isNull);
      expect(
        (await subject.watchCheckInRecord(uid).first)!.lastCompletedWeekStart,
        at,
      );
      expect(await subject.watchCheckInRecord('other').first, isNull);
    });

    test('saving settings merges and clears a cleared start date', () async {
      final subject = InMemoryCheckInRepository(
        settings: [
          NutritionStrategySettings(authorId: uid, calculationStartDate: at),
        ],
      );
      final watched = subject.watchStrategySettings(uid);
      expect((await watched.first).calculationStartDate, at);
      final next = expectLater(
        watched.map((s) => s.calculationStartDate),
        emitsInOrder([at, null]),
      );

      await subject.saveStrategySettings(
        const NutritionStrategySettings(authorId: uid, fastCheckIn: true),
      );
      await next;

      expect((await watched.first).fastCheckIn, isTrue);
    });

    test('annotations save in day order, and an empty one deletes', () async {
      final subject = InMemoryCheckInRepository();
      NutritionDayAnnotation note(String day, {bool partial = false}) =>
          NutritionDayAnnotation(
            dayKey: day,
            authorId: uid,
            dateModified: at,
            isPartiallyLogged: partial,
          );

      await subject.saveDayAnnotations(uid, [
        note('2026-10-12', partial: true),
        note('2026-10-10', partial: true),
      ]);
      expect(
        (await subject.watchDayAnnotations(uid).first).map((a) => a.dayKey),
        ['2026-10-10', '2026-10-12'],
      );

      await subject.saveDayAnnotations(uid, [note('2026-10-12')]);
      expect(
        (await subject.watchDayAnnotations(uid).first).map((a) => a.dayKey),
        ['2026-10-10'],
      );
    });

    test('a break starts open, ends once, and a second one opens', () async {
      final subject = InMemoryCheckInRepository();
      await subject.endLoggingBreak(uid, at);
      expect(await subject.watchLoggingBreak(uid).first, isNull);

      await subject.startLoggingBreak(uid, at);
      final end = at.add(const Duration(days: 7));
      await subject.endLoggingBreak(uid, end);
      await subject.endLoggingBreak(uid, end.add(const Duration(days: 1)));
      expect((await subject.watchLoggingBreak(uid).first)!.endDate, end);

      final again = end.add(const Duration(days: 30));
      await subject.startLoggingBreak(uid, again);
      final read = await subject.watchLoggingBreak(uid).first;
      expect(read!.startDate, again);
      expect(read.isOpenAt(again), isTrue);
    });

    test('marking weeks creates the record and keeps both fields', () async {
      final subject = InMemoryCheckInRepository();
      final week = DateTime(2026, 10, 12);
      final earlier = DateTime(2026, 10, 5);

      await subject.markCheckInSkipped(uid, earlier);
      await subject.markCheckInCompleted(uid, week);

      final read = await subject.watchCheckInRecord(uid).first;
      expect(read!.authorId, uid);
      expect(read.lastCompletedWeekStart, week);
      expect(read.lastSkippedWeekStart, earlier);
    });
  });
}
