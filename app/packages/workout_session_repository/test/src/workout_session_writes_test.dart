// The two writes finishing a workout makes, checked against the Firestore
// contract: what is stored is exactly the model's canonical encoding.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/contract.dart';

void main() {
  group('FirestoreWorkoutSessionRepository writes', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreWorkoutSessionRepository subject;

    DocumentReference<Map<String, dynamic>> document(String uid, String id) =>
        firestore.doc('users/$uid/workout_sessions/$id');
    Future<Map<String, Object?>> stored(String uid, String id) async =>
        storedAsTagged((await document(uid, id).get()).data()!);

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = FirestoreWorkoutSessionRepository(firestore: firestore);
    });

    group('saveSession', () {
      for (final name in [
        'full',
        'minimal',
        'legacy-lenient-nested.expected',
        'legacy-null-optionals.expected',
        'legacy-retired-keys.expected',
      ]) {
        test('stores the $name fixture as the model encodes it', () async {
          final model = WorkoutSessionModel.fromFirestore(
            modelFixture('workout_session', name),
          );

          await subject.saveSession(model.authorId, model);

          final written = await stored(model.authorId, model.id);
          expect(
            written,
            strictlyEquals(firestoreToTaggedJson(model.toFirestore())),
          );
          expect(
            written,
            strictlyEquals(taggedFixture('workout_session', name)),
          );
        });
      }

      test('reads back as the session saved', () async {
        final model = WorkoutSessionModel.fromFirestore(
          modelFixture('workout_session', 'full'),
        );

        await subject.saveSession(model.authorId, model);
        final read = await subject.session(model.authorId, model.id);

        expect(
          firestoreToTaggedJson(read!.toFirestore()),
          strictlyEquals(taggedFixture('workout_session', 'full')),
        );
      });

      test('merges, keeping a field this app does not know', () async {
        final model = WorkoutSessionModel.fromFirestore(
          modelFixture('workout_session', 'full'),
        );
        await document(
          model.authorId,
          model.id,
        ).set({'field_from_a_newer_build': 1});

        await subject.saveSession(model.authorId, model);

        expect(
          await stored(model.authorId, model.id),
          strictlyEquals({
            ...taggedFixture('workout_session', 'full'),
            'field_from_a_newer_build': 1,
          }),
        );
      });

      test('replaces the exercises whole, as a merge does a list', () async {
        final full = WorkoutSessionModel.fromFirestore(
          modelFixture('workout_session', 'full'),
        );
        await subject.saveSession(full.authorId, full);
        final emptied = WorkoutSessionModel.fromFirestore({
          ...full.toFirestore(),
          WorkoutSessionModelKeys.exercises: <Object?>[],
        });

        await subject.saveSession(full.authorId, emptied);

        final written = await stored(full.authorId, full.id);
        expect(written[WorkoutSessionModelKeys.exercises], isEmpty);
      });
    });

    group('updateWeekStreakCount', () {
      test('sets week_streak_count alone, as an int', () async {
        final model = WorkoutSessionModel.fromFirestore(
          modelFixture('workout_session', 'full'),
        );
        await document(
          model.authorId,
          model.id,
        ).set(storedFixture('workout_session', 'full'));

        await subject.updateWeekStreakCount(model.authorId, model.id, 9);

        expect(
          await stored(model.authorId, model.id),
          strictlyEquals({
            ...taggedFixture('workout_session', 'full'),
            WorkoutSessionModelKeys.weekStreakCount: 9,
          }),
        );
      });

      test('fails when there is no such session, as Firestore does', () async {
        await expectLater(
          subject.updateWeekStreakCount('someone', 'missing', 3),
          throwsA(isA<FirebaseException>()),
        );
      });

      test('names a field of the contract', () {
        expect(
          taggedFixture('workout_session', 'full'),
          contains(WorkoutSessionModelKeys.weekStreakCount),
        );
      });
    });
  });

  group('InMemoryWorkoutSessionRepository writes', () {
    final model = WorkoutSessionModel.fromFirestore(
      modelFixture('workout_session', 'full'),
    );
    final uid = model.authorId;
    late InMemoryWorkoutSessionRepository subject;

    setUp(() => subject = InMemoryWorkoutSessionRepository(sessions: []));

    test('saves a new session, and watchers see it', () async {
      final ids = subject
          .watchSessions(uid)
          .map((sessions) => [for (final s in sessions) s.id]);
      final expectation = expectLater(
        ids,
        emitsInOrder([
          <String>[],
          [model.id],
        ]),
      );

      await subject.saveSession(uid, model);

      await expectation;
      final read = await subject.session(uid, model.id);
      expect(
        firestoreToTaggedJson(read!.toFirestore()),
        strictlyEquals(taggedFixture('workout_session', 'full')),
      );
    });

    test('merges a save over the stored session field by field', () async {
      await subject.saveSession(uid, model);
      final minimal = WorkoutSessionModel.fromFirestore({
        ...modelFixture('workout_session', 'minimal'),
        WorkoutSessionModelKeys.id: model.id,
        WorkoutSessionModelKeys.authorId: uid,
      });

      await subject.saveSession(uid, minimal);

      final read = (await subject.session(uid, model.id))!;
      expect(read.name, minimal.name);
      expect(read.notes, model.notes);
      expect(read.exercises, isEmpty);
    });

    test('sets the week streak on a stored session', () async {
      await subject.saveSession(uid, model);

      await subject.updateWeekStreakCount(uid, model.id, 11);

      expect((await subject.session(uid, model.id))!.weekStreakCount, 11);
    });

    test('fails to set the week streak on a missing session', () async {
      await expectLater(
        subject.updateWeekStreakCount(uid, 'missing', 1),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'not-found'),
        ),
      );
    });
  });
}
