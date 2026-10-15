import 'package:compound_models/compound_models.dart';
import 'package:food_repository/src/random_id.dart';

/// A food as a meal item, and the portions it offers (Swift
/// `FoodModel+MealItem.swift` and `FoodModel`'s portion helpers).
extension FoodMealItem on FoodModel {
  /// Grams in one portion: the serving weight, else the mass portion's.
  double? get portionGrams => servingWeight ?? portionWeight;

  /// Millilitres in one portion (foods measured by volume).
  double? get portionMilliliters => portionVolume;

  /// How many of [portionNameShown] one portion is, such as 4 for "4
  /// pieces".
  double? get portionQuantity =>
      portionSize ?? weightPortionSize ?? volumePortionSize;

  /// The portion's unit name: the first that is set and not empty.
  String? get portionNameShown => [
    portionName,
    weightPortionName,
    volumePortionName,
  ].firstWhere((name) => name != null && name.isNotEmpty, orElse: () => null);

  /// The unit a logged amount is counted in: `g`, or `ml` for a food
  /// measured by volume.
  String get loggedUnitLabel => switch (measurementMethod) {
    MeasurementMethod.weight => 'g',
    MeasurementMethod.volume => 'ml',
  };

  /// One portion in [loggedUnitLabel]: the declared portion, or 100 (what
  /// the nutrients are recorded per) when there is none usable.
  double get defaultPortionAmount {
    final declared = measurementMethod == MeasurementMethod.weight
        ? portionGrams
        : portionMilliliters;
    return declared != null && declared.isFinite && declared > 0
        ? declared
        : 100;
  }

  /// One portion as the user thinks of it: the named portion when one of
  /// [FoodModel.servingUnits] has its name ("1 slice", "0.5 cup"), else
  /// [defaultPortionAmount] of grams or millilitres (no unit).
  ({double amount, ServingUnit? unit}) get defaultPortion {
    final name = portionNameShown;
    for (final unit in servingUnits) {
      if (unit.name == name) return (amount: portionQuantity ?? 1, unit: unit);
    }
    return (amount: defaultPortionAmount, unit: null);
  }

  /// What a picker row's figures are scaled by: one default portion over
  /// the 100 the nutrients are recorded per.
  double get rowNutrientScale => defaultPortionAmount / 100;

  /// This food as a meal item of [amount] of [unit], or of
  /// [loggedUnitLabel] when no unit is given: "2 slice" is two of a slice,
  /// resolved to its grams, and the nutrients scale from per 100.
  ///
  /// An amount that is negative or not finite counts as 0, so nothing
  /// stored can subtract food from a day or fail to print (Swift leaves
  /// that to the amount screen). [itemId] defaults to a new UUID.
  MealItemModel mealItem(double amount, {ServingUnit? unit, String? itemId}) {
    final logged = amount.isFinite && amount > 0 ? amount : 0.0;
    final base = logged * (unit?.grams ?? 1);
    final factor = base / 100;
    return MealItemModel(
      itemId: itemId ?? randomUuid(),
      sourceType: MealItemSourceType.ingredient,
      sourceId: ingredientId,
      displayName: name,
      amount: logged,
      unit: unit?.name ?? loggedUnitLabel,
      resolvedGrams: measurementMethod == MeasurementMethod.weight
          ? base
          : null,
      resolvedMilliliters: measurementMethod == MeasurementMethod.volume
          ? base
          : null,
      nutrients: NutrientMap(
        nutrients.values.map((key, value) => MapEntry(key, value * factor)),
      ),
    );
  }

  /// What a picker row's "+" logs without the amount screen: this food at
  /// the amount and unit it was last logged at in [meals] (by meal date,
  /// the last such item in that meal), or its [defaultPortion] if never.
  MealItemModel quickAddItem(List<MealLogModel> meals, {String? itemId}) {
    bool isThisFood(MealItemModel item) =>
        item.sourceType == MealItemSourceType.ingredient &&
        item.sourceId == ingredientId;
    MealLogModel? latest;
    for (final meal in meals) {
      if (meal.items.any(isThisFood) &&
          (latest == null || meal.date.isAfter(latest.date))) {
        latest = meal;
      }
    }
    final last = latest?.items.lastWhere(isThisFood);
    if (last == null) {
      final portion = defaultPortion;
      return mealItem(portion.amount, unit: portion.unit, itemId: itemId);
    }
    return mealItem(
      last.amount,
      unit: servingUnits.where((unit) => unit.name == last.unit).firstOrNull,
      itemId: itemId,
    );
  }
}
