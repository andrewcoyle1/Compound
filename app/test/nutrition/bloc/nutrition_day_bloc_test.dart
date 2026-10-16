import 'package:bloc_test/bloc_test.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show withItems;
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/review/review_moment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = 'uid';
  final today = DateTime(2026, 9, 21);
  DateTime now() => DateTime(2026, 9, 21, 13, 45);
  final initial = NutritionDayState(selectedDay: today, today: today);
  final meals = sampleMealLogs(uid: uid, now: now());
  final plan = sampleDietPlan(uid: uid, now: now());
  const settings = FoodLogSettings(authorId: uid, hideEmptyHours: true);

  late NutritionRepository repository;

  setUp(() {
    repository = MockNutritionRepository();
    when(() => repository.watchMeals(uid))
        .thenAnswer((_) => Stream.value(meals));
    when(() => repository.watchDietPlan(uid))
        .thenAnswer((_) => Stream.value(plan));
    when(() => repository.watchFoodLogSettings(uid))
        .thenAnswer((_) => Stream.value(settings));
  });

  NutritionDayBloc build() =>
      NutritionDayBloc(nutritionRepository: repository, uid: uid, now: now);

  group(NutritionDayBloc, () {
    test('opens on today, loading', () {
      final bloc = build();
      expect(bloc.state, initial);
      expect(bloc.state.status, NutritionDayStatus.loading);
    });

    blocTest<NutritionDayBloc, NutritionDayState>(
      'loads the meals, plan and settings',
      build: build,
      act: (bloc) => bloc.add(const NutritionDaySubscriptionRequested()),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.status, NutritionDayStatus.loaded);
        expect(state.meals, meals);
        expect(state.dietPlan, plan);
        expect(state.settings, settings);
        // Today's sample meals, up to 13:45: breakfast and lunch.
        expect(state.dayMeals, hasLength(2));
        expect([for (final hour in state.timeline) hour.hour.hour], [7, 12]);
        expect(state.totals.calories, greaterThan(0));
        // Monday is a training day in the sample plan.
        expect(state.target?.calories, 2550);
        expect(state.markers.keys, contains('2026-09-21'));
      },
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'fails when the meals cannot be read',
      setUp: () =>
          when(() => repository.watchMeals(uid))
              .thenAnswer((_) => Stream.error(Exception('offline'))),
      build: build,
      act: (bloc) => bloc.add(const NutritionDaySubscriptionRequested()),
      verify: (bloc) => expect(bloc.state.status, NutritionDayStatus.failure),
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'falls back to no plan and default settings when those streams fail',
      setUp: () {
        when(() => repository.watchDietPlan(uid))
            .thenAnswer((_) => Stream.error(Exception('denied')));
        when(() => repository.watchFoodLogSettings(uid))
            .thenAnswer((_) => Stream.error(Exception('denied')));
      },
      build: build,
      act: (bloc) => bloc.add(const NutritionDaySubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.status, NutritionDayStatus.loaded);
        expect(bloc.state.dietPlan, isNull);
        expect(bloc.state.target, isNull);
        expect(bloc.state.settings?.authorId, uid);
        expect(bloc.state.settings?.hideEmptyHours, isFalse);
      },
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'selects a day, at midnight',
      build: build,
      act: (bloc) =>
          bloc.add(NutritionDayDateSelected(DateTime(2026, 9, 19, 18))),
      expect: () => [
        NutritionDayState(selectedDay: DateTime(2026, 9, 19), today: today),
      ],
    );
  });

  group('deleting a logged food', () {
    MealItemModel food(String id) => MealItemModel(
      itemId: id,
      sourceType: MealItemSourceType.quickAdd,
      sourceId: 'q',
      displayName: id,
      amount: 1,
      unit: 'serving',
    );
    final meal = MealLogModel(
      mealId: 'M',
      authorId: uid,
      dayKey: '2026-09-21',
      date: DateTime(2026, 9, 21, 8),
      items: [food('a'), food('b')],
    );

    setUpAll(() => registerFallbackValue(meal));

    blocTest<NutritionDayBloc, NutritionDayState>(
      'saves the meal without it',
      setUp: () =>
          when(() => repository.saveMeal(any())).thenAnswer((_) async {}),
      build: build,
      act: (bloc) => bloc.add(NutritionDayItemDeleted(meal, 'a')),
      verify: (_) {
        final saved =
            verify(() => repository.saveMeal(captureAny())).captured.single
                as MealLogModel;
        expect(saved.toFirestore(), {
          ...meal.toFirestore(),
          'items': [food('b').toFirestore()],
        });
      },
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'deletes the meal with its last food',
      setUp: () =>
          when(() => repository.deleteMeal(uid, 'M')).thenAnswer((_) async {}),
      build: build,
      act: (bloc) =>
          bloc.add(NutritionDayItemDeleted(withItems(meal, [food('b')]), 'b')),
      verify: (_) => verify(() => repository.deleteMeal(uid, 'M')).called(1),
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'a failure is counted, so the screen says so',
      setUp: () =>
          when(() => repository.saveMeal(any()))
              .thenAnswer((_) async => throw Exception('refused')),
      build: build,
      act: (bloc) => bloc.add(NutritionDayItemDeleted(meal, 'a')),
      expect: () => [initial.copyWith(deleteFailures: 1)],
    );
  });

  group('editing and logging again (NutritionPresenterTests)', () {
    MealItemModel food(String id, double amount) => MealItemModel(
      itemId: id,
      sourceType: MealItemSourceType.ingredient,
      sourceId: 's',
      displayName: id,
      amount: amount,
      unit: 'g',
      nutrients: NutrientMap({NutrientKey.calories: amount}),
    );
    final meal = MealLogModel(
      mealId: 'm1',
      authorId: uid,
      dayKey: '2026-09-14',
      date: DateTime(2026, 9, 14, 8),
      items: [food('a', 100), food('b', 200)],
      notes: 'Post-run',
    );
    late AnalyticsRecorder analytics;

    setUpAll(() => registerFallbackValue(meal));
    setUp(() => analytics = AnalyticsRecorder());

    NutritionDayBloc buildWithAnalytics() => NutritionDayBloc(
      nutritionRepository: repository,
      uid: uid,
      analyticsRepository: analytics,
      now: now,
      newId: () => 'copy',
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'editing a logged item saves the new amount into its meal',
      setUp: () =>
          when(() => repository.saveMeal(any())).thenAnswer((_) async {}),
      build: buildWithAnalytics,
      act: (bloc) => bloc.add(NutritionDayItemEdited(meal, food('b', 250))),
      expect: () => <NutritionDayState>[],
      verify: (_) {
        final saved =
            verify(() => repository.saveMeal(captureAny())).captured.single
                as MealLogModel;
        expect(saved.mealId, 'm1');
        expect(saved.items.map((item) => item.itemId), ['a', 'b']);
        expect(saved.items.map((item) => item.amount), [100, 250]);
        expect(saved.notes, 'Post-run');
        expect(analytics.names, [
          'NutritionView_SaveMeal_Start',
          'NutritionView_SaveMeal_Success',
        ]);
      },
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'an item no longer in the meal is left alone',
      build: buildWithAnalytics,
      act: (bloc) => bloc.add(NutritionDayItemEdited(meal, food('z', 1))),
      verify: (_) => verifyNever(() => repository.saveMeal(any())),
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'a failed edit is reported',
      setUp: () =>
          when(() => repository.saveMeal(any()))
              .thenAnswer((_) async => throw Exception('refused')),
      build: buildWithAnalytics,
      act: (bloc) => bloc.add(NutritionDayItemEdited(meal, food('a', 50))),
      expect: () => [initial.copyWith(editFailures: 1)],
      verify: (_) =>
          expect(analytics.names.last, 'NutritionView_SaveMeal_Fail'),
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'log again logs a copy of the meal now',
      setUp: () =>
          when(() => repository.saveMeal(any())).thenAnswer((_) async {}),
      build: buildWithAnalytics,
      act: (bloc) => bloc.add(NutritionDayMealLoggedAgain(meal)),
      // Logged again from today, the copy is on screen: no message.
      expect: () => <NutritionDayState>[],
      verify: (_) {
        final copy =
            verify(() => repository.saveMeal(captureAny())).captured.single
                as MealLogModel;
        expect(copy.mealId, 'copy');
        expect(copy.dayKey, '2026-09-21');
        expect(copy.date, now());
        expect(copy.items.map((item) => item.itemId), ['a', 'b']);
        expect(copy.notes, 'Post-run');
      },
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'log again from another day says where the meal went',
      setUp: () =>
          when(() => repository.saveMeal(any())).thenAnswer((_) async {}),
      build: buildWithAnalytics,
      act: (bloc) => bloc
        ..add(NutritionDayDateSelected(DateTime(2026, 9, 14)))
        ..add(NutritionDayMealLoggedAgain(meal)),
      skip: 1,
      expect: () => [
        NutritionDayState(
          selectedDay: DateTime(2026, 9, 14),
          today: today,
          loggedAgainToday: 1,
        ),
      ],
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'a failed log again is reported',
      setUp: () =>
          when(() => repository.saveMeal(any()))
              .thenAnswer((_) async => throw Exception('refused')),
      build: buildWithAnalytics,
      act: (bloc) => bloc.add(NutritionDayMealLoggedAgain(meal)),
      expect: () => [initial.copyWith(logAgainFailures: 1)],
    );
  });

  // Swift's `addMeal` asks for a rating on the seventh day of logging in a
  // row: after deleting one food, editing one and logging a meal again.
  group('asking for a rating', () {
    MealItemModel item(String id) => MealItemModel(
      itemId: id,
      sourceType: MealItemSourceType.quickAdd,
      sourceId: 'q',
      displayName: id,
      amount: 1,
      unit: 'serving',
    );
    final food = item('a');
    MealLogModel mealOn(int day) => MealLogModel(
      mealId: 'meal-$day',
      authorId: uid,
      dayKey: '2026-09-${day.toString().padLeft(2, '0')}',
      date: DateTime(2026, 9, day, 8),
      items: [food, item('b')],
    );
    late FakeStoreReview store;

    setUpAll(() => registerFallbackValue(mealOn(1)));

    setUp(() {
      store = FakeStoreReview();
      when(() => repository.saveMeal(any())).thenAnswer((_) async {});
    });

    NutritionDayBloc buildWith(List<int> loggedDays) {
      when(() => repository.watchMeals(uid)).thenAnswer(
        (_) => Stream.value([for (final day in loggedDays) mealOn(day)]),
      );
      return NutritionDayBloc(
        nutritionRepository: repository,
        uid: uid,
        now: now,
        newId: () => 'copy',
        reviews: ReviewPrompter(review: store, now: now),
      )..add(const NutritionDaySubscriptionRequested());
    }

    final sixDays = [15, 16, 17, 18, 19, 20];

    blocTest<NutritionDayBloc, NutritionDayState>(
      'logging again on the seventh day asks',
      build: () => buildWith(sixDays),
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc.add(NutritionDayMealLoggedAgain(mealOn(20)));
      },
      verify: (_) => expect(store.requests, 1),
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'deleting one food on the seventh day asks',
      build: () => buildWith([...sixDays, 21]),
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc.add(NutritionDayItemDeleted(mealOn(21), 'a'));
      },
      verify: (_) => expect(store.requests, 1),
    );

    blocTest<NutritionDayBloc, NutritionDayState>(
      'editing a food on the sixth day does not',
      build: () => buildWith([17, 18, 19, 20, 21]),
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc.add(NutritionDayItemEdited(mealOn(21), food));
      },
      verify: (_) => expect(store.requests, 0),
    );
  });

  group(NutritionDayState, () {
    test('has no timeline before the settings arrive', () {
      expect(initial.copyWith(meals: meals).timeline, isEmpty);
      expect(initial.copyWith(meals: meals).status, NutritionDayStatus.loading);
    });

    test('keeps the plan unless one is given', () {
      final withPlan = initial.copyWith(dietPlan: () => plan);
      expect(withPlan.copyWith().dietPlan, plan);
      expect(withPlan.copyWith(dietPlan: () => null).dietPlan, isNull);
    });
  });
}
