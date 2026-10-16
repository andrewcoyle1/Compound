import 'package:compound/review/review_moment.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

// ReviewMomentTests, case for case, then the prompter that shares one
// cooldown between the moments and Settings' Rate row.
void main() {
  final today = DateTime.now();
  final now = DateTime(today.year, today.month, today.day, 12);
  DateTime daysAgo(int days) =>
      DateTime(now.year, now.month, now.day - days, 12);

  bool asks(ReviewMoment moment, {DateTime? lastRequestedAt}) =>
      moment.shouldAsk(lastRequestedAt: lastRequestedAt, now: now);

  group(ReviewMoment, () {
    test('only the workout that completes the week asks', () {
      expect(
        asks(const ReviewWorkoutFinished(sessionsThisWeek: 2, weeklyGoal: 3)),
        isFalse,
      );
      expect(
        asks(const ReviewWorkoutFinished(sessionsThisWeek: 3, weeklyGoal: 3)),
        isTrue,
      );
      expect(
        asks(const ReviewWorkoutFinished(sessionsThisWeek: 4, weeklyGoal: 3)),
        isFalse,
      );
      expect(
        asks(const ReviewWorkoutFinished(sessionsThisWeek: 0, weeklyGoal: 0)),
        isFalse,
      );
    });

    test('only the seventh day of food logging asks', () {
      expect(
        [
          for (var days = 1; days <= 10; days++)
            if (asks(ReviewFoodLogged(days))) days,
        ],
        [7],
      );
    });

    test('nothing asks inside the cooldown', () {
      const goalMet = ReviewWorkoutFinished(sessionsThisWeek: 3, weeklyGoal: 3);
      expect(asks(goalMet, lastRequestedAt: daysAgo(119)), isFalse);
      expect(asks(goalMet, lastRequestedAt: daysAgo(120)), isTrue);
    });

    test('days in a row stop at the first gap', () {
      final logged = [
        for (final days in [0, 1, 2, 4, 5]) daysAgo(days),
      ];
      // Two entries on the same day count once.
      final withDuplicate = [
        ...logged,
        DateTime(now.year, now.month, now.day, 8),
      ];
      expect(ReviewMoment.daysInARow(today: now, loggedDays: withDuplicate), 3);
      expect(
        ReviewMoment.daysInARow(today: daysAgo(-1), loggedDays: logged),
        0,
      );
    });
  });

  group(ReviewPrompter, () {
    test(
      'asks at an earned moment, then not again inside the cooldown',
      () async {
        final store = FakeStoreReview();
        final prompter = ReviewPrompter(review: store, now: () => now);
        await prompter.requestIfEarned(const ReviewFoodLogged(6));
        expect(store.requests, 0);
        await prompter.requestIfEarned(const ReviewFoodLogged(7));
        expect(store.requests, 1);
        await prompter.requestIfEarned(
          const ReviewWorkoutFinished(sessionsThisWeek: 3, weeklyGoal: 3),
        );
        expect(store.requests, 1);
      },
    );

    test("Settings' Rate row always asks, and starts the cooldown", () async {
      final store = FakeStoreReview();
      final prompter = ReviewPrompter(review: store, now: () => now);
      await prompter.request();
      await prompter.request();
      expect(store.requests, 2);
      await prompter.requestIfEarned(const ReviewFoodLogged(7));
      expect(store.requests, 2);
    });

    test('the last request is kept on the device across launches', () async {
      final device = InMemoryDeviceStore();
      final store = FakeStoreReview();
      await ReviewPrompter(
        review: store,
        now: () => now,
        store: device,
      ).request();
      expect(
        device.getString(ReviewPrompter.lastRequestKey),
        now.toUtc().toIso8601String(),
      );
      final relaunched = ReviewPrompter(
        review: store,
        now: () => now,
        store: device,
      );
      expect(relaunched.lastRequestedAt!.isAtSameMomentAs(now), isTrue);
      await relaunched.requestIfEarned(const ReviewFoodLogged(7));
      expect(store.requests, 1);
    });
  });
}
