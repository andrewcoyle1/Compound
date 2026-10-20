import 'package:checkin_repository/checkin_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contract.dart';

void main() {
  group(FirestoreCheckInRepository, () {
    const uid = 'user_contract_full';
    late FakeFirebaseFirestore firestore;
    late List<(String, Object)> decodeErrors;
    late FirestoreCheckInRepository subject;

    const settingsPath =
        'users/$uid/nutrition_strategy_settings/nutrition_strategy_settings';
    const breakPath = 'users/$uid/logging_break/logging_break';
    const recordPath = 'users/$uid/check_in_record/check_in_record';
    String annotationPath(String owner, String day) =>
        'users/$owner/nutrition_day_annotations/$day';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      decodeErrors = [];
      subject = FirestoreCheckInRepository(
        firestore: firestore,
        onDecodeError: (path, error, _) => decodeErrors.add((path, error)),
      );
    });

    Future<Map<String, Object?>> stored(String path) async =>
        storedAsTagged((await firestore.doc(path).get()).data()!);

    group('strategy settings', () {
      test('reads the full fixture back exactly', () async {
        await firestore
            .doc(settingsPath)
            .set(storedFixture('nutrition_strategy_settings', 'full'));

        final read = await subject.watchStrategySettings(uid).first;

        expect(
          firestoreToTaggedJson(read.toFirestore()),
          strictlyEquals(taggedFixture('nutrition_strategy_settings', 'full')),
        );
        expect(read.bmrEquation, BmrEquation.cunningham);
      });

      test("emits Swift's defaults when there is no document", () async {
        final read = await subject.watchStrategySettings(uid).first;

        expect(
          read.toFirestore(),
          const NutritionStrategySettings(authorId: uid).toFirestore(),
        );
      });

      test('reports a document Swift cannot read and emits defaults', () async {
        await firestore
            .doc(settingsPath)
            .set(
              storedFixture('nutrition_strategy_settings', 'full')
                ..remove('fast_check_in'),
            );

        final read = await subject.watchStrategySettings(uid).first;

        expect(read.checkInWeekday, 2);
        expect(decodeErrors.single.$1, settingsPath);
      });

      test('logs a failure when no handler is given', () async {
        await firestore.doc(settingsPath).set({'id': 'x'});
        final logging = FirestoreCheckInRepository(firestore: firestore);

        expect((await logging.watchStrategySettings(uid).first).authorId, uid);
      });

      for (final name in ['full', 'minimal']) {
        test('saves the $name fixture exactly', () async {
          final settings = NutritionStrategySettings.fromFirestore(
            modelFixture('nutrition_strategy_settings', name),
          );

          await subject.saveStrategySettings(settings);

          expect(
            await stored(
              'users/${settings.authorId}/nutrition_strategy_settings/'
              'nutrition_strategy_settings',
            ),
            strictlyEquals(taggedFixture('nutrition_strategy_settings', name)),
          );
        });
      }

      test(
        'merges, keeping unknown fields and deleting a cleared start date',
        () async {
          await firestore.doc(settingsPath).set({
            ...storedFixture('nutrition_strategy_settings', 'full'),
            'field_from_a_newer_build': 'kept',
          });
          final full = NutritionStrategySettings.fromFirestore(
            modelFixture('nutrition_strategy_settings', 'full'),
          );

          await subject.saveStrategySettings(
            NutritionStrategySettings(
              authorId: uid,
              checkInWeekday: full.checkInWeekday,
              fastCheckIn: full.fastCheckIn,
              partialLoggingEnabled: full.partialLoggingEnabled,
              weighInEnabled: full.weighInEnabled,
              fastingEnabled: full.fastingEnabled,
              loggingBreakEnabled: full.loggingBreakEnabled,
              estimationMethod: full.estimationMethod,
              bmrEquation: full.bmrEquation,
              calculationMode: full.calculationMode,
              stepInformedUpdates: full.stepInformedUpdates,
              predictiveGoalAdjustments: full.predictiveGoalAdjustments,
            ),
          );

          expect(
            await stored(settingsPath),
            strictlyEquals(
              {
                ...taggedFixture('nutrition_strategy_settings', 'full'),
                'field_from_a_newer_build': 'kept',
              }..remove(NutritionStrategySettingsKeys.calculationStartDate),
            ),
          );
        },
      );
    });

    group('day annotations', () {
      test('reads every annotation in day order', () async {
        await firestore
            .doc(annotationPath(uid, '2026-10-12'))
            .set(storedFixture('nutrition_day_annotation', 'full'));
        await firestore
            .doc(annotationPath(uid, '2026-10-11'))
            .set(
              storedFixture('nutrition_day_annotation', 'full')
                ..['day_key'] = '2026-10-11',
            );

        final read = await subject.watchDayAnnotations(uid).first;

        expect(read.map((a) => a.dayKey), ['2026-10-11', '2026-10-12']);
        expect(
          firestoreToTaggedJson(read.last.toFirestore()),
          strictlyEquals(taggedFixture('nutrition_day_annotation', 'full')),
        );
      });

      test('skips and reports one that does not decode', () async {
        await firestore.doc(annotationPath(uid, 'bad')).set({'day_key': 'bad'});

        expect(await subject.watchDayAnnotations(uid).first, isEmpty);
        expect(decodeErrors.single.$1, annotationPath(uid, 'bad'));
      });

      test('saves the full fixture exactly, under its day key', () async {
        final annotation = NutritionDayAnnotation.fromFirestore(
          modelFixture('nutrition_day_annotation', 'full'),
        );

        await subject.saveDayAnnotations(uid, [annotation]);

        expect(
          await stored(annotationPath(uid, annotation.dayKey)),
          strictlyEquals(taggedFixture('nutrition_day_annotation', 'full')),
        );
      });

      test(
        'an empty annotation deletes the day, and replaces nothing else',
        () async {
          final full = NutritionDayAnnotation.fromFirestore(
            modelFixture('nutrition_day_annotation', 'full'),
          );
          await subject.saveDayAnnotations(uid, [full]);
          final empty = NutritionDayAnnotation(
            dayKey: full.dayKey,
            authorId: uid,
            dateModified: full.dateModified,
          );
          final other = NutritionDayAnnotation(
            dayKey: '2026-10-10',
            authorId: uid,
            dateModified: full.dateModified,
            isFastingDay: true,
          );

          await subject.saveDayAnnotations(uid, [empty, other]);

          expect(
            (await firestore.doc(annotationPath(uid, full.dayKey)).get())
                .exists,
            isFalse,
          );
          expect(
            (await subject.watchDayAnnotations(uid).first).single.toFirestore(),
            other.toFirestore(),
          );
        },
      );
    });

    group('logging break', () {
      test('reads the full fixture back, and null when absent', () async {
        expect(await subject.watchLoggingBreak(uid).first, isNull);
        await firestore
            .doc(breakPath)
            .set(storedFixture('logging_break', 'full'));

        final read = await subject.watchLoggingBreak(uid).first;

        expect(
          firestoreToTaggedJson(read!.toFirestore()),
          strictlyEquals(taggedFixture('logging_break', 'full')),
        );
      });

      test('starting one stores the minimal fixture exactly', () async {
        final minimal = LoggingBreak.fromFirestore(
          modelFixture('logging_break', 'minimal'),
        );

        await subject.startLoggingBreak(minimal.authorId, minimal.startDate);

        expect(
          await stored('users/${minimal.authorId}/logging_break/logging_break'),
          strictlyEquals(taggedFixture('logging_break', 'minimal')),
        );
      });

      test('starting one after an ended one opens it', () async {
        await firestore.doc(breakPath).set({
          ...storedFixture('logging_break', 'full'),
          'field_from_a_newer_build': 1,
        });
        final start = DateTime.utc(2026, 10, 14, 8);

        await subject.startLoggingBreak(uid, start);

        final read = await subject.watchLoggingBreak(uid).first;
        expect(read!.endDate, isNull);
        expect(read.isOpenAt(start), isTrue);
        expect(
          await stored(breakPath),
          containsPair('field_from_a_newer_build', 1),
        );
      });

      test('ending the open one stores the full fixture exactly', () async {
        final full = LoggingBreak.fromFirestore(
          modelFixture('logging_break', 'full'),
        );
        await subject.startLoggingBreak(uid, full.startDate);

        await subject.endLoggingBreak(uid, full.endDate!);

        expect(
          await stored(breakPath),
          strictlyEquals(taggedFixture('logging_break', 'full')),
        );
      });

      test('ending does nothing with no break, or an ended one', () async {
        await subject.endLoggingBreak(uid, DateTime.utc(2026));
        expect((await firestore.doc(breakPath).get()).exists, isFalse);

        await firestore
            .doc(breakPath)
            .set(storedFixture('logging_break', 'full'));
        await subject.endLoggingBreak(uid, DateTime.utc(2026, 10));
        expect(
          await stored(breakPath),
          strictlyEquals(taggedFixture('logging_break', 'full')),
        );
      });
    });

    group('check-in record', () {
      test('reads the full fixture back, and null when absent', () async {
        expect(await subject.watchCheckInRecord(uid).first, isNull);
        await firestore
            .doc(recordPath)
            .set(storedFixture('check_in_record', 'full'));

        final read = await subject.watchCheckInRecord(uid).first;

        expect(
          firestoreToTaggedJson(read!.toFirestore()),
          strictlyEquals(taggedFixture('check_in_record', 'full')),
        );
      });

      test('completing then skipping writes the full fixture', () async {
        final full = CheckInRecord.fromFirestore(
          modelFixture('check_in_record', 'full'),
        );

        await subject.markCheckInCompleted(uid, full.lastCompletedWeekStart!);
        expect(
          await stored(recordPath),
          strictlyEquals(
            taggedFixture('check_in_record', 'full')
              ..remove(CheckInRecordKeys.lastSkippedWeekStart),
          ),
        );
        await subject.markCheckInSkipped(uid, full.lastSkippedWeekStart!);

        expect(
          await stored(recordPath),
          strictlyEquals(taggedFixture('check_in_record', 'full')),
        );
      });

      test('marking a week keeps the other field', () async {
        await firestore
            .doc(recordPath)
            .set(storedFixture('check_in_record', 'full'));
        final week = DateTime.utc(2026, 10, 12);

        await subject.markCheckInCompleted(uid, week);

        final read = await subject.watchCheckInRecord(uid).first;
        expect(read!.lastCompletedWeekStart, week);
        expect(read.lastSkippedWeekStart, DateTime.utc(2026, 9, 28));
      });
    });

    test('every field written by name is a contract key', () {
      expect(
        taggedFixture('nutrition_strategy_settings', 'full').keys,
        contains(NutritionStrategySettingsKeys.calculationStartDate),
      );
      expect(
        taggedFixture('logging_break', 'full').keys,
        contains(LoggingBreakKeys.endDate),
      );
      expect(
        taggedFixture('check_in_record', 'full').keys,
        containsAll(CheckInRecordKeys.all),
      );
    });

    test('a stored timestamp reads as UTC', () async {
      await firestore.doc(breakPath).set({
        ...storedFixture('logging_break', 'minimal'),
        'start_date': Timestamp.fromDate(DateTime.utc(2026, 1, 2, 3)),
      });

      final read = await subject.watchLoggingBreak(uid).first;

      expect(read!.startDate, DateTime.utc(2026, 1, 2, 3));
      expect(read.startDate.isUtc, isTrue);
    });
  });
}
