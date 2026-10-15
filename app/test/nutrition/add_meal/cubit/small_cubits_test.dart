import 'package:bloc_test/bloc_test.dart';
import 'package:compound/nutrition/add_meal/cubit/amount_cubit.dart';
import 'package:compound/nutrition/add_meal/cubit/quick_add_cubit.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';

void main() {
  group(AmountCubit, () {
    const slice = ServingUnit(name: 'slice', grams: 40);

    blocTest<AmountCubit, AmountState>(
      'takes what is typed, and rewrites it for a new unit',
      build: () => AmountCubit(const AmountState(text: '80')),
      act: (cubit) => cubit
        ..textChanged('120')
        ..unitChanged(slice)
        ..textChanged('2')
        ..unitChanged(null),
      expect: () => const [
        AmountState(text: '120'),
        AmountState(text: '1', unit: slice),
        AmountState(text: '2', unit: slice),
        AmountState(text: '80'),
      ],
    );
  });

  group(QuickAddCubit, () {
    blocTest<QuickAddCubit, QuickAddState>(
      'keeps every field',
      build: QuickAddCubit.new,
      act: (cubit) => cubit
        ..nameChanged('Snack')
        ..energyChanged(100)
        ..energyUnitChanged(EnergyUnit.kilojoule)
        ..proteinChanged(1)
        ..carbsChanged(2)
        ..fatChanged(3)
        ..alcoholChanged(4)
        ..macroUnitChanged(MacroUnit.ounces)
        ..energyChanged(null),
      verify: (cubit) => expect(
        cubit.state,
        const QuickAddState(
          name: 'Snack',
          energyUnit: EnergyUnit.kilojoule,
          protein: 1,
          carbs: 2,
          fat: 3,
          alcohol: 4,
          macroUnit: MacroUnit.ounces,
        ),
      ),
    );
  });

  group(MealDraftCubit, () {
    final full = MealLogModel(
      mealId: 'M',
      authorId: 'uid',
      dayKey: '2026-09-21',
      date: DateTime(2026, 9, 21),
      items: const [
        MealItemModel(
          itemId: 'a',
          sourceType: MealItemSourceType.quickAdd,
          sourceId: 'q',
          displayName: 'Snack',
          amount: 1,
          unit: 'serving',
        ),
      ],
    );

    test('keeps a plate, clears on an empty one or when asked', () {
      final cubit = MealDraftCubit()..keep(full);
      expect(cubit.state, same(full));
      cubit.keep(withItems(full, const []));
      expect(cubit.state, isNull);
      cubit
        ..keep(full)
        ..clear();
      expect(cubit.state, isNull);
    });
  });
}
