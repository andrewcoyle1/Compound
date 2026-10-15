/// Logging a meal, ported from the Swift `AddMealPresenter`,
/// `IngredientAmountPresenter`, `MealItemAmountViewPresenter`,
/// `FoodItemQuickAddPresenter`, `MealHourHeaderPresenter`, `NutritionScaling`
/// and `RecentPick`: the new meal's time, amounts typed in, the plate's
/// totals, quick add and recent foods. Pure, so the blocs and sheets only
/// read it.
library;

import 'dart:math' as math;

import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound_maths/compound_maths.dart' show Macros;
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart' show DietPlan;

// MARK: - A new meal

/// When a meal logged from the toolbar's + is eaten
/// (`NutritionPresenter.onLogMealPressed`): now on today, else midday on
/// [selectedDay], so the meal lands on the day being looked at.
DateTime toolbarMealDate({
  required DateTime selectedDay,
  required DateTime now,
}) => startOfDay(selectedDay) == startOfDay(now)
    ? now
    : DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 12);

/// When a meal logged from an hour header's + is eaten
/// (`MealHourHeaderPresenter.mealTime`): the hour's start, or now when
/// [autoSetCurrentTime] is on and the hour is today. Never now on another
/// day, which would move the meal to today.
DateTime hourMealDate({
  required DateTime hour,
  required DateTime now,
  required bool autoSetCurrentTime,
}) => autoSetCurrentTime && startOfDay(hour) == startOfDay(now) ? now : hour;

/// An empty meal for [uid] eaten at [date], as Swift's `MealLogModel(authorId:
/// dayKey: date.dayKey, date:, items: [])`.
MealLogModel newMeal({
  required String uid,
  required DateTime date,
  required String mealId,
}) => MealLogModel(
  mealId: mealId,
  authorId: uid,
  dayKey: dayKeyOf(date),
  date: date,
  items: const [],
);

/// [meal] moved to [date] (`AddMealPresenter.updateMealTime`): the same
/// foods, the new time and that time's day.
MealLogModel movedMeal(MealLogModel meal, DateTime date) => MealLogModel(
  mealId: meal.mealId,
  authorId: meal.authorId,
  dayKey: dayKeyOf(date),
  date: date,
  items: meal.items,
  notes: meal.notes,
);

/// [meal] with [items] in place of its own.
MealLogModel withItems(MealLogModel meal, List<MealItemModel> items) =>
    MealLogModel(
      mealId: meal.mealId,
      authorId: meal.authorId,
      dayKey: meal.dayKey,
      date: meal.date,
      items: items,
      notes: meal.notes,
    );

// MARK: - Amounts

/// The largest amount a field takes: far above any real portion, so a finite
/// but absurd figure cannot multiply a nutrient up to infinity.
const maximumEnteredAmount = 1000000.0;

/// A number typed into an amount field (Swift `Double.enteredAmount`): a
/// comma reads as the decimal point, and anything that is not a usable
/// number, negative or not finite ("nan", "1e400") reads as 0, which every
/// screen already refuses to submit.
double enteredAmount(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value < 0) return 0;
  return value > maximumEnteredAmount ? maximumEnteredAmount : value;
}

/// [value] to [places] decimal places (`NutritionScaling.rounded`); not a
/// number reads as 0, and -0 as 0.
double roundedAmount(double value, {int places = 1}) {
  if (!value.isFinite) return 0;
  final scale = math.pow(10, math.max(places, 0)).toDouble();
  return (value * scale).roundToDouble() / scale + 0.0;
}

/// [value] as an amount field shows it: no grouping, no trailing `.0`.
String amountText(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toString();

/// What an amount sheet holds: the text typed and, for a food, the serving
/// unit it is counted in (null for grams or millilitres).
class const AmountState({required final String text, final ServingUnit? unit})
    extends Equatable {
  /// The amount typed, as a number.
  double get amount => enteredAmount(text);

  /// Grams (or millilitres) of the food: [amount] of [unit]
  /// (`NutritionScaling.baseAmount`).
  double get baseAmount => amount * (unit?.grams ?? 1);

  /// The same food counted in [newUnit] (`IngredientAmountPresenter
  /// .selectedUnit`): 1 of a serving unit, or back in grams or millilitres
  /// as the same quantity that was entered.
  AmountState withUnit(ServingUnit? newUnit) {
    if (newUnit?.name == unit?.name) return this;
    return AmountState(
      text: newUnit == null ? amountText(roundedAmount(baseAmount)) : '1',
      unit: newUnit,
    );
  }

  @override
  List<Object?> get props => [text, unit?.name, unit?.grams];
}

/// Where [food]'s amount sheet opens (`IngredientAmountPresenter
/// .onViewAppear`): its own portion, the one its row describes.
AmountState initialAmount(FoodModel food) {
  final portion = food.defaultPortion;
  return portion.unit != null
      ? AmountState(text: amountText(portion.amount), unit: portion.unit)
      : AmountState(text: amountText(roundedAmount(portion.amount)));
}

/// [food]'s calories and macros at [amount], each null when the food does
/// not record it.
({double? calories, double? protein, double? carbs, double? fat})
foodAmountMacros(FoodModel food, AmountState amount) {
  final scale = amount.baseAmount / 100;
  double? of(NutrientKey key) {
    final value = food.nutrients.values[key];
    return value == null ? null : value * scale;
  }

  return (
    calories: of(NutrientKey.calories),
    protein: of(NutrientKey.protein),
    carbs: of(NutrientKey.carbs),
    fat: of(NutrientKey.fatTotal),
  );
}

/// [item]'s nutrients for one of its unit (`MealItemAmountViewDelegate
/// .unitNutrients`); empty when its amount is 0.
NutrientMap unitNutrients(MealItemModel item) => item.amount > 0
    ? NutrientMap(
        item.nutrients.values.map((k, v) => MapEntry(k, v / item.amount)),
      )
    : const NutrientMap();

/// [item] corrected to [amount] (`MealItemAmountViewPresenter
/// .onConfirmPressed`): its nutrients and resolved grams or millilitres
/// scaled from what was stored, its id and everything else kept.
MealItemModel editedItem(MealItemModel item, double amount) {
  final ratio = item.amount > 0 ? amount / item.amount : 0.0;
  final perUnit = unitNutrients(item);
  return MealItemModel(
    itemId: item.itemId,
    sourceType: item.sourceType,
    sourceId: item.sourceId,
    displayName: item.displayName,
    amount: amount,
    unit: item.unit,
    resolvedGrams: item.resolvedGrams == null
        ? null
        : item.resolvedGrams! * ratio,
    resolvedMilliliters: item.resolvedMilliliters == null
        ? null
        : item.resolvedMilliliters! * ratio,
    nutrients: NutrientMap(
      perUnit.values.map((k, v) => MapEntry(k, v * amount)),
    ),
  );
}

// MARK: - The plate

/// What the logger's totals show: the plate alone, or the day with it.
enum NutritionScope {
  /// The plate being built.
  plate,

  /// The plate added to what is already logged that day.
  day,
}

/// The targets used when there is no plan for the meal's day
/// (`AddMealPresenter.targetCalories` and the rest).
const Macros fallbackTarget = (
  calories: 2000,
  proteinGrams: 150,
  carbGrams: 200,
  fatGrams: 65,
);

/// What the logger shows for [meal] at [scope]: the plate, or the plate
/// plus the other meals logged on its day in [meals].
Macros scopedTotals(
  MealLogModel meal,
  List<MealLogModel> meals,
  NutritionScope scope,
) => switch (scope) {
  NutritionScope.plate => meal.macros,
  NutritionScope.day => totalsOf([
    meal,
    for (final other in mealsOnDay(meals, meal.dayKey))
      if (other.mealId != meal.mealId) other,
  ]),
};

/// The plan's target for [meal]'s day, or [fallbackTarget].
Macros plateTarget(MealLogModel meal, DietPlan? plan) =>
    dailyTarget(plan, meal.dayKey) ?? fallbackTarget;

/// How many times the food [ingredientId] is on [items], for the
/// checkmark-and-count a picker row shows once it has been added.
int addedCount(List<MealItemModel> items, String ingredientId) => items
    .where(
      (item) =>
          item.sourceType == MealItemSourceType.ingredient &&
          item.sourceId == ingredientId,
    )
    .length;

// MARK: - Finding foods

/// The foods most recently eaten, newest first and each once, as the search
/// screen's "Recent" (`[MealLogModel].recentPicks`, foods only until
/// recipes arrive). By the meals' dates, then the last item first.
List<FoodModel> recentFoods(
  List<MealLogModel> meals,
  List<FoodModel> foods, {
  int limit = 20,
}) {
  final byId = <String, FoodModel>{};
  for (final food in foods) {
    byId.putIfAbsent(food.ingredientId, () => food);
  }
  final seen = <String>{};
  final result = <FoodModel>[];
  final sorted = [...meals]..sort((a, b) => b.date.compareTo(a.date));
  for (final meal in sorted) {
    for (final item in meal.items.reversed) {
      if (item.sourceType != MealItemSourceType.ingredient) continue;
      final food = byId[item.sourceId];
      if (food == null || !seen.add(food.ingredientId)) continue;
      result.add(food);
      if (result.length == limit) return result;
    }
  }
  return result;
}

/// The user's foods matching [query] by name or brand, ignoring case, at
/// most 20 (`FoodItemSearchPresenter.libraryResults`). A blank query finds
/// nothing.
List<FoodModel> libraryMatches(List<FoodModel> foods, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  return foods
      .where(
        (food) =>
            food.name.toLowerCase().contains(needle) ||
            (food.brandName?.toLowerCase().contains(needle) ?? false),
      )
      .take(20)
      .toList();
}

/// [online] less the foods already listed from the library above them
/// (`FoodItemSearchPresenter.onlineResults`).
List<FoodModel> onlineResults(List<FoodModel> online, List<FoodModel> library) {
  final saved = {for (final food in library) food.ingredientId};
  return [
    for (final food in online)
      if (!saved.contains(food.ingredientId)) food,
  ];
}

/// The Open Food Facts country tag for a region (Swift
/// `ProductionOpenFoodFactsService.countryTag`: the English name,
/// lower-cased and hyphenated), so the user's own shops come first.
///
/// ponytail: the main markets only, since Dart has no region-name table; any
/// other region searches the world, as Swift does for a name OFF spells
/// differently. Add a line per market that asks.
String? countryTag(String? regionCode) {
  final name = _regionNames[regionCode?.toUpperCase()];
  return name == null ? null : 'en:$name';
}

const _regionNames = {
  'AR': 'argentina',
  'AT': 'austria',
  'AU': 'australia',
  'BE': 'belgium',
  'BR': 'brazil',
  'CA': 'canada',
  'CH': 'switzerland',
  'CL': 'chile',
  'CO': 'colombia',
  'DE': 'germany',
  'DK': 'denmark',
  'ES': 'spain',
  'FI': 'finland',
  'FR': 'france',
  'GB': 'united-kingdom',
  'IE': 'ireland',
  'IN': 'india',
  'IT': 'italy',
  'MX': 'mexico',
  'NL': 'netherlands',
  'NO': 'norway',
  'NZ': 'new-zealand',
  'PE': 'peru',
  'PL': 'poland',
  'PT': 'portugal',
  'SE': 'sweden',
  'US': 'united-states',
  'ZA': 'south-africa',
};

// MARK: - Quick add

/// The energy units quick add takes.
enum EnergyUnit {
  /// Kilocalories, which `NutrientKey.calories` stores.
  kcal,

  /// Kilojoules.
  kilojoule;

  /// The unit's symbol.
  String get symbol => switch (this) {
    kcal => 'kcal',
    kilojoule => 'kJ',
  };
}

/// The mass units quick add's macros take.
enum MacroUnit {
  /// Grams.
  grams,

  /// Ounces.
  ounces;

  /// The unit's symbol.
  String get symbol => switch (this) {
    grams => 'g',
    ounces => 'oz',
  };
}

/// Quick add's form (Swift `FoodItemQuickAddPresenter`): a name and energy,
/// or macros that add up to some.
class const QuickAddState({
  final String name = '',
  final double? energy,
  final EnergyUnit energyUnit = EnergyUnit.kcal,
  final double? protein,
  final double? carbs,
  final double? fat,
  final double? alcohol,
  final MacroUnit macroUnit = MacroUnit.grams,
}) extends Equatable {
  static const kilojoulesPerKilocalorie = 4.184;
  static const gramsPerOunce = 28.349523125;

  double _grams(double? value) =>
      (value ?? 0) * (macroUnit == MacroUnit.ounces ? gramsPerOunce : 1);

  /// The macros' energy by Atwater factors, in whole kcal, the macros
  /// converted to grams first.
  int get macroEnergy =>
      (_grams(protein) * 4 +
              _grams(carbs) * 4 +
              _grams(fat) * 9 +
              _grams(alcohol) * 7)
          .round();

  /// [macroEnergy] in [energyUnit], for the line under the energy field.
  int get macroEnergyInUnit => energyUnit == EnergyUnit.kilojoule
      ? (macroEnergy * kilojoulesPerKilocalorie).round()
      : macroEnergy;

  /// The energy logged, in kcal: a typed figure wins over [macroEnergy].
  double get calories {
    final energy = this.energy;
    if (energy == null || energy <= 0) return macroEnergy.toDouble();
    return energyUnit == EnergyUnit.kilojoule
        ? energy / kilojoulesPerKilocalorie
        : energy;
  }

  /// The name, trimmed.
  String get trimmedName => name.trim();

  /// Nothing is worth logging without a name and some energy.
  bool get canSubmit => trimmedName.isNotEmpty && calories > 0;

  /// The item quick add logs: one unscaled serving, with no food behind it.
  /// A macro left blank or 0 is absent, not zero; alcohol has no nutrient
  /// of its own and only counts toward the calories.
  MealItemModel item({required String itemId, required String sourceId}) =>
      MealItemModel(
        itemId: itemId,
        sourceType: MealItemSourceType.quickAdd,
        sourceId: sourceId,
        displayName: trimmedName,
        amount: 1,
        unit: 'serving',
        nutrients: NutrientMap({
          NutrientKey.calories: calories,
          if ((protein ?? 0) > 0) NutrientKey.protein: _grams(protein),
          if ((carbs ?? 0) > 0) NutrientKey.carbs: _grams(carbs),
          if ((fat ?? 0) > 0) NutrientKey.fatTotal: _grams(fat),
        }),
      );

  QuickAddState copyWith({
    String? name,
    double? Function()? energy,
    EnergyUnit? energyUnit,
    double? Function()? protein,
    double? Function()? carbs,
    double? Function()? fat,
    double? Function()? alcohol,
    MacroUnit? macroUnit,
  }) => QuickAddState(
    name: name ?? this.name,
    energy: energy == null ? this.energy : energy(),
    energyUnit: energyUnit ?? this.energyUnit,
    protein: protein == null ? this.protein : protein(),
    carbs: carbs == null ? this.carbs : carbs(),
    fat: fat == null ? this.fat : fat(),
    alcohol: alcohol == null ? this.alcohol : alcohol(),
    macroUnit: macroUnit ?? this.macroUnit,
  );

  @override
  List<Object?> get props => [
    name,
    energy,
    energyUnit,
    protein,
    carbs,
    fat,
    alcohol,
    macroUnit,
  ];
}
