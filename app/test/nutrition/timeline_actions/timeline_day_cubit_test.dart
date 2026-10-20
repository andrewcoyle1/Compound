import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/timeline_actions/timeline_day_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../helpers/helpers.dart';

class _FakeMeal extends Fake implements MealLogModel;

// Ported from TimelineActionsPresenterTests (copy and clear). The toggles'
// cases are the Food Log settings cubit's, under `TimelineActionsView`.
void main() {
  const uid = 'user-1';
  // Monday 14 September 2026: a day in the past, so an action that acted on
  // today would not pass by accident.
  final monday = DateTime(2026, 9, 14);
  final tuesday = DateTime(2026, 9, 15);

  MealItemModel item(String id) => MealItemModel(
    itemId: id,
    sourceType: MealItemSourceType.ingredient,
    sourceId: 'source-1',
    displayName: 'Food $id',
    amount: 100,
    unit: 'g',
    resolvedGrams: 100,
    nutrients: const NutrientMap({NutrientKey.calories: 100}),
  );
  MealLogModel meal(String id, int hour, {int minute = 30, String? notes}) {
    final date = DateTime(monday.year, monday.month, monday.day, hour, minute);
    return MealLogModel(
      mealId: id,
      authorId: uid,
      dayKey: dayKeyOf(date),
      date: date,
      items: [item('$id-item')],
      notes: notes,
    );
  }

  late AnalyticsRecorder analytics;
  late InMemoryNutritionRepository nutrition;
  var ids = 0;

  setUpAll(() => registerFallbackValue(_FakeMeal()));

  setUp(() {
    analytics = AnalyticsRecorder();
    ids = 0;
  });

  Future<TimelineDayCubit> build(
    List<MealLogModel> meals, {
    String? uid = uid,
    NutritionRepository? repo,
  }) async {
    nutrition = InMemoryNutritionRepository(meals: meals);
    final cubit = TimelineDayCubit(
      uid: uid,
      day: monday,
      nutrition: repo ?? nutrition,
      analytics: analytics,
      newId: () => 'copy-${ids++}',
    );
    await pumpEventQueue();
    return cubit;
  }

  Future<List<MealLogModel>> copiesOn(DateTime day) async =>
      mealsOnDay(await nutrition.watchMeals(uid).first, dayKeyOf(day));

  group('copy day', () {
    test('opens on the following day', () async {
      final cubit = await build([meal('m1', 8)]);
      expect(cubit.defaultCopyDestination, tuesday);
    });

    test('re-logs every meal on the destination', () async {
      final cubit = await build([meal('m1', 8), meal('m2', 13)]);

      await cubit.copyDay(tuesday);

      expect(await copiesOn(tuesday), hasLength(2));
      expect(cubit.state.done, isTrue);
      expect(cubit.state.isWorking, isFalse);
    });

    test('a second copy tap while copying copies once', () async {
      final cubit = await build([meal('m1', 8)]);

      final first = cubit.copyDay(tuesday);
      expect(cubit.state.isWorking, isTrue);
      await cubit.copyDay(tuesday);
      await first;

      expect(await copiesOn(tuesday), hasLength(1));
    });

    test('a copied meal is a new entry, not a move', () async {
      final cubit = await build([meal('m1', 8)]);

      await cubit.copyDay(tuesday);

      expect((await copiesOn(tuesday)).single.mealId, 'copy-0');
      expect(await copiesOn(monday), hasLength(1));
    });

    test('a copied meal keeps its time of day', () async {
      final cubit = await build([meal('m1', 8, minute: 45)]);

      await cubit.copyDay(tuesday);

      final copy = (await copiesOn(tuesday)).single.date.toLocal();
      expect((copy.hour, copy.minute), (8, 45));
    });

    test('a copied meal keeps its items and notes', () async {
      final cubit = await build([meal('m1', 8, notes: 'Post-run')]);

      await cubit.copyDay(tuesday);

      final copy = (await copiesOn(tuesday)).single;
      expect(copy.items.map((item) => item.displayName), ['Food m1-item']);
      expect(copy.notes, 'Post-run');
    });

    test('copying an empty day says so and copies nothing', () async {
      final cubit = await build([]);

      await cubit.copyDay(tuesday);

      expect(cubit.state.alert, TimelineDayAlert.nothingToCopy);
      expect(cubit.state.alertCount, 1);
      expect(await copiesOn(tuesday), isEmpty);
      expect(cubit.state.done, isFalse);
    });

    test('copying a day is tracked with its meal count', () async {
      final cubit = await build([meal('m1', 8), meal('m2', 13)]);

      await cubit.copyDay(tuesday);

      expect(analytics.names, [
        'TimelineActionsView_CopyDay',
        'TimelineActionsView_CopyDay_Success',
      ]);
      expect(analytics.parameters('TimelineActionsView_CopyDay'), {
        'meal_count': 2,
      });
    });

    test('a failed copy is reported', () async {
      final failing = MockNutritionRepository();
      when(() => failing.watchMeals(uid))
          .thenAnswer((_) => Stream.value([meal('m1', 8)]));
      when(() => failing.saveMeal(any()))
          .thenThrow(StateError('connection lost'));
      final cubit = await build([], repo: failing);

      await cubit.copyDay(tuesday);

      expect(cubit.state.alert, TimelineDayAlert.copyFailed);
      expect(cubit.state.isWorking, isFalse);
      expect(analytics.names.last, 'TimelineActionsView_Action_Fail');
    });

    test('copying without a user writes nothing', () async {
      final cubit = await build([meal('m1', 8)], uid: null);

      await cubit.copyDay(tuesday);

      expect(await copiesOn(tuesday), isEmpty);
      expect(cubit.state.meals, isEmpty);
    });
  });

  group('clear day', () {
    test('deletes nothing until confirmed', () async {
      final cubit = await build([meal('m1', 8), meal('m2', 13)]);

      cubit.clearDayPressed();

      expect(cubit.state.alert, TimelineDayAlert.confirmClear);
      expect(await copiesOn(monday), hasLength(2));
      expect(analytics.names, isEmpty);
    });

    test('an empty day says so', () async {
      final cubit = await build([]);

      cubit
        ..clearDayPressed()
        ..clearDayPressed();

      expect(cubit.state.alert, TimelineDayAlert.nothingToClear);
      expect(cubit.state.alertCount, 2);
      await cubit.clearDay();
      expect(analytics.names, isEmpty);
    });

    test('once confirmed, deletes the day’s meals', () async {
      final cubit = await build([meal('m1', 8), meal('m2', 13)]);

      await cubit.clearDay();

      expect(await copiesOn(monday), isEmpty);
      expect(cubit.state.done, isTrue);
      expect(analytics.names, [
        'TimelineActionsView_ClearDay',
        'TimelineActionsView_ClearDay_Success',
      ]);
    });

    test('a failed clear is reported', () async {
      final failing = MockNutritionRepository();
      when(() => failing.watchMeals(uid))
          .thenAnswer((_) => Stream.value([meal('m1', 8)]));
      when(() => failing.deleteMeal(uid, 'm1'))
          .thenThrow(StateError('connection lost'));
      final cubit = await build([], repo: failing);

      await cubit.clearDay();

      expect(cubit.state.alert, TimelineDayAlert.clearFailed);
      expect(analytics.names.last, 'TimelineActionsView_Action_Fail');
    });
  });

  test('both actions act on the sheet’s day, not today', () async {
    final now = DateTime.now();
    final today = MealLogModel(
      mealId: 'today',
      authorId: uid,
      dayKey: dayKeyOf(now),
      date: now,
      items: [item('today-item')],
    );
    final cubit = await build([meal('m1', 8), today]);

    await cubit.copyDay(tuesday);

    expect(
      (await copiesOn(tuesday)).single.items.map((item) => item.displayName),
      ['Food m1-item'],
    );
  });

  test('a failed read is logged as a warning', () async {
    final failing = MockNutritionRepository();
    when(() => failing.watchMeals(uid))
        .thenAnswer((_) => Stream.error(StateError('denied')));
    await build([], repo: failing);

    expect(analytics.names, ['TimelineActionsView_GetMeals_Fail']);
  });
}
