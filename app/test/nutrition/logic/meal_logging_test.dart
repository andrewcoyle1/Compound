import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart'
    show sampleDietPlan;

void main() {
  const uid = 'uid';

  MealItemModel item(
    String id, {
    String sourceId = 'food',
    MealItemSourceType type = MealItemSourceType.ingredient,
    double amount = 100,
    double calories = 100,
    double protein = 10,
  }) => MealItemModel(
    itemId: id,
    sourceType: type,
    sourceId: sourceId,
    displayName: id,
    amount: amount,
    unit: 'g',
    resolvedGrams: amount,
    nutrients: NutrientMap({
      NutrientKey.calories: calories,
      NutrientKey.protein: protein,
    }),
  );

  MealLogModel meal(String id, DateTime date, List<MealItemModel> items) =>
      MealLogModel(
        mealId: id,
        authorId: uid,
        dayKey:
            '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        date: date,
        items: items,
      );

  FoodModel food(
    String id, {
    String name = 'Oats',
    String? brand,
    double? servingWeight,
    double? portionSize,
    String? portionName,
  }) => FoodModel(
    ingredientId: id,
    authorId: uid,
    name: name,
    brandName: brand,
    nutrients: const NutrientMap({
      NutrientKey.calories: 400,
      NutrientKey.protein: 10,
      NutrientKey.carbs: 60,
    }),
    servingWeight: servingWeight,
    portionSize: portionSize,
    portionName: portionName,
    dateCreated: DateTime.utc(2026),
    dateModified: DateTime.utc(2026),
  );

  group('a new meal', () {
    final now = DateTime(2026, 9, 21, 13, 42);

    test('from the toolbar is now on today', () {
      expect(
        toolbarMealDate(selectedDay: DateTime(2026, 9, 21), now: now),
        now,
      );
    });

    test('from the toolbar is midday on another day', () {
      expect(
        toolbarMealDate(selectedDay: DateTime(2026, 9, 19), now: now),
        DateTime(2026, 9, 19, 12),
      );
    });

    test('from an hour is filed at the hour', () {
      final hour = DateTime(2026, 9, 21, 13);
      expect(
        hourMealDate(hour: hour, now: now, autoSetCurrentTime: false),
        hour,
      );
    });

    test('from an hour today is now when Auto Set Current Time is on', () {
      expect(
        hourMealDate(
          hour: DateTime(2026, 9, 21, 8),
          now: now,
          autoSetCurrentTime: true,
        ),
        now,
      );
    });

    test('from an hour on another day never moves to today', () {
      final hour = DateTime(2026, 9, 20, 8);
      expect(
        hourMealDate(hour: hour, now: now, autoSetCurrentTime: true),
        hour,
      );
    });

    test('is empty, owned by the user and keyed to its day', () {
      final created = newMeal(uid: uid, date: now, mealId: 'M');
      expect(created.toFirestore(), {
        'meal_id': 'M',
        'author_id': uid,
        'day_key': '2026-09-21',
        'date': now,
        'items': <Object?>[],
      });
    });

    test('moving keeps its contents and takes its day', () {
      final original = meal('M', now, [item('a')]);
      final moved = movedMeal(original, DateTime(2026, 9, 20, 23, 30));
      expect(moved.mealId, 'M');
      expect(moved.dayKey, '2026-09-20');
      expect(moved.date, DateTime(2026, 9, 20, 23, 30));
      expect(moved.items.single.itemId, 'a');
    });
  });

  group('enteredAmount', () {
    test('reads a full stop or a comma as the decimal point', () {
      expect(enteredAmount('1.5'), 1.5);
      expect(enteredAmount(' 1,5 '), 1.5);
    });

    test('reads anything that is not a usable number as 0', () {
      for (final text in ['', 'abc', 'nan', 'NaN', 'Infinity', '1e400', '-2']) {
        expect(enteredAmount(text), 0, reason: text);
      }
    });

    test('caps an absurd figure', () {
      expect(enteredAmount('99999999'), maximumEnteredAmount);
    });
  });

  test('roundedAmount rounds to a place and never prints -0', () {
    expect(roundedAmount(37.46), 37.5);
    expect(roundedAmount(2.25, places: 0), 2);
    expect(roundedAmount(-0.01).isNegative, isFalse);
    expect(roundedAmount(double.nan), 0);
  });

  test('amountText drops a trailing .0', () {
    expect(amountText(2), '2');
    expect(amountText(37.5), '37.5');
  });

  group('the amount sheet', () {
    final slices = food(
      'bread',
      servingWeight: 80,
      portionSize: 2,
      portionName: 'slice',
    );

    test("opens on the food's own named portion", () {
      final amount = initialAmount(slices);
      expect(amount.text, '2');
      expect(amount.unit?.name, 'slice');
      expect(amount.baseAmount, 80);
    });

    test('opens on grams when the food has no named portion', () {
      expect(initialAmount(food('oats', servingWeight: 37.46)).text, '37.5');
      expect(initialAmount(food('oats')).text, '100');
    });

    test('a serving unit reads 1; grams keep the same quantity', () {
      final grams = const AmountState(text: '120')
          .withUnit(slices.servingUnits.single);
      expect(grams.text, '1');
      final back = const AmountState(text: '3')
          .withUnit(slices.servingUnits.single)
          .withUnit(null);
      expect(back.text, '40');
    });

    test('choosing the same unit changes nothing', () {
      const state = AmountState(text: '55');
      expect(state.withUnit(null), same(state));
    });

    test('scales the macros from per 100 and leaves absent ones null', () {
      final macros = foodAmountMacros(
        slices,
        AmountState(text: '1', unit: slices.servingUnits.single),
      );
      expect(macros.calories, 160);
      expect(macros.protein, 4);
      expect(macros.carbs, 24);
      expect(macros.fat, isNull);
    });

    test('an amount that is not a number gives finite figures', () {
      final macros = foodAmountMacros(slices, const AmountState(text: 'inf'));
      expect(macros.calories, 0);
    });
  });

  group('editing a plate item', () {
    test('scales from the stored amount and keeps the item', () {
      final edited = editedItem(item('a', amount: 50, calories: 200), 75);
      expect(edited.toFirestore(), {
        ...item('a').toFirestore(),
        'amount': 75.0,
        'resolvedGrams': 75.0,
        'nutrients': {'calories': 300.0, 'protein': 15.0},
      });
    });

    test('a stored amount of 0 edits to nothing', () {
      final edited = editedItem(item('a', amount: 0), 10);
      expect(edited.nutrients.values, isEmpty);
      expect(edited.resolvedGrams, 0);
    });
  });

  group('the plate totals', () {
    final today = DateTime(2026, 9, 21, 8);
    final plate = meal('plate', today, [item('a'), item('b', calories: 50)]);
    final logged = [
      meal('lunch', DateTime(2026, 9, 21, 13), [item('c', calories: 500)]),
      meal('yesterday', DateTime(2026, 9, 20, 13), [item('d')]),
      // A saved copy of the plate itself is not counted twice.
      meal('plate', today, [item('a')]),
    ];

    test("at plate scope are the plate's own", () {
      expect(scopedTotals(plate, logged, NutritionScope.plate).calories, 150);
    });

    test('at day scope add the rest of its day', () {
      expect(scopedTotals(plate, logged, NutritionScope.day).calories, 650);
      expect(scopedTotals(plate, const [], NutritionScope.day).calories, 150);
    });

    test('are shown against the plan, or the standard targets', () {
      expect(plateTarget(plate, null), fallbackTarget);
      final plan = sampleDietPlan(uid: uid, now: today);
      // 21 September 2026 is a Monday.
      expect(plateTarget(plate, plan).calories, plan.days.first.calories);
    });
  });

  test('addedCount counts only this food', () {
    expect(
      addedCount([
        item('a', sourceId: 'oats'),
        item('b', sourceId: 'oats'),
        item('c', sourceId: 'rice'),
        item('d', sourceId: 'oats', type: MealItemSourceType.quickAdd),
      ], 'oats'),
      2,
    );
  });

  group('libraryMatches', () {
    final foods = [
      food('oats', name: 'Rolled Oats', brand: 'Flahavan'),
      food('rice', name: 'Rice'),
      for (var i = 0; i < 25; i++) food('bar$i', name: 'Bar $i'),
    ];

    test('matches name or brand, ignoring case', () {
      expect(libraryMatches(foods, 'OATS').single.ingredientId, 'oats');
      expect(libraryMatches(foods, 'flahavan').single.ingredientId, 'oats');
    });

    test('finds nothing for a blank query, and at most 20', () {
      expect(libraryMatches(foods, '  '), isEmpty);
      expect(libraryMatches(foods, 'bar'), hasLength(20));
    });

    test('online results leave out what the library lists', () {
      expect(
        onlineResults([foods[0], food('new')], [foods[0]]).single.ingredientId,
        'new',
      );
    });
  });

  test('countryTag names the main markets as Open Food Facts does', () {
    expect(countryTag('IE'), 'en:ireland');
    expect(countryTag('gb'), 'en:united-kingdom');
    expect(countryTag('US'), 'en:united-states');
    expect(countryTag('XX'), isNull);
    expect(countryTag(null), isNull);
  });

  group('QuickAddState', () {
    test('a serving needs a name and some energy', () {
      expect(const QuickAddState(energy: 100).canSubmit, isFalse);
      expect(const QuickAddState(name: '  ', energy: 100).canSubmit, isFalse);
      expect(const QuickAddState(name: 'Snack').canSubmit, isFalse);
      expect(const QuickAddState(name: 'Snack', energy: 100).canSubmit, isTrue);
      expect(const QuickAddState(name: 'Snack', protein: 10).canSubmit, isTrue);
    });

    test('macros add up by Atwater factors', () {
      const state = QuickAddState(protein: 10, carbs: 20, fat: 5, alcohol: 2);
      expect(state.macroEnergy, 40 + 80 + 45 + 14);
      expect(state.calories, 179);
    });

    test('macros in ounces are converted before they are added', () {
      const state = QuickAddState(protein: 1, macroUnit: MacroUnit.ounces);
      expect(state.macroEnergy, (QuickAddState.gramsPerOunce * 4).round());
    });

    test('a typed energy wins, and kilojoules are stored as kcal', () {
      expect(const QuickAddState(energy: 250, protein: 10).calories, 250);
      const kj = QuickAddState(
        energy: 418.4,
        energyUnit: EnergyUnit.kilojoule,
        protein: 10,
      );
      expect(kj.calories, closeTo(100, 1e-9));
      expect(kj.macroEnergyInUnit, (40 * 4.184).round());
    });

    test('the item is one unscaled serving, blank macros absent', () {
      const state = QuickAddState(
        name: ' Snack ',
        energy: 300,
        protein: 1,
        fat: 0,
        macroUnit: MacroUnit.ounces,
      );
      expect(state.item(itemId: 'I', sourceId: 'S').toFirestore(), {
        'itemId': 'I',
        'sourceType': 'quick_add',
        'sourceId': 'S',
        'displayName': 'Snack',
        'amount': 1.0,
        'unit': 'serving',
        'nutrients': {
          'calories': 300.0,
          'protein': QuickAddState.gramsPerOunce,
        },
      });
    });

    test('copyWith clears a value', () {
      const state = QuickAddState(energy: 1);
      expect(state.copyWith(energy: () => null).energy, isNull);
      expect(state.copyWith().energy, 1);
    });
  });

  test('the units name their symbols', () {
    expect(EnergyUnit.values.map((unit) => unit.symbol), ['kcal', 'kJ']);
    expect(MacroUnit.values.map((unit) => unit.symbol), ['g', 'oz']);
  });
}
