import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

/// A recorded `coachChat` stream: its chunks and result
/// (test/fixtures/coach/).
Map<String, Object?> _stream(String name) =>
    jsonDecode(File('test/fixtures/coach/$name').readAsStringSync())
        as Map<String, Object?>;

/// Every block of a recorded stream, in order.
List<CoachBlock> _blocks(String name) => [
  for (final chunk in _stream(name)['chunks']! as List<Object?>)
    if ((chunk! as Map<String, Object?>)['block']
        case final Map<String, Object?> block)
      // As the chat stores it: the chunk's asOf is as_of there.
      CoachBlock.fromFirestore({...block, 'as_of': block['asOf']}),
];

const Map<String, Object?> _create = {
  'version': 'v0.9',
  'createSurface': {'surfaceId': 's', 'catalogId': coachCatalogId},
};

Map<String, Object?> _components(List<Object?> components) => {
  'version': 'v0.9',
  'updateComponents': {'surfaceId': 's', 'components': components},
};

Map<String, Object?> _data(Object? value, {String path = '/'}) => {
  'version': 'v0.9',
  'updateDataModel': {'surfaceId': 's', 'path': path, 'value': value},
};

/// A block whose root is [component] with [props], over [data].
CoachBlock _block(
  String component,
  Map<String, Object?> props,
  Object? data, {
  Map<String, Object?> create = _create,
}) => CoachBlock(
  surfaceId: 's',
  kind: 'k',
  asOf: '2026-10-19',
  fallback: 'In words.',
  messages: [
    create,
    _components([
      {'id': 'root', 'component': component, ...props},
    ]),
    _data(data),
  ],
);

void main() {
  group('A2uiMessage', () {
    test('reads the four messages', () {
      expect(
        A2uiMessage.parse(_create),
        isA<A2uiCreateSurface>()
            .having((m) => m.surfaceId, 'surfaceId', 's')
            .having((m) => m.catalogId, 'catalogId', coachCatalogId),
      );
      expect(
        A2uiMessage.parse(
          _components([
            {'id': 'root', 'component': 'StatRow', 'stats': 1},
          ]),
        ),
        isA<A2uiUpdateComponents>().having(
          (m) => m.components.single.props,
          'props',
          {'stats': 1},
        ),
      );
      expect(
        A2uiMessage.parse(_data(3, path: '/a')),
        isA<A2uiUpdateDataModel>()
            .having((m) => m.path, 'path', '/a')
            .having((m) => m.value, 'value', 3),
      );
      expect(
        A2uiMessage.parse({
          'version': 'v0.9',
          'deleteSurface': {'surfaceId': 's'},
        }),
        isA<A2uiDeleteSurface>(),
      );
    });

    test('refuses another version, an unknown message or a bad one', () {
      for (final json in <Object?>[
        null,
        'createSurface',
        {..._create, 'version': 'v0.8'},
        {'version': 'v0.9', 'beginRendering': <String, Object?>{}},
        {
          'version': 'v0.9',
          'createSurface': {'surfaceId': 's'},
        },
        _components([
          {'id': 'root'},
        ]),
      ]) {
        expect(() => A2uiMessage.parse(json), throwsFormatException);
      }
    });
  });

  group('A2uiSurface', () {
    A2uiSurface surface(List<Object?> messages) =>
        A2uiSurface.fromMessages([_create, ...messages]);

    test('applies components by id, and data by path', () {
      final built = surface([
        _components([
          {'id': 'root', 'component': 'A'},
          {'id': 'other', 'component': 'B'},
        ]),
        _components([
          {'id': 'root', 'component': 'C'},
        ]),
        _data({
          'a': {'b': 1},
        }),
        _data(2, path: '/a/c'),
        _data(3, path: '/d/e'),
        _data(4, path: '/a/b/f'),
      ]);

      expect(built.surfaceId, 's');
      expect(built.catalogId, coachCatalogId);
      expect(built.root?.component, 'C');
      expect(built.components['other']?.component, 'B');
      expect(built.read('/'), {
        'a': {
          'b': {'f': 4},
          'c': 2,
        },
        'd': {'e': 3},
      });
    });

    test('reads JSON pointers', () {
      final built = surface([
        _data({
          'list': [10, 20],
          'a/b': 'slash',
          'm~n': 'tilde',
          'n': 5,
        }),
      ]);

      expect(built.read('/list/1'), 20);
      expect(built.read('/list/2'), isNull);
      expect(built.read('/list/-1'), isNull);
      expect(built.read('/list/x'), isNull);
      expect(built.read('/a~1b'), 'slash');
      expect(built.read('/m~0n'), 'tilde');
      expect(built.read('/n/deeper'), isNull);
      expect(built.read('/missing'), isNull);
      expect(built.read('n'), 5);
    });

    test('resolves bindings, and passes literals through', () {
      final built = surface([
        _data({'v': 1}),
      ]);

      expect(built.resolve({'path': '/v'}), 1);
      expect(built.resolve('weight'), 'weight');
      expect(built.resolve({'path': '/v', 'other': 1}), {
        'path': '/v',
        'other': 1,
      });
    });

    test('has no root before its components', () {
      expect(surface([]).root, isNull);
    });

    test('refuses a sequence that does not build one surface', () {
      final delete = {
        'version': 'v0.9',
        'deleteSurface': {'surfaceId': 's'},
      };
      final elsewhere = {
        'version': 'v0.9',
        'deleteSurface': {'surfaceId': 'elsewhere'},
      };
      for (final messages in [
        <Object?>[],
        [_data(1)],
        [_create, _create],
        [_create, delete],
        [_create, elsewhere],
      ]) {
        expect(() => A2uiSurface.fromMessages(messages), throwsFormatException);
      }
    });
  });

  group('CoachComponent', () {
    test('reads every block of the recorded weight stream', () {
      final [chart, stats, actions, followUps] = [
        for (final block in _blocks('weight_stream.json'))
          CoachComponent.of(block),
      ];

      chart as CoachTrendChart?;
      expect(chart!.metric, CoachTrendMetric.weight);
      expect(chart.unit, CoachUnit.kg);
      expect(chart.points, hasLength(38));
      expect(chart.points.first, (x: DateTime(2026, 8, 25), y: 73.0));
      expect(chart.trend?.last, (x: DateTime(2026, 10, 19), y: 72.3));
      expect(chart.exerciseName, isNull);

      expect((stats! as CoachStatRow).stats, [
        (
          key: CoachStatKey.weightTrend,
          exerciseId: null,
          value: 72.3,
          unit: CoachUnit.kg,
          exerciseName: null,
        ),
        (
          key: CoachStatKey.weightRatePerWeek,
          exerciseId: null,
          value: -0.1,
          unit: CoachUnit.kgPerWeek,
          exerciseName: null,
        ),
        (
          key: CoachStatKey.expenditure,
          exerciseId: null,
          value: 2290.0,
          unit: CoachUnit.kcal,
          exerciseName: null,
        ),
      ]);

      expect((actions! as CoachActions).actions, [
        (
          kind: CoachActionKind.logWeight,
          exerciseId: null,
          exerciseName: null,
          metric: null,
        ),
        (
          kind: CoachActionKind.openMetric,
          exerciseId: null,
          exerciseName: null,
          metric: CoachMetric.weight,
        ),
      ]);

      expect((followUps! as CoachFollowUps).questions, [
        'How much should I eat to lose faster?',
        'Is my protein high enough?',
      ]);
    });

    test('reads every block of the recorded nutrition stream', () {
      final [bars, chart, actions, stats] = [
        for (final block in _blocks('nutrition_stream.json'))
          CoachComponent.of(block),
      ];

      bars as CoachTargetBars?;
      expect(bars!.day, DateTime(2026, 10, 19));
      expect(bars.rows.first, (
        nutrient: CoachNutrient.calories,
        value: 1640.0,
        target: 2200.0,
        unit: CoachUnit.kcal,
      ));
      expect(bars.rows.last.value, isNull);
      expect(bars.rows.last.target, isNull);
      expect(bars.rows.map((row) => row.nutrient), CoachNutrient.values);

      chart as CoachTrendChart?;
      expect(chart!.metric, CoachTrendMetric.exerciseE1rm);
      expect(chart.points.last.y, 101.6);
      expect(chart.exerciseName, 'Barbell Bench Press');
      expect(chart.trend, isNull);

      expect((actions! as CoachActions).actions.map((action) => action.kind), [
        CoachActionKind.logMeal,
        CoachActionKind.openExercise,
        CoachActionKind.startWorkout,
      ]);
      expect(
        (actions as CoachActions).actions[1].exerciseId,
        'barbell-bench-press',
      );

      final [_, protein, e1rm] = (stats! as CoachStatRow).stats;
      expect(protein.value, isNull);
      expect(e1rm.key, CoachStatKey.exerciseE1rm);
      expect(e1rm.exerciseId, 'barbell-bench-press');
      expect(e1rm.exerciseName, 'Barbell Bench Press');
    });

    test("reads a target bars' today and absent day as today", () {
      for (final day in ['today', null]) {
        final bars = CoachComponent.of(
          _block(
            'TargetBars',
            {
              'rows': {'path': '/rows'},
              'day': {'path': '/day'},
            },
            {'rows': <Object?>[], 'day': day},
          ),
        );
        bars as CoachTargetBars?;
        expect(bars!.day, isNull);
        expect(bars.rows, isEmpty);
      }
    });

    test('reads an empty trend as none', () {
      final chart = CoachComponent.of(
        _block(
          'TrendChart',
          {
            'metric': 'steps',
            'points': {'path': '/points'},
            'trend': {'path': '/trend'},
            'unit': 'steps',
          },
          {
            'points': [
              {'x': '2026-10-19', 'y': 8420},
            ],
            'trend': <Object?>[],
          },
        ),
      );
      expect((chart! as CoachTrendChart).trend, isNull);
    });

    test('reads every value of the enums', () {
      for (final values in <List<FirestoreEnum>>[
        CoachTrendMetric.values,
        CoachUnit.values,
        CoachNutrient.values,
        CoachStatKey.values,
        CoachActionKind.values,
        CoachMetric.values,
      ]) {
        for (final value in values) {
          expect(enumFromValue(values, value.value), value);
        }
      }
    });

    group('is null, for the fallback, for', () {
      final stats = {
        'stats': {'path': '/stats'},
      };
      final actions = {
        'actions': {'path': '/actions'},
      };
      final chart = {
        'metric': 'weight',
        'points': {'path': '/points'},
        'unit': 'kg',
      };
      final rows = {
        'rows': {'path': '/rows'},
      };
      final cases = <String, CoachBlock>{
        'an invalid message': const CoachBlock(
          surfaceId: 's',
          kind: 'k',
          asOf: '2026-10-19',
          fallback: 'f',
          messages: [
            {'version': 'v0.9'},
          ],
        ),
        'another catalog': _block(
          'StatRow',
          stats,
          {'stats': <Object?>[]},
          create: {
            'version': 'v0.9',
            'createSurface': {'surfaceId': 's', 'catalogId': 'other.v1'},
          },
        ),
        'messages emptied to fit the chat': const CoachBlock(
          surfaceId: 's',
          kind: 'k',
          asOf: '2026-10-19',
          fallback: 'f',
          messages: [],
        ),
        'no root': const CoachBlock(
          surfaceId: 's',
          kind: 'k',
          asOf: '2026-10-19',
          fallback: 'f',
          messages: [_create],
        ),
        'an unknown component': _block('Map', {}, null),
        'missing data': _block('StatRow', stats, null),
        'an unknown unit': _block(
          'TrendChart',
          {...chart, 'unit': 'st'},
          {'points': <Object?>[]},
        ),
        'a point without a value': _block('TrendChart', chart, {
          'points': [
            {'x': '2026-10-19'},
          ],
        }),
        'a bad date': _block('TrendChart', chart, {
          'points': [
            {'x': 'yesterday', 'y': 1},
          ],
        }),
        'a row without its value': _block('TargetBars', rows, {
          'rows': [
            {'nutrient': 'fat', 'unit': 'g'},
          ],
        }),
        'a stat without a unit': _block('StatRow', stats, {
          'stats': [
            {'key': 'goal_weight', 'value': 1},
          ],
        }),
        'an e1RM without its exercise': _block('StatRow', stats, {
          'stats': [
            {'key': 'exercise_e1rm', 'value': 1, 'unit': 'kg'},
          ],
        }),
        'an exercise on another stat': _block('StatRow', stats, {
          'stats': [
            {'key': 'goal_weight:x', 'value': 1, 'unit': 'kg'},
          ],
        }),
        'an action without a kind': _block('Actions', actions, {
          'actions': [<String, Object?>{}],
        }),
        'an exercise without its id': _block('Actions', actions, {
          'actions': [
            {'kind': 'open_exercise'},
          ],
        }),
        'a metric without its metric': _block('Actions', actions, {
          'actions': [
            {'kind': 'open_metric', 'metric': 'sleep'},
          ],
        }),
        'a question that is not text': _block(
          'FollowUps',
          {
            'questions': {'path': '/questions'},
          },
          {
            'questions': [1],
          },
        ),
      };
      for (final MapEntry(key: name, value: block) in cases.entries) {
        test(name, () => expect(CoachComponent.of(block), isNull));
      }
    });
  });
}
