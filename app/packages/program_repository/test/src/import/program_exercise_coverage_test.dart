// Swift ProgramExerciseCoverageTests: every exercise name on the two
// programs the importer was built against matches the bundled library, the
// names that already matched still match the same exercise, and names that
// differ only by grip or implement land on different exercises.
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show PrebuiltCatalogue;

final _matcher = ExerciseNameMatcher(PrebuiltCatalogue.instance.exercises);

String? _matchedId(String name) => _matcher.match(name)?.id;

Map<String, String?> _matched(Iterable<String> names) => {
  for (final name in names) name: _matchedId(name),
};

/// The names that matched nothing before the library grew from 64
/// exercises.
const _formerlyUnmatched = [
  '1-Arm Cable Pulldown',
  '45° Hyperextension',
  '45° Incline Barbell Press',
  '45° Incline Machine Press',
  'Bench Dip',
  'Bottom-Half Seated Cable Flye',
  'Cable Crossover Ladder',
  'Cable Flye',
  'Cable Hip Abduction',
  'Cable Hip Adduction',
  'Cable Lat Pullover',
  'Cable Pull-Through',
  'Cable Shoulder Press',
  'Cable Triceps Kickback',
  'Cable Wrist Extension',
  'Cable Y-Raise',
  'Chest-Supported DB Row',
  'Chest-Supported Machine Row',
  'Close-Grip Pull-Up',
  'Copenhagen Hip Adduction',
  'DB Cheat Curl',
  'DB Curl',
  'DB Hammer Curl',
  'DB Lat Pullover',
  'DB Lateral Raise',
  'DB Row',
  'DB Shrug',
  'DB Skull Crusher',
  'DB Static Lunge',
  'DB Step-Up',
  'DB Triceps Kickback',
  'DB Walking Lunge',
  'DB Wrist Curl',
  'DB Wrist Extension',
  'Decline Weighted Crunch',
  'Donkey Calf Raise',
  'Dual-Handle Elbows-Out Cable Row',
  'EZ-Bar Cheat Curl',
  'EZ-Bar Curl',
  'Glute Kickback',
  'Glute-Ham Raise',
  'Goblet Squat',
  'Hanging Leg Raise',
  'Helms Row',
  'Incline Chest-Supported DB Row',
  'Incline DB Stretch Curl',
  'Incline DB Y-Raise',
  'Katana Triceps Extension',
  'Lateral Band Walk',
  'Lean-Back Machine Pulldown',
  'Lean-In DB Lateral Raise',
  'Long-Lever Plank',
  'Lying Reverse DB Flye',
  'Machine Chest Press',
  'Machine Lat Pullover',
  'Machine Lateral Raise',
  'Machine Shrug',
  'Meadows Row',
  'Modified Candlestick',
  'Nordic Ham Curl',
  'Pull-Up',
  'Pull-Up (Wide Grip)',
  'Reverse Cable Crossover',
  'Reverse Nordic',
  'Roman Chair Leg Raise',
  'Seated Smith Machine Shoulder Press',
  'Single-Arm Machine Lateral Raise',
  'Sissy Squat',
  'Smith Machine Bench Press',
  'Smith Machine Row',
  'Smith Machine Static Lunge',
  'Standing Calf Raise',
  'Stiff-Leg Deadlift',
  'Swiss Ball Rollout',
  'Triceps Pressdown',
  'Triceps Pressdown (Bar)',
  'Triceps Pressdown (Rope)',
  'Walking Lunge',
  'Weighted Crunch',
];

void main() {
  test('every program name matches', () {
    expect(_formerlyUnmatched, hasLength(79));
    expect([
      for (final name in _formerlyUnmatched)
        if (_matchedId(name) == null) name,
    ], isEmpty);
  });

  test('spellings of an existing exercise land on it', () {
    const cases = {
      'Pull-Up (Wide Grip)': 'system-wide-grip-pull-up',
      'Triceps Pressdown (Bar)': 'system-cable-pushdown-straight-bar',
      '45° Incline Barbell Press': 'system-barbell-incline-bench-press',
      '45° Incline Machine Press': 'system-lever-incline-hammer-chest-press',
      'Cable Triceps Kickback': 'system-neutral-grip-cable-triceps-kickback',
      'DB Row': 'system-single-arm-row',
      'Incline Chest-Supported DB Row': 'system-chest-supported-dumbbell-row',
      'Cable Crossover Ladder': 'system-cable-fly',
      'DB Cheat Curl': 'system-dumbbell-curl',
      'EZ-Bar Cheat Curl': 'system-ez-bar-curl',
    };
    expect(_matched(cases.keys), cases);
  });

  test('grips and implements stay separate', () {
    const pairs = [
      ('Triceps Pressdown (Rope)', 'Triceps Pressdown (Bar)'),
      ('DB Curl', 'EZ-Bar Curl'),
      ('Pull-Up', 'Pull-Up (Wide Grip)'),
      ('Pull-Up', 'Close-Grip Pull-Up'),
      ('Machine Lateral Raise', 'Single-Arm Machine Lateral Raise'),
      ('Weighted Crunch', 'Decline Weighted Crunch'),
      ('Cable Flye', 'Reverse Cable Crossover'),
    ];
    for (final (first, second) in pairs) {
      expect(_matchedId(first), isNotNull, reason: first);
      expect(_matchedId(first), isNot(_matchedId(second)), reason: second);
    }
  });

  test('names that already matched still match the same exercise', () {
    const cases = {
      'Machine Shoulder Press': 'system-pin-loaded-machine-shoulder-press',
      'EZ-Bar Cable Curl': 'system-cable-bicep-curl-straight-bar',
      'Neutral-Grip Pull-Up': 'system-weighted-hammer-grip-pull-up-on-dip',
      'Wide-Grip Pull-Up': 'system-wide-grip-pull-up',
      'Single-Arm DB Row': 'system-single-arm-row',
      'DB Bulgarian Split Squat': 'system-bulgarian-split-squat',
      'Smith Machine Static Lunge w/ Elevated Front Foot':
          'system-smith-machine-front-foot-elevated-split-squat',
      'Hammer Preacher Curl': 'system-ez-barbell-preacher-curl',
      'Machine Hip Abduction': 'system-seated-machine-hip-abduction',
      'Seated Calf Raise': 'system-seated-plate-loaded-machine-calf-raise',
      'Bottom-Half DB Flye': 'system-dumbbell-fly',
      'Low-to-High Cable Crossover': 'system-low-to-high-cable-fly',
      'High-Cable Lateral Raise': 'system-standing-lateral-raise-cable',
      'Wide-Grip Lat Pulldown': 'system-wide-grip-cable-lat-pulldown',
      'Snatch-Grip RDL': 'system-barbell-romanian-deadlift',
      'Machine Crunch': 'system-machine-crunch-with-overhead-handles',
      'DB Preacher Curl': 'system-dumbbell-preacher-curl',
    };
    expect(_matched(cases.keys), cases);
  });

  test('names that used to match the wrong lift match the right one', () {
    const cases = {
      'Bayesian Cable Curl': 'system-single-arm-bayesian-curl',
      'Seated Super-Bayesian High Cable Curl': 'system-seated-high-cable-curl',
      'Cable Wrist Curl': 'system-cable-wrist-curl',
      'Concentration Cable Curl': 'system-cable-concentration-curl',
      'Reverse Pec Deck': 'system-reverse-fly',
      '1-Arm Reverse Pec Deck': 'system-single-arm-reverse-pec-deck',
      'Lat Pulldown (Wide Grip)': 'system-wide-grip-cable-lat-pulldown',
      'Lean-Back Lat Pulldown': 'system-overhand-grip-cable-lat-pulldown',
      'Dual-Handle Lat Pulldown': 'system-cable-neutral-grip-lat-pulldown',
      'Smith Machine Split Squat': 'system-smith-machine-static-lunge',
      'DB RDL': 'system-dumbbell-romanian-deadlift',
    };
    expect(_matched(cases.keys), cases);
  });
}
