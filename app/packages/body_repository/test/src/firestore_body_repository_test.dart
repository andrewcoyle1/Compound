import 'dart:convert';
import 'dart:io';

import 'package:body_repository/body_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contract.dart';

Map<String, Object?> _tagged(String model, String name) => jsonDecode(
  File('../../../contracts/firestore/$model/$name.json').readAsStringSync(),
) as Map<String, Object?>;

/// A contract fixture as Firestore holds it: each tagged timestamp a
/// [Timestamp].
Map<String, Object?> _fixture(String model, String name) =>
    _toFirestore(taggedJsonToFirestore(_tagged(model, name)));

Map<String, Object?> _toFirestore(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _value(value)));

Object? _value(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => _toFirestore(map),
  final List<Object?> list => list.map(_value).toList(),
  _ => value,
};

void main() {
  group(FirestoreBodyRepository, () {
    const uid = 'user_contract_full';
    late FakeFirebaseFirestore firestore;
    late List<(String, Object)> decodeErrors;
    late FirestoreBodyRepository subject;

    CollectionReference<Map<String, dynamic>> collection(
      String owner,
      String name,
    ) => firestore.collection('users/$owner/$name');

    setUp(() {
      firestore = FakeFirebaseFirestore();
      decodeErrors = [];
      subject = FirestoreBodyRepository(
        firestore: firestore,
        onDecodeError: (path, error, _) => decodeErrors.add((path, error)),
      );
    });

    group('watchMeasurements', () {
      Map<String, Object?> live(String id, String date) =>
          _fixture('body_measurement', 'full')
            ..['id'] = id
            ..['date'] = Timestamp.fromDate(DateTime.parse(date))
            ..remove('deleted_at');

      test(
        'reads the full fixture back exactly, timestamps included',
        () async {
          await collection(uid, 'body_measurements')
              .doc('full')
              .set(_fixture('body_measurement', 'full')..remove('deleted_at'));

          final read = await subject.watchMeasurements(uid).first;

          expect(
            firestoreToTaggedJson(read.single.toFirestore()),
            equals(_tagged('body_measurement', 'full')..remove('deleted_at')),
          );
          expect(read.single.date, DateTime.utc(2026, 10, 12, 6, 45, 0, 250));
          expect(read.single.date.isUtc, isTrue);
          expect(decodeErrors, isEmpty);
        },
      );

      test("returns $uid's live entries, oldest first", () async {
        final entries = collection(uid, 'body_measurements');
        await entries.doc('b').set(live('b', '2026-10-12T07:00:00Z'));
        await entries.doc('a').set(live('a', '2026-10-10T07:00:00Z'));
        await entries.doc('deleted').set(_fixture('body_measurement', 'full'));
        await entries
            .doc('forged')
            .set(live('forged', '2026-10-11T07:00:00Z')..['author_id'] = 'x');
        await collection(
          'someone_else',
          'body_measurements',
        ).doc('theirs').set(live('theirs', '2026-10-11T07:00:00Z'));

        final read = await subject.watchMeasurements(uid).first;

        expect(read.map((entry) => entry.id), ['a', 'b']);
      });

      test('skips and reports an entry that does not decode', () async {
        final entries = collection(uid, 'body_measurements');
        await entries.doc('good').set(live('good', '2026-10-12T07:00:00Z'));
        await entries
            .doc('bad')
            .set(live('bad', '2026-10-12T07:00:00Z')..['source'] = 'scale');

        final read = await subject.watchMeasurements(uid).first;

        expect(read.map((entry) => entry.id), ['good']);
        expect(decodeErrors.single.$1, 'users/$uid/body_measurements/bad');
      });

      test('emits again when an entry changes', () async {
        final counts = expectLater(
          subject.watchMeasurements(uid).map((list) => list.length),
          emitsInOrder([0, 1]),
        );
        await Future<void>.delayed(Duration.zero);
        await collection(
          uid,
          'body_measurements',
        ).doc('new').set(live('new', '2026-10-12T07:00:00Z'));
        await counts;
      });
    });

    group('watchSteps', () {
      Map<String, Object?> live(String id, String date) =>
          _fixture('steps', 'full')
            ..['id'] = id
            ..['date'] = Timestamp.fromDate(DateTime.parse(date))
            ..remove('deleted_at');

      test('reads the full fixture back exactly', () async {
        await collection(
          uid,
          'steps',
        ).doc('full').set(_fixture('steps', 'full')..remove('deleted_at'));

        final read = await subject.watchSteps(uid).first;

        expect(
          firestoreToTaggedJson(read.single.toFirestore()),
          equals(_tagged('steps', 'full')..remove('deleted_at')),
        );
      });

      test("returns $uid's live counts, oldest first", () async {
        final steps = collection(uid, 'steps');
        await steps.doc('b').set(live('b', '2026-10-12T00:00:00Z'));
        await steps.doc('a').set(live('a', '2026-10-11T00:00:00Z'));
        await steps.doc('deleted').set(_fixture('steps', 'full'));
        await steps
            .doc('forged')
            .set(live('forged', '2026-10-10T00:00:00Z')..['author_id'] = 'x');
        await steps
            .doc('bad')
            .set(live('bad', '2026-10-10T00:00:00Z')..['number'] = 'many');

        final read = await subject.watchSteps(uid).first;

        expect(read.map((entry) => entry.id), ['a', 'b']);
        expect(decodeErrors.single.$1, 'users/$uid/steps/bad');
      });
    });

    group('watchAnalyticsSettings', () {
      DocumentReference<Map<String, dynamic>> settings() =>
          firestore.doc('users/$uid/analytics_settings/analytics_settings');

      test('reads the settings document back exactly', () async {
        await settings().set(_fixture('analytics_settings', 'full'));

        final read = await subject.watchAnalyticsSettings(uid).first;

        expect(
          firestoreToTaggedJson(read.toFirestore()),
          equals(_tagged('analytics_settings', 'full')),
        );
        expect(read.stepGoal, 12000);
      });

      test("emits Swift's defaults when there is no document", () async {
        final read = await subject.watchAnalyticsSettings(uid).first;

        expect(
          read.toFirestore(),
          const AnalyticsSettings(authorId: uid).toFirestore(),
        );
        expect(read.stepGoal, 8000);
      });

      test('reports a document Swift cannot read and emits defaults', () async {
        await settings().set(
          _fixture('analytics_settings', 'full')..remove('hidden_section_ids'),
        );

        final read = await subject.watchAnalyticsSettings(uid).first;

        expect(read.hiddenSectionIds, isEmpty);
        expect(read.dailyStepGoal, isNull);
        expect(
          decodeErrors.single.$1,
          'users/$uid/analytics_settings/analytics_settings',
        );
      });
    });

    group('watchCurrentGoal', () {
      test('reads the goal currentGoalId names, exactly', () async {
        await collection(
          uid,
          'goals',
        ).doc('goal_contract_full').set(_fixture('weight_goal', 'full'));

        final read = await subject
            .watchCurrentGoal(uid, currentGoalId: 'goal_contract_full')
            .first;

        expect(
          firestoreToTaggedJson(read!.toFirestore()),
          equals(_tagged('weight_goal', 'full')),
        );
        expect(read.objective, OverarchingObjective.gainWeight);
      });

      test('reads the goal under the user id when there is no '
          'currentGoalId, with no goal_id stored', () async {
        await collection(
          uid,
          'goals',
        ).doc(uid).set(_fixture('weight_goal', 'full')..remove('goal_id'));

        for (final currentGoalId in [null, '']) {
          final read = await subject
              .watchCurrentGoal(uid, currentGoalId: currentGoalId)
              .first;
          expect(read!.goalId, uid);
        }
      });

      test('emits null when there is no goal', () async {
        expect(
          await subject.watchCurrentGoal(uid, currentGoalId: 'gone').first,
          isNull,
        );
      });

      test(
        'emits null and reports a goal stored as a string objective',
        () async {
          await collection(uid, 'goals')
              .doc(uid)
              .set(
                _fixture('weight_goal', 'full')..['objective'] = 'loseWeight',
              );

          expect(await subject.watchCurrentGoal(uid).first, isNull);
          expect(decodeErrors.single.$1, 'users/$uid/goals/$uid');
        },
      );

      test('logs a failure when no handler is given', () async {
        await collection(uid, 'goals').doc(uid).set({'user_id': uid});
        final logging = FirestoreBodyRepository(firestore: firestore);

        expect(await logging.watchCurrentGoal(uid).first, isNull);
      });
    });

    Future<Map<String, Object?>> stored(String path) async =>
        storedAsTagged((await firestore.doc(path).get()).data()!);

    group('saveMeasurement', () {
      for (final name in ['full', 'minimal']) {
        test('stores the $name fixture as the model encodes it', () async {
          final entry = BodyMeasurementEntry.fromFirestore(
            modelFixture('body_measurement', name),
          );

          await subject.saveMeasurement(entry);

          final written = await stored(
            'users/${entry.authorId}/body_measurements/${entry.id}',
          );
          expect(
            written,
            strictlyEquals(firestoreToTaggedJson(entry.toFirestore())),
          );
          expect(
            written,
            strictlyEquals(taggedFixture('body_measurement', name)),
          );
        });
      }

      test('merges: a field the entry omits is kept, as in Swift', () async {
        final full = BodyMeasurementEntry.fromFirestore(
          modelFixture('body_measurement', 'full'),
        );
        final path = 'users/$uid/body_measurements/${full.id}';
        await firestore.doc(path).set({
          ...storedFixture('body_measurement', 'full'),
          'field_from_a_newer_build': true,
        });

        await subject.saveMeasurement(
          BodyMeasurementEntry(
            id: full.id,
            authorId: full.authorId,
            date: full.date,
            source: full.source,
            dateCreated: full.dateCreated,
            weightKg: 70.5,
          ),
        );

        expect(
          await stored(path),
          strictlyEquals({
            ...taggedFixture('body_measurement', 'full'),
            'weight_kg': 70.5,
            'field_from_a_newer_build': true,
          }),
        );
      });
    });

    group('saveGoal', () {
      for (final name in ['full', 'minimal']) {
        test('stores the $name fixture as the model encodes it', () async {
          final goal = WeightGoal.fromFirestore(
            modelFixture('weight_goal', name),
          );

          await subject.saveGoal(goal);

          final written = await stored(
            'users/${goal.userId}/goals/${goal.goalId}',
          );
          expect(
            written,
            strictlyEquals(firestoreToTaggedJson(goal.toFirestore())),
          );
          expect(written, strictlyEquals(taggedFixture('weight_goal', name)));
          final read = await subject
              .watchCurrentGoal(goal.userId, currentGoalId: goal.goalId)
              .first;
          expect(read!.toFirestore(), goal.toFirestore());
        });
      }
    });

    group('abandonGoal', () {
      test('writes status and nothing else', () async {
        const path = 'users/$uid/goals/goal_contract_full';
        await firestore.doc(path).set(storedFixture('weight_goal', 'full'));

        await subject.abandonGoal(uid, 'goal_contract_full');

        expect(
          await stored(path),
          strictlyEquals({
            ...taggedFixture('weight_goal', 'full'),
            'status': 'abandoned',
          }),
        );
      });

      test('abandons a goal from before goal ids, under the user id', () async {
        const legacy = 'user_legacy';
        const path = 'users/$legacy/goals/$legacy';
        await firestore
            .doc(path)
            .set(storedFixture('weight_goal', 'legacy-no-goal-id'));

        await subject.abandonGoal(legacy, legacy);

        expect(
          await stored(path),
          strictlyEquals({
            ...taggedFixture('weight_goal', 'legacy-no-goal-id'),
            'status': 'abandoned',
          }),
        );
      });

      test('fails when there is no such goal, as Firestore does', () async {
        await expectLater(
          subject.abandonGoal(uid, 'missing'),
          throwsA(isA<FirebaseException>()),
        );
      });
    });
  });
}
