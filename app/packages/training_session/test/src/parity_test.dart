// The port against contracts/fixtures/tracker-parity.json, which
// TrackerParityTests.swift records from the Swift: every item of the
// contract's full gym resolved to a weight step in both units, and sessions
// built from a template over that gym.
import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

final Map<String, Object?> _fixture = jsonDecode(
  File('../../../contracts/fixtures/tracker-parity.json').readAsStringSync(),
) as Map<String, Object?>;

final m.GymProfileModel _gym = m.GymProfileModel.fromFirestore(
  m.taggedJsonToFirestore(
    jsonDecode(
      File('../../../contracts/firestore/gym_profile/full.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  ),
);

/// Equal JSON values, numbers within a millionth (as `CoachParityTests`).
bool _matches(Object? actual, Object? expected) => switch ((actual, expected)) {
  (final Map<String, Object?> a, final Map<String, Object?> e) =>
    a.length == e.length &&
        a.keys.every((key) => e.containsKey(key) && _matches(a[key], e[key])),
  (final List<Object?> a, final List<Object?> e) =>
    a.length == e.length &&
        [for (var i = 0; i < a.length; i++) i]
            .every((i) => _matches(a[i], e[i])),
  (final num a, final num e) =>
    (a - e).abs() <= 1e-6 * (e.abs() > 1 ? e.abs() : 1),
  _ => actual == expected,
};

/// Where [actual] first differs from [expected], for the failure message.
String? _difference(Object? actual, Object? expected, [String path = r'$']) {
  if (_matches(actual, expected)) return null;
  if (actual is Map<String, Object?> && expected is Map<String, Object?>) {
    for (final key in {...actual.keys, ...expected.keys}) {
      final found = _difference(actual[key], expected[key], '$path.$key');
      if (found != null) return found;
    }
  }
  if (actual is List<Object?> &&
      expected is List<Object?> &&
      actual.length == expected.length) {
    for (var i = 0; i < actual.length; i++) {
      final found = _difference(actual[i], expected[i], '$path[$i]');
      if (found != null) return found;
    }
  }
  return '$path: Dart ${jsonEncode(actual)}, Swift ${jsonEncode(expected)}';
}

Object? _step(Map<String, Object?> input) {
  final refs = [
    for (final ref in input['refs']! as List<Object?>)
      m.EquipmentRef.fromFirestore((ref! as Map).cast()),
  ];
  final unit = r.WeightUnit.values.byName(input['unit']! as String);
  final profile = input['gym'] == true ? _gym : null;
  var step = WeightStepper.steps(refs, profile, unit);
  if (input['assisted'] case final bool bodyweightOnly) {
    step = step.assisted(bodyweightOnly: bodyweightOnly);
  }
  final rule = r.WeightRoundingRule(
    step: step,
    unit: unit,
    preferredUnit: unit,
  );
  return {
    'kind': switch (step.kind) {
      r.StepIncrement(:final step, :final min, :final max) => {
        'increment': step,
        'min': min,
        'max': max,
      },
      r.StepList(:final weights) => {'list': weights},
      r.StepBands() => 'bands',
    },
    'baseWeight': step.baseWeight,
    'plates': [
      for (final plate in step.plates) [plate.weight, plate.perSleeve],
    ],
    'sleeves': step.sleeves,
    'isAssisted': step.isAssisted,
    'constrainsWeight': step.constrainsWeight,
    'bands': step.bands,
    'equipmentUnit': WeightStepper.equipmentUnit(refs, profile)?.value,
    'rounded': [
      for (final value in [-23.7, 0.0, 13.3, 61.3, 101.1, 187.9])
        rule.round(value),
    ],
  };
}

UnitPreference _preference(Map<String, Object?> json) => UnitPreference(
  weightUnit: m.ExerciseWeightUnit.values.byName(json['unit']! as String),
  weightUnitIsChosen: json['chosen']! as bool,
);

Map<String, Object?> _tagged(Object? json) =>
    m.taggedJsonToFirestore(json! as Map<String, Object?>);

Object? _session(Map<String, Object?> input) {
  final template = m.WorkoutTemplateModel.fromFirestore(
    _tagged(input['template']),
  );
  final previous = input['previous'] == null
      ? null
      : m.WorkoutSessionModel.fromFirestore(_tagged(input['previous']));
  final history = [
    for (final json in input['history']! as List<Object?>)
      m.WorkoutSessionModel.fromFirestore(_tagged(json)),
  ];
  final gym = input['gym'] == true ? _gym : null;
  final microcycle = input['microcycle'] as int?;
  final units = {
    for (final MapEntry(:key, :value)
        in ((input['units'] as Map<String, Object?>?) ?? {}).entries)
      key: _preference(value! as Map<String, Object?>),
  };
  final prefill = switch (input['prefill']) {
    'empty' => const r.PrefillEmpty() as r.SessionPrefill,
    'suggestions' => r.PrefillSuggestions(
      r.ProgressionPlanner.suggestions(
        contexts: [
          for (final (index, load) in sessionLoads(
            template,
            previous: previous,
            gym: gym,
            unitPreferences: units,
          ).indexed)
            templateContext(
              weekOf(template, microcycle).exercises[index],
              gym: gym,
              load: load,
              occurrence: template.exercises
                  .take(index)
                  .where(
                    (e) =>
                        e.exercise.id == template.exercises[index].exercise.id,
                  )
                  .length,
            ),
        ],
        history: history.map(rulesSession).toList(),
        adjustmentMode: r.ProgressionAdjustmentMode.weightFirst,
        amrap: const r.AmrapProgression(ceiling: 12),
      ),
    ),
    _ => const r.PrefillPreviousValues(),
  };
  final built = sessionFromTemplate(
    authorId: 'parity',
    template: template,
    now: DateTime.utc(2026, 10, 2, 8),
    id: 'built',
    microcycleIndex: microcycle,
    previousSession: previous,
    gym: gym,
    unitPreferences: units,
    prefill: prefill,
    plansSets: input['plansSets']! as bool,
  );
  return _normalised(m.firestoreToTaggedJson(built.toFirestore()));
}

/// As `TrackerParityTests.normalised`: random ids made positional, each
/// set's creation time left out.
Map<String, Object?> _normalised(Map<String, Object?> session) {
  final ids = <String, String>{};
  return {
    ...session,
    'exercises': [
      for (final (e, exercise)
          in (session['exercises']! as List<Object?>).indexed)
        () {
          final json = exercise! as Map<String, Object?>;
          final sets = json['sets']! as List<Object?>;
          for (final (s, set) in sets.indexed) {
            ids[(set! as Map)['id']! as String] = 'e${e + 1}s${s + 1}';
          }
          return {
            ...json,
            'id': 'e${e + 1}',
            'sets': [
              for (final set in sets)
                {
                  for (final MapEntry(:key, :value)
                      in (set! as Map<String, Object?>).entries)
                    if (key != 'date_created')
                      key: switch (key) {
                        'id' || 'parent_set_id' => ids[value]!,
                        _ => value,
                      },
                },
            ],
          };
        }(),
    ],
  };
}

void main() {
  group('WeightStepper matches the Swift', () {
    final cases = _fixture['weightSteps']! as List<Object?>;
    test('over ${cases.length} cases', () {
      expect(cases.length, greaterThan(100));
      for (final (index, testCase) in cases.indexed) {
        final json = testCase! as Map<String, Object?>;
        final actual = _step(json['input']! as Map<String, Object?>);
        expect(
          _matches(actual, json['expected']),
          isTrue,
          reason:
              'weightSteps[$index] ${jsonEncode(json['input'])}: Dart gives '
              '${jsonEncode(actual)}, Swift ${jsonEncode(json['expected'])}',
        );
      }
    });
  });

  group('sessionFromTemplate matches the Swift', () {
    final cases = _fixture['sessions']! as List<Object?>;
    for (final (index, testCase) in cases.indexed) {
      test('case $index', () {
        final json = testCase! as Map<String, Object?>;
        final input = json['input']! as Map<String, Object?>;
        final actual = _session(input);
        expect(
          _matches(actual, json['expected']),
          isTrue,
          reason: _difference(actual, json['expected']),
        );
      });
    }
  });
}
