import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_repository/ai_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFunctions extends Mock implements FirebaseFunctions;

class _MockCallable extends Mock implements HttpsCallable;

class _MockResult extends Mock implements HttpsCallableResult<Object?>;

Matcher _failure(AiFailure failure) =>
    isA<AiException>().having((error) => error.failure, 'failure', failure);

void main() {
  final now = DateTime.utc(2026, 10, 15, 8);
  late List<(String, Map<String, Object?>)> calls;
  late Object? Function(String name) answer;

  AiRepository subject() => AiRepository(
    callFunction: (name, data) async {
      calls.add((name, data));
      return answer(name);
    },
    now: () => now,
    newId: () => 'new-id',
  );

  void expectCall(String name, Map<String, Object?> data) {
    expect(calls.single.$1, name);
    expect(calls.single.$2, data);
  }

  setUp(() {
    calls = [];
    answer = (_) => null;
  });

  group('callAiFunction', () {
    test('calls the named callable with the data and returns its answer', () {
      final functions = _MockFunctions();
      final callable = _MockCallable();
      final result = _MockResult();
      when(() => functions.httpsCallable('mealDescribe')).thenReturn(callable);
      when(() => result.data).thenReturn({'result': '{}'});
      when(() => callable.call<Object?>({'description': 'eggs'}))
          .thenAnswer((_) async => result);

      expect(
        callAiFunction(functions)('mealDescribe', {'description': 'eggs'}),
        completion({'result': '{}'}),
      );
    });
  });

  group('analyzeFood', () {
    test('sends the photo as base64 and reads the items', () async {
      answer = (_) => {
        'result': jsonEncode({
          'items': [
            {
              'id': '1',
              'name': 'Chicken',
              'amountGrams': 150,
              'calories': 248,
              'proteinGrams': 46.5,
              'carbGrams': null,
              'ingredientId': 'ing-1',
            },
          ],
        }),
      };

      final items = await subject().analyzeFood(Uint8List.fromList([1, 2]));

      expectCall('foodAnalyze', {'imageBase64': 'AQI='});
      final item = items.single;
      expect(item.id, '1');
      expect(item.name, 'Chicken');
      expect(item.amountGrams, 150.0);
      expect(item.calories, 248.0);
      expect(item.proteinGrams, 46.5);
      expect(item.carbGrams, isNull);
      expect(item.fatGrams, isNull);
      expect(item.ingredientId, 'ing-1');
    });
  });

  group('describeMeal', () {
    test('sends the description', () async {
      answer = (_) => {'result': '{"items":[]}'};

      expect(await subject().describeMeal('two eggs'), isEmpty);
      expectCall('mealDescribe', {'description': 'two eggs'});
    });
  });

  group('analyzeNutritionLabel', () {
    test('makes a new food with every nutrient the label gives', () async {
      answer = (_) => {
        'result': jsonEncode({
          'name': 'Oat Drink',
          'measurementMethod': 'volume',
          'calories': 46,
          'protein': 1.0,
          'carbs': 6.7,
          'fatTotal': 1.5,
          'fatSaturated': 0.2,
          'fiber': 0.8,
          'sugar': 4,
          'sodiumMg': 40,
          'potassiumMg': 120,
          'calciumMg': 120,
          'ironMg': null,
        }),
      };

      final food = await subject().analyzeNutritionLabel(
        'Energy 46 kcal',
        authorId: 'user-1',
      );

      expectCall('nutritionLabelAnalyze', {'labelText': 'Energy 46 kcal'});
      expect(food.ingredientId, 'new-id');
      expect(food.authorId, 'user-1');
      expect(food.name, 'Oat Drink');
      expect(food.measurementMethod, MeasurementMethod.volume);
      expect(food.dateCreated, now);
      expect(food.dateModified, now);
      expect(food.nutrients.values, {
        NutrientKey.calories: 46.0,
        NutrientKey.protein: 1.0,
        NutrientKey.carbs: 6.7,
        NutrientKey.fatTotal: 1.5,
        NutrientKey.fatSaturated: 0.2,
        NutrientKey.fiber: 0.8,
        NutrientKey.sugar: 4.0,
        NutrientKey.sodiumMg: 40.0,
        NutrientKey.potassiumMg: 120.0,
        NutrientKey.calciumMg: 120.0,
      });
    });

    test('reads anything but volume as weight, and no owner as none', () async {
      answer = (_) => {'result': '{"name":"Bar","measurementMethod":"x"}'};

      final food = await subject().analyzeNutritionLabel('text');

      expect(food.measurementMethod, MeasurementMethod.weight);
      expect(food.authorId, isNull);
      expect(food.nutrients.values, isEmpty);
    });
  });

  group('generateImage', () {
    test('decodes the base64 image', () async {
      answer = (_) => {'base64': 'AQID'};

      expect(await subject().generateImage('an apple'), [1, 2, 3]);
      expectCall('imageGenerate', {'prompt': 'an apple'});
    });
  });

  group('failures', () {
    for (final (code, failure) in [
      ('unauthenticated', AiFailure.unauthenticated),
      ('permission-denied', AiFailure.permissionDenied),
      ('resource-exhausted', AiFailure.rateLimited),
      ('internal', AiFailure.unavailable),
      ('unavailable', AiFailure.unavailable),
    ]) {
      test('$code reads as ${failure.name}', () {
        answer = (_) =>
            throw FirebaseFunctionsException(message: code, code: code);

        expect(subject().describeMeal('x'), throwsA(_failure(failure)));
      });
    }

    for (final (label, data) in <(String, Object?)>[
      ('no answer', null),
      ('no result', <String, Object?>{}),
      ('a result that is not JSON', {'result': 'not json'}),
      ('JSON without items', {'result': '{"foods":[]}'}),
      ('a bare array', {'result': '[]'}),
      ('an item without a name', {'result': '{"items":[{"id":"1"}]}'}),
      (
        'a number as text',
        {'result': '{"items":[{"id":"1","name":"a","amountGrams":"5"}]}'},
      ),
    ]) {
      test('a food answer with $label is an invalid response', () {
        answer = (_) => data;

        expect(
          subject().analyzeFood(Uint8List(0)),
          throwsA(_failure(AiFailure.invalidResponse)),
        );
      });
    }

    test('a label without a name is an invalid response', () {
      answer = (_) => {'result': '{"calories":1}'};

      expect(
        subject().analyzeNutritionLabel('text'),
        throwsA(_failure(AiFailure.invalidResponse)),
      );
    });

    test('an image that is not base64 is an invalid response', () {
      answer = (_) => {'base64': '!!'};

      expect(
        subject().generateImage('x'),
        throwsA(_failure(AiFailure.invalidResponse)),
      );
    });

    test('describes itself', () {
      expect(
        const AiException(AiFailure.rateLimited, 'cause').toString(),
        'AiException(rateLimited, cause)',
      );
    });
  });

  group('stagingAiCall', () {
    final staging = AiRepository(callFunction: stagingAiCall);

    test('finds the mock service three foods in a photo or a description', () {
      for (final call in [
        () => staging.analyzeFood(Uint8List(0)),
        () => staging.describeMeal('dinner'),
      ]) {
        expect(
          call().then((items) => [for (final item in items) item.name]),
          completion([
            'Grilled Chicken Breast',
            'Brown Rice',
            'Steamed Broccoli',
          ]),
        );
      }
    });

    test('reads a label as the protein shake mix', () async {
      final food = await staging.analyzeNutritionLabel('label');

      expect(food.name, 'Protein Shake Mix');
      expect(food.nutrients.values, hasLength(11));
      expect(food.ingredientId, matches(RegExp(r'^[0-9A-F-]{36}$')));
      expect(food.dateCreated.isUtc, isTrue);
    });

    test('draws a one-pixel PNG', () async {
      final png = await staging.generateImage('apple');

      expect(png.sublist(1, 4), utf8.encode('PNG'));
    });

    test('refuses any other function', () {
      expect(
        stagingAiCall('coachChat', {}),
        throwsA(
          isA<FirebaseFunctionsException>().having(
            (error) => error.code,
            'code',
            'not-found',
          ),
        ),
      );
    });
  });
}
