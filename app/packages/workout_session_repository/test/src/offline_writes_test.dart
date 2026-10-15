import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The repository's writes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy).
void main() {
  group('FirestoreWorkoutSessionRepository offline', () {
    late OfflineFirestore firestore;
    late List<(String, String)> refused;
    late FirestoreWorkoutSessionRepository subject;

    // FieldValue sentinels bind to whichever FieldValue factory is

    // installed when first used; fake_cloud_firestore installs its own

    // only when a fake is built. Build one first, or when this file runs

    // before the Firestore tests in one isolate (very_good test's

    // optimisation) they get the method-channel factory.

    setUpAll(FakeFirebaseFirestore.new);

    setUp(() {
      firestore = OfflineFirestore();
      refused = [];
      subject = FirestoreWorkoutSessionRepository(
        firestore: firestore,
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
      );
    });

    test('saveSession complete offline; a refusal is reported', () async {
      final session = WorkoutSessionModel.fromFirestore(
        modelFixture('workout_session', 'full'),
      );
      await subject.saveSession('u', session);
      expect(firestore.writes, ['users/u/workout_sessions/${session.id}']);
      expect(refused, isEmpty);

      firestore.refuse('permission-denied');
      await pumpEventQueue();

      expect(refused, [
        for (final path in ['users/u/workout_sessions/${session.id}'])
          (path, 'permission-denied'),
      ]);
    });

    test(
      'updateWeekStreakCount completes offline; not-found is reported',
      () async {
        await subject.updateWeekStreakCount('u', 's', 3);
        expect(refused, isEmpty);

        firestore.refuse('not-found');
        await pumpEventQueue();

        expect(refused, [('users/u/workout_sessions/s', 'not-found')]);
      },
    );

    test(
      'updateStravaActivityId completes offline; not-found is reported',
      () async {
        await subject.updateStravaActivityId('u', 's', 42);
        expect(refused, isEmpty);

        firestore.refuse('not-found');
        await pumpEventQueue();

        expect(refused, [('users/u/workout_sessions/s', 'not-found')]);
      },
    );
  });
}
