import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

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
  group(FirestoreNutritionRepository, () {
    const uid = 'user_contract_full';
    late FakeFirebaseFirestore firestore;
    late List<(String, Object)> decodeErrors;
    late FirestoreNutritionRepository subject;

    CollectionReference<Map<String, dynamic>> meals(String owner) =>
        firestore.collection('users/$owner/meal_logs');
    DocumentReference<Map<String, dynamic>> plan(String owner) =>
        firestore.doc('diet_plans/$owner');
    DocumentReference<Map<String, dynamic>> settings(String owner) =>
        firestore.doc('users/$owner/food_log_settings/food_log_settings');

    setUp(() {
      firestore = FakeFirebaseFirestore();
      decodeErrors = [];
      subject = FirestoreNutritionRepository(
        firestore: firestore,
        onDecodeError: (path, error, _) => decodeErrors.add((path, error)),
      );
    });

    group('watchMeals', () {
      test(
        'reads the full fixture back exactly, timestamps included',
        () async {
          await meals(uid)
              .doc('meal_log_contract_full')
              .set(_fixture('meal_log', 'full'));

          final read = await subject.watchMeals(uid).first;

          expect(
            firestoreToTaggedJson(read.single.toFirestore()),
            equals(_tagged('meal_log', 'full')),
          );
          expect(read.single.date, DateTime.utc(2026, 10, 12, 7, 45, 30, 250));
          expect(read.single.date.isUtc, isTrue);
          expect(decodeErrors, isEmpty);
        },
      );

      test(
        'returns only meals $uid authored in their own collection',
        () async {
          Map<String, Object?> minimal() =>
              _fixture('meal_log', 'minimal')..['author_id'] = uid;
          await meals(uid).doc('mine').set(minimal());
          await meals(uid).doc('forged').set(_fixture('meal_log', 'minimal'));
          await meals('someone_else').doc('theirs').set(minimal());

          final read = await subject.watchMeals(uid).first;

          expect(read.map((meal) => meal.authorId), [uid]);
        },
      );

      test("drops a day's Apple Health import beside logged meals", () async {
        final logged = _fixture('meal_log', 'full');
        final import = _fixture('meal_log', 'full')
          ..['meal_id'] = MealLogModel.healthKitMealId('2026-10-12');
        await meals(uid).doc('logged').set(logged);
        await meals(uid).doc('import').set(import);

        final read = await subject.watchMeals(uid).first;

        expect(read.map((meal) => meal.mealId), ['meal_log_contract_full']);
      });

      test('skips and reports a meal that does not decode', () async {
        await meals(uid).doc('good').set(_fixture('meal_log', 'full'));
        await meals(uid)
            .doc('bad')
            .set(_fixture('meal_log', 'full')..remove('day_key'));

        final read = await subject.watchMeals(uid).first;

        expect(read.map((meal) => meal.mealId), ['meal_log_contract_full']);
        expect(decodeErrors.single.$1, 'users/$uid/meal_logs/bad');
      });

      test('emits again when a meal changes', () async {
        final first = expectLater(
          subject.watchMeals(uid).map((list) => list.length),
          emitsInOrder([0, 1]),
        );
        await Future<void>.delayed(Duration.zero);
        await meals(uid).doc('new').set(_fixture('meal_log', 'full'));
        await first;
      });
    });

    group('watchDietPlan', () {
      test('reads diet_plans/{uid} back exactly', () async {
        await plan(uid).set(_fixture('diet_plan', 'full'));

        final read = await subject.watchDietPlan(uid).first;

        expect(
          firestoreToTaggedJson(read!.toFirestore()),
          equals(_tagged('diet_plan', 'full')),
        );
        expect(read.days, hasLength(7));
      });

      test('emits null when there is no plan', () async {
        expect(await subject.watchDietPlan(uid).first, isNull);
      });

      test('emits null and reports a plan that does not decode', () async {
        await plan(uid).set({'planId': uid});

        expect(await subject.watchDietPlan(uid).first, isNull);
        expect(decodeErrors.single.$1, 'diet_plans/$uid');
      });

      test('logs a failure when no handler is given', () async {
        await plan(uid).set({'planId': uid});
        final logging = FirestoreNutritionRepository(firestore: firestore);

        expect(await logging.watchDietPlan(uid).first, isNull);
      });
    });

    group('watchFoodLogSettings', () {
      test('reads the settings document back exactly', () async {
        await settings(uid).set(_fixture('food_log_settings', 'full'));

        final read = await subject.watchFoodLogSettings(uid).first;

        expect(
          firestoreToTaggedJson(read.toFirestore()),
          equals(_tagged('food_log_settings', 'full')),
        );
      });

      test("emits Swift's defaults when there is no document", () async {
        final read = await subject.watchFoodLogSettings(uid).first;

        expect(
          read.toFirestore(),
          const FoodLogSettings(authorId: uid).toFirestore(),
        );
      });

      test('reports a document Swift cannot read and emits defaults', () async {
        await settings(uid).set(
          _fixture('food_log_settings', 'full')..remove('hide_empty_hours'),
        );

        final read = await subject.watchFoodLogSettings(uid).first;

        expect(read.hideEmptyHours, isFalse);
        expect(read.startHour, 7);
        expect(
          decodeErrors.single.$1,
          'users/$uid/food_log_settings/food_log_settings',
        );
      });
    });

    Future<Map<String, Object?>> stored(String path) async =>
        storedAsTagged((await firestore.doc(path).get()).data()!);

    group('saveMeal', () {
      for (final name in ['full', 'minimal']) {
        test('stores the $name fixture as the model encodes it', () async {
          final meal = MealLogModel.fromFirestore(
            modelFixture('meal_log', name),
          );

          await subject.saveMeal(meal);

          final written = await stored(
            'users/${meal.authorId}/meal_logs/${meal.mealId}',
          );
          expect(
            written,
            strictlyEquals(firestoreToTaggedJson(meal.toFirestore())),
          );
          expect(written, strictlyEquals(taggedFixture('meal_log', name)));
        });
      }

      test(
        'merges, replacing items whole and keeping unknown fields',
        () async {
          final full = MealLogModel.fromFirestore(
            modelFixture('meal_log', 'full'),
          );
          final path = 'users/${full.authorId}/meal_logs/${full.mealId}';
          await firestore.doc(path).set({
            ...storedFixture('meal_log', 'full'),
            'field_from_a_newer_build': 'kept',
          });

          await subject.saveMeal(
            MealLogModel(
              mealId: full.mealId,
              authorId: full.authorId,
              dayKey: full.dayKey,
              date: full.date,
              items: const [],
            ),
          );

          expect(
            await stored(path),
            strictlyEquals({
              ...taggedFixture('meal_log', 'full'),
              'items': <Object?>[],
              'field_from_a_newer_build': 'kept',
            }),
          );
        },
      );
    });

    group('saveDietPlan', () {
      for (final name in ['full', 'minimal']) {
        test('stores the $name fixture as the model encodes it', () async {
          final dietPlan = DietPlan.fromFirestore(
            modelFixture('diet_plan', name),
          );

          await subject.saveDietPlan(dietPlan);

          final written = await stored('diet_plans/${dietPlan.planId}');
          expect(
            written,
            strictlyEquals(firestoreToTaggedJson(dietPlan.toFirestore())),
          );
          expect(written, strictlyEquals(taggedFixture('diet_plan', name)));
          expect(
            (await subject.watchDietPlan(dietPlan.planId).first)!.toFirestore(),
            dietPlan.toFirestore(),
          );
        });
      }

      test('merges, keeping a field this app does not know', () async {
        final full = DietPlan.fromFirestore(modelFixture('diet_plan', 'full'));
        await plan(full.planId).set({'field_from_a_newer_build': 2});

        await subject.saveDietPlan(full);

        expect(
          await stored('diet_plans/${full.planId}'),
          strictlyEquals({
            ...taggedFixture('diet_plan', 'full'),
            'field_from_a_newer_build': 2,
          }),
        );
      });
    });
  });
}
