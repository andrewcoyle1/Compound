import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 8);

  group('productToFood', () {
    // Swift OpenFoodFactsDecodingTests: trimmed from
    // api/v2/product/5010029000061.json (Weetabix Original).
    final weetabix =
        (jsonDecode('''
    {"code":"5010029000061","status":1,"product":{
      "product_name":"Weetabix Original","brands":"Weetabix Limited","serving_size":"2 biscuits (37.5 g)","serving_quantity":37.5,
      "nutriments":{"energy-kcal_100g":362,"proteins_100g":12,"carbohydrates_100g":69,"fat_100g":2,"sodium_100g":0.112,
        "iron_100g":0.012,"vitamin-b1_100g":0.0012,"vitamin-pp_100g":0.014,"vitamin-d_100g":0.0000025,"energy_unit":"kJ",
        "fiber_100g":""}
    }}''') as Map<String, Object?>)['product']!
            as Map<String, Object?>;

    test("micronutrients arrive in the app's units", () {
      final food = productToFood(weetabix, barcode: '5010029000061', now: now)!;
      final n = food.nutrients.values;

      expect(food.ingredientId, 'off-5010029000061');
      expect(food.authorId, isNull);
      expect(food.name, 'Weetabix Original');
      expect(food.brandName, 'Weetabix Limited');
      expect(food.barcode, '5010029000061');
      expect(food.measurementMethod, MeasurementMethod.weight);
      expect(food.servingWeight, 37.5);
      expect(food.portionSize, 2);
      expect(food.portionName, 'biscuits (37.5 g)');
      expect(food.dateCreated, now);
      expect(food.dateModified, now);
      expect(n[NutrientKey.calories], 362);
      expect(n[NutrientKey.protein], 12);
      expect(n[NutrientKey.ironMg], closeTo(12, 1e-9));
      expect(n[NutrientKey.sodiumMg], closeTo(112, 1e-9));
      expect(n[NutrientKey.thiaminMg], closeTo(1.2, 1e-9));
      expect(n[NutrientKey.niacinMg], closeTo(14, 1e-9));
      expect(n[NutrientKey.vitaminDMcg], closeTo(2.5, 1e-9));
      // A non-numeric field is skipped rather than failing the product.
      expect(n.containsKey(NutrientKey.fiber), isFalse);
    });

    test('a product with no name is no food', () {
      expect(productToFood(const {}, barcode: '1', now: now), isNull);
      expect(
        productToFood(const {'product_name': ''}, barcode: '1', now: now),
        isNull,
      );
    });

    test('energy falls back to kilojoules, then to plain energy', () {
      NutrientMap nutrients(Map<String, Object?> nutriments) => productToFood(
        {'product_name': 'X', 'nutriments': nutriments},
        barcode: '1',
        now: now,
      )!.nutrients;

      expect(
        nutrients({'energy-kj_100g': 418.4}).values[NutrientKey.calories],
        closeTo(100, 1e-9),
      );
      expect(
        nutrients({'energy_100g': 836.8}).values[NutrientKey.calories],
        closeTo(200, 1e-9),
      );
      expect(
        nutrients({'energy-kcal_100g': 50, 'energy-kj_100g': 1000})
            .values[NutrientKey.calories],
        50,
      );
      expect(nutrients({}).values, isEmpty);
    });

    test('the first name a nutrient is stored under wins', () {
      final food = productToFood(
        {
          'product_name': 'X',
          'nutriments': {
            'thiamin_100g': 0.002,
            'vitamin-b1_100g': 0.001,
            'folates_100g': 0.0001,
          },
        },
        barcode: '1',
        now: now,
      )!;

      expect(food.nutrients.values[NutrientKey.thiaminMg], closeTo(1, 1e-9));
      expect(food.nutrients.values[NutrientKey.folateMcg], closeTo(100, 1e-9));
    });

    test('reads loosely typed fields as Open Food Facts sends them', () {
      final food = productToFood(
        {
          'product_name': 'X',
          'brands': ['not', 'a string'],
          'serving_quantity': '30',
          'image_url': 'https://example.com/large.jpg',
          'nutriments': 'not a map',
        },
        barcode: '1',
        now: now,
      )!;

      expect(food.brandName, isNull);
      expect(food.servingWeight, 30);
      expect(food.portionSize, isNull);
      expect(food.imageUrl, 'https://example.com/large.jpg');
      expect(food.nutrients.values, isEmpty);
      expect(
        productToFood(
          {'product_name': 'X', 'serving_quantity': true},
          barcode: '1',
          now: now,
        )!.servingWeight,
        isNull,
      );
    });

    test('prefers the small front image', () {
      final food = productToFood(
        {
          'product_name': 'X',
          'image_front_small_url': 'https://example.com/small.jpg',
          'image_url': 'https://example.com/large.jpg',
        },
        barcode: '1',
        now: now,
      )!;

      expect(food.imageUrl, 'https://example.com/small.jpg');
    });
  });

  group('parseServingSize', () {
    test('splits a leading number from the name', () {
      expect(parseServingSize('2 biscuits (37.5 g)'), (
        portionSize: 2.0,
        portionName: 'biscuits (37.5 g)',
      ));
      expect(parseServingSize(' 37.5g '), (
        portionSize: 37.5,
        portionName: 'g',
      ));
    });

    test('text with no leading number is one of itself', () {
      expect(parseServingSize('a slice'), (
        portionSize: 1.0,
        portionName: 'a slice',
      ));
      expect(parseServingSize('250'), (portionSize: 1.0, portionName: '250'));
      expect(parseServingSize('2 \t'), (portionSize: 1.0, portionName: '2'));
    });
  });

  group('searchRowToFood', () {
    test('maps a foodSearch row as Swift does', () {
      final food = searchRowToFood(
        {
          'code': '5010029000061',
          'name': 'Weetabix Original',
          'brandName': 'Weetabix Limited',
          'imageURL': 'https://example.com/w.jpg',
          'servingWeight': 37.5,
          'servingSize': '2 biscuits (37.5 g)',
          'calories': 362,
          'fatTotal': 2.5,
          'pantothenicAcidMg': 1.25,
          'sodiumMg': null,
          'chromiumMcg': 9,
          'fiber': 'ten',
        },
        now: now,
        newId: () => fail('a row with a barcode needs no new id'),
      )!;

      expect(food.ingredientId, 'off-5010029000061');
      expect(food.authorId, isNull);
      expect(food.name, 'Weetabix Original');
      expect(food.brandName, 'Weetabix Limited');
      expect(food.barcode, '5010029000061');
      expect(food.imageUrl, 'https://example.com/w.jpg');
      expect(food.servingWeight, 37.5);
      expect(food.portionSize, 2);
      expect(food.portionName, 'biscuits (37.5 g)');
      expect(food.dateCreated, now);
      // Only the nutrients Swift reads, ints widened.
      expect(food.nutrients.values, {
        NutrientKey.calories: 362.0,
        NutrientKey.fatTotal: 2.5,
        NutrientKey.pantothenicAcidMg: 1.25,
      });
    });

    test('a row with no barcode gets a new id, one with no name is none', () {
      final food = searchRowToFood(
        {'name': 'Loose Apples'},
        now: now,
        newId: () => 'new-id',
      )!;

      expect(food.ingredientId, 'new-id');
      expect(food.barcode, isNull);
      expect(food.portionName, isNull);
      expect(searchRowToFood({'name': 3}, now: now, newId: () => 'x'), isNull);
    });
  });

  test('openFoodFactsId prefixes the barcode', () {
    expect(openFoodFactsId('123'), 'off-123');
  });
}
