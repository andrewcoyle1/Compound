import 'package:compound/programs/cubit/mesocycle_design_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../helpers.dart';

/// Saves after [delay], failing when [fails].
class _Programs extends InMemoryProgramRepository {
  bool fails = false;
  Duration delay = Duration.zero;
  final saved = <Mesocycle>[];

  @override
  Future<void> saveMesocycle(Mesocycle mesocycle) async {
    await Future<void>.delayed(delay);
    if (fails) throw StateError('rejected');
    saved.add(mesocycle);
    await super.saveMesocycle(mesocycle);
  }
}

const _labels = DayNameLabels(restDay: 'Rest Day', workout: _workout);

String _workout(String letter) => 'Workout $letter';

final WorkoutTemplateModel _push = programDays[0];
final WorkoutTemplateModel _rest = programDays[1];
final WorkoutTemplateModel _legs = programDays[2];

Mesocycle _mesocycle(List<WorkoutTemplateModel> days) =>
    editedMesocycle(programMesocycle('m1'), workoutTemplates: days);

void main() {
  late ProgramWorld world;
  late _Programs programs;
  late int ids;

  MesocycleDesignCubit build(Mesocycle mesocycle) {
    programs = _Programs();
    world = ProgramWorld.seeded();
    final cubit = MesocycleDesignCubit(
      mesocycle: mesocycle,
      uid: programUid,
      labels: _labels,
      programs: programs,
      service: ProgramService(
        programs: programs,
        users: world.users,
        sessions: world.sessions,
      ),
      analytics: world.analytics,
      newId: () => 'day-${++ids}',
    );
    addTearDown(cubit.close);
    return cubit;
  }

  List<String> names(MesocycleDesignCubit cubit) => [
    for (final day in cubit.state.days) day.name,
  ];

  setUp(() => ids = 0);

  group('starting state', () {
    test('a new mesocycle starts on its one rest day', () {
      final cubit = build(
        newMesocycle(
          id: 'm1',
          authorId: programUid,
          name: 'Block',
          icon: 'flag',
          colour: '#FF0000',
          now: programNow,
        ),
      );
      expect(cubit.state.days, hasLength(1));
      expect(
        cubit.state.selectedDay.workoutId,
        cubit.state.days.single.workoutId,
      );
      expect(world.analytics.names, ['ProgramDesignView_Appear']);
    });

    test('an existing mesocycle opens on its first day', () {
      final cubit = build(_mesocycle([_push, _legs]));
      expect(names(cubit), ['Upper', 'Lower']);
      expect(cubit.state.selectedDay.name, 'Upper');
    });
  });

  group('adding and removing days', () {
    test('adding a day appends it, selects it and is saved with it', () {
      final cubit = build(_mesocycle([_push]))..addDay();
      expect(cubit.state.days, hasLength(2));
      expect(cubit.state.selectedDay.workoutId, 'day-1');
      expect(cubit.state.mesocycle.workoutTemplates.last.workoutId, 'day-1');
    });

    test('the last day cannot be removed', () {
      final cubit = build(_mesocycle([_push]));
      expect(cubit.state.canRemoveDay, isFalse);
      cubit.removeSelectedDay();
      expect(cubit.state.days, hasLength(1));
    });

    test('removing the selected day selects another', () {
      final cubit = build(_mesocycle([_push, _legs]))
        ..selectDay(_legs.workoutId)
        ..removeSelectedDay();
      expect(names(cubit), ['Upper']);
      expect(cubit.state.selectedDay.name, 'Upper');
    });
  });

  group('day names', () {
    test('a typed day name survives later edits', () {
      final cubit = build(_mesocycle([_push]))
        ..renameDay(_push.workoutId, 'Leg Day')
        ..addDay();
      expect(names(cubit), ['Leg Day', 'Rest Day']);
    });

    test('a renamed day is renamed in the mesocycle and selection', () {
      final cubit = build(_mesocycle([_push]))
        ..renameDay(_push.workoutId, 'Leg Day');
      expect(cubit.state.mesocycle.workoutTemplates.single.name, 'Leg Day');
      expect(cubit.state.selectedDay.name, 'Leg Day');
    });
  });

  group('settings', () {
    test('reordering the days survives the next edit', () {
      final cubit = build(_mesocycle([_push, _rest, _legs]))
        ..edit(days: [_legs, _push, _rest]);
      expect(names(cubit), ['Lower', 'Upper', 'Rest Day']);
      cubit.addDay();
      expect(names(cubit), ['Lower', 'Upper', 'Rest Day', 'Rest Day']);
    });

    test(
      'the deload and cycles survive the next edit and count as unsaved',
      () {
        final cubit = build(_mesocycle([_push]));
        expect(cubit.state.hasUnsavedChanges, isFalse);
        cubit
          ..edit(
            deload: DeloadType.end,
            numMicrocycles: 4,
            name: 'Renamed',
            icon: 'gamecontroller',
            colour: '#34C759',
            periodisation: true,
          )
          ..addDay();
        final mesocycle = cubit.state.mesocycle;
        expect(mesocycle.deload, DeloadType.end);
        expect(mesocycle.numMicrocycles, 4);
        expect(mesocycle.name, 'Renamed');
        expect(mesocycle.icon, 'gamecontroller');
        expect(mesocycle.colour, '#34C759');
        expect(mesocycle.periodisation, isTrue);
        expect(cubit.state.hasUnsavedChanges, isTrue);
      },
    );

    test('selecting a day is not an edit', () {
      final cubit = build(_mesocycle([_push, _legs]))
        ..selectDay(_legs.workoutId);
      expect(cubit.state.hasUnsavedChanges, isFalse);
    });

    test('other screens of the editor are tracked', () {
      build(_mesocycle([_push]))
        ..appeared('ProgramSettingsView')
        ..disappeared('ProgramSettingsView');
      expect(world.analytics.names, [
        'ProgramDesignView_Appear',
        'ProgramSettingsView_Appear',
        'ProgramSettingsView_Disappear',
      ]);
    });
  });

  group('saving and activating', () {
    test('saving stores the mesocycle as it stands', () async {
      final cubit = build(_mesocycle([_push]))..addDay();
      await cubit.save();
      expect(programs.saved.single.workoutTemplates, hasLength(2));
      expect(cubit.state.status, MesocycleDesignStatus.succeeded);
      expect(cubit.state.lastAction, MesocycleDesignAction.save);
      expect(
        world.analytics.names,
        containsAllInOrder([
          'ProgramDesignView_Save_Start',
          'ProgramDesignView_Save_Success',
        ]),
      );
    });

    test('a failed save stores nothing and says so', () async {
      final cubit = build(_mesocycle([_push]));
      programs.fails = true;
      await cubit.save();
      expect(programs.saved, isEmpty);
      expect(cubit.state.status, MesocycleDesignStatus.failed);
      expect(world.analytics.names.last, 'ProgramDesignView_Save_Fail');
    });

    test('a mesocycle of rest days cannot be saved or activated', () async {
      final cubit = build(_mesocycle([_rest]));
      expect(cubit.state.canSave, isFalse);
      await cubit.save();
      await cubit.activate();
      expect(programs.saved, isEmpty);
      expect(cubit.state.status, MesocycleDesignStatus.editing);
    });

    test('a second tap during a save stores nothing extra', () async {
      final cubit = build(_mesocycle([_push]));
      programs.delay = const Duration(milliseconds: 20);
      final first = cubit.save();
      expect(cubit.state.status, MesocycleDesignStatus.saving);
      expect(cubit.state.canSave, isFalse);
      await cubit.save();
      await first;
      expect(programs.saved, hasLength(1));
    });

    test('activating saves, then follows it, asking nothing', () async {
      final cubit = build(_mesocycle([_push, _rest]));
      await cubit.activate();
      expect(programs.saved.single.id, 'm1');
      final macrocycle =
          (await programs.watchMacrocycles(programUid).first).single;
      expect(macrocycle.mesocycleIds, ['m1']);
      expect(
        (await world.users.watchUser(programUid).first)
            ?.submittedActiveMesocycleId,
        'm1',
      );
      expect(cubit.state.lastAction, MesocycleDesignAction.activate);
    });

    test('a failed save does not activate', () async {
      final cubit = build(_mesocycle([_push]));
      programs.fails = true;
      await cubit.activate(screen: 'ProgramSettingsView');
      expect(await programs.watchMacrocycles(programUid).first, isEmpty);
      expect(world.analytics.names.last, 'ProgramSettingsView_Activate_Fail');
    });
  });

  test('deleting from the editor deletes the mesocycle', () async {
    final cubit = build(_mesocycle([_rest]));
    await programs.saveMesocycle(cubit.state.mesocycle);
    await cubit.delete();
    expect(await programs.watchMesocycles(programUid).first, isEmpty);
    expect(cubit.state.lastAction, MesocycleDesignAction.delete);
    expect(world.analytics.names.last, 'ProgramDesignView_Delete_Success');
  });

  test('closing is tracked', () async {
    final cubit = build(_mesocycle([_push]));
    await cubit.close();
    expect(world.analytics.names.last, 'ProgramDesignView_Disappear');
  });
}
