import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The repository's writes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy).
void main() {
  group('FirestoreProgramRepository offline', () {
    late OfflineFirestore firestore;
    late List<(String, String)> refused;
    late FirestoreProgramRepository subject;

    setUp(() {
      firestore = OfflineFirestore();
      refused = [];
      subject = FirestoreProgramRepository(
        firestore: firestore,
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
      );
    });

    test('the writes complete offline; a refusal is reported', () async {
      final mesocycle = Mesocycle.fromFirestore(
        modelFixture('mesocycle', 'full'),
      );
      final macrocycle = Macrocycle.fromFirestore(
        modelFixture('macrocycle', 'full'),
      );
      await subject.saveMesocycle(mesocycle);
      await subject.saveMacrocycle(macrocycle);
      expect(firestore.writes, [
        'users/${mesocycle.authorId}/mesocycles/${mesocycle.id}',
        'users/${macrocycle.authorId}/macrocycles/${macrocycle.id}',
      ]);
      expect(refused, isEmpty);

      firestore.refuse('permission-denied');
      await pumpEventQueue();

      expect(refused, [
        for (final path in [
          'users/${mesocycle.authorId}/mesocycles/${mesocycle.id}',
          'users/${macrocycle.authorId}/macrocycles/${macrocycle.id}',
        ])
          (path, 'permission-denied'),
      ]);
    });
  });
}
