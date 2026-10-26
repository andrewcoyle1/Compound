// Its goldens load alchemist's fonts, which would stay loaded for every
// test after it in very_good's single optimised run and change their text
// metrics, so this file runs in an isolate of its own.
@Tags(['skip_very_good_optimization'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/check_in/check_in.dart';
import 'package:compound/coach/view/coach_message_body.dart';
import 'package:compound/coach/view/coach_surface.dart';
import 'package:compound/expenditure_metric/expenditure_metric.dart';
import 'package:compound/goal_editing/goal_editing_routes.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/progress/view/progress_metric_pages.dart';
import 'package:compound/training_library/view/exercise_detail_page.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/golden.dart';
import '../../helpers/helpers.dart';

class _MockActiveWorkoutCubit extends MockCubit<ActiveWorkoutState>
    implements ActiveWorkoutCubit;

/// Every block of a recorded `coachChat` stream (compound_models'
/// test/fixtures/coach/), as the chat stores it.
List<CoachBlock> _recorded(String name) {
  final stream = jsonDecode(
    File('packages/compound_models/test/fixtures/coach/$name')
        .readAsStringSync(),
  ) as Map<String, Object?>;
  return [
    for (final chunk in stream['chunks']! as List<Object?>)
      if ((chunk! as Map<String, Object?>)['block']
          case final Map<String, Object?> block)
        CoachBlock.fromFirestore({...block, 'as_of': block['asOf']}),
  ];
}

final List<CoachBlock> _weight = _recorded('weight_stream.json');
final List<CoachBlock> _nutrition = _recorded('nutrition_stream.json');

CoachBlock _kind(List<CoachBlock> blocks, String kind) =>
    blocks.firstWhere((block) => block.kind == kind);

final CoachBlock _weightChart = _kind(_weight, 'trend_chart');
final CoachBlock _weightStats = _kind(_weight, 'stat_row');
final CoachBlock _weightActions = _kind(_weight, 'actions');
final CoachBlock _followUps = _kind(_weight, 'follow_ups');
final CoachBlock _targetBars = _kind(_nutrition, 'target_bars');
final CoachBlock _oneRepMax = _kind(_nutrition, 'trend_chart');
final CoachBlock _nutritionActions = _kind(_nutrition, 'actions');
final CoachBlock _nutritionStats = _kind(_nutrition, 'stat_row');

/// A block built by hand: [component] as the root over [data].
CoachBlock _block(
  String kind,
  Map<String, Object?> component,
  Map<String, Object?> data, {
  String fallback = 'In words.',
}) => CoachBlock(
  surfaceId: 's',
  kind: kind,
  asOf: '2026-10-19',
  fallback: fallback,
  messages: [
    {
      'version': 'v0.9',
      'createSurface': {'surfaceId': 's', 'catalogId': 'compound.coach.v1'},
    },
    {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': 's',
        'components': [
          {'id': 'root', ...component},
        ],
      },
    },
    {
      'version': 'v0.9',
      'updateDataModel': {'surfaceId': 's', 'path': '/', 'value': data},
    },
  ],
);

final CoachBlock _steps = _block(
  'trend_chart',
  {
    'component': 'TrendChart',
    'metric': 'steps',
    'points': {'path': '/points'},
    'unit': {'path': '/unit'},
  },
  {
    'points': [
      for (var day = 13; day <= 19; day++)
        {'x': '2026-10-$day', 'y': 6000 + day * 150 % 2400},
    ],
    'unit': 'steps',
  },
  fallback: 'Steps, 2026-10-13 to 2026-10-19: 8,420 steps a day on average.',
);

final CoachBlock _expenditure = stagingCoachBlocks(
  CoachContextKind.expenditure,
  messageId: 'm',
  now: DateTime(2026, 10, 19),
).single;

final CoachBlock _poundStats = _block(
  'stat_row',
  {
    'component': 'StatRow',
    'stats': {'path': '/stats'},
  },
  {
    'stats': [
      {'key': 'goal_weight', 'value': 160, 'unit': 'lb'},
      {'key': 'weight_rate_per_week', 'value': -0.5, 'unit': 'lb_per_week'},
      {'key': 'exercise_e1rm:squat', 'value': 225, 'unit': 'lb'},
    ],
  },
);

final CoachBlock _morePoundStats = _block(
  'stat_row',
  {
    'component': 'StatRow',
    'stats': {'path': '/stats'},
  },
  {
    'stats': [
      {'key': 'calorie_target', 'value': 2200, 'unit': 'kcal'},
      {'key': 'today_calories', 'value': 1640, 'unit': 'kcal'},
      {'key': 'steps_average', 'value': 8420, 'unit': 'steps'},
    ],
  },
);

final CoachBlock _metricActions = _block(
  'actions',
  {
    'component': 'Actions',
    'actions': {'path': '/actions'},
  },
  {
    'actions': [
      {'kind': 'open_metric', 'metric': 'expenditure'},
      {'kind': 'open_metric', 'metric': 'steps'},
      {'kind': 'open_check_in'},
      {'kind': 'open_diet_plan'},
      {'kind': 'open_exercise', 'exerciseId': 'squat'},
    ],
  },
);

final CoachBlock _broken = _block(
  'map',
  {'component': 'Map'},
  {},
  fallback: 'Your runs this month, on a map.',
);

void main() {
  var followUps = <String>[];

  setUp(() => followUps = []);

  Widget surface(CoachBlock block, {bool saved = false}) =>
      CoachSurface(block: block, saved: saved, onFollowUp: followUps.add);

  Future<void> pump(
    WidgetTester tester,
    CoachBlock block, {
    bool saved = false,
  }) => tester.pumpApp(
    // On a screen, as in the chat.
    AppScaffold(
      body: SingleChildScrollView(child: surface(block, saved: saved)),
    ),
  );

  group('draws', () {
    testWidgets('a weight trend: dots under the trend line, the latest '
        'trend, in kilograms', (tester) async {
      await pump(tester, _weightChart);

      expect(find.text('WEIGHT'), findsOneWidget);
      expect(find.text('72.3 KG'), findsOneWidget);
      final data = tester
          .widget<CartesianChart>(find.byType(CartesianChart))
          .data;
      expect(data.series.map((s) => s.mark), [ChartMark.dot, ChartMark.line]);
      expect(data.series.first.points, hasLength(38));
      expect(data.start, DateTime(2026, 8, 25));
      expect(data.end, DateTime(2026, 10, 20));
      expect(data.yFit, ChartYFit.tight);
    });

    testWidgets("an exercise's estimated 1RM as a line", (tester) async {
      await pump(tester, _oneRepMax);

      expect(find.text('BARBELL BENCH PRESS ESTIMATED 1RM'), findsOneWidget);
      expect(find.text('101.6 KG'), findsOneWidget);
      final data = tester
          .widget<CartesianChart>(find.byType(CartesianChart))
          .data;
      expect(data.series.single.mark, ChartMark.line);
    });

    testWidgets('steps as bars from zero, and expenditure', (tester) async {
      await pump(tester, _steps);
      expect(find.text('STEPS'), findsOneWidget);
      final data = tester
          .widget<CartesianChart>(find.byType(CartesianChart))
          .data;
      expect(data.series.single.mark, ChartMark.bar);
      expect(data.yFit, ChartYFit.zero);

      await pump(tester, _expenditure);
      expect(find.text('EXPENDITURE'), findsOneWidget);
      expect(find.textContaining('KCAL'), findsOneWidget);
    });

    testWidgets('an e1RM chart without its exercise, and with no points', (
      tester,
    ) async {
      await pump(
        tester,
        _block(
          'trend_chart',
          {
            'component': 'TrendChart',
            'metric': 'exercise_e1rm',
            'points': {'path': '/points'},
            'unit': 'lb',
          },
          {'points': <Object?>[]},
        ),
      );

      expect(find.text('ESTIMATED 1RM'), findsOneWidget);
      expect(find.text(AppFormat.placeholder), findsOneWidget);
      expect(find.byType(CartesianChart), findsOneWidget);
    });

    testWidgets("a day's targets: eaten against each, in its colour", (
      tester,
    ) async {
      await pump(tester, _targetBars);

      expect(find.textContaining(RegExp(r'^MON, OCT.19$')), findsOneWidget);
      expect(find.text('Cals'), findsOneWidget);
      expect(find.text('1,640 / 2,200 kcal'), findsOneWidget);
      expect(find.text('98 / 160 g'), findsOneWidget);
      // Fat: no value, no target.
      expect(find.text(AppFormat.placeholder), findsOneWidget);
      final bars = tester.widgetList<BulletBar>(find.byType(BulletBar));
      expect(bars.map((bar) => bar.color), [
        AppColors.light.calories,
        AppColors.light.protein,
        AppColors.light.carbs,
        AppColors.light.fat,
      ]);
      expect(bars.first.target, 2200);
      expect(bars.first.over, isFalse);
    });

    testWidgets('a row over its target, with no target, and no day', (
      tester,
    ) async {
      await pump(
        tester,
        _block(
          'target_bars',
          {
            'component': 'TargetBars',
            'rows': {'path': '/rows'},
          },
          {
            'rows': [
              {'nutrient': 'protein', 'value': 190, 'target': 160, 'unit': 'g'},
              {'nutrient': 'carbs', 'value': 120, 'target': null, 'unit': 'g'},
              {'nutrient': 'fat', 'value': null, 'target': 70, 'unit': 'g'},
            ],
          },
        ),
      );

      // The day it was read stands in for "today".
      expect(find.textContaining(RegExp(r'^MON, OCT.19$')), findsOneWidget);
      final bars = tester
          .widgetList<BulletBar>(find.byType(BulletBar))
          .toList();
      expect(bars[0].over, isTrue);
      expect(bars[1].target, isNull);
      expect(find.text('120 g'), findsOneWidget);
      expect(find.text('— / 70 g'), findsOneWidget);
    });

    testWidgets('figures with their labels, and none as the placeholder', (
      tester,
    ) async {
      await pump(tester, _weightStats);
      expect(find.text('TREND WEIGHT'), findsOneWidget);
      expect(find.text('72.3 KG'), findsOneWidget);
      expect(find.text('WEEKLY CHANGE'), findsOneWidget);
      expect(find.text('-0.1 KG A WEEK'), findsOneWidget);
      expect(find.text('2,290 KCAL'), findsOneWidget);

      await pump(tester, _nutritionStats);
      expect(find.text('PROTEIN TARGET'), findsOneWidget);
      expect(find.text('160 G'), findsOneWidget);
      expect(find.text('PROTEIN TODAY'), findsOneWidget);
      expect(find.text(AppFormat.placeholder), findsOneWidget);
      expect(find.text('BARBELL BENCH PRESS 1RM'), findsOneWidget);

      await pump(tester, _poundStats);
      expect(find.text('GOAL WEIGHT'), findsOneWidget);
      expect(find.text('160 LB'), findsOneWidget);
      expect(find.text('-0.5 LB A WEEK'), findsOneWidget);
      expect(find.text('ESTIMATED 1RM'), findsOneWidget);

      await pump(tester, _morePoundStats);
      expect(find.text('CALORIE TARGET'), findsOneWidget);
      expect(find.text('CALORIES TODAY'), findsOneWidget);
      expect(find.text('AVERAGE STEPS'), findsOneWidget);
      expect(find.text('8,420 STEPS'), findsOneWidget);
    });

    testWidgets('the fallback for a block it cannot draw', (tester) async {
      await pump(tester, _broken);

      expect(find.text('Your runs this month, on a map.'), findsOneWidget);
    });
  });

  group('screen readers', () {
    testWidgets('hear the fallback in place of a chart', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, _weightChart);

      expect(
        tester.getSemantics(find.byType(CoachSurface)),
        matchesSemantics(label: _weightChart.fallback),
      );
      handle.dispose();
    });

    testWidgets('hear the fallback, then the buttons of actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, _weightActions);

      expect(find.bySemanticsLabel(_weightActions.fallback), findsOneWidget);
      expect(find.bySemanticsLabel('Log Weight'), findsOneWidget);
      handle.dispose();
    });
  });

  group('as of', () {
    testWidgets('a saved block says the day it was read', (tester) async {
      await pump(tester, _weightStats, saved: true);
      expect(find.text('As of Oct 19, 2026'), findsOneWidget);
    });

    testWidgets('the live reply does not', (tester) async {
      await pump(tester, _weightStats);
      expect(find.textContaining('As of'), findsNothing);
    });
  });

  testWidgets('a follow-up sends its question', (tester) async {
    await pump(tester, _followUps);
    expect(find.text('ASK NEXT'), findsOneWidget);

    await tester.tap(find.text('Is my protein high enough?'));

    expect(followUps, ['Is my protein high enough?']);
  });

  group('actions open', () {
    late ActiveWorkoutCubit workout;

    setUp(() {
      workout = _MockActiveWorkoutCubit();
      when(() => workout.state).thenReturn(const ActiveWorkoutState());
      when(() => workout.start(eventPrefix: any(named: 'eventPrefix')))
          .thenAnswer((_) async {});
    });

    /// Taps [label] on [block] and returns where it landed.
    Future<String> open(
      WidgetTester tester,
      CoachBlock block,
      String label,
    ) async {
      GoRoute screen(String path, String name) => GoRoute(
        path: path,
        name: name,
        builder: (_, _) => Text('screen:$name'),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => SingleChildScrollView(child: surface(block)),
          ),
          screen(LogWeightPage.path, LogWeightPage.name),
          screen(AddMealPage.path, AddMealPage.name),
          screen(CheckInPage.path, CheckInPage.name),
          screen(DietPlanRoute.path, DietPlanRoute.name),
          screen(WorkoutTrackerPage.path, WorkoutTrackerPage.name),
          screen(
            '/exercises/:${ExerciseDetailPage.idParameter}',
            ExerciseDetailPage.name,
          ),
          screen('/weight-trend', WeightMetric.weightTrend.name),
          screen('/expenditure', ExpenditureMetric.expenditure.name),
          screen('/steps', StepsPage.name),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpApp(
        const SizedBox.shrink(),
        router: router,
        activeWorkoutCubit: workout,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final landed = find.textContaining('screen:');
      return (tester.widget<Text>(landed).data!).substring(7) +
          (router.state.pathParameters.isEmpty
              ? ''
              : ' ${router.state.pathParameters.values.single}');
    }

    for (final (block, label, landed) in [
      (_weightActions, 'Log Weight', LogWeightPage.name),
      (_weightActions, 'View Weight Trend', WeightMetric.weightTrend.name),
      (_nutritionActions, 'Log Meal', AddMealPage.name),
      (
        _nutritionActions,
        'View Barbell Bench Press',
        '${ExerciseDetailPage.name} barbell-bench-press',
      ),
      (_nutritionActions, 'Start Workout', WorkoutTrackerPage.name),
      (_metricActions, 'View Expenditure', ExpenditureMetric.expenditure.name),
      (_metricActions, 'View Steps', StepsPage.name),
      (_metricActions, 'Open Check-In', CheckInPage.name),
      (_metricActions, 'Open Diet Plan', DietPlanRoute.name),
      (_metricActions, 'View Exercise', '${ExerciseDetailPage.name} squat'),
    ]) {
      testWidgets('$label: $landed', (tester) async {
        expect(await open(tester, block, label), landed);
      });
    }

    testWidgets('Start Workout starts one from the coach', (tester) async {
      await open(tester, _nutritionActions, 'Start Workout');
      verify(() => workout.start(eventPrefix: 'CoachView_Action')).called(1);
    });
  });

  testWidgets('a message sets its markdown, then its blocks in order', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    // A Material, as the conversation's screen gives it: the long press
    // draws its pressed state on one.
    await tester.pumpApp(
      Material(
        child: SingleChildScrollView(
          child: CoachMessageBody(
            role: CoachMessageRole.assistant,
            text: 'About **0.1 kg a week**.',
            blocks: _weight,
            saved: true,
            onFollowUp: followUps.add,
          ),
        ),
      ),
    );

    expect(find.byType(AppMarkdownText), findsOneWidget);
    expect(
      find.bySemanticsLabel('Coach: About 0.1 kg a week.'),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<CoachSurface>(find.byType(CoachSurface))
          .map((surface) => (surface.block.kind, surface.saved)),
      [
        ('trend_chart', true),
        ('stat_row', true),
        ('actions', true),
        ('follow_ups', true),
      ],
    );
    handle.dispose();
  });

  group('CoachSurface golden', () {
    goldenStates('coach_surface', [
      ('Weight trend', surface(_weightChart)),
      ('Estimated 1RM, saved', surface(_oneRepMax, saved: true)),
      ('Steps', surface(_steps)),
      ('Target bars', surface(_targetBars)),
      ('Stat row', surface(_weightStats)),
      ('Stat row, none', surface(_nutritionStats)),
      ('Actions', surface(_nutritionActions)),
      ('Follow-ups', surface(_followUps)),
      ('Fallback', surface(_broken)),
    ]);
  });
}
