import 'package:bloc_test/bloc_test.dart';
import 'package:compound/programs/cubit/macrocycle_draft_cubit.dart';
import 'package:compound/programs/logic/microcycle_view.dart';
import 'package:compound/programs/logic/todays_workout.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../helpers.dart';

void main() {
  final m1 = programMesocycle('m1', deload: DeloadType.end);

  // An ordinary day, and either side of midnight after both 2026 clock
  // changes: in Europe/London 29 Mar is 23 hours long and 25 Oct 25, so a
  // day of elapsed hours back from 23:30 on the 25th is still the 25th.
  for (final now in [
    DateTime(2026, 10, 14, 13),
    DateTime(2026, 3, 29, 23, 30),
    DateTime(2026, 3, 30, 0, 30),
    DateTime(2026, 10, 25, 23, 30),
    DateTime(2026, 10, 26, 0, 30),
  ]) {
    group('at $now', () => _schedule(m1, now));
  }

  _macrocycleDraft(m1);
}

void _schedule(Mesocycle m1, DateTime programNow) {
  // The previous calendar day at the same time.
  final yesterday = DateTime(
    programNow.year,
    programNow.month,
    programNow.day - 1,
    programNow.hour,
    programNow.minute,
  );
  MesocycleRun run({int first = 0, List<CycleSkip> skips = const []}) =>
      MesocycleRun(
        mesocycle: m1,
        startedAt: yesterday.subtract(const Duration(hours: 1)),
        skips: skips,
        firstMicrocycleIndex: first,
      );

  group(MicrocycleView, () {
    test('shows the microcycle the user is on, today marked', () {
      final view = MicrocycleView.build(run(), [
        programSession('upper', yesterday),
      ], now: programNow);
      expect(view.cycleCount, 2);
      expect(view.currentCycleIndex, 0);
      expect(view.displayedCycleIndex, 0);
      expect(view.isDeload, isFalse);
      expect(view.phase, isNull);
      final [upper, rest, lower] = view.items;
      expect(upper.isCompleted, isTrue);
      expect(upper.canSkip, isFalse);
      expect(rest.isRest, isTrue);
      expect(rest.isSkipped, isFalse);
      expect(rest.canToggleRest, isTrue);
      expect(lower.isToday, isTrue);
      expect(lower.canSkip, isTrue);
      expect(lower.timing, MicrocycleTiming.current);
    });

    test('a later microcycle is upcoming and the deload', () {
      final view = MicrocycleView.build(
        run(),
        const [],
        now: programNow,
        viewedCycleIndex: 1,
      );
      expect(view.isDeload, isTrue);
      expect(
        view.items.every((item) => item.timing == MicrocycleTiming.future),
        isTrue,
      );
      expect(view.items.any((item) => item.canSkip), isFalse);
    });

    test('a microcycle before the join point is past and not tracked', () {
      final view = MicrocycleView.build(
        run(first: 1),
        const [],
        now: programNow,
        viewedCycleIndex: 0,
      );
      expect(view.items.first.timing, MicrocycleTiming.past);
      expect(view.items.first.isBeforeStart, isTrue);
      expect(view.items[1].canToggleRest, isFalse);
    });

    test("today's finished workout is today's", () {
      final view = MicrocycleView.build(run(), [
        programSession('upper', programNow, id: 'done'),
      ], now: programNow);
      expect(view.items.first.isToday, isTrue);
      expect(view.items.last.isToday, isFalse);
      expect(view.props, isNotEmpty);
      expect(view.items.first.props, isNotEmpty);
    });
  });

  group(TodaysWorkout, () {
    ProgramsState state(List<WorkoutSessionModel> sessions) => ProgramsState(
      status: ProgramsStatus.loaded,
      mesocycles: [m1],
      macrocycles: [
        programMacrocycle('p', ['m1'], now: programNow),
      ],
      sessions: sessions,
      activeMesocycleId: 'm1',
    );

    test('the next workout is startable and skippable', () {
      final workout = TodaysWorkout.of(state(const []), programNow);
      expect(workout.today?.dayPlan.workoutId, 'upper');
      expect(workout.isRestDay, isFalse);
      expect(workout.isCompleted, isFalse);
      expect(workout.openSlot?.dayPlan.workoutId, 'upper');
      expect(workout.startableSlot, workout.openSlot);
      expect(workout.isDeload, isFalse);
      expect(workout.completedSession, isNull);
      expect(workout.estimatedMinutes, 10);
    });

    test("today's finished workout shows what it came to", () {
      final done = programSession('upper', programNow, id: 'done');
      final workout = TodaysWorkout.of(state([done]), programNow);
      expect(workout.isCompleted, isTrue);
      expect(workout.openSlot, isNull);
      expect(workout.completedSession, done);
    });

    test('a pre-logged rest today offers the next workout instead', () {
      final workout = TodaysWorkout.of(
        state([
          programSession('upper', yesterday),
          programSession('rest', programNow, id: 'rest-today', rest: true),
        ]),
        programNow,
      );
      expect(workout.isRestDay, isTrue);
      expect(workout.openSlot, isNull);
      expect(workout.startableSlot?.dayPlan.workoutId, 'lower');
      expect(workout.completedSession, isNull);
      expect(workout.estimatedMinutes, isNull);
    });

    test('without a mesocycle there is nothing', () {
      final workout = TodaysWorkout.of(const ProgramsState(), programNow);
      expect(workout.today, isNull);
      expect(workout.isDeload, isFalse);
      expect(workout.startableSlot, isNull);
    });

    test('the estimate is the median of recent sessions', () {
      WorkoutSessionModel timed(int minutes, int daysAgo) {
        final start = programNow.subtract(Duration(days: daysAgo));
        return WorkoutSessionModel(
          id: 's$daysAgo',
          authorId: programUid,
          name: 'Upper',
          workoutTemplateId: 'upper',
          dateCreated: start,
          dateModified: start,
          endedAt: start.add(Duration(minutes: minutes)),
          exercises: const [],
        );
      }

      expect(
        TodaysWorkout.estimatedDuration(programDays.first, [
          timed(40, 1),
          timed(60, 2),
          timed(50, 3),
        ]),
        const Duration(minutes: 50),
      );
    });
  });
}

void _macrocycleDraft(Mesocycle m1) {
  group(MacrocycleDraftCubit, () {
    final m2 = programMesocycle('m2', cycles: 4);
    final existing = programMacrocycle('p', ['m1', 'm2']);

    blocTest<MacrocycleDraftCubit, MacrocycleDraft>(
      'edits keep the start point in range',
      build: () => MacrocycleDraftCubit(mesocycles: [m1, m2]),
      act: (cubit) => cubit
        ..added(m1)
        ..added(m2)
        ..startMesocycleChanged(1)
        ..startMicrocycleChanged(3)
        ..moved(1, 0)
        ..removed(1)
        ..nameChanged('  ')
        ..mesocyclesChanged([m1, m2]),
      expect: () => [
        const MacrocycleDraft(name: 'Block m1', mesocycleIds: ['m1']),
        const MacrocycleDraft(name: 'Block m1', mesocycleIds: ['m1', 'm2']),
        const MacrocycleDraft(
          name: 'Block m1',
          mesocycleIds: ['m1', 'm2'],
          startMesocycleIndex: 1,
        ),
        const MacrocycleDraft(
          name: 'Block m1',
          mesocycleIds: ['m1', 'm2'],
          startMesocycleIndex: 1,
          startMicrocycleIndex: 3,
        ),
        // m2 moves first; the start stays at index 1, now m1, of 2.
        const MacrocycleDraft(
          name: 'Block m1',
          mesocycleIds: ['m2', 'm1'],
          startMesocycleIndex: 1,
          startMicrocycleIndex: 1,
        ),
        const MacrocycleDraft(
          name: 'Block m1',
          mesocycleIds: ['m2'],
          startMicrocycleIndex: 1,
        ),
        const MacrocycleDraft(
          name: '  ',
          mesocycleIds: ['m2'],
          startMicrocycleIndex: 1,
        ),
      ],
    );

    test('saves an edited copy, or a new unstarted one', () {
      final draft = MacrocycleDraftCubit(
        mesocycles: [m1, m2],
        existing: existing,
      ).state.copyWith(name: ' Renamed ');
      expect(draft.canSave, isTrue);
      expect(draft.startMicrocycleCount(const []), 1);
      final edited = draft.edited(
        existing: existing,
        authorId: programUid,
        newId: () => 'new',
        now: programNow,
      );
      expect(edited.id, 'p');
      expect(edited.name, 'Renamed');
      final created = draft.edited(
        existing: null,
        authorId: programUid,
        newId: () => 'new',
        now: programNow,
      );
      expect(created.id, 'new');
      expect(created.status, MacrocycleStatus.notStarted);
      expect(const MacrocycleDraft().canSave, isFalse);
    });
  });
}
