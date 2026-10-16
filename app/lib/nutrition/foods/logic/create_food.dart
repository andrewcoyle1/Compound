import 'package:compound/nutrition/logic/meal_logging.dart' show EnergyUnit;
import 'package:food_repository/food_repository.dart';

/// What the nutrition facts typed in describe (Swift
/// `NutritionDefinitionOption`). Only [serving] is offered: Swift's picker
/// for the other two is commented out, but the save still handles them.
enum NutritionDefinitionOption {
  /// One serving, of the weight given when there is one.
  serving,

  /// 100 g.
  standardMass,

  /// 100 ml.
  standardVolume,
}

/// The nutrient groups on the nutrition facts form, in its order (Swift
/// `FoodDefinitionView`'s sections).
enum NutrientGroup {
  /// Calories & Macros, open from the start.
  macros,

  /// Carbs Breakdown.
  carbs,

  /// Fats Breakdown.
  fats,

  /// Protein Breakdown.
  proteins,

  /// Vitamins Breakdown.
  vitamins,

  /// Minerals Breakdown.
  minerals,

  /// Other.
  other,
}

/// One field on the nutrition facts form: the nutrient it is stored as, and
/// its group. Energy is the form's own field, not one of these.
typedef NutrientField = ({NutrientKey key, NutrientGroup group});

/// Every nutrient field, in the form's order (Swift `FoodDefinitionView`'s
/// `Row` tables).
const List<NutrientField> nutrientFields = [
  (key: NutrientKey.protein, group: NutrientGroup.macros),
  (key: NutrientKey.carbs, group: NutrientGroup.macros),
  (key: NutrientKey.fatTotal, group: NutrientGroup.macros),
  (key: NutrientKey.fiber, group: NutrientGroup.carbs),
  (key: NutrientKey.starch, group: NutrientGroup.carbs),
  (key: NutrientKey.sugar, group: NutrientGroup.carbs),
  (key: NutrientKey.addedSugars, group: NutrientGroup.carbs),
  (key: NutrientKey.fatMonounsaturated, group: NutrientGroup.fats),
  (key: NutrientKey.fatPolyunsaturated, group: NutrientGroup.fats),
  (key: NutrientKey.omega3, group: NutrientGroup.fats),
  (key: NutrientKey.omega3Ala, group: NutrientGroup.fats),
  (key: NutrientKey.omega3Dha, group: NutrientGroup.fats),
  (key: NutrientKey.omega3Epa, group: NutrientGroup.fats),
  (key: NutrientKey.omega6, group: NutrientGroup.fats),
  (key: NutrientKey.fatSaturated, group: NutrientGroup.fats),
  (key: NutrientKey.fatTrans, group: NutrientGroup.fats),
  (key: NutrientKey.cysteine, group: NutrientGroup.proteins),
  (key: NutrientKey.histidine, group: NutrientGroup.proteins),
  (key: NutrientKey.isoleucine, group: NutrientGroup.proteins),
  (key: NutrientKey.leucine, group: NutrientGroup.proteins),
  (key: NutrientKey.lysine, group: NutrientGroup.proteins),
  (key: NutrientKey.methionine, group: NutrientGroup.proteins),
  (key: NutrientKey.phenylalanine, group: NutrientGroup.proteins),
  (key: NutrientKey.threonine, group: NutrientGroup.proteins),
  (key: NutrientKey.tryptophan, group: NutrientGroup.proteins),
  (key: NutrientKey.tyrosine, group: NutrientGroup.proteins),
  (key: NutrientKey.valine, group: NutrientGroup.proteins),
  (key: NutrientKey.thiaminMg, group: NutrientGroup.vitamins),
  (key: NutrientKey.riboflavinMg, group: NutrientGroup.vitamins),
  (key: NutrientKey.niacinMg, group: NutrientGroup.vitamins),
  (key: NutrientKey.pantothenicAcidMg, group: NutrientGroup.vitamins),
  (key: NutrientKey.vitaminB6Mg, group: NutrientGroup.vitamins),
  (key: NutrientKey.vitaminB12Mcg, group: NutrientGroup.vitamins),
  (key: NutrientKey.folateMcg, group: NutrientGroup.vitamins),
  (key: NutrientKey.vitaminAMcg, group: NutrientGroup.vitamins),
  (key: NutrientKey.vitaminCMg, group: NutrientGroup.vitamins),
  (key: NutrientKey.vitaminDMcg, group: NutrientGroup.vitamins),
  (key: NutrientKey.vitaminEMg, group: NutrientGroup.vitamins),
  (key: NutrientKey.vitaminKMcg, group: NutrientGroup.vitamins),
  (key: NutrientKey.calciumMg, group: NutrientGroup.minerals),
  (key: NutrientKey.copperMg, group: NutrientGroup.minerals),
  (key: NutrientKey.ironMg, group: NutrientGroup.minerals),
  (key: NutrientKey.magnesiumMg, group: NutrientGroup.minerals),
  (key: NutrientKey.manganeseMg, group: NutrientGroup.minerals),
  (key: NutrientKey.phosphorusMg, group: NutrientGroup.minerals),
  (key: NutrientKey.potassiumMg, group: NutrientGroup.minerals),
  (key: NutrientKey.seleniumMcg, group: NutrientGroup.minerals),
  (key: NutrientKey.sodiumMg, group: NutrientGroup.minerals),
  (key: NutrientKey.zincMg, group: NutrientGroup.minerals),
  (key: NutrientKey.alcohol, group: NutrientGroup.other),
  (key: NutrientKey.caffeineMg, group: NutrientGroup.other),
  (key: NutrientKey.cholesterolMg, group: NutrientGroup.other),
  (key: NutrientKey.water, group: NutrientGroup.other),
];

/// The unit [key] is stored in (Swift `NutrientKey.unit`), so sodium reads
/// mg and vitamin D mcg.
String nutrientUnit(NutrientKey key) => switch (key) {
  NutrientKey.calories => 'kcal',
  NutrientKey.sodiumMg ||
  NutrientKey.potassiumMg ||
  NutrientKey.calciumMg ||
  NutrientKey.ironMg ||
  NutrientKey.magnesiumMg ||
  NutrientKey.zincMg ||
  NutrientKey.copperMg ||
  NutrientKey.manganeseMg ||
  NutrientKey.phosphorusMg ||
  NutrientKey.chlorideMg ||
  NutrientKey.vitaminB6Mg ||
  NutrientKey.vitaminCMg ||
  NutrientKey.vitaminEMg ||
  NutrientKey.niacinMg ||
  NutrientKey.thiaminMg ||
  NutrientKey.riboflavinMg ||
  NutrientKey.pantothenicAcidMg ||
  NutrientKey.caffeineMg ||
  NutrientKey.cholesterolMg => 'mg',
  NutrientKey.seleniumMcg ||
  NutrientKey.chromiumMcg ||
  NutrientKey.molybdenumMcg ||
  NutrientKey.vitaminAMcg ||
  NutrientKey.vitaminB12Mcg ||
  NutrientKey.vitaminDMcg ||
  NutrientKey.vitaminKMcg ||
  NutrientKey.biotinMcg ||
  NutrientKey.folateMcg ||
  NutrientKey.iodineMcg => 'mcg',
  _ => 'g',
};

/// Energy as stored: `NutrientKey.calories` is kilocalories, whichever unit
/// was typed (`FoodDefinitionPresenter.energyInKilocalories`).
double energyInKilocalories(double energy, EnergyUnit unit) =>
    unit == EnergyUnit.kilojoule ? energy / 4.184 : energy;

/// The serving a new food is defined by (Swift `PortionDefinitionDelegate`
/// and `FoodDefinitionDelegate`'s portion fields).
typedef PortionInput = ({
  NutritionDefinitionOption option,
  double? servingWeight,
  double? portionSize,
  String? portionName,
});

/// Whether the portion step can go on (`PortionDefinitionPresenter
/// .canSave`): a serving needs a quantity that is not 0 and a name.
bool canContinuePortion(PortionInput portion) =>
    portion.option != NutritionDefinitionOption.serving ||
    (portion.portionSize != null &&
        portion.portionSize != 0 &&
        (portion.portionName ?? '').isNotEmpty);

/// The food the create flow saves (`FoodDefinitionPresenter.createFood`):
/// the nutrients entered, and only those, so a blank stays absent rather
/// than 0; figures for a serving of a known weight scaled to per 100 g, the
/// basis every later amount is computed from.
FoodModel createdFood({
  required String id,
  required String authorId,
  required String name,
  required String? brandName,
  required String? barcode,
  required PortionInput portion,
  required Map<NutrientKey, double> nutrients,
  required DateTime now,
}) {
  final weight = portion.servingWeight;
  final scale =
      portion.option == NutritionDefinitionOption.serving &&
          weight != null &&
          weight > 0
      ? 100 / weight
      : 1.0;
  return FoodModel(
    ingredientId: id,
    authorId: authorId,
    name: name,
    brandName: brandName,
    nutrients: NutrientMap({
      for (final MapEntry(:key, :value) in nutrients.entries)
        key: value * scale,
    }),
    barcode: barcode,
    servingWeight: weight,
    portionSize: portion.portionSize,
    portionName: portion.portionName,
    dateCreated: now,
    dateModified: now,
  );
}
