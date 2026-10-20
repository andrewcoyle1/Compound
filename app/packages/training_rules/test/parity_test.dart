// The Dart port against the fixture ProgressionParityTests.swift records from
// the Swift and checks, with the same tolerance (a millionth).
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

const _fixturePath = '../../../contracts/fixtures/progression-parity.json';

typedef Json = Map<String, dynamic>;

/// The first mismatch's path between JSON values, numbers within a
/// millionth, or `null`.
String? mismatch(Object? actual, Object? expected, String path) {
  if (expected is num) {
    if (actual is! num) return '$path: expected $expected, got $actual';
    final tolerance = 1e-6 * (expected.abs() > 1 ? expected.abs() : 1);
    return (actual - expected).abs() <= tolerance
        ? null
        : '$path: $actual != $expected';
  }
  if (expected is List) {
    if (actual is! List || actual.length != expected.length) {
      return '$path: expected $expected, got $actual';
    }
    for (var i = 0; i < expected.length; i++) {
      final m = mismatch(actual[i], expected[i], '$path[$i]');
      if (m != null) return m;
    }
    return null;
  }
  if (expected is Map) {
    if (actual is! Map ||
        actual.length != expected.length ||
        !actual.keys.every(expected.containsKey)) {
      return '$path: expected $expected, got $actual';
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

final _start = DateTime.fromMillisecondsSinceEpoch(1000000000, isUtc: true);

WorkoutSet set(int offset, Json json) => WorkoutSet(
  id: json['id'] as String? ?? 'set-${offset + 1}',
  index: offset + 1,
  reps: json['reps'] as int?,
  weightKg: _double(json['kg']),
  durationSec: json['dur'] as int?,
  distanceMeters: _double(json['dist']),
  rpe: _double(json['rpe']),
  side: switch (json['side']) {
    final String side => SetSide.values.byName(side),
    _ => null,
  },
  parentSetId: json['parent'] as String?,
  targetReps: json['target'] as int?,
  machineBaseKg: _double(json['base']),
  isWarmup: json['warmup'] as bool? ?? false,
  completedAt: json['open'] == true ? null : _start,
);

List<WorkoutSet> sets(Object? json) => [
  for (final (i, s) in ((json as List?) ?? []).cast<Json>().indexed) set(i, s),
];

SetTarget target(int offset, Json json) => SetTarget(
  setNumber: offset + 1,
  minReps: json['min'] as int?,
  maxReps: json['max'] as int?,
  rirTarget: json['rir'] as int?,
  setType: switch (json['type']) {
    final String type => SetTargetSetType.values.byName(type),
    _ => SetTargetSetType.standard,
  },
  amrapTargetReps: json['amrap'] as int?,
);

WeightUnit? _unit(Object? name) =>
    name == null ? null : WeightUnit.values.byName(name as String);

WeightRoundingRule rule(Json json) {
  final unit = _unit(json['unit']) ?? WeightUnit.kilograms;
  final stepJson = json['step'] as Json;
  var step = switch (stepJson['kind']) {
    'increment' => WeightStep(
      StepIncrement(
        _double(stepJson['step'])!,
        min: _double(stepJson['min'])!,
        max: _double(stepJson['max']),
      ),
    ),
    'list' => WeightStep(
      StepList([for (final w in stepJson['weights'] as List) _double(w)!]),
    ),
    'plates' => () {
      final sleeves = stepJson['sleeves'] as int;
      final plates = [
        for (final p in (stepJson['plates'] as List).cast<Json>())
          Plate(_double(p['weight'])!, perSleeve: p['perSleeve'] as int?),
      ];
      final bar = _double(stepJson['bar'])!;
      return WeightStep(
        StepIncrement(plates.first.weight * sleeves, min: bar),
        baseWeight: bar,
        plates: plates,
        sleeves: sleeves,
      );
    }(),
    _ => WeightStep.fallback(unit),
  };
  if (json['assisted'] == true) {
    step = step.assisted(bodyweightOnly: json['bodyweightOnly'] as bool);
  }
  return WeightRoundingRule(
    step: step,
    unit: unit,
    preferredUnit: _unit(json['preferredUnit']),
  );
}

ExerciseType? _type(Object? name) =>
    name == null ? null : ExerciseType.values.byName(name as String);

ProgressionRounding rounding(WeightRoundingRule rule) => ProgressionRounding(
  round: rule.round,
  minimumIncrementKg: rule.minimumIncrementKg,
);

Json suggestedJson(SuggestedSet s) => {
  'kg': ?s.weightKg,
  'reps': ?s.reps,
  'dur': ?s.durationSec,
  'dist': ?s.distanceMeters,
  'target': ?s.targetReps,
};

Object suggest(Json input) {
  final suggestion = ProgressionEngine.suggest(
    ProgressionInput(
      trackingMode: TrackingMode.values.byName(input['mode'] as String),
      setTargets: [
        for (final (i, t) in (input['targets'] as List).cast<Json>().indexed)
          target(i, t),
      ],
      history: [for (final session in input['history'] as List) sets(session)],
      adjustmentMode: ProgressionAdjustmentMode.values.byName(
        input['adjustment'] as String,
      ),
      rounding: rounding(rule(input['rule'] as Json)),
      amrap: input['amrap'] == true
          ? AmrapProgression(ceiling: input['amrapCeiling'] as int?)
          : null,
      exerciseType: _type(input['type']),
    ),
  );
  return {
    'rationale': suggestion.rationale.name,
    'sets': [for (final s in suggestion.sets) suggestedJson(s)],
  };
}

Object adjustRemaining(Json input) {
  final targetJson = input['target'] as Json?;
  return [
    for (final s in ProgressionEngine.adjustRemaining(
      completed: set(0, input['completed'] as Json),
      target: targetJson == null ? null : target(0, targetJson),
      remaining: sets(input['remaining']),
      mode: TrackingMode.values.byName(input['mode'] as String),
      rounding: rounding(rule(input['rule'] as Json)),
      exerciseType: _type(input['type']),
    ))
      if (s == null) null else suggestedJson(s),
  ];
}

Object roundingCase(Json input) {
  final weightRule = rule(input['rule'] as Json);
  final weights = [for (final w in input['weights'] as List) _double(w)!];
  return {
    'minimumIncrementKg': weightRule.minimumIncrementKg,
    'round': weights.map(weightRule.round).toList(),
    'deload': [
      for (final w in weights)
        MesocycleDeload.lighterWeight(w, weightRule.round),
    ],
  };
}

Object keptSets(Json input) => [
  for (final s in MesocycleDeload.keptSets(sets(input['sets'])))
    {'id': s.id, 'index': s.index},
];

void main() {
  final fixture =
      jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;
  final runners = <String, Object Function(Json)>{
    'suggest': suggest,
    'suggestMissing': suggest,
    'adjustRemaining': adjustRemaining,
    'rounding': roundingCase,
    'keptSets': keptSets,
  };

  group('progression-parity.json', () {
    for (final MapEntry(key: name, value: run) in runners.entries) {
      test('$name matches the Swift', () {
        final cases = (fixture[name] as List).cast<Json>();
        expect(cases, isNotEmpty);
        for (final (index, testCase) in cases.indexed) {
          final problem = mismatch(
            run(testCase['input'] as Json),
            testCase['expected'],
            '$name[$index]',
          );
          expect(problem, isNull, reason: jsonEncode(testCase['input']));
        }
      });
    }
  });

  test('mismatch reports differences', () {
    expect(mismatch(1, 1.0000000001, r'$'), isNull);
    expect(mismatch('a', 1, r'$'), isNotNull);
    expect(mismatch(2, 1, r'$'), isNotNull);
    expect(mismatch(1, [1], r'$'), isNotNull);
    expect(mismatch([2], [1], r'$'), isNotNull);
    expect(mismatch(1, {'a': 1}, r'$'), isNotNull);
    expect(mismatch({'a': 2}, {'a': 1}, r'$'), isNotNull);
    expect(mismatch('a', 'b', r'$'), isNotNull);
  });
}
