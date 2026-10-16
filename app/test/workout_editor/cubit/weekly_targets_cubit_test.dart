import 'package:compound/workout_editor/workout_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';

/// Mirrors `WeeklyTargetsPresenterTests`.
void main() {
  late AnalyticsRecorder analytics;
  late List<MicrocycleSetTargets>? changes;
  late int ids;

  List<SetTarget> sets(int count, {int reps = 8}) => [
    for (var i = 1; i <= count; i++)
      SetTarget(id: 'base-$i', setNumber: i, minReps: reps, maxReps: reps),
  ];

  WeeklyTargetsCubit build({
    int base = 2,
    List<MicrocycleSetTargets> overrides = const [],
  }) {
    analytics = AnalyticsRecorder();
    changes = null;
    final cubit = WeeklyTargetsCubit(
      exercise: fixtureSlot(fixtureLibraryExercise('bench'))
          .copyWith(setTargets: sets(base), setTargetsByMicrocycle: overrides),
      onChange: (value) => changes = value,
      analytics: analytics,
      newId: () => 'id-${ids++}',
    );
    addTearDown(cubit.close);
    return cubit;
  }

  List<int> weeks(WeeklyTargetsCubit cubit) => [
    for (final variation in cubit.state.variations) variation.fromMicrocycle,
  ];

  setUp(() => ids = 0);

  test('appearing is tracked', () {
    build();
    expect(analytics.names, ['WeeklyTargetsView_Appear']);
  });

  test('the first variation starts at week 2, a copy of the base', () {
    final cubit = build();
    expect(cubit.state.nextWeek, 2);
    cubit.add();
    final added = cubit.state.variations.single;
    expect(added.fromMicrocycle, 2);
    expect([for (final t in added.setTargets) t.minReps], [8, 8]);
    expect(added.setTargets.every((t) => !t.id.startsWith('base')), isTrue);
    expect([for (final c in changes!) c.fromMicrocycle], [2]);
    expect(analytics.names.last, 'WeeklyTargetsView_AddVariation');
    expect(analytics.parameters('WeeklyTargetsView_AddVariation'), {'week': 2});
  });

  test('the next variation copies the week before it', () {
    final cubit = build(
      overrides: [
        MicrocycleSetTargets(fromMicrocycle: 4, setTargets: sets(3, reps: 6)),
      ],
    )..add();
    expect(weeks(cubit), [4, 5]);
    expect(
      [for (final t in cubit.state.variations[1].setTargets) t.minReps],
      [6, 6, 6],
    );
  });

  test('past week 52 the first free week is used, none once all are taken', () {
    expect(
      build(
        overrides: [
          MicrocycleSetTargets(fromMicrocycle: 52, setTargets: sets(1)),
        ],
      ).state.nextWeek,
      2,
    );
    final full = build(
      overrides: [
        for (var week = 2; week <= 52; week++)
          MicrocycleSetTargets(fromMicrocycle: week, setTargets: sets(1)),
      ],
    );
    expect(full.state.nextWeek, isNull);
    full.add();
    expect(full.state.variations, hasLength(51));
  });

  test('overrides arrive sorted by week', () {
    final cubit = build(
      overrides: [
        MicrocycleSetTargets(fromMicrocycle: 9, setTargets: sets(4)),
        MicrocycleSetTargets(fromMicrocycle: 2, setTargets: sets(3)),
      ],
    );
    expect(weeks(cubit), [2, 9]);
  });

  test("a week cannot step onto another's week or out of 2 to 52", () {
    final cubit = build(
      overrides: [
        MicrocycleSetTargets(fromMicrocycle: 2, setTargets: sets(1)),
        MicrocycleSetTargets(fromMicrocycle: 3, setTargets: sets(1)),
        MicrocycleSetTargets(fromMicrocycle: 52, setTargets: sets(1)),
      ],
    );
    final variations = cubit.state.variations;
    expect(cubit.state.canStep(variations[0], -1), isFalse);
    expect(cubit.state.canStep(variations[0], 1), isFalse);
    expect(cubit.state.canStep(variations[1], -1), isFalse);
    expect(cubit.state.canStep(variations[1], 1), isTrue);
    expect(cubit.state.canStep(variations[2], 1), isFalse);

    cubit.step(variations[0], 1);
    expect(weeks(cubit), [2, 3, 52]);
    expect(changes, isNull);

    cubit.step(variations[1], 1);
    expect(weeks(cubit), [2, 4, 52]);
    expect([for (final c in changes!) c.fromMicrocycle], [2, 4, 52]);
  });

  test('deleting a variation hands back the rest', () {
    final cubit = build(
      overrides: [
        MicrocycleSetTargets(fromMicrocycle: 2, setTargets: sets(3)),
        MicrocycleSetTargets(fromMicrocycle: 9, setTargets: sets(4)),
      ],
    );
    cubit.delete(cubit.state.variations.first);
    expect([for (final c in changes!) c.fromMicrocycle], [9]);
  });

  test("a variation's own targets are edited and saved back to it", () {
    final cubit = build(
      overrides: [MicrocycleSetTargets(fromMicrocycle: 3, setTargets: sets(2))],
    );
    final variation = cubit.state.variations.single;
    final exercise = cubit.state.exerciseFor(variation);
    expect(exercise.setTargets, hasLength(2));
    expect(exercise.setTargetsByMicrocycle, isEmpty);
    cubit.targetsEdited(variation.id, sets(3));
    expect(cubit.state.variations.single.setTargets, hasLength(3));
    expect(changes!.single.setTargets, hasLength(3));
    expect(cubit.state.variations.single, isNot(variation));
  });
}
