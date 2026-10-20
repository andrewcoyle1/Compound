import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/nutrient_map.dart';
import 'package:compound_models/src/nutrition_enums.dart';

/// Field names of a [MealItemModel]. Swift declares no `CodingKeys`, so
/// these are its camelCase property names.
abstract final class MealItemModelKeys {
  /// `itemId`.
  static const itemId = 'itemId';

  /// `sourceType`.
  static const sourceType = 'sourceType';

  /// `sourceId`.
  static const sourceId = 'sourceId';

  /// `displayName`.
  static const displayName = 'displayName';

  /// `amount`.
  static const amount = 'amount';

  /// `unit`.
  static const unit = 'unit';

  /// `resolvedGrams`.
  static const resolvedGrams = 'resolvedGrams';

  /// `resolvedMilliliters`.
  static const resolvedMilliliters = 'resolvedMilliliters';

  /// `nutrients`.
  static const nutrients = 'nutrients';

  /// Every field, in declaration order.
  static const List<String> all = [
    itemId,
    sourceType,
    sourceId,
    displayName,
    amount,
    unit,
    resolvedGrams,
    resolvedMilliliters,
    nutrients,
  ];
}

/// One food, recipe or quick add within a logged meal (Swift
/// `MealItemModel`).
class const MealItemModel({
  /// The item's id.
  required final String itemId,

  /// Where it came from.
  required final MealItemSourceType sourceType,

  /// The food or recipe it came from.
  required final String sourceId,

  /// Its name as logged.
  required final String displayName,

  /// The amount the user entered, in [unit].
  required final double amount,

  /// The unit entered, such as `g`, `ml` or `serving`.
  required final String unit,

  /// Its full nutrient snapshot when it was logged.
  final NutrientMap nutrients = const NutrientMap(),

  /// The amount in grams, when known.
  final double? resolvedGrams,

  /// The amount in millilitres, when known.
  final double? resolvedMilliliters,
}) {
  /// Creates a [MealItemModel].
  this;

  /// Decodes as Swift's synthesized decoder does, strictly, except that an
  /// unknown source type reads as an ingredient and the nutrients drop what
  /// [NutrientMap.fromFirestore] drops.
  factory fromFirestore(Map<String, Object?> data) => MealItemModel(
    itemId: data[MealItemModelKeys.itemId]! as String,
    sourceType: MealItemSourceType.fromFirestore(
      data[MealItemModelKeys.sourceType],
    ),
    sourceId: data[MealItemModelKeys.sourceId]! as String,
    displayName: data[MealItemModelKeys.displayName]! as String,
    amount: readDouble(data[MealItemModelKeys.amount]),
    unit: data[MealItemModelKeys.unit]! as String,
    resolvedGrams: readOptionalDouble(data[MealItemModelKeys.resolvedGrams]),
    resolvedMilliliters: readOptionalDouble(
      data[MealItemModelKeys.resolvedMilliliters],
    ),
    nutrients: NutrientMap.fromFirestore(
      readMap(data[MealItemModelKeys.nutrients]),
    ),
  );

  /// The Firestore-shaped map Swift writes: a null field is left out.
  Map<String, Object?> toFirestore() => {
    MealItemModelKeys.itemId: itemId,
    MealItemModelKeys.sourceType: sourceType.value,
    MealItemModelKeys.sourceId: sourceId,
    MealItemModelKeys.displayName: displayName,
    MealItemModelKeys.amount: amount,
    MealItemModelKeys.unit: unit,
    MealItemModelKeys.resolvedGrams: ?resolvedGrams,
    MealItemModelKeys.resolvedMilliliters: ?resolvedMilliliters,
    MealItemModelKeys.nutrients: nutrients.toFirestore(),
  };
}
