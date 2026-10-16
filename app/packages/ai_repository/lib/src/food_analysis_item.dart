import 'package:ai_repository/src/random_id.dart';
import 'package:compound_models/compound_models.dart';

/// One food the model found in a photo or a description (Swift
/// `FoodAnalysisItem`). The figures are absolute for [amountGrams], not per
/// 100 g; a nutrient the model did not give is null.
class const FoodAnalysisItem({
  /// The model's own id for the item, such as `1`.
  required final String id,

  /// What the food is.
  required final String name,

  /// The estimated amount, in grams.
  required final double amountGrams,

  /// Calories in [amountGrams].
  final double? calories,

  /// Protein in [amountGrams], in grams.
  final double? proteinGrams,

  /// Carbohydrate in [amountGrams], in grams.
  final double? carbGrams,

  /// Fat in [amountGrams], in grams.
  final double? fatGrams,

  /// The food the function found or created for it in the user's
  /// `ingredient_templates`.
  final String? ingredientId,
}) {
  /// Creates a [FoodAnalysisItem].
  this;

  /// Decodes as Swift's `JSONDecoder` does: `id`, `name` and `amountGrams`
  /// are required, a number may be an int, and a wrong type throws.
  factory fromJson(Map<String, Object?> json) => FoodAnalysisItem(
    id: json['id']! as String,
    name: json['name']! as String,
    amountGrams: (json['amountGrams']! as num).toDouble(),
    calories: (json['calories'] as num?)?.toDouble(),
    proteinGrams: (json['proteinGrams'] as num?)?.toDouble(),
    carbGrams: (json['carbGrams'] as num?)?.toDouble(),
    fatGrams: (json['fatGrams'] as num?)?.toDouble(),
    ingredientId: json['ingredientId'] as String?,
  );

  /// The estimate as a meal item, as is: the figures go through unscaled,
  /// and a nutrient the model did not give stays absent
  /// (`FoodAnalysisItem.mealItem`). [newId] names the item, and the source
  /// when there is no [ingredientId].
  MealItemModel mealItem({String Function() newId = randomUuid}) =>
      MealItemModel(
        itemId: newId(),
        sourceType: MealItemSourceType.ingredient,
        sourceId: ingredientId ?? newId(),
        displayName: name,
        amount: amountGrams,
        unit: 'g',
        resolvedGrams: amountGrams,
        nutrients: _nutrients(1),
      );

  /// A transient food built from the estimate, scaled to per 100 g, which is
  /// what the amount screen reads, so opening it at [amountGrams] shows the
  /// figures the result row did (`FoodAnalysisItem.estimatedFood`).
  FoodModel estimatedFood({
    required DateTime now,
    String Function() newId = randomUuid,
  }) => FoodModel(
    ingredientId: ingredientId ?? newId(),
    name: name,
    nutrients: _nutrients(amountGrams > 0 ? 100 / amountGrams : 1),
    dateCreated: now,
    dateModified: now,
  );

  NutrientMap _nutrients(double scale) => NutrientMap({
    if (calories case final value?) NutrientKey.calories: value * scale,
    if (proteinGrams case final value?) NutrientKey.protein: value * scale,
    if (carbGrams case final value?) NutrientKey.carbs: value * scale,
    if (fatGrams case final value?) NutrientKey.fatTotal: value * scale,
  });
}
