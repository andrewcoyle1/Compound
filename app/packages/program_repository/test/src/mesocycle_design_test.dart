import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../helpers/contract.dart';

final _now = DateTime.utc(2026, 10, 15);

final WorkoutTemplateExercise _exercise = Mesocycle.fromFirestore(
  modelFixture('mesocycle', 'full'),
).workoutTemplates.expand((plan) => plan.exercises).first;

final DayNameLabels _labels = DayNameLabels(
  restDay: 'Día de descanso',
  workout: (letter) => 'Entreno $letter',
);

WorkoutTemplateModel _day(String name, {int exercises = 0, String? id}) =>
    WorkoutTemplateModel(
      workoutId: id ?? name,
      authorId: 'user-1',
      name: name,
      dateCreated: _now,
      dateModified: _now,
      exercises: [for (var i = 0; i < exercises; i++) _exercise],
    );

Mesocycle _mesocycle(List<WorkoutTemplateModel> days) => Mesocycle(
  id: 'program-1',
  authorId: 'user-1',
  name: 'Block',
  icon: 'flag',
  colour: '#FF0000',
  workoutTemplates: days,
  dateCreated: _now,
  dateModified: _now,
);

List<String> _names(Mesocycle mesocycle) => [
  for (final day in mesocycle.workoutTemplates) day.name,
];

void main() {
  test('the palette is Swift default colours and icons', () {
    expect(mesocycleColours, hasLength(7));
    expect(mesocycleColours.first, '#000000');
    expect(mesocycleIcons.first, 'flag.pattern.checkered');
    expect(mesocycleIcons, hasLength(7));
  });

  test('a new mesocycle starts with one rest day named Rest', () {
    final mesocycle = newMesocycle(
      id: 'p',
      authorId: 'user-7',
      name: 'Block',
      icon: 'gamecontroller',
      colour: '#34C759',
      now: _now,
      newId: () => 'day-1',
    );
    expect(_names(mesocycle), ['Rest']);
    expect(mesocycle.workoutTemplates.single.workoutId, 'day-1');
    expect(mesocycle.workoutTemplates.single.authorId, 'user-7');
    expect(mesocycle.numMicrocycles, 8);
    expect(mesocycle.deload, DeloadType.none);
    expect(mesocycle.dateCreated, _now);
  });

  test('editedMesocycle changes only what it is given', () {
    final mesocycle = _mesocycle([_day('Push')]);
    final edited = editedMesocycle(
      mesocycle,
      name: 'Renamed',
      icon: 'sailboat.fill',
      colour: '#007AFF',
      numMicrocycles: 4,
      deload: DeloadType.end,
      periodisation: true,
    );
    expect(edited.id, mesocycle.id);
    expect(edited.name, 'Renamed');
    expect(edited.icon, 'sailboat.fill');
    expect(edited.colour, '#007AFF');
    expect(edited.numMicrocycles, 4);
    expect(edited.deload, DeloadType.end);
    expect(edited.periodisation, isTrue);
    expect(_names(edited), ['Push']);
    expect(
      hasUnsavedMesocycleChanges(mesocycle, editedMesocycle(mesocycle)),
      isFalse,
    );
  });

  group('workoutLetter', () {
    test('runs A to Z, then numbers the round', () {
      expect(workoutLetter(0), 'A');
      expect(workoutLetter(25), 'Z');
      expect(workoutLetter(26), 'A1');
      expect(workoutLetter(53), 'B2');
      expect(workoutLetter(-1), 'A');
    });
  });

  group('adding and removing days', () {
    test('adding a day appends a rest day', () {
      final added = addingDay(
        _mesocycle([_day('Push', exercises: 1)]),
        id: 'new',
        now: _now,
        labels: _labels,
      );
      expect(added.workoutTemplates.last.workoutId, 'new');
      expect(added.workoutTemplates.last.exercises, isEmpty);
      expect(added.workoutTemplates, hasLength(2));
    });

    test('the last day cannot be removed', () {
      final mesocycle = _mesocycle([_day('Push')]);
      expect(removingDay(mesocycle, 'Push', labels: _labels), same(mesocycle));
    });

    test('removing a day leaves the others', () {
      final removed = removingDay(
        _mesocycle([_day('Push'), _day('Pull')]),
        'Pull',
        labels: _labels,
      );
      expect(_names(removed), ['Push']);
    });
  });

  group('automatic day names', () {
    test('rest days do not consume a workout letter', () {
      final added = addingDay(
        _mesocycle([
          _day('Rest', exercises: 1, id: '1'),
          _day('Rest', id: '2'),
          _day('Rest', exercises: 1, id: '3'),
        ]),
        id: '4',
        now: _now,
        labels: const DayNameLabels(restDay: 'Rest Day', workout: _english),
      );
      expect(_names(added), ['Workout A', 'Rest Day', 'Workout B', 'Rest Day']);
    });

    test('filling a day renames it and the days after it', () {
      final filled = withDayNames(
        _mesocycle([
          _day('Rest', exercises: 1, id: '1'),
          _day('Rest', exercises: 1, id: '2'),
        ]),
        _labels,
      );
      expect(_names(filled), ['Entreno A', 'Entreno B']);
    });

    test('a typed day name survives later edits', () {
      final renamed = renamingDay(
        _mesocycle([_day('Rest', exercises: 1, id: '1')]),
        '1',
        'Leg Day',
      );
      final added = addingDay(renamed, id: '2', now: _now, labels: _labels);
      expect(_names(added), ['Leg Day', 'Día de descanso']);
    });

    test('older English and lettered names count as generated', () {
      final renamed = withDayNames(
        _mesocycle([
          _day('Rest Day', id: '1'),
          _day('Workout Z', exercises: 1, id: '2'),
          _day('Workout AB', exercises: 1, id: '3'),
          _day('Entreno D', exercises: 1, id: '4'),
        ]),
        _labels,
      );
      expect(_names(renamed), [
        'Día de descanso',
        'Entreno A',
        'Workout AB',
        'Entreno C',
      ]);
    });

    test('renaming changes only that day', () {
      final renamed = renamingDay(
        _mesocycle([_day('Push'), _day('Pull')]),
        'Pull',
        'Back',
      );
      expect(_names(renamed), ['Push', 'Back']);
    });
  });

  test('a mesocycle of rest days has no workout day', () {
    expect(hasWorkoutDay(_mesocycle([_day('Rest')])), isFalse);
    expect(hasWorkoutDay(_mesocycle([_day('Push', exercises: 1)])), isTrue);
  });

  group('hasUnsavedMesocycleChanges', () {
    test('only a real edit counts', () {
      final initial = _mesocycle([_day('Push', exercises: 1)]);
      expect(
        hasUnsavedMesocycleChanges(
          initial,
          _mesocycle([_day('Push', exercises: 1)]),
        ),
        isFalse,
      );
      expect(
        hasUnsavedMesocycleChanges(
          initial,
          addingDay(initial, id: 'x', now: _now, labels: _labels),
        ),
        isTrue,
      );
      expect(
        hasUnsavedMesocycleChanges(
          initial,
          editedMesocycle(initial, numMicrocycles: 4),
        ),
        isTrue,
      );
      expect(
        hasUnsavedMesocycleChanges(initial, _mesocycle([_day('Push')])),
        isTrue,
      );
    });
  });
}

String _english(String letter) => 'Workout $letter';
