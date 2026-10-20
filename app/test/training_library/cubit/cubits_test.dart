import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository;

void main() {
  late AnalyticsRepository analytics;

  setUpAll(() => registerFallbackValue(const AnalyticsEvent('fallback')));
  setUp(() => analytics = _MockAnalyticsRepository());

  List<AnalyticsEvent> tracked() =>
      verify(() => analytics.trackEvent(captureAny())).captured
          .cast<AnalyticsEvent>();

  List<AnalyticsEvent> screens() =>
      verify(() => analytics.trackScreenView(captureAny())).captured
          .cast<AnalyticsEvent>();

  final bench = fixtureLibraryExercise('bench', name: 'Bench Press');
  final squat = fixtureLibraryExercise('squat', name: 'Squat');

  group(ExerciseListCubit, () {
    ExerciseListCubit build() => ExerciseListCubit(analytics: analytics);

    blocTest<ExerciseListCubit, ExerciseListState>(
      'keeps the query',
      build: build,
      act: (cubit) => cubit.queryChanged('bench'),
      expect: () => [const ExerciseListState(query: 'bench')],
    );

    blocTest<ExerciseListCubit, ExerciseListState>(
      'changes and resets the filters, tracking each',
      build: build,
      act: (cubit) => cubit
        ..filtersReset()
        ..filtersChanged(
          const ExerciseFilters(minimumStability: 3),
          'Stability',
        )
        ..filtersReset(),
      expect: () => [
        const ExerciseListState(filters: ExerciseFilters(minimumStability: 3)),
        const ExerciseListState(),
      ],
      verify: (_) {
        final events = tracked();
        expect(events.map((event) => event.eventName), [
          'ExercisesView_Filter_Changed',
          'ExercisesView_Filters_Reset',
        ]);
        expect(events.first.parameters, {'filter': 'Stability'});
      },
    );

    blocTest<ExerciseListCubit, ExerciseListState>(
      'tracks the screen and each exercise picked',
      build: build,
      act: (cubit) => cubit
        ..appeared('ExercisesView')
        ..exerciseSelected(bench),
      expect: () => const <ExerciseListState>[],
      verify: (_) {
        expect(screens().single.eventName, 'ExercisesView_Appear');
        final event = tracked().single;
        expect(event.eventName, 'ExercisesView_Exercise_Selected');
        expect(event.parameters, {
          'exercise_id': 'bench',
          'exercise_name': 'Bench Press',
        });
      },
    );
  });

  group(ExercisePickerCubit, () {
    blocTest<ExercisePickerCubit, ExercisePickerState>(
      'ticks and unticks exercises in order',
      build: ExercisePickerCubit.new,
      act: (cubit) => cubit
        ..toggled(bench)
        ..toggled(squat)
        ..toggled(bench),
      expect: () => [
        ExercisePickerState(picked: [bench]),
        ExercisePickerState(picked: [bench, squat]),
        ExercisePickerState(picked: [squat]),
      ],
    );

    blocTest<ExercisePickerCubit, ExercisePickerState>(
      'an exercise already added stays ticked; an excluded one cannot be',
      build: () =>
          ExercisePickerCubit(committedIds: {'bench'}, excludedIds: {'squat'}),
      act: (cubit) => cubit
        ..toggled(bench)
        ..toggled(squat),
      expect: () => const <ExercisePickerState>[],
      verify: (cubit) {
        expect(cubit.state.isSelected('bench'), isTrue);
        expect(cubit.state.isSelected('squat'), isFalse);
        expect(cubit.state.canSave, isFalse);
        expect(cubit.state.hasUnsavedChanges, isFalse);
      },
    );
  });

  group(LibrarySearchCubit, () {
    final workout = fixtureTemplate('push', name: 'Push Day');

    blocTest<LibrarySearchCubit, String>(
      'keeps the query and tracks the screen and picks',
      build: () => LibrarySearchCubit(analytics: analytics),
      act: (cubit) => cubit
        ..appeared('WorkoutsView')
        ..queryChanged('push')
        ..workoutSelected(workout, isMesocycleDay: true),
      expect: () => ['push'],
      verify: (_) {
        expect(screens().single.eventName, 'WorkoutsView_Appear');
        final event = tracked().single;
        expect(event.eventName, 'WorkoutsView_Workout_Selected');
        expect(event.parameters, {
          'workout_id': 'push',
          'workout_name': 'Push Day',
          'is_mesocycle_day': true,
        });
      },
    );
  });

  test('ExerciseListState copies', () {
    const state = ExerciseListState(query: 'a');
    expect(state.copyWith(), state);
    expect(
      state.copyWith(
        filters: const ExerciseFilters(types: {ExerciseType.core}),
      ),
      const ExerciseListState(
        query: 'a',
        filters: ExerciseFilters(types: {ExerciseType.core}),
      ),
    );
  });
}
