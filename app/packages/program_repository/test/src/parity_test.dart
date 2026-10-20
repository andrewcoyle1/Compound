// The port against contracts/fixtures/program-parity.json, which
// ProgramParityTests.swift records from the Swift: MesocycleSchedule over
// the situations MesocycleScheduleTests covers and seeded random histories,
// and Macrocycle's advanced and started. Times are milliseconds since 1970;
// days are UTC days.
import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

final Map<String, Object?> _fixture = jsonDecode(
  File('../../../contracts/fixtures/program-parity.json').readAsStringSync(),
) as Map<String, Object?>;

/// An exercise for a workout day: the contract mesocycle's first.
final WorkoutTemplateExercise _exercise = Mesocycle.fromFirestore(
  taggedJsonToFirestore(
    jsonDecode(
      File('../../../contracts/firestore/mesocycle/full.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  ),
).workoutTemplates.expand((plan) => plan.exercises).first;

DateTime _date(Object? millis) =>
    DateTime.fromMillisecondsSinceEpoch((millis! as num).toInt(), isUtc: true);

int _millis(DateTime date) => date.millisecondsSinceEpoch;

bool _sameUtcDay(DateTime a, DateTime b) {
  final x = a.toUtc();
  final y = b.toUtc();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

final _wednesday = DateTime.utc(2026, 9, 30, 9);

Map<String, Object?> _schedule(Map<String, Object?> input) {
  final mesocycle = Mesocycle(
    id: 'program-1',
    authorId: 'me',
    name: 'Block',
    icon: 'dumbbell',
    colour: '#FF0000',
    numMicrocycles: input['cycles']! as int,
    deload: DeloadType.values.byName(input['deload']! as String),
    periodisation: input['periodisation']! as bool,
    workoutTemplates: [
      for (final day in (input['days']! as List).cast<Map<String, Object?>>())
        WorkoutTemplateModel(
          workoutId: day['id']! as String,
          authorId: 'me',
          name: day['name']! as String,
          dateCreated: _wednesday,
          dateModified: _wednesday,
          exercises: day['rest']! as bool ? const [] : [_exercise],
        ),
    ],
    dateCreated: _wednesday,
    dateModified: _wednesday,
  );
  final sessions = [
    for (final s in (input['sessions']! as List).cast<Map<String, Object?>>())
      WorkoutSessionModel(
        id: s['id']! as String,
        authorId: 'me',
        name: s['name']! as String,
        workoutTemplateId: s['templateId'] as String?,
        mesocycleId: s['mesocycleId'] as String?,
        dateCreated: _date(s['createdAt']),
        dateModified: _date(s['createdAt']),
        endedAt: s['endedAt'] == null ? null : _date(s['endedAt']),
        deletedAt: s['deleted']! as bool ? _date(s['createdAt']) : null,
        isRestDay: s['rest']! as bool,
        exercises: const [],
      ),
  ];
  final skips = [
    for (final s in (input['skips']! as List).cast<Map<String, Object?>>())
      CycleSkip(
        mesocycleIndex: 0,
        cycleIndex: s['cycleIndex']! as int,
        position: s['position']! as int,
        templateId: s['templateId']! as String,
        date: _wednesday,
      ),
  ];
  final expected = <String, Object?>{};
  final DateTime startedAt;
  if (input['startedAt'] case final millis?) {
    startedAt = _date(millis);
  } else {
    startedAt = MesocycleSchedule.legacyRun(mesocycle, sessions).startedAt;
    expected['legacyStartedAt'] = _millis(startedAt);
  }
  final run = MesocycleRun(
    mesocycle: mesocycle,
    startedAt: startedAt,
    skips: skips,
    firstMicrocycleIndex: input['firstMicrocycleIndex']! as int,
  );
  final now = _date(input['now']);
  final progress = MesocycleSchedule.progress(run, sessions, now: now);
  expected['slots'] = [
    for (final cycle in progress.cycles)
      [
        for (final slot in cycle)
          switch (slot.status) {
            SlotStatus.open => 'open',
            SlotStatus.done =>
              'done:${slot.completedSessionId}@${_millis(slot.completedAt!)}',
            SlotStatus.skipped => 'skipped',
            SlotStatus.beforeStart => 'beforeStart',
          },
      ],
  ];
  expected['current'] = progress.currentCycleIndex;
  expected['next'] = progress.next?.id;
  expected['complete'] = progress.isMesocycleComplete;
  final today = MesocycleSchedule.todayItem(
    run,
    sessions,
    now: now,
    sameDay: _sameUtcDay,
  );
  expected['today'] = today == null
      ? null
      : {
          'plan': today.dayPlan.workoutId,
          'session': today.completedSessionId,
          'cycle': today.cycleIndex,
        };
  final count = mesocycle.numMicrocycles < 1 ? 1 : mesocycle.numMicrocycles;
  expected['deload'] = [
    for (var cycle = 1; cycle <= count; cycle++)
      MesocycleSchedule.isDeload(cycle, mesocycle),
  ];
  expected['phases'] = [
    for (var cycle = 1; cycle <= count; cycle++)
      MesocycleSchedule.phase(cycle, mesocycle)?.name,
  ];
  return expected;
}

Map<String, Object?> _macrocycle(Map<String, Object?> input) {
  final count = input['count']! as int;
  final macrocycle = Macrocycle(
    id: 'plan',
    authorId: 'me',
    name: 'Plan',
    mesocycleIds: [for (var i = 0; i < count; i++) 'meso-$i'],
    status: MacrocycleStatus.values.byName(input['status']! as String),
    mesocycleIndex: input['index']! as int,
    mesocycleStartedAt: _wednesday,
    startMicrocycleIndex: input['start'] as int?,
    skips: [
      CycleSkip(
        mesocycleIndex: 0,
        cycleIndex: 0,
        position: 0,
        templateId: 'a',
        date: _wednesday,
      ),
    ],
    iteration: input['iteration']! as int,
    dateCreated: _wednesday,
    dateModified: _wednesday,
  );
  final now = _wednesday.add(const Duration(days: 1));
  final result = input['op'] == 'advance'
      ? macrocycle.advanced(now)
      : macrocycle.started(
          now,
          mesocycleIndex: input['mesocycle']! as int,
          microcycleIndex: input['microcycle']! as int,
        );
  return {
    'status': result.status.value,
    'index': result.mesocycleIndex,
    'startedAt': _millis(result.mesocycleStartedAt),
    'start': result.startMicrocycleIndex,
    'skips': result.skips.length,
    'iteration': result.iteration,
    'modified': _millis(result.dateModified),
    'current': result.currentMesocycleId,
    'last': result.isLastMesocycle,
  };
}

/// Equal JSON values; a whole double equals its int.
bool _matches(Object? actual, Object? expected) => switch ((actual, expected)) {
  (final Map<String, Object?> a, final Map<String, Object?> e) =>
    a.length == e.length &&
        a.keys.every((key) => e.containsKey(key) && _matches(a[key], e[key])),
  (final List<Object?> a, final List<Object?> e) =>
    a.length == e.length &&
        [for (var i = 0; i < a.length; i++) i]
            .every((i) => _matches(a[i], e[i])),
  (final num a, final num e) => a == e,
  _ => actual == expected,
};

void main() {
  for (final section in ['schedules', 'macrocycles']) {
    group(section, () {
      final cases = (_fixture[section]! as List).cast<Map<String, Object?>>();
      test('has cases', () => expect(cases, isNotEmpty));
      for (final (index, testCase) in cases.indexed) {
        test('$section[$index] matches the Swift', () {
          final input = testCase['input']! as Map<String, Object?>;
          final actual = section == 'schedules'
              ? _schedule(input)
              : _macrocycle(input);
          expect(
            _matches(actual, testCase['expected']),
            isTrue,
            reason:
                'Dart gives ${jsonEncode(actual)}\n'
                'Swift gives ${jsonEncode(testCase['expected'])}',
          );
        });
      }
    });
  }
}
