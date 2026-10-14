import 'package:bloc_test/bloc_test.dart';
import 'package:compound/nutrition/nutrition.dart';
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
