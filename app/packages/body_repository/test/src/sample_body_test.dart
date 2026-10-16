import 'package:body_repository/body_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 14, 6, 30);

  group('sampleBodyMeasurements', () {
    late List<BodyMeasurementEntry> entries;

    setUp(() => entries = sampleBodyMeasurements(uid: 'me', now: now));

    test("are ninety days of the user's weigh-ins, none after now", () {
      expect(entries.first.date, DateTime(2026, 7, 17, 7, 19));
      // Today's 07:10 weigh-in is still to come at 06:30.
      expect(entries.last.date, DateTime(2026, 10, 13, 7, 11));
      expect(entries.length, inInclusiveRange(65, 80));
      for (final entry in entries) {
        expect(entry.authorId, 'me');
        expect(entry.date.isAfter(now), isFalse);
        expect(entry.weightKg, inInclusiveRange(69, 75.5));
      }
      expect(
        sampleBodyMeasurements(
          uid: 'me',
          now: DateTime(2026, 10, 14, 9),
        ).last.date,
        DateTime(2026, 10, 14, 7, 10),
      );
    });

    test('trend down by about 4 kg, toward the goal', () {
      final first =
          entries.take(7).map((e) => e.weightKg!).reduce((a, b) => a + b) / 7;
      final last =
          entries.reversed
              .take(7)
              .map((e) => e.weightKg!)
              .reduce((a, b) => a + b) /
          7;
      expect(first - last, inInclusiveRange(3, 4.5));
    });

    test('include body fat, circumferences, notes and both sources', () {
      expect(entries.where((e) => e.bodyFatPercentage != null), isNotEmpty);
      expect(entries.where((e) => e.waistCircumference != null), isNotEmpty);
      expect(entries.where((e) => e.notes != null), isNotEmpty);
      expect(entries.map((e) => e.source).toSet(), {
        WeightSource.healthkit,
        WeightSource.manual,
      });
      for (final entry in entries) {
        expect(
          entry.healthKitUuid != null,
          entry.source == WeightSource.healthkit,
        );
      }
    });

    test('are documents the Swift app can read', () {
      for (final entry in entries) {
        expect(
          BodyMeasurementEntry.fromFirestore(entry.toFirestore()).toFirestore(),
          equals(entry.toFirestore()),
        );
      }
    });
  });

  group('sampleSteps', () {
    final steps = sampleSteps(uid: 'me', now: now);

    test("are thirty days of the user's Apple Health totals", () {
      expect(steps, hasLength(30));
      expect(steps.last.date, DateTime(2026, 10, 14));
      for (final day in steps) {
        expect(day.authorId, 'me');
        expect(day.source, StepsSource.healthkit);
        expect(
          StepsModel.fromFirestore(day.toFirestore()).toFirestore(),
          equals(day.toFirestore()),
        );
      }
    });

    test('count today only as far as now, and dip on a rest day', () {
      final whole = steps.take(29).map((s) => s.number);
      expect(whole.reduce((a, b) => a < b ? a : b), 1800);
      expect(steps.last.number, lessThan(3000));
      expect(steps.last.dateModified, now);
    });
  });

  test('sampleWeightGoal is an active loss toward 68 kg under the uid', () {
    final goal = sampleWeightGoal(uid: 'me', now: now);
    expect(goal.goalId, 'me');
    expect(goal.status, GoalStatus.active);
    expect(goal.objective, OverarchingObjective.loseWeight);
    expect(goal.startingWeightKg, closeTo(sampleTrendWeightKg(30), 0.05));
    expect(goal.targetWeightKg, lessThan(sampleTrendWeightKg(0)));
    expect(
      WeightGoal.fromFirestore(goal.toFirestore()).toFirestore(),
      equals(goal.toFirestore()),
    );
  });

  test('sampleProgressPhotos are two front photos a month apart', () {
    final photos = sampleProgressPhotos(uid: 'me', now: now);
    expect(photos.map((photo) => photo.pose), [
      ProgressPhotoPose.front,
      ProgressPhotoPose.front,
    ]);
    expect(photos.first.date.isBefore(photos.last.date), isTrue);
    expect(photos.last.date.isAfter(now), isFalse);
    for (final photo in photos) {
      expect(photo.authorId, 'me');
      expect(
        photo.storagePath,
        ProgressPhotoModel.storagePathFor('me', photo.id),
      );
      expect(photo.imageUrl, startsWith('assets/exercises/'));
      expect(photo.weightKg, isNotNull);
    }
  });
}
