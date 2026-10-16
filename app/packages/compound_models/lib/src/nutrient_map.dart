import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';

/// A nutrient a [NutrientMap] records (Swift `NutrientKey`), in the Swift
/// declaration order.
enum NutrientKey implements FirestoreEnum {
  /// `calories`.
  calories('calories'),

  /// `protein`.
  protein('protein'),

  /// `carbs`.
  carbs('carbs'),

  /// `fat_total`.
  fatTotal('fat_total'),

  /// `fat_saturated`.
  fatSaturated('fat_saturated'),

  /// `fat_monounsaturated`.
  fatMonounsaturated('fat_monounsaturated'),

  /// `fat_polyunsaturated`.
  fatPolyunsaturated('fat_polyunsaturated'),

  /// `fat_trans`.
  fatTrans('fat_trans'),

  /// `omega_3`.
  omega3('omega_3'),

  /// `omega_3_ala`.
  omega3Ala('omega_3_ala'),

  /// `omega_3_dha`.
  omega3Dha('omega_3_dha'),

  /// `omega_3_epa`.
  omega3Epa('omega_3_epa'),

  /// `omega_6`.
  omega6('omega_6'),

  /// `fiber`.
  fiber('fiber'),

  /// `sugar`.
  sugar('sugar'),

  /// `added_sugars`.
  addedSugars('added_sugars'),

  /// `starch`.
  starch('starch'),

  /// `cysteine`.
  cysteine('cysteine'),

  /// `histidine`.
  histidine('histidine'),

  /// `isoleucine`.
  isoleucine('isoleucine'),

  /// `leucine`.
  leucine('leucine'),

  /// `lysine`.
  lysine('lysine'),

  /// `methionine`.
  methionine('methionine'),

  /// `phenylalanine`.
  phenylalanine('phenylalanine'),

  /// `threonine`.
  threonine('threonine'),

  /// `tryptophan`.
  tryptophan('tryptophan'),

  /// `tyrosine`.
  tyrosine('tyrosine'),

  /// `valine`.
  valine('valine'),

  /// `sodium_mg`.
  sodiumMg('sodium_mg'),

  /// `potassium_mg`.
  potassiumMg('potassium_mg'),

  /// `calcium_mg`.
  calciumMg('calcium_mg'),

  /// `iron_mg`.
  ironMg('iron_mg'),

  /// `magnesium_mg`.
  magnesiumMg('magnesium_mg'),

  /// `zinc_mg`.
  zincMg('zinc_mg'),

  /// `copper_mg`.
  copperMg('copper_mg'),

  /// `manganese_mg`.
  manganeseMg('manganese_mg'),

  /// `phosphorus_mg`.
  phosphorusMg('phosphorus_mg'),

  /// `selenium_mcg`.
  seleniumMcg('selenium_mcg'),

  /// `chloride_mg`.
  chlorideMg('chloride_mg'),

  /// `chromium_mcg`.
  chromiumMcg('chromium_mcg'),

  /// `molybdenum_mcg`.
  molybdenumMcg('molybdenum_mcg'),

  /// `vitamin_a_mcg`.
  vitaminAMcg('vitamin_a_mcg'),

  /// `vitamin_b6_mg`.
  vitaminB6Mg('vitamin_b6_mg'),

  /// `vitamin_b12_mcg`.
  vitaminB12Mcg('vitamin_b12_mcg'),

  /// `vitamin_c_mg`.
  vitaminCMg('vitamin_c_mg'),

  /// `vitamin_d_mcg`.
  vitaminDMcg('vitamin_d_mcg'),

  /// `vitamin_e_mg`.
  vitaminEMg('vitamin_e_mg'),

  /// `vitamin_k_mcg`.
  vitaminKMcg('vitamin_k_mcg'),

  /// `biotin_mcg`.
  biotinMcg('biotin_mcg'),

  /// `folate_mcg`.
  folateMcg('folate_mcg'),

  /// `iodine_mcg`.
  iodineMcg('iodine_mcg'),

  /// `niacin_mg`.
  niacinMg('niacin_mg'),

  /// `thiamin_mg`.
  thiaminMg('thiamin_mg'),

  /// `riboflavin_mg`.
  riboflavinMg('riboflavin_mg'),

  /// `pantothenic_acid_mg`.
  pantothenicAcidMg('pantothenic_acid_mg'),

  /// `caffeine_mg`.
  caffeineMg('caffeine_mg'),

  /// `cholesterol_mg`.
  cholesterolMg('cholesterol_mg'),

  /// `alcohol`.
  alcohol('alcohol'),

  /// `water`.
  water('water');

  new(this.value);

  @override
  final String value;
}

/// Field names of a [NutrientMap]: the value of every [NutrientKey].
abstract final class NutrientMapKeys {
  /// Every nutrient, in declaration order.
  static final List<String> all = [
    for (final key in NutrientKey.values) key.value,
  ];
}

/// A nutrient snapshot (Swift `NutrientMap`), stored as a map of
/// [NutrientKey] values to amounts. A nutrient that is absent is not
/// recorded, which is not the same as zero.
class const NutrientMap([
  /// The recorded amounts.
  final Map<NutrientKey, double> values = const {},
]) {
  /// Creates a [NutrientMap].
  this;

  /// Decodes as Swift does: every value must be a number (an int widens),
  /// then a key this build does not know, and a NaN or infinity, are
  /// dropped rather than failing the document.
  factory fromFirestore(Map<String, Object?> data) {
    final values = <NutrientKey, double>{};
    for (final MapEntry(:key, :value) in data.entries) {
      final amount = readDouble(value);
      final nutrient = enumFromValueOrNull(NutrientKey.values, key);
      if (nutrient != null && amount.isFinite) values[nutrient] = amount;
    }
    return NutrientMap(values);
  }

  /// The map Swift writes: a NaN or infinity is left out.
  Map<String, Object?> toFirestore() => {
    for (final MapEntry(:key, :value) in values.entries)
      if (value.isFinite) key.value: value,
  };
}
