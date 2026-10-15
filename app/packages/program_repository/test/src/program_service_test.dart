import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/contract.dart';

const _uid = 'me';
final _start = DateTime(2026, 9, 30, 9);

final WorkoutTemplateExercise _exercise = Mesocycle.fromFirestore(
  modelFixture('mesocycle', 'full'),
).workoutTemplates.expand((plan) => plan.exercises).first;

WorkoutTemplateModel _day(String id, {bool rest = false}) =>
    WorkoutTemplateModel(
      workoutId: id,
      authorId: _uid,
      name: id.toUpperCase(),
      dateCreated: _start,
      dateModified: _start,
      exercises: rest ? const [] : [_exercise],
    );

Mesocycle _mesocycle(String id, {int cycles = 1}) => Mesocycle(
  id: id,
  authorId: _uid,
  name: 'Block $id',
  icon: 'dumbbell',
  colour: '#FF0000',
  numMicrocycles: cycles,
  workoutTemplates: [
    _day('a'),
    _day('rest1', rest: true),
    _day('rest2', rest: true),
    _day('b'),
  ],
  dateCreated: _start,
  dateModified: _start,
);

Macrocycle _macrocycle(
  String id, {
  List<String> mesocycleIds = const ['m1'],
  MacrocycleStatus status = MacrocycleStatus.active,
  int index = 0,
  DateTime? modified,
}) => Macrocycle(
  id: id,
  authorId: _uid,
  name: 'Plan $id',
  mesocycleIds: mesocycleIds,
  status: status,
  mesocycleIndex: index,
  mesocycleStartedAt: _start,
  dateCreated: _start,
  dateModified: modified ?? _start,
);

WorkoutSessionModel _session(
  String templateId,
  DateTime at, {
  String id = '',
  bool rest = false,
  String? mesocycleId = 'm1',
}) => WorkoutSessionModel(
  id: id.isEmpty ? '$templateId-${at.millisecondsSinceEpoch}' : id,
  authorId: _uid,
  name: templateId.toUpperCase(),
  workoutTemplateId: templateId,
  mesocycleId: mesocycleId,
  dateCreated: at,
  dateModified: at,
  endedAt: at,
  isRestDay: rest,
  exercises: const [],
);

void main() {
  late InMemoryProgramRepository programs;
  late InMemoryUserRepository users;
  late InMemoryWorkoutSessionRepository sessions;
  late List<String> events;
  late DateTime now;
  late int count;
  late ProgramService subject;

  void build({
    List<Mesocycle> mesocycles = const [],
    List<Macrocycle> macrocycles = const [],
    List<WorkoutSessionModel> history = const [],
    String? active = 'm1',
  }) {
    programs = InMemoryProgramRepository(
      mesocycles: mesocycles,
      macrocycles: macrocycles,
    );
    users = InMemoryUserRepository(
      users: {
        _uid: UserModel.fromFirestore({
          ...modelFixture('user_model', 'minimal'),
          UserModelKeys.userId: _uid,
          UserModelKeys.submittedActiveMesocycleId: ?active,
        }),
      },
    );
    sessions = InMemoryWorkoutSessionRepository(sessions: history);
    subject = ProgramService(
      programs: programs,
      users: users,
      sessions: sessions,
      now: () => now,
      newId: () => 'id-${++count}',
      onEvent: (name, _) => events.add(name),
    );
  }

  Future<List<Macrocycle>> macrocycles() =>
      programs.watchMacrocycles(_uid).first;
  Future<Macrocycle> stored(String id) async =>
      (await macrocycles()).firstWhere((m) => m.id == id);
  Future<String?> following() async =>
      (await users.watchUser(_uid).first)?.submittedActiveMesocycleId;

  setUp(() {
    events = [];
    now = _start.add(const Duration(days: 1));
    count = 0;
  });

  test('without onEvent, events go nowhere', () async {
    build(macrocycles: [_macrocycle('p', status: MacrocycleStatus.notStarted)]);
    await ProgramService(
      programs: programs,
      users: users,
      sessions: sessions,
    ).startMacrocycle(_uid, _macrocycle('p'));
    expect((await stored('p')).status, MacrocycleStatus.active);
  });

  group('startMacrocycle', () {
    test(
      'ends the one followed, starts this and follows its mesocycle',
      () async {
        build(
          macrocycles: [
            _macrocycle('old'),
            _macrocycle('done', status: MacrocycleStatus.completed),
            _macrocycle('saved', status: MacrocycleStatus.notStarted),
          ],
        );

        final started = await subject.startMacrocycle(
          _uid,
          _macrocycle(
            'new',
            mesocycleIds: ['m1', 'm2'],
            status: MacrocycleStatus.notStarted,
          ),
          mesocycleIndex: 1,
          microcycleIndex: 2,
        );

        expect(started.mesocycleIndex, 1);
        expect(started.startMicrocycleIndex, 2);
        expect((await stored('old')).status, MacrocycleStatus.ended);
        expect((await stored('done')).status, MacrocycleStatus.ended);
        expect((await stored('saved')).status, MacrocycleStatus.notStarted);
        expect((await stored('new')).status, MacrocycleStatus.active);
        expect(await following(), 'm2');
        expect(events, ['MacrocycleMan_Start']);
      },
    );

    test('of no mesocycles follows nothing new', () async {
      build(active: null);
      await subject.startMacrocycle(
        _uid,
        _macrocycle('empty', mesocycleIds: const []),
      );
      expect(await following(), isNull);
    });
  });

  group('saveMacrocycle', () {
    test('keeps the followed one on its mesocycle when reordered', () async {
      build(
        macrocycles: [
          _macrocycle('p', mesocycleIds: ['m1', 'm2']),
        ],
      );

      await subject.saveMacrocycle(
        _uid,
        _macrocycle('p', mesocycleIds: ['m2', 'm1']),
      );

      final saved = await stored('p');
      expect(saved.mesocycleIndex, 1);
      expect(saved.dateModified, now);
      expect(await following(), 'm1');
    });

    test('points the profile at a new current mesocycle', () async {
      build(
        macrocycles: [
          _macrocycle('p', mesocycleIds: ['m1', 'm2']),
        ],
      );

      await subject.saveMacrocycle(
        _uid,
        _macrocycle('p', mesocycleIds: ['m2']),
      );

      final saved = await stored('p');
      expect(saved.mesocycleIndex, 0);
      expect(saved.mesocycleStartedAt, now);
      expect(await following(), 'm2');
    });

    test('a saved, unstarted one leaves the profile alone', () async {
      build();
      await subject.saveMacrocycle(
        _uid,
        _macrocycle('p', status: MacrocycleStatus.notStarted),
      );
      expect((await stored('p')).status, MacrocycleStatus.notStarted);
      expect(await following(), 'm1');
    });
  });

  test('deletes a macrocycle and a mesocycle', () async {
    build(mesocycles: [_mesocycle('m1')], macrocycles: [_macrocycle('p')]);
    await subject.deleteMacrocycle(_uid, 'p');
    await subject.deleteMesocycle(_uid, 'm1');
    expect(await macrocycles(), isEmpty);
    expect(await programs.watchMesocycles(_uid).first, isEmpty);
  });

  group('skip', () {
    test('records the slot and moves on once nothing is open', () async {
      build(
        mesocycles: [_mesocycle('m1'), _mesocycle('m2')],
        macrocycles: [
          _macrocycle('p', mesocycleIds: ['m1', 'm2']),
        ],
        history: [_session('a', _start.add(const Duration(hours: 1)))],
      );
      final progress = MesocycleSchedule.progress(
        MesocycleRun(mesocycle: _mesocycle('m1'), startedAt: _start),
        await sessions.watchSessions(_uid).first,
        now: now,
      );

      await subject.skip(_uid, progress.next!);

      final saved = await stored('p');
      expect(saved.skips.single.templateId, 'b');
      expect(saved.mesocycleIndex, 1);
      expect(saved.startMicrocycleIndex, isNull);
      expect(await following(), 'm2');
      expect(events, ['MacrocycleMan_Skip', 'MacrocycleMan_AdvanceMesocycle']);
    });

    test('completes the macrocycle after its last mesocycle', () async {
      build(
        mesocycles: [_mesocycle('m1')],
        macrocycles: [_macrocycle('p')],
        history: [_session('a', _start.add(const Duration(hours: 1)))],
      );
      final slot = MesocycleSchedule.progress(
        MesocycleRun(mesocycle: _mesocycle('m1'), startedAt: _start),
        await sessions.watchSessions(_uid).first,
        now: now,
      ).next!;

      await subject.skip(_uid, slot);

      expect((await stored('p')).status, MacrocycleStatus.completed);
      expect(events.last, 'MacrocycleMan_Complete');
      expect(await following(), 'm1');
    });

    test('an account from before plans gets one where it was', () async {
      final earlier = _start.subtract(const Duration(days: 3));
      build(
        mesocycles: [_mesocycle('m1', cycles: 2)],
        history: [_session('a', earlier)],
      );
      final slot = MesocycleSchedule.progress(
        MesocycleRun(
          mesocycle: _mesocycle('m1', cycles: 2),
          startedAt: MesocycleSchedule.epoch,
        ),
        await sessions.watchSessions(_uid).first,
        now: now,
      ).next!;

      await subject.skip(_uid, slot);

      final created = (await macrocycles()).single;
      expect(created.id, 'id-1');
      expect(created.mesocycleStartedAt, MesocycleSchedule.epoch);
      expect(created.status, MacrocycleStatus.active);
      expect(created.skips.single.templateId, 'b');
      expect(events, ['MacrocycleMan_Start', 'MacrocycleMan_Skip']);
    });

    test('without a mesocycle fails', () async {
      build(active: null);
      await expectLater(
        subject.skip(
          _uid,
          ScheduleSlot(cycleIndex: 0, position: 0, dayPlan: _day('a')),
        ),
        throwsStateError,
      );
    });
  });

  group('activateMesocycle', () {
    test('saves it and follows it as a macrocycle of one', () async {
      build(macrocycles: [_macrocycle('old')], active: null);

      await subject.activateMesocycle(_uid, _mesocycle('m2'));

      expect((await programs.watchMesocycles(_uid).first).single.id, 'm2');
      expect((await stored('old')).status, MacrocycleStatus.ended);
      final started = await stored('id-1');
      expect(started.mesocycleIds, ['m2']);
      expect(started.name, 'Block m2');
      expect(started.status, MacrocycleStatus.active);
      expect(started.mesocycleStartedAt, now);
      expect(await following(), 'm2');
      expect(events, ['MacrocycleMan_Start']);
    });

    test('keeps the progress of the mesocycle under way', () async {
      build(macrocycles: [_macrocycle('p')], active: null);

      await subject.activateMesocycle(_uid, _mesocycle('m1'));

      expect((await macrocycles()).single.id, 'p');
      expect(await following(), 'm1');
      expect(events, isEmpty);
    });
  });

  group('migrateIfNeeded', () {
    test('gives a legacy account one dated where its schedule was', () async {
      final history = [_session('a', _start.subtract(const Duration(days: 3)))];
      build(mesocycles: [_mesocycle('m1', cycles: 2)], history: history);

      await subject.migrateIfNeeded(_uid);

      final created = (await macrocycles()).single;
      expect(
        created.mesocycleStartedAt,
        MesocycleSchedule.legacyRun(
          _mesocycle('m1', cycles: 2),
          history,
        ).startedAt,
      );
      expect(created.mesocycleIds, ['m1']);
      expect(created.status, MacrocycleStatus.active);
    });

    test('leaves an account that already has one', () async {
      build(
        mesocycles: [_mesocycle('m1', cycles: 2)],
        macrocycles: [_macrocycle('p')],
      );

      await subject.migrateIfNeeded(_uid);

      expect((await macrocycles()).single.id, 'p');
      expect(events, isEmpty);
    });

    test('moves a finished mesocycle on', () async {
      build(
        mesocycles: [_mesocycle('m1'), _mesocycle('m2')],
        macrocycles: [
          _macrocycle('p', mesocycleIds: ['m1', 'm2']),
        ],
        history: [
          _session('a', _start.add(const Duration(hours: 1))),
          _session('b', _start.add(const Duration(hours: 2))),
        ],
      );

      await subject.migrateIfNeeded(_uid);

      expect((await stored('p')).mesocycleIndex, 1);
      expect(await following(), 'm2');
    });

    test('swallows failures, as Swift does', () async {
      build(active: null);
      subject = ProgramService(
        programs: _BrokenPrograms(),
        users: users,
        sessions: sessions,
      );

      await subject.migrateIfNeeded(_uid);
    });
  });

  group('advanceIfMesocycleComplete', () {
    test('leaves an unfinished, finished or missing one', () async {
      build(
        mesocycles: [_mesocycle('m1')],
        macrocycles: [_macrocycle('done', status: MacrocycleStatus.completed)],
      );
      await subject.advanceIfMesocycleComplete(_uid);
      expect((await stored('done')).dateModified, _start);

      build(mesocycles: [_mesocycle('m1')], macrocycles: [_macrocycle('p')]);
      await subject.advanceIfMesocycleComplete(_uid);
      expect((await stored('p')).mesocycleIndex, 0);

      build(mesocycles: [_mesocycle('m1')]);
      await subject.advanceIfMesocycleComplete(_uid);
      expect(events, isEmpty);
    });
  });

  group('repeatCurrent', () {
    test('starts the followed macrocycle over from its first', () async {
      build(
        macrocycles: [
          _macrocycle(
            'p',
            mesocycleIds: ['m1', 'm2'],
            status: MacrocycleStatus.completed,
            index: 1,
          ),
        ],
        active: 'm2',
      );

      await subject.repeatCurrent(_uid);

      final repeated = await stored('p');
      expect(repeated.status, MacrocycleStatus.active);
      expect(repeated.mesocycleIndex, 0);
      expect(repeated.iteration, 2);
      expect(await following(), 'm1');
      expect(events, ['MacrocycleMan_Repeat']);
    });

    test('does nothing without one', () async {
      build(macrocycles: [_macrocycle('p', mesocycleIds: const [])]);
      await subject.repeatCurrent(_uid);
      build();
      await subject.repeatCurrent(_uid);
      expect(events, isEmpty);
    });
  });

  group('toggleRestDay', () {
    final restSlot = ScheduleSlot(
      cycleIndex: 0,
      position: 1,
      dayPlan: _day('rest1', rest: true),
    );

    test('ticks an open rest as taken now', () async {
      build();
      await subject.toggleRestDay(_uid, restSlot, mesocycleId: 'm1');
      final saved = (await sessions.watchSessions(_uid).first).single;
      expect(saved.id, 'id-1');
      expect(saved.isRestDay, isTrue);
      expect(saved.workoutTemplateId, 'rest1');
      expect(saved.mesocycleId, 'm1');
      expect(saved.dateCreated, now);
      expect(saved.endedAt, now);
    });

    test('moves a rest pre-logged for later to now', () async {
      build(
        history: [
          _session(
            'rest1',
            now.add(const Duration(days: 1)),
            id: 'pre',
            rest: true,
          ),
        ],
      );
      await subject.toggleRestDay(_uid, restSlot, mesocycleId: 'm1');
      final saved = (await sessions.watchSessions(_uid).first).single;
      expect(saved.id, 'pre');
      expect(saved.dateCreated, now);
    });

    test('unticks a taken rest', () async {
      build(history: [_session('rest1', now, id: 'r', rest: true)]);
      await subject.toggleRestDay(
        _uid,
        ScheduleSlot(
          cycleIndex: 0,
          position: 1,
          dayPlan: _day('rest1', rest: true),
          status: SlotStatus.done,
          completedSessionId: 'r',
          completedAt: now,
        ),
        mesocycleId: 'm1',
      );
      expect(await sessions.watchSessions(_uid).first, isEmpty);
    });
  });

  group('workoutFinished', () {
    test("drops today's rest, pre-logs the rests after and moves on", () async {
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final finished = _session('a', now);
      build(
        mesocycles: [_mesocycle('m1'), _mesocycle('m2')],
        macrocycles: [
          _macrocycle('p', mesocycleIds: ['m1', 'm2']),
        ],
        history: [
          _session('rest2', now, id: 'today-rest', rest: true),
          _session('rest1', tomorrow, id: 'already', rest: true),
          _session('b', _start.add(const Duration(hours: 1))),
          finished,
        ],
      );

      await subject.workoutFinished(_uid, finished, saved: true);

      final rests = [
        for (final s in await sessions.watchSessions(_uid).first)
          if (s.isRestDay) (s.id, s.workoutTemplateId, s.dateCreated),
      ];
      expect(rests, [
        ('already', 'rest1', tomorrow),
        ('id-1', 'rest2', DateTime(now.year, now.month, now.day + 2)),
      ]);
      expect((await stored('p')).mesocycleIndex, 1);
      expect(await following(), 'm2');
    });

    test('an unsaved workout pre-logs but never moves on', () async {
      final finished = _session('a', now);
      build(
        mesocycles: [_mesocycle('m1')],
        macrocycles: [_macrocycle('p')],
        history: [_session('b', _start.add(const Duration(hours: 1)))],
      );

      await subject.workoutFinished(_uid, finished, saved: false);

      expect([
        for (final s in await sessions.watchSessions(_uid).first) s.id,
      ], hasLength(3));
      expect((await stored('p')).status, MacrocycleStatus.active);
    });

    test(
      'a workout outside the mesocycle, or off its days, adds no rests',
      () async {
        build(mesocycles: [_mesocycle('m1')]);
        await subject.workoutFinished(
          _uid,
          _session('a', now, mesocycleId: 'other'),
          saved: false,
        );
        await subject.workoutFinished(_uid, _session('zzz', now), saved: false);
        await subject.workoutFinished(
          _uid,
          WorkoutSessionModel(
            id: 'blank',
            authorId: _uid,
            name: 'Workout',
            mesocycleId: 'm1',
            dateCreated: now,
            dateModified: now,
            exercises: const [],
          ),
          saved: false,
        );
        expect(await sessions.watchSessions(_uid).first, isEmpty);
      },
    );
  });
}

class _BrokenPrograms extends InMemoryProgramRepository {
  @override
  Stream<List<Macrocycle>> watchMacrocycles(String uid) =>
      Stream.error(StateError('offline'));
}
