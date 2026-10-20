import 'package:compound_models/compound_models.dart';
import 'package:food_repository/src/open_food_facts.dart';
import 'package:food_repository/src/open_food_facts_mapping.dart';

/// [OpenFoodFacts] with canned products, for the staging flavor and tests
/// (Swift `MockOpenFoodFactsService`). Nothing leaves the device.
///
/// A search finds the products whose name or brand contains any word of
/// the query; a barcode finds its product or fails with
/// [FoodDataFailure.notFound]. Products are mapped exactly as the real
/// barcode lookup maps them.
class FakeOpenFoodFacts implements OpenFoodFacts {
  /// Creates a [FakeOpenFoodFacts] whose foods are stamped with `now`.
  new({DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  final DateTime Function() _now;

  @override
  Future<List<FoodModel>> searchFoods(
    String query, {
    String? country,
    String? language,
  }) async {
    final words = query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((word) => word.isEmpty);
    final now = _now();
    return [
      for (final MapEntry(key: code, value: product) in _products.entries)
        if (words.any(
          '${product['product_name']} ${product['brands']}'
              .toLowerCase()
              .contains,
        ))
          productToFood(product, barcode: code, now: now)!,
    ];
  }

  @override
  Future<FoodModel> lookupBarcode(String barcode) async {
    final product = _products[barcode];
    if (product == null) {
      throw const FoodDataException(FoodDataFailure.notFound);
    }
    return productToFood(product, barcode: barcode, now: _now())!;
  }
}

/// Barcode products as the product API returns them. Weetabix is the real
/// product the Swift decoding test uses; the rest have in-store (`2…`)
/// barcodes, which no real product carries.
const _products = <String, Map<String, Object?>>{
  '5010029000061': {
    'product_name': 'Weetabix Original',
    'brands': 'Weetabix Limited',
    'serving_size': '2 biscuits (37.5 g)',
    'serving_quantity': 37.5,
    'nutriments': {
      'energy-kcal_100g': 362,
      'proteins_100g': 12,
      'carbohydrates_100g': 69,
      'fat_100g': 2,
      'fiber_100g': 10,
      'sugars_100g': 4.4,
      'sodium_100g': 0.112,
      'iron_100g': 0.012,
    },
  },
  '2000000000015': {
    'product_name': 'Greek Style Yogurt',
    'brands': 'Sample Dairy',
    'serving_size': '1 pot (150 g)',
    'serving_quantity': 150,
    'nutriments': {
      'energy-kcal_100g': 97,
      'proteins_100g': 9,
      'carbohydrates_100g': 3.6,
      'fat_100g': 5,
      'sugars_100g': 3.2,
      'calcium_100g': 0.11,
    },
  },
  '2000000000022': {
    'product_name': 'Peanut Butter Smooth',
    'brands': 'Sample Pantry',
    'serving_size': '1 tbsp (15 g)',
    'serving_quantity': 15,
    'nutriments': {
      'energy-kcal_100g': 597,
      'proteins_100g': 25,
      'carbohydrates_100g': 12,
      'fat_100g': 49,
      'saturated-fat_100g': 9.5,
      'fiber_100g': 7,
      'sugars_100g': 6,
      'sodium_100g': 0.24,
    },
  },
  '2000000000039': {
    'product_name': 'Wholemeal Bread',
    'brands': 'Sample Bakery',
    'serving_size': '1 slice (40 g)',
    'serving_quantity': 40,
    'nutriments': {
      'energy-kj_100g': 1033,
      'proteins_100g': 13,
      'carbohydrates_100g': 41,
      'fat_100g': 3.4,
      'fiber_100g': 7,
      'sodium_100g': 0.45,
    },
  },
  '2000000000046': {
    'product_name': 'Protein Bar Chocolate',
    'brands': 'Sample Sports',
    'serving_size': '1 bar (60 g)',
    'serving_quantity': 60,
    'nutriments': {
      'energy-kcal_100g': 350,
      'proteins_100g': 33,
      'carbohydrates_100g': 35,
      'fat_100g': 11,
      'sugars_100g': 3,
      'fiber_100g': 9,
    },
  },
  '2000000000053': {
    'product_name': 'Apple Juice',
    'brands': 'Sample Orchard',
    'serving_size': '200 ml',
    'serving_quantity': 200,
    'nutriments': {
      'energy-kcal_100g': 46,
      'carbohydrates_100g': 11,
      'sugars_100g': 10,
      'vitamin-c_100g': 0.03,
    },
  },
};
