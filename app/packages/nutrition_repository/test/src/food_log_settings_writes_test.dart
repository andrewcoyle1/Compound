// saveFoodLogSettings, checked against the Firestore contract: what is
// stored is exactly the model's canonical encoding.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../helpers/contract.dart';

void main() {
  group('FirestoreNutritionRepository.saveFoodLogSettings', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreNutritionRepository subject;

    DocumentReference<Map<String, dynamic>> document(String uid) =>
        firestore.doc('users/$uid/food_log_settings/food_log_settings');
    Future<Map<String, Object?>> stored(String uid) async =>
        storedAsTagged((await document(uid).get()).data()!);

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = FirestoreNutritionRepository(firestore: firestore);
    });

    for (final name in ['full', 'minimal']) {
      test('stores the $name fixture as the model encodes it', () async {
        final model = FoodLogSettings.fromFirestore(
          modelFixture('food_log_settings', name),
        );

        await subject.saveFoodLogSettings(model);

        final written = await stored(model.authorId);
        expect(written, strictlyEquals(model.toFirestore()));
        expect(
          written,
          strictlyEquals(taggedFixture('food_log_settings', name)),
        );
      });
    }

    test('reads back through watchFoodLogSettings', () async {
      final model = FoodLogSettings.fromFirestore(
        modelFixture('food_log_settings', 'full'),
      );

      await subject.saveFoodLogSettings(model);
      final read = await subject.watchFoodLogSettings(model.authorId).first;

      expect(
        read.toFirestore(),
        strictlyEquals(taggedFixture('food_log_settings', 'full')),
      );
    });

    test('merges: a field this app does not know survives, and the whole '
        'document is rewritten', () async {
      final full = FoodLogSettings.fromFirestore(
        modelFixture('food_log_settings', 'full'),
      );
      await document(full.authorId).set({
        ...storedFixture('food_log_settings', 'full'),
        'field_from_a_newer_build': 1,
      });

      final change = FoodLogSettings(authorId: full.authorId, premove: true);
      await subject.saveFoodLogSettings(change);

      expect(
        await stored(full.authorId),
        strictlyEquals({
          ...change.toFirestore(),
          'field_from_a_newer_build': 1,
        }),
      );
    });
  });

  group('InMemoryNutritionRepository.saveFoodLogSettings', () {
    const uid = 'me';

    test('saves new settings, and watchers see them', () async {
      final subject = InMemoryNutritionRepository();
      final premove = subject
          .watchFoodLogSettings(uid)
          .map((settings) => settings.premove);
      final expectation = expectLater(premove, emitsInOrder([false, true]));

      await subject.saveFoodLogSettings(
        const FoodLogSettings(authorId: uid, premove: true),
      );

      await expectation;
    });

    test('merges over stored settings, and keeps other users apart', () async {
      final subject = InMemoryNutritionRepository(
        foodLogSettings: const FoodLogSettings(authorId: uid, startHour: 5),
      );

      await subject.saveFoodLogSettings(
        const FoodLogSettings(authorId: uid, endHour: 20),
      );

      final mine = await subject.watchFoodLogSettings(uid).first;
      expect(mine.endHour, 20);
      // A whole document is written, so the default start hour replaces 5.
      expect(mine.startHour, 7);
      expect((await subject.watchFoodLogSettings('you').first).endHour, 23);
    });
  });
}
