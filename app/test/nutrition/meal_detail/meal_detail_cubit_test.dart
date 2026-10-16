import 'package:compound/nutrition/meal_detail/meal_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = 'user-1';
  final date = DateTime(2026, 9, 14, 8, 30);
  MealItemModel item(String id) => MealItemModel(
    itemId: id,
    sourceType: MealItemSourceType.ingredient,
    sourceId: 'source-1',
    displayName: 'Food $id',
    amount: 100,
    unit: 'g',
    nutrients: const NutrientMap({NutrientKey.calories: 100}),
  );
  final meal = MealLogModel(
    mealId: 'm1',
    authorId: uid,
    dayKey: '2026-09-14',
    date: date,
    items: [item('a'), item('b')],
  );

  late AnalyticsRecorder analytics;
  late InMemoryNutritionRepository nutrition;

  setUp(() {
    analytics = AnalyticsRecorder();
    nutrition = InMemoryNutritionRepository(meals: [meal]);
  });

  MealDetailCubit build({MealLogModel? opened, NutritionRepository? repo}) =>
      MealDetailCubit(
        uid: uid,
        mealId: 'm1',
        meal: opened,
        nutrition: repo ?? nutrition,
        analytics: analytics,
      );

  group(MealDetailCubit, () {
    test('opens on the meal given, logging its item count', () async {
      final cubit = build(opened: meal);

      expect(cubit.state.meal, meal);
      expect(cubit.state.loaded, isTrue);
      await pumpEventQueue();
      await cubit.close();
      expect(analytics.names, [
        'MealDetailView_Appear',
        'MealDetailView_Disappear',
      ]);
      expect(analytics.parameters('MealDetailView_Appear'), {'item_count': 2});
    });

    test('without one, reads it by id and logs it once found', () async {
      final cubit = build();
      expect(cubit.state.loaded, isFalse);

      await pumpEventQueue();

      expect(cubit.state.meal?.mealId, 'm1');
      expect(analytics.names, ['MealDetailView_Appear']);
    });

    test('a meal that is not logged is missing', () async {
      final cubit = MealDetailCubit(
        uid: uid,
        mealId: 'gone',
        nutrition: nutrition,
        analytics: analytics,
      );
      await pumpEventQueue();

      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.meal, isNull);
      expect(analytics.names, isEmpty);
    });

    test('an unreadable log still finishes loading', () async {
      final failing = MockNutritionRepository();
      when(() => failing.watchMeals(uid))
          .thenAnswer((_) => Stream.error(StateError('denied')));
      final cubit = build(repo: failing);
      await pumpEventQueue();

      expect(cubit.state.loaded, isTrue);
    });

    test('a confirmed delete removes the meal, then leaves', () async {
      final cubit = build(opened: meal);

      await cubit.deleteConfirmed();
      await cubit.deleteConfirmed();

      expect(await nutrition.watchMeals(uid).first, isEmpty);
      expect(cubit.state.status, MealDetailStatus.deleted);
      expect(analytics.names, [
        'MealDetailView_Appear',
        'MealDetailView_Delete_Start',
        'MealDetailView_Delete_Success',
      ]);
    });

    test('a failed delete says so and stays', () async {
      final failing = MockNutritionRepository();
      when(() => failing.watchMeals(uid))
          .thenAnswer((_) => Stream.value([meal]));
      when(() => failing.deleteMeal(uid, 'm1'))
          .thenThrow(StateError('offline'));
      final cubit = build(opened: meal, repo: failing);

      await cubit.deleteConfirmed();

      expect(cubit.state.status, MealDetailStatus.idle);
      expect(cubit.state.deleteFailures, 1);
      expect(analytics.names.last, 'MealDetailView_Delete_Fail');
    });
  });
}
