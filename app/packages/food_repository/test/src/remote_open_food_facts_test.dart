import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class _MockFunctions extends Mock implements FirebaseFunctions;

class _MockCallable extends Mock implements HttpsCallable;

class _MockResult extends Mock implements HttpsCallableResult<Object?>;

Matcher _failure(FoodDataFailure failure) => isA<FoodDataException>().having(
  (error) => error.failure,
  'failure',
  failure,
);

FirebaseFunctionsException _functionsError(String code) =>
    FirebaseFunctionsException(message: code, code: code);

void main() {
  final now = DateTime.utc(2026, 10, 15, 8);
  late _MockFunctions functions;
  late _MockCallable callable;
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;

  RemoteOpenFoodFacts subject() => RemoteOpenFoodFacts(
    functions: functions,
    client: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
    now: () => now,
    newId: () => 'new-id',
  );

  void answer(Object? data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Object?>(any<Object?>()))
        .thenAnswer((_) async => result);
  }

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    requests = [];
    respond = (_) => http.Response('{"status":0}', 404);
    when(() => functions.httpsCallable('foodSearch')).thenReturn(callable);
  });

  group('searchFoods', () {
    test('calls foodSearch with the query, country and language', () async {
      answer(<Object?, Object?>{
        'products': [
          <Object?, Object?>{'code': '1', 'name': 'Oats', 'calories': 379},
          <Object?, Object?>{'name': 'Loose Apples'},
          <Object?, Object?>{'name': null},
          'not a row',
        ],
      });

      final foods = await subject().searchFoods(
        'oats',
        country: 'en:ireland',
        language: 'ga',
      );

      verify(
        () => callable.call<Object?>({
          'query': 'oats',
          'country': 'en:ireland',
          'lang': 'ga',
        }),
      ).called(1);
      expect(foods.map((food) => food.ingredientId), ['off-1', 'new-id']);
      expect(foods.first.nutrients.values, {NutrientKey.calories: 379.0});
      expect(foods.first.dateCreated, now);
    });

    test('leaves out a country and language it was not given', () async {
      answer(<Object?, Object?>{'products': <Object?>[]});

      await subject().searchFoods('oats');

      verify(() => callable.call<Object?>({'query': 'oats'})).called(1);
    });

    test('a blank query finds nothing without calling', () async {
      expect(await subject().searchFoods('  '), isEmpty);
      verifyNever(() => functions.httpsCallable(any()));
    });

    test('an answer with no product list is no results', () async {
      answer('nonsense');
      expect(await subject().searchFoods('oats'), isEmpty);
      answer(<Object?, Object?>{'products': 'nonsense'});
      expect(await subject().searchFoods('oats'), isEmpty);
    });

    test('maps callable errors to failures', () async {
      const cases = {
        'unauthenticated': FoodDataFailure.unauthenticated,
        'permission-denied': FoodDataFailure.unauthenticated,
        'resource-exhausted': FoodDataFailure.rateLimited,
        'unavailable': FoodDataFailure.unavailable,
        'deadline-exceeded': FoodDataFailure.unavailable,
        'internal': FoodDataFailure.unavailable,
      };
      for (final MapEntry(key: code, value: failure) in cases.entries) {
        when(() => callable.call<Object?>(any<Object?>()))
            .thenThrow(_functionsError(code));

        await expectLater(
          subject().searchFoods('oats'),
          throwsA(_failure(failure)),
        );
      }
    });
  });

  group('lookupBarcode', () {
    const weetabix =
        '{"code":"5010029000061","status":1,"product":{'
        '"product_name":"Weetabix Original","brands":"Weetabix Limited", '
        '"serving_size":"37.5 g","serving_quantity":37.5, '
        '"nutriments":{"energy-kcal_100g":362,"iron_100g":0.012}}}';

    test('reads the product API, naming the app', () async {
      respond = (_) => http.Response.bytes(utf8.encode(weetabix), 200);

      final food = await subject().lookupBarcode('5010029000061');

      final request = requests.single;
      expect(
        request.url.toString(),
        'https://world.openfoodfacts.org/api/v2/product/5010029000061.json',
      );
      expect(request.headers['User-Agent'], RemoteOpenFoodFacts.userAgent);
      expect(food.ingredientId, 'off-5010029000061');
      expect(food.name, 'Weetabix Original');
      expect(food.nutrients.values[NutrientKey.ironMg], closeTo(12, 1e-9));
      expect(food.dateCreated, now);
    });

    test('a code cannot leave the product path', () async {
      await expectLater(
        subject().lookupBarcode('../search'),
        throwsA(_failure(FoodDataFailure.notFound)),
      );

      expect(requests.single.url.pathSegments, [
        'api',
        'v2',
        'product',
        '../search.json',
      ]);
    });

    test('an unknown product is not found', () async {
      for (final body in [
        '{"code":"00000001","status":0}',
        '{"status":1}',
        '{"status":1,"product":{"brands":"No name"}}',
      ]) {
        respond = (_) => http.Response(body, 200);
        await expectLater(
          subject().lookupBarcode('00000001'),
          throwsA(_failure(FoodDataFailure.notFound)),
        );
      }
    });

    test('an empty code is not found without asking', () async {
      await expectLater(
        subject().lookupBarcode(''),
        throwsA(_failure(FoodDataFailure.notFound)),
      );
      expect(requests, isEmpty);
    });

    test('a 429 is rate limiting, not a missing product', () async {
      respond = (_) => http.Response('<html>slow down</html>', 429);

      await expectLater(
        subject().lookupBarcode('1'),
        throwsA(_failure(FoodDataFailure.rateLimited)),
      );
    });

    test('anything but a JSON object is unavailable', () async {
      for (final body in ['<html>down</html>', '[]']) {
        respond = (_) => http.Response(body, 503);
        await expectLater(
          subject().lookupBarcode('1'),
          throwsA(_failure(FoodDataFailure.unavailable)),
        );
      }
    });

    test('a network failure is unavailable', () async {
      respond = (_) => throw http.ClientException('offline');

      await expectLater(
        subject().lookupBarcode('1'),
        throwsA(_failure(FoodDataFailure.unavailable)),
      );
    });
  });

  test('defaults stamp the time and make UUIDs', () async {
    answer(<Object?, Object?>{
      'products': [
        <Object?, Object?>{'name': 'Loose Apples'},
      ],
    });
    final before = DateTime.now().toUtc();

    final food = (await RemoteOpenFoodFacts(
      functions: functions,
      client: MockClient((_) async => http.Response('', 500)),
    ).searchFoods('apples')).single;

    expect(food.dateCreated.isUtc, isTrue);
    expect(food.dateCreated.isBefore(before), isFalse);
    expect(
      food.ingredientId,
      matches(
        RegExp(
          r'^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-\w{12}$',
        ),
      ),
    );
  });

  test('FoodDataException says what failed', () {
    expect(
      const FoodDataException(FoodDataFailure.notFound, 'why').toString(),
      'FoodDataException(notFound, why)',
    );
  });
}
