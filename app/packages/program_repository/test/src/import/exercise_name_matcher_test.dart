// Swift ExerciseNameMatcherTests: matching a sheet's names to the library
// without ever guessing.
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../../helpers/program_fixtures.dart';

ExerciseNameMatcher _library(List<String> names) =>
    ExerciseNameMatcher([for (final name in names) fixtureExercise(name)]);

void main() {
  final matcher = ExerciseNameMatcher([
    fixtureExercise('Dumbbell Bench Press'),
    fixtureExercise('Barbell Row'),
    fixtureExercise('Single-Arm Cable Row'),
    fixtureExercise('Smith Machine Squat'),
    fixtureExercise('Lat Pull-Down'),
    fixtureExercise('Cable Fly'),
    fixtureExercise('Leg Curl', alternateNames: ['Hamstring Curl']),
  ]);
  String? matched(String name) => matcher.match(name)?.name;

  test('the exact name matches', () {
    expect(matched('Barbell Row'), 'Barbell Row');
  });

  test('an alternate name matches', () {
    expect(matched('Hamstring Curl'), 'Leg Curl');
  });

  test('case and punctuation are ignored', () {
    expect(matched('LEG-CURL'), 'Leg Curl');
    expect(matched('lat pull down'), 'Lat Pull-Down');
    expect(matched('  barbell row '), 'Barbell Row');
  });

  test('each abbreviation is spelled out', () {
    const cases = {
      'DB Bench Press': 'Dumbbell Bench Press',
      'BB Row': 'Barbell Row',
      '1-Arm Cable Row': 'Single-Arm Cable Row',
      'One-Arm Cable Row': 'Single-Arm Cable Row',
      'SM Squat': 'Smith Machine Squat',
      'Lat Pulldown': 'Lat Pull-Down',
      'Cable Flye': 'Cable Fly',
    };
    expect({for (final name in cases.keys) name: matched(name)}, cases);
  });

  test('a near miss stays unmatched', () {
    for (final name in [
      'Leg Curls',
      'Dumbbell Press',
      'Row',
      'Cable Flyes',
      'Flye',
    ]) {
      expect(matched(name), isNull, reason: name);
    }
  });

  test('the same words in another order match', () {
    expect(matched('Cable Single-Arm Row'), 'Single-Arm Cable Row');
    expect(matched('Bench Press DB'), 'Dumbbell Bench Press');
  });

  test(
    'a library name that only adds a position or equipment word matches',
    () {
      final matcher = _library([
        'Seated Machine Hip Adduction',
        'Kneeling Cable Crunch',
        'Cable Neutral Grip Lat Pulldown',
        'Seated Plate-Loaded Machine Calf Raise',
        'Dumbbell Concentration Curl',
        '45° Leg Press',
        'Calf Press on Leg Press',
      ]);
      expect(
        matcher.match('Machine Hip Adduction')?.name,
        'Seated Machine Hip Adduction',
      );
      expect(matcher.match('Cable Crunch')?.name, 'Kneeling Cable Crunch');
      expect(
        matcher.match('Neutral-Grip Lat Pulldown')?.name,
        'Cable Neutral Grip Lat Pulldown',
      );
      expect(
        matcher.match('Seated Calf Raise')?.name,
        'Seated Plate-Loaded Machine Calf Raise',
      );
      expect(matcher.match('Leg Press')?.name, '45° Leg Press');
      expect(matcher.match('Dumbbell Curl'), isNull);
      expect(matcher.match('Curl'), isNull);
    },
  );

  test(
    'a sheet name that adds words to a library name matches the longest',
    () {
      final library = _library([
        'T-Bar Row',
        'Row',
        'Dumbbell Fly',
        'Dumbbell Incline Fly',
        'Seated Row',
        'Cable Row',
      ]);
      expect(library.match('Chest-Supported T-Bar Row')?.name, 'T-Bar Row');
      expect(
        library.match('Bottom-Half Dumbbell Incline Fly')?.name,
        'Dumbbell Incline Fly',
      );
      expect(library.match('Helms Row'), isNull);
      expect(library.match('Seated Cable Row'), isNull);
      expect(matched('Seated Leg Curl'), 'Leg Curl');
    },
  );

  test('added words that change the lift match nothing', () {
    final library = ExerciseNameMatcher([
      fixtureExercise('Cable Curl'),
      fixtureExercise('Pec Deck'),
      fixtureExercise(
        'Barbell Romanian Deadlift',
        alternateNames: ['Romanian Deadlift'],
      ),
      fixtureExercise('Bulgarian Split Squat'),
    ]);
    for (final name in [
      'Cable Wrist Curl',
      'Concentration Cable Curl',
      'Bayesian Cable Curl',
      'Reverse Pec Deck',
      'DB RDL',
    ]) {
      expect(library.match(name), isNull, reason: name);
    }
    expect(library.match('Snatch-Grip RDL')?.name, 'Barbell Romanian Deadlift');
    expect(
      library.match('DB Bulgarian Split Squat')?.name,
      'Bulgarian Split Squat',
    );
  });

  test('parentheticals are optional qualifiers on either side', () {
    final library = _library([
      'Machine Crunch (With Overhead Handles)',
      'Cable Overhead Triceps Extension',
      'Barbell Romanian Deadlift',
      'EZ Barbell Preacher Curl',
      'Cable Pushdown',
    ]);
    expect(
      library.match('Machine Crunch')?.name,
      'Machine Crunch (With Overhead Handles)',
    );
    expect(
      library.match('Overhead Cable Triceps Extension (Rope)')?.name,
      'Cable Overhead Triceps Extension',
    );
    expect(library.match('Barbell RDL')?.name, 'Barbell Romanian Deadlift');
    expect(
      library.match('EZ-Bar Preacher Curl')?.name,
      'EZ Barbell Preacher Curl',
    );
    expect(library.match('Cable Pressdown')?.name, 'Cable Pushdown');
  });

  test('suggestions rank by shared words and stop at three', () {
    final names = [
      for (final e in matcher.suggestions('Seated Cable Row')) e.name,
    ];
    expect(names.first, 'Single-Arm Cable Row');
    expect(names, contains('Barbell Row'));
    expect(names.length, lessThanOrEqualTo(3));
    expect(
      [for (final e in matcher.suggestions('Nordic Ham Curl')) e.name],
      ['Leg Curl'],
    );
    expect(matcher.suggestions('Plank'), isEmpty);
    expect(matcher.suggestions('(the)'), isEmpty);
  });

  test('a loose match to two exercises matches neither', () {
    final matcher = ExerciseNameMatcher([
      fixtureExercise('Pull-Down'),
      fixtureExercise('Pull Down', system: false, id: 'user-pull-down'),
    ]);
    expect(matcher.match('pull down'), isNull);
    expect(matcher.match('Pulldown'), isNull);
    expect(matcher.match('Pull-Down')?.name, 'Pull-Down');
  });

  test('a name of punctuation alone matches nothing', () {
    expect(matched('--'), isNull);
  });
}
