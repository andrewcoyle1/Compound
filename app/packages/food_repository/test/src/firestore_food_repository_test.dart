import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';

import '../helpers/contract.dart';

void main() {
  group(FirestoreFoodRepository, () {
    const uid = 'user_contract_full';
    late FakeFirebaseFirestore firestore;
    late List<(String, Object)> decodeErrors;
    late FirestoreFoodRepository subject;

    CollectionReference<Map<String, dynamic>> foods(String owner) =>
        firestore.collection('users/$owner/foods');
    Future<Map<String, Object?>> stored(String path) async =>
        storedAsTagged((await firestore.doc(path).get()).data()!);
    FoodModel fixtureFood(String name) =>
        FoodModel.fromFirestore(modelFixture('food_model', name));

    setUp(() {
      firestore = FakeFirebaseFirestore();
      decodeErrors = [];
      subject = FirestoreFoodRepository(
        firestore: firestore,
        onDecodeError: (path, error, _) => decodeErrors.add((path, error)),
      );
    });

    group('watchFoods', () {
      test('reads every fixture back as Swift writes it back', () async {
        final cases = {
          'full': 'full',
          'minimal': 'minimal',
          'legacy-null-optionals': 'legacy-null-optionals.expected',
          'legacy-retired-keys': 'legacy-retired-keys.expected',
        };
        for (final name in cases.keys) {
          await foods(uid).doc(name).set(storedFixture('food_model', name));
        }

        final read = await subject.watchFoods(uid).first;

        expect(read, hasLength(cases.length));
        for (final (index, expected) in cases.values.indexed) {
          expect(
            firestoreToTaggedJson(read[index].toFirestore()),
            strictlyEquals(taggedFixture('food_model', expected)),
          );
        }
        expect(decodeErrors, isEmpty);
      });

      test('reads only the user its path names', () async {
        await foods('someone_else')
            .doc('f')
            .set(storedFixture('food_model', 'full'));

        expect(await subject.watchFoods(uid).first, isEmpty);
      });

      test('skips and reports a food that does not decode', () async {
        await foods(uid).doc('full').set(storedFixture('food_model', 'full'));
        await foods(uid).doc('broken').set({'name': 'No id'});

        final read = await subject.watchFoods(uid).first;

        expect(read.map((food) => food.ingredientId), ['food_contract_full']);
        expect(decodeErrors.single.$1, 'users/$uid/foods/broken');
      });

      test('logs a failure when no handler is given', () async {
        await foods(uid).doc('broken').set({'name': 'No id'});

        final read = await FirestoreFoodRepository(firestore: firestore)
            .watchFoods(uid)
            .first;

        expect(read, isEmpty);
      });

      test('emits again when a food is saved', () async {
        final emissions = subject.watchFoods(uid).take(2).toList();
        await pumpEventQueue();

        await subject.saveFood(fixtureFood('full'));

        final [before, after] = await emissions;
        expect(before, isEmpty);
        expect(after.single.ingredientId, 'food_contract_full');
      });
    });

    group('saveFood', () {
      test('stores the full fixture exactly as the model encodes it', () async {
        final food = fixtureFood('full');

        await subject.saveFood(food);

        final written = await stored('users/$uid/foods/food_contract_full');
        expect(
          written,
          strictlyEquals(firestoreToTaggedJson(food.toFirestore())),
        );
        expect(written, strictlyEquals(taggedFixture('food_model', 'full')));
      });

      test('stores the minimal fixture once it has an author', () async {
        final food = FoodModel.fromFirestore({
          ...modelFixture('food_model', 'minimal'),
          FoodModelKeys.authorId: uid,
        });

        await subject.saveFood(food);

        expect(
          await stored('users/$uid/foods/food_contract_minimal'),
          strictlyEquals({
            ...taggedFixture('food_model', 'minimal'),
            FoodModelKeys.authorId: uid,
          }),
        );
      });

      test('refuses a food with no author, writing nothing', () async {
        final minimal = fixtureFood('minimal');
        final blank = FoodModel.fromFirestore({
          ...modelFixture('food_model', 'minimal'),
          FoodModelKeys.authorId: '',
        });

        expect(() => subject.saveFood(minimal), throwsArgumentError);
        expect(() => subject.saveFood(blank), throwsArgumentError);
        expect((await firestore.collectionGroup('foods').get()).docs, isEmpty);
      });

      test('refuses a food with no id', () {
        final food = FoodModel.fromFirestore({
          ...modelFixture('food_model', 'full'),
          FoodModelKeys.ingredientId: '',
        });

        expect(() => subject.saveFood(food), throwsArgumentError);
      });

      test('merges, keeping a field this app does not know', () async {
        const path = 'users/$uid/foods/food_contract_full';
        await firestore.doc(path).set({
          ...storedFixture('food_model', 'full'),
          'field_from_a_newer_build': 'kept',
        });

        await subject.saveFood(fixtureFood('full'));

        expect(
          await stored(path),
          strictlyEquals({
            ...taggedFixture('food_model', 'full'),
            'field_from_a_newer_build': 'kept',
          }),
        );
      });

      // As Swift's `setData(merge: true)`: a nutrient left out of a save is
      // kept, so removing one never reaches Firestore.
      test('merges nutrients key by key, as Swift does', () async {
        final full = fixtureFood('full');
        await subject.saveFood(full);

        await subject.saveFood(
          FoodModel.fromFirestore({
            ...full.toFirestore(),
            FoodModelKeys.nutrients: {'calories': 42.5},
          }),
        );

        final written = await stored('users/$uid/foods/food_contract_full');
        final expected = {
          ...(taggedFixture('food_model', 'full')['nutrients']!
              as Map<String, Object?>),
          'calories': 42.5,
        };
        expect(written['nutrients'], strictlyEquals(expected));
      });
    });

    group('deleteFood', () {
      test('deletes the document, and a missing one is no error', () async {
        final full = fixtureFood('full');
        await subject.saveFood(full);

        await subject.deleteFood(uid, full.ingredientId);
        await subject.deleteFood(uid, 'missing');

        expect((await foods(uid).get()).docs, isEmpty);
      });
    });
  });
}
