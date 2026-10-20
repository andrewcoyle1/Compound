import 'package:compound_models/compound_models.dart';

/// An Open Food Facts product's id in the library, from its barcode
/// (Swift `FoodModel.openFoodFactsId`), so the same product found twice is
/// saved once.
String openFoodFactsId(String barcode) => 'off-$barcode';

/// A serving as Open Food Facts writes it, such as "2 biscuits (37.5 g)",
/// read as a count and a name (Swift `parseServingSize`): `(2, "biscuits
/// (37.5 g)")`. Text with no leading number is one of itself.
({double portionSize, String portionName}) parseServingSize(String serving) {
  final trimmed = serving.replaceAll(_edgeSpaces, '');
  final match = _servingPattern.firstMatch(trimmed);
  if (match != null) {
    final name = match[2]!.replaceAll(_edgeSpaces, '');
    if (name.isNotEmpty) {
      return (portionSize: double.parse(match[1]!), portionName: name);
    }
  }
  return (portionSize: 1, portionName: trimmed);
}

final _servingPattern = RegExp(r'^(\d+(?:\.\d+)?)\s*([^\d].*)$');

/// Swift's `.whitespaces`: spaces and tabs, but not line breaks.
final _edgeSpaces = RegExp(r'^[\p{Zs}\t]+|[\p{Zs}\t]+$', unicode: true);

/// A product from the barcode endpoint (`api/v2/product/{code}.json`) as a
/// food, or null when it has no name (Swift `OFFProductDTO.toFoodModel`).
///
/// Nutrients are per 100 g in the app's units ([productNutrients]). The
/// food has no author: whoever saves it adds one.
FoodModel? productToFood(
  Map<String, Object?> product, {
  required String barcode,
  required DateTime now,
}) {
  final name = lenientString(product['product_name']);
  if (name == null || name.isEmpty) return null;
  final serving = lenientString(product['serving_size']);
  final parsed = serving == null ? null : parseServingSize(serving);
  return FoodModel(
    ingredientId: openFoodFactsId(barcode),
    name: name,
    brandName: lenientString(product['brands']),
    nutrients: productNutrients(product['nutriments']),
    barcode: barcode,
    servingWeight: _number(product['serving_quantity']),
    portionSize: parsed?.portionSize,
    portionName: parsed?.portionName,
    imageUrl:
        lenientString(product['image_front_small_url']) ??
        lenientString(product['image_url']),
    dateCreated: now,
    dateModified: now,
  );
}

/// A number, or a number written as text, as Open Food Facts sometimes
/// sends `serving_quantity` (`functions/lib.js` reads it the same way).
double? _number(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text),
  _ => null,
};

/// Each nutrient, the Open Food Facts names it may be stored under (the
/// first found wins), and the factor from OFF's grams to the app's unit
/// (Swift `OFFProductDTO.nutrientTable`, `OFF_NUTRIENTS` in
/// `functions/lib.js`).
const _nutrientTable = <(NutrientKey, List<String>, double)>[
  (NutrientKey.protein, ['proteins'], _grams),
  (NutrientKey.carbs, ['carbohydrates'], _grams),
  (NutrientKey.fatTotal, ['fat'], _grams),
  (NutrientKey.fatSaturated, ['saturated-fat'], _grams),
  (NutrientKey.fiber, ['fiber'], _grams),
  (NutrientKey.sugar, ['sugars'], _grams),
  (NutrientKey.sodiumMg, ['sodium'], _milligrams),
  (NutrientKey.potassiumMg, ['potassium'], _milligrams),
  (NutrientKey.calciumMg, ['calcium'], _milligrams),
  (NutrientKey.ironMg, ['iron'], _milligrams),
  (NutrientKey.magnesiumMg, ['magnesium'], _milligrams),
  (NutrientKey.zincMg, ['zinc'], _milligrams),
  (NutrientKey.phosphorusMg, ['phosphorus'], _milligrams),
  (NutrientKey.manganeseMg, ['manganese'], _milligrams),
  (NutrientKey.copperMg, ['copper'], _milligrams),
  (NutrientKey.chlorideMg, ['chloride'], _milligrams),
  (NutrientKey.cholesterolMg, ['cholesterol'], _milligrams),
  (NutrientKey.caffeineMg, ['caffeine'], _milligrams),
  (NutrientKey.vitaminCMg, ['vitamin-c'], _milligrams),
  (NutrientKey.vitaminEMg, ['vitamin-e'], _milligrams),
  (NutrientKey.vitaminB6Mg, ['vitamin-b6'], _milligrams),
  (NutrientKey.thiaminMg, ['vitamin-b1', 'thiamin'], _milligrams),
  (NutrientKey.riboflavinMg, ['vitamin-b2', 'riboflavin'], _milligrams),
  (NutrientKey.niacinMg, ['vitamin-pp', 'niacin'], _milligrams),
  (NutrientKey.pantothenicAcidMg, ['pantothenic-acid'], _milligrams),
  (NutrientKey.vitaminAMcg, ['vitamin-a'], _micrograms),
  (NutrientKey.vitaminDMcg, ['vitamin-d'], _micrograms),
  (NutrientKey.vitaminKMcg, ['vitamin-k'], _micrograms),
  (NutrientKey.vitaminB12Mcg, ['vitamin-b12'], _micrograms),
  (NutrientKey.biotinMcg, ['biotin', 'vitamin-b7'], _micrograms),
  (NutrientKey.folateMcg, ['vitamin-b9', 'folates'], _micrograms),
  (NutrientKey.iodineMcg, ['iodine'], _micrograms),
  (NutrientKey.seleniumMcg, ['selenium'], _micrograms),
];

const _grams = 1.0;
const _milligrams = 1000.0;
const _micrograms = 1000000.0;

/// A product's `nutriments` per 100 g in the app's units (Swift
/// `OFFProductDTO.nutrientMap`): every finite numeric `<name>_100g` field,
/// scaled by [_nutrientTable], with energy from kilojoules when there are
/// no kilocalories. A field that is not a number is skipped.
NutrientMap productNutrients(Object? nutriments) {
  final per100g = <String, double>{
    if (nutriments is Map)
      for (final MapEntry(:key, :value) in nutriments.entries)
        if (key is String &&
            key.endsWith('_100g') &&
            value is num &&
            value.isFinite)
          key.substring(0, key.length - '_100g'.length): value.toDouble(),
  };
  final kilojoules = per100g['energy-kj'] ?? per100g['energy'];
  final calories =
      per100g['energy-kcal'] ??
      (kilojoules == null ? null : kilojoules / 4.184);
  return NutrientMap({
    NutrientKey.calories: ?calories,
    for (final (key, names, factor) in _nutrientTable)
      if (names.map((name) => per100g[name]).nonNulls.firstOrNull
          case final value?)
        key: value * factor,
  });
}

/// The nutrients a `foodSearch` row carries, each under its Swift
/// `NutrientKey` case name (`ProductionOpenFoodFactsService.nutrientMap`).
const _searchNutrients = <NutrientKey>[
  NutrientKey.calories,
  NutrientKey.protein,
  NutrientKey.carbs,
  NutrientKey.fatTotal,
  NutrientKey.fatSaturated,
  NutrientKey.fiber,
  NutrientKey.sugar,
  NutrientKey.sodiumMg,
  NutrientKey.potassiumMg,
  NutrientKey.calciumMg,
  NutrientKey.ironMg,
  NutrientKey.vitaminAMcg,
  NutrientKey.vitaminB6Mg,
  NutrientKey.vitaminB12Mcg,
  NutrientKey.vitaminCMg,
  NutrientKey.vitaminDMcg,
  NutrientKey.vitaminEMg,
  NutrientKey.vitaminKMcg,
  NutrientKey.magnesiumMg,
  NutrientKey.zincMg,
  NutrientKey.biotinMcg,
  NutrientKey.copperMg,
  NutrientKey.folateMcg,
  NutrientKey.iodineMcg,
  NutrientKey.niacinMg,
  NutrientKey.thiaminMg,
  NutrientKey.caffeineMg,
  NutrientKey.chlorideMg,
  NutrientKey.seleniumMcg,
  NutrientKey.manganeseMg,
  NutrientKey.phosphorusMg,
  NutrientKey.riboflavinMg,
  NutrientKey.cholesterolMg,
  NutrientKey.pantothenicAcidMg,
];

/// One row of the `foodSearch` callable's `products` as a food, or null
/// when it has no name (Swift `ProductionOpenFoodFactsService.foodModel`).
/// A row with no barcode gets [newId]'s id.
FoodModel? searchRowToFood(
  Map<Object?, Object?> row, {
  required DateTime now,
  required String Function() newId,
}) {
  final name = lenientString(row['name']);
  if (name == null) return null;
  final serving = lenientString(row['servingSize']);
  final parsed = serving == null ? null : parseServingSize(serving);
  final code = lenientString(row['code']);
  return FoodModel(
    ingredientId: code == null ? newId() : openFoodFactsId(code),
    name: name,
    brandName: lenientString(row['brandName']),
    nutrients: NutrientMap({
      for (final key in _searchNutrients) key: ?lenientDouble(row[key.name]),
    }),
    barcode: code,
    servingWeight: lenientDouble(row['servingWeight']),
    portionSize: parsed?.portionSize,
    portionName: parsed?.portionName,
    imageUrl: lenientString(row['imageURL']),
    dateCreated: now,
    dateModified: now,
  );
}
