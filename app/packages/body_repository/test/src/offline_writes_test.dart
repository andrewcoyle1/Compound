import 'package:body_repository/body_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The repository's writes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy).
void main() {
  group('FirestoreBodyRepository offline', () {
    late OfflineFirestore firestore;
    late List<(String, String)> refused;
    late FirestoreBodyRepository subject;

    setUp(() {
      firestore = OfflineFirestore();
      refused = [];
      subject = FirestoreBodyRepository(
        firestore: firestore,
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
      );
    });

    test(
      'saveMeasurement and saveGoal complete offline; a refusal is reported',
      () async {
        final entry = BodyMeasurementEntry.fromFirestore(
          modelFixture('body_measurement', 'full'),
        );
        final goal = WeightGoal.fromFirestore(
          modelFixture('weight_goal', 'full'),
        );
        await subject.saveMeasurement(entry);
        await subject.saveGoal(goal);
        expect(firestore.writes, [
          'users/${entry.authorId}/body_measurements/${entry.id}',
          'users/${goal.userId}/goals/${goal.goalId}',
        ]);
        expect(refused, isEmpty);

        firestore.refuse('permission-denied');
        await pumpEventQueue();

        expect(refused, [
          for (final path in [
            'users/${entry.authorId}/body_measurements/${entry.id}',
            'users/${goal.userId}/goals/${goal.goalId}',
          ])
            (path, 'permission-denied'),
        ]);
      },
    );

    test('abandonGoal completes offline; not-found is reported', () async {
      await subject.abandonGoal('u', 'g');
      expect(refused, isEmpty);

      firestore.refuse('not-found');
      await pumpEventQueue();

      expect(refused, [('users/u/goals/g', 'not-found')]);
    });
  });
}
