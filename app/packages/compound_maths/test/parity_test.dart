// The Dart port against the fixture CoachParityTests.swift and
// functions/coach-maths.test.js also check, with the same tolerance.
import 'dart:convert';
import 'dart:io';

import 'package:compound_maths/compound_maths.dart';
import 'package:test/test.dart';

const _fixturePath = '../../../CompoundUnitTests/Fixtures/coach-parity.json';

typedef Json = Map<String, dynamic>;

/// Equal JSON values, numbers within a millionth: the languages round the last
/// bit apart. Returns the first mismatch's path, or `null`.
String? mismatch(Object? actual, Object? expected, String path) {
  if (expected is num) {
    if (actual is! num) return '$path: expected $expected, got $actual';
    final tolerance = 1e-6 * (expected.abs() > 1 ? expected.abs() : 1);
    return (actual - expected).abs() <= tolerance
        ? null
        : '$path: $actual != $expected';
  }
  if (expected is List) {
    if (actual is! List) return '$path: expected a list, got $actual';
    if (actual.length != expected.length) return '$path: length';
    for (var i = 0; i < expected.length; i++) {
      final m = mismatch(actual[i], expected[i], '$path[$i]');
      if (m != null) return m;
    }
    return null;
  }
  if (expected is Map) {
    if (actual is! Map) return '$path: expected a map, got $actual';
    final keys = {...actual.keys, ...expected.keys};
    if (keys.length != expected.length || actual.length != expected.length) {
      return '$path: keys ${actual.keys} != ${expected.keys}';
    }
    for (final key in expected.keys) {
      final m = mismatch(actual[key], expected[key], '$path.$key');
      if (m != null) return m;
    }
    return null;
  }
  return actual == expected ? null : '$path: $actual != $expected';
}

double? _double(Object? value) => (value as num?)?.toDouble();

/// Sessions as the Swift builds them: ended at noon plus `order` seconds on
/// their day, sets with the Swift's default ids.
List<WorkoutSession> sessions(Json testCase) => [
  for (final (index, session)
      in (testCase['sessions'] as List).cast<Json>().indexed)
    WorkoutSession(
      day: session['day'] as String,
      at: DateTime.parse('${session['day']}T12:00:00Z')
          .add(Duration(seconds: (session['order'] as num? ?? 0).toInt())),
      exercises: [
        for (final (position, exercise)
            in (session['exercises'] as List).cast<Json>().indexed)
          WorkoutExercise(
            templateId: exercise['templateId'] as String,
            name: exercise['name'] as String,
            sets: [
              for (final (setIndex, set)
                  in (exercise['sets'] as List).cast<Json>().indexed)
                WorkoutSet(
                  id: set['id'] as String? ?? 's$index-$position-$setIndex',
                  reps: set['reps'] as int?,
                  weightKg: _double(set['weightKg']),
                  rpe: _double(set['rpe']),
                  side: set['side'] == null
                      ? null
                      : SetSide.values.byName(set['side'] as String),
                  kind: set['kind'] == null
                      ? SetKind.standard
                      : SetKind.values.byName(set['kind'] as String),
                  parentSetId: set['parentSetId'] as String?,
                  isWarmup: set['isWarmup'] as bool? ?? false,
                  completed: set['completed'] as bool? ?? false,
                ),
            ],
          ),
      ],
    ),
];

Object? expenditureEngine(Json c) {
  final settings = c['settings'] as Json? ?? {};
  final history = expenditureHistory(
    samples: [
      for (final s in (c['samples'] as List).cast<Json>())
        DailySample(
          day: s['day'] as String,
          intakeKcal: _double(s['intakeKcal']),
          weightKg: _double(s['weightKg']),
          steps: s['steps'] as int?,
          isExcluded: s['isExcluded'] as bool? ?? false,
          isFastingDay: s['isFastingDay'] as bool? ?? false,
        ),
    ],
    priorKcal: _double(c['priorKcal']) ?? 0,
    today: c['today'] as String,
    settings: ExpenditureSettings(
      calculationMode: settings['calculationMode'] == 'fixed'
          ? ExpenditureCalculationMode.fixed
          : ExpenditureCalculationMode.dynamic,
      calculationStartDay: settings['calculationStartDay'] as String?,
      stepInformedUpdates: settings['stepInformedUpdates'] as bool? ?? false,
    ),
    kcalPerKg: _double(c['kcalPerKg']) ?? EnergyDensity.conventionalKcalPerKg,
  );
  return [
    for (final e in history)
      {
        'day': e.day,
        'kcal': e.kcal,
        'source': e.source.name,
        'isProvisional': e.isProvisional,
        'trendWeightKg': e.trendWeightKg,
        'weeklyTrendChangeKg': e.weeklyTrendChangeKg,
        'loggedDays': e.loggedDays,
        'weighInCount': e.weighInCount,
        'windowDays': e.windowDays,
        'stepAdjustmentKcal': e.stepAdjustmentKcal,
        'sdKcal': e.sdKcal,
        'weeklyTrendChangeSDKg': e.weeklyTrendChangeSDKg,
        'recentIntakeKcal': e.recentIntakeKcal,
      },
  ];
}

Object? expenditureSamplesCase(Json c) {
  final loggingBreak = c['loggingBreak'] as Json?;
  final samples = expenditureSamples(
    today: c['today'] as String,
    meals: [
      for (final m in (c['meals'] as List).cast<Json>())
        (dayKey: m['dayKey'] as String, calories: _double(m['calories'])!),
    ],
    measurements: [
      for (final m in (c['measurements'] as List).cast<Json>())
        WeighIn(
          day: m['day'] as String,
          weightKg: _double(m['weightKg']),
          deleted: m['deleted'] as bool? ?? false,
        ),
    ],
    steps: [
      for (final s in (c['steps'] as List).cast<Json>())
        StepRecord(
          day: s['day'] as String,
          number: s['number'] as int,
          deleted: s['deleted'] as bool? ?? false,
        ),
    ],
    annotations: [
      for (final a in (c['annotations'] as List).cast<Json>())
        DayAnnotation(
          dayKey: a['dayKey'] as String,
          isPartiallyLogged: a['isPartiallyLogged'] as bool? ?? false,
          isFastingDay: a['isFastingDay'] as bool? ?? false,
        ),
    ],
    loggingBreak: loggingBreak == null
        ? null
        : (
            startDay: loggingBreak['startDay'] as String,
            endDay: loggingBreak['endDay'] as String?,
          ),
  );
  return [
    for (final s in samples)
      {
        'day': s.day,
        'intakeKcal': s.intakeKcal,
        'weightKg': s.weightKg,
        'steps': s.steps,
        'isExcluded': s.isExcluded,
        'isFastingDay': s.isFastingDay,
      },
  ];
}

Object? tdee(Json c) {
  final profile = c['profile'] as Json;
  return estimateTdee(
    gender: Gender.tryParse(profile['gender'] as String?),
    weightKg: _double(profile['weightKg']),
    heightCm: _double(profile['heightCm']),
    activity: ActivityLevel.tryParse(profile['activity'] as String?),
    equation:
        BmrEquation.tryParse(c['equation'] as String?) ??
        BmrEquation.mifflinStJeor,
    bodyFatPercentage: _double(c['bodyFatPercentage']),
  );
}

Object? weightTrendCase(Json c) => weightTrend([
  for (final v in c['values'] as List) (v as num).toDouble(),
], days: (c['days'] as List?)?.cast<String>());

Object? oneRepMax(Json c) => exerciseOneRepMax(sessions(c)).map(
  (id, a) => MapEntry(id, {
    'name': a.name,
    'latest1RM': a.latest1RM,
    'last7Workouts': [
      for (final p in a.last7Workouts) {'day': p.day, 'value': p.value},
    ],
  }),
);

Object? weeklySets(Json c) => weeklyMuscleSets(
  sessions(c),
  {
    for (final MapEntry(:key, :value) in (c['templates'] as Json).entries)
      key: {
        for (final MapEntry(key: muscle, value: target)
            in (value as Json).entries)
          Muscle.values.byName(muscle): MuscleTarget.values.byName(
            target as String,
          ),
      },
  },
  c['endDay'] as String,
  weeks: c['weeks'] as int,
).map((muscle, sets) => MapEntry(muscle.name, sets));

Object? pairedSets(Json c) => pairedSetCount([
  for (final side in c['sides'] as List)
    WorkoutSet(
      side: side == null ? null : SetSide.values.byName(side as String),
    ),
]);

void main() {
  final fixture = jsonDecode(File(_fixturePath).readAsStringSync()) as Json;
  final runners = <String, Object? Function(Json)>{
    'expenditureEngine': expenditureEngine,
    'expenditureSamples': expenditureSamplesCase,
    'tdee': tdee,
    'weightTrend': weightTrendCase,
    'oneRepMax': oneRepMax,
    'weeklyMuscleSets': weeklySets,
    'pairedSetCount': pairedSets,
  };

  test('every section of the fixture has a runner', () {
    expect(
      fixture.keys.where((key) => key != 'note').toSet(),
      runners.keys.toSet(),
    );
  });

  group('matches the Swift:', () {
    for (final MapEntry(key: section, value: run) in runners.entries) {
      final cases = (fixture[section] as List).cast<Json>();
      test('$section has cases', () => expect(cases, isNotEmpty));
      for (final testCase in cases) {
        test('$section / ${testCase['name']}', () {
          final result = mismatch(run(testCase), testCase['expected'], section);
          expect(result, isNull, reason: result);
        });
      }
    }
  });

  group('mismatch', () {
    test('finds each kind of difference', () {
      expect(mismatch('1', 1, 'x'), isNotNull);
      expect(mismatch(1.1, 1, 'x'), isNotNull);
      expect(mismatch(1, [1], 'x'), isNotNull);
      expect(mismatch([1, 2], [1], 'x'), isNotNull);
      expect(mismatch([2], [1], 'x'), isNotNull);
      expect(mismatch(1, {'a': 1}, 'x'), isNotNull);
      expect(mismatch({'b': 1}, {'a': 1}, 'x'), isNotNull);
      expect(mismatch({'a': 2}, {'a': 1}, 'x'), isNotNull);
      expect(mismatch(true, false, 'x'), isNotNull);
      expect(mismatch({'a': 1.0000001}, {'a': 1}, 'x'), isNull);
    });
  });
}
