import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The repository's writes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy).
void main() {
  group('FirestoreFoodRepository offline', () {
    late OfflineFirestore firestore;
    late List<(String, String)> refused;
    late FirestoreFoodRepository subject;

    setUp(() {
      firestore = OfflineFirestore();
      refused = [];
      subject = FirestoreFoodRepository(
        firestore: firestore,
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
      );
    });

    test('saveFood complete offline; a refusal is reported', () async {
      final food = FoodModel.fromFirestore(modelFixture('food_model', 'full'));
      await subject.saveFood(food);
      expect(firestore.writes, [
        'users/${food.authorId}/foods/${food.ingredientId}',
      ]);
      expect(refused, isEmpty);

      firestore.refuse('permission-denied');
      await pumpEventQueue();

      expect(refused, [
        for (final path in [
          'users/${food.authorId}/foods/${food.ingredientId}',
        ])
          (path, 'permission-denied'),
      ]);
    });
  });
}
