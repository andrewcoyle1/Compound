import 'package:bloc_test/bloc_test.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../helpers.dart';

/// Saves fail, as an encoder rejecting a value would.
class _FailingPrograms extends InMemoryProgramRepository {
  new({super.mesocycles});

  @override
  Future<void> saveMacrocycle(Macrocycle macrocycle) =>
      Future.error(StateError('rejected'));

  @override
  Future<void> saveMesocycle(Mesocycle mesocycle) =>
      Future.error(StateError('rejected'));

  @override
  Future<void> deleteMesocycle(String uid, String id) =>
      Future.error(StateError('rejected'));
}

/// A repository whose reads fail.
class _BrokenPrograms extends InMemoryProgramRepository {
  @override
  Stream<List<Mesocycle>> watchMesocycles(String uid) =>
      Stream.error(StateError('unreadable'));
}

void main() {
  final m1 = programMesocycle('m1');
  final m2 = programMesocycle('m2');

  Future<ProgramsCubit> follow(
    ProgramWorld world, {
    ProgramRepository? p,
  }) async {
    final cubit = world.cubit(programs: p)..userChanged(programUid);
    await pumpEventQueue();
    addTearDown(cubit.close);
    return cubit;
  }

  group(ProgramsCubit, () {
    test('loads the programs, sessions and followed mesocycle', () async {
      final world = ProgramWorld.seeded(
        mesocycles: [m1, m2],
        macrocycles: [
          programMacrocycle('p', ['m1']),
        ],
        history: [programSession('upper', programNow)],
        active: 'm1',
      );
      final cubit = await follow(world);

      final state = cubit.state;
      expect(state.status, ProgramsStatus.loaded);
      expect(state.activeMesocycle?.id, 'm1');
      expect(state.currentMacrocycle?.id, 'p');
      expect([for (final m in state.inactiveMesocycles) m.id], ['m2']);
      expect(
        state.activeRun?.startedAt,
        state.currentMacrocycle!.mesocycleStartedAt,
      );
      expect(state.runOf(m2).startedAt, MesocycleSchedule.epoch);
      expect(state.sessions, hasLength(1));

      // The same user again changes nothing; signing out empties it.
      cubit
        ..userChanged(programUid)
        ..userChanged(null);
      expect(cubit.state, const ProgramsState());
    });

    test('without an active mesocycle there is no run', () async {
      final cubit = await follow(ProgramWorld.seeded(mesocycles: [m1]));
      expect(cubit.state.activeRun, isNull);
      expect(
        cubit.state.copyWith(activeMesocycleId: () => 'm1').activeMesocycle,
        m1,
      );
    });

    blocTest<ProgramsCubit, ProgramsState>(
      'a read that fails is a failure',
      build: () => ProgramWorld.seeded().cubit(programs: _BrokenPrograms()),
      act: (cubit) => cubit.userChanged(programUid),
      expect: () => [
        const ProgramsState(),
        const ProgramsState(status: ProgramsStatus.failure),
      ],
    );

    blocTest<ProgramsCubit, ProgramsState>(
      'signing out from nobody changes nothing',
      build: () => ProgramWorld.seeded().cubit(),
      act: (cubit) => cubit.userChanged(null),
      expect: () => const <ProgramsState>[],
    );

    test(
      'skips, ticks a rest, deletes and repeats, with Swift events',
      () async {
        final world = ProgramWorld.seeded(
          mesocycles: [m1],
          macrocycles: [
            programMacrocycle('p', ['m1']),
          ],
          active: 'm1',
        );
        final cubit = await follow(world);
        final run = cubit.state.activeRun!;
        final progress = MesocycleSchedule.progress(
          run,
          cubit.state.sessions,
          now: programNow,
        );
        final rest = progress.cycles.first[1];

        expect(
          await cubit.succeeded(
            (c) => c.skip(progress.next!, eventPrefix: 'TodaysWorkoutCard'),
          ),
          isTrue,
        );
        expect(
          await cubit.succeeded((c) => c.toggleRestDay(rest, 'm1')),
          isTrue,
        );
        expect(await cubit.succeeded((c) => c.repeatMacrocycle()), isTrue);
        expect(
          await cubit.succeeded(
            (c) => c.deleteMesocycle(
              m1,
              eventPrefix: 'TrainingProgramLibraryView',
            ),
          ),
          isTrue,
        );
        cubit
          ..pressed('Pressed')
          ..appeared('Screen')
          ..disappeared('Screen');

        expect(world.analytics.names, [
          'TodaysWorkoutCard_Skip_Start',
          'TodaysWorkoutCard_Skip_Success',
          'ActiveTrainingProgramView_ToggleRest_Start',
          'ActiveTrainingProgramView_ToggleRest_Success',
          'TodayView_RepeatPlan_Press',
          'TodayView_RepeatPlan_Success',
          'TrainingProgramLibraryView_DeleteProgram_Start',
          'TrainingProgramLibraryView_DeleteProgram_Success',
          'Pressed',
          'Screen_Appear',
          'Screen_Disappear',
        ]);
        expect(
          world.analytics.parameters(
            'ActiveTrainingProgramView_ToggleRest_Start',
          ),
          {'ticking': true},
        );
      },
    );

    test('starts a template and a macrocycle, saves and deletes one', () async {
      final world = ProgramWorld.seeded(mesocycles: [m1, m2]);
      final cubit = await follow(world);
      final template = PrebuiltCatalogue.instance.mesocycles.first;
      final plan = programMacrocycle('new', [
        'm1',
        'm2',
      ], status: MacrocycleStatus.notStarted);

      expect(await cubit.succeeded((c) => c.startPrebuilt(template)), isTrue);
      expect(await cubit.succeeded((c) => c.saveMacrocycle(plan)), isTrue);
      expect(
        await cubit.succeeded(
          (c) => c.startMacrocycle(plan, mesocycleIndex: 1, microcycleIndex: 0),
        ),
        isTrue,
      );
      await pumpEventQueue();
      expect(cubit.state.activeMesocycleId, 'm2');
      expect(await cubit.succeeded((c) => c.deleteMacrocycle(plan)), isTrue);

      expect(world.analytics.names, [
        'PrebuiltProgramDetailView_Start_Start',
        'PrebuiltProgramDetailView_Start_Success',
        'MacrocycleDetailView_Save_Start',
        'MacrocycleDetailView_Save_Success',
        'MacrocycleDetailView_Start',
        'MacrocycleDetailView_Start_Success',
        'MacrocycleDetailView_Delete_Start',
        'MacrocycleDetailView_Delete_Success',
      ]);
      expect(world.analytics.parameters('MacrocycleDetailView_Start'), {
        'start_mesocycle_index': 1,
        'start_microcycle_index': 0,
      });
    });

    test('a failed write answers false and logs a severe _Fail', () async {
      final world = ProgramWorld.seeded(mesocycles: [m1], active: 'm1');
      final cubit = await follow(world, p: _FailingPrograms(mesocycles: [m1]));

      expect(
        await cubit.succeeded(
          (c) =>
              c.deleteMesocycle(m1, eventPrefix: 'ActiveTrainingProgramView'),
        ),
        isFalse,
      );
      expect(
        world.analytics.names.last,
        'ActiveTrainingProgramView_DeleteProgram_Fail',
      );
    });

    test('signed out, actions do nothing', () async {
      final world = ProgramWorld.seeded();
      final cubit = world.cubit();
      addTearDown(cubit.close);
      expect(await cubit.succeeded((c) => c.repeatMacrocycle()), isFalse);
      expect(world.analytics.names, ['TodayView_RepeatPlan_Press']);
    });

    group('on sign-in', () {
      test('a legacy account gets a macrocycle once', () async {
        final world = ProgramWorld.seeded(
          mesocycles: [m1],
          history: [programSession('upper', programNow)],
          active: 'm1',
        );
        final cubit = await follow(world);
        await pumpEventQueue();

        final macrocycles = cubit.state.macrocycles;
        expect(macrocycles, hasLength(1));
        expect(macrocycles.single.mesocycleIds, ['m1']);
        expect(
          macrocycles.single.mesocycleStartedAt,
          MesocycleSchedule.legacyRun(m1, cubit.state.sessions).startedAt,
        );

        // Later emissions do not run it again.
        await world.programs.saveMesocycle(m2);
        await pumpEventQueue();
        expect(cubit.state.macrocycles, hasLength(1));
      });

      test('an account with a macrocycle is left alone', () async {
        final world = ProgramWorld.seeded(
          mesocycles: [m1],
          macrocycles: [
            programMacrocycle('p', ['m1']),
          ],
          active: 'm1',
        );
        final cubit = await follow(world);
        await pumpEventQueue();
        expect(cubit.state.macrocycles.single.id, 'p');
      });
    });

    test('saves a day as a workout of the user own', () async {
      final world = ProgramWorld.seeded(mesocycles: [m1], active: 'm1');
      final cubit = await follow(world);
      expect(
        await cubit.succeeded(
          (c) => c.saveWorkoutCopy(
            programDays.first,
            library: const [],
            copyName: (name) => '$name (copy)',
          ),
        ),
        isTrue,
      );
      expect(world.analytics.names, [
        'WorkoutTemplateDetailView_SaveCopy_Start',
        'WorkoutTemplateDetailView_SaveCopy_Success',
      ]);
    });
  });
}
