/// The coach's block catalog, `compound.coach.v1`: what each component
/// shows, read from an [A2uiSurface] into typed values. Every number is
/// the server's, from its tools; the app formats and labels them.
library;

import 'package:compound_models/src/a2ui.dart';
import 'package:compound_models/src/coach_chat.dart';
import 'package:compound_models/src/firestore_enum.dart';

/// The catalog the app draws.
const coachCatalogId = 'compound.coach.v1';

/// What a [CoachTrendChart] plots.
enum CoachTrendMetric implements FirestoreEnum {
  /// Body weight.
  weight('weight'),

  /// An exercise's estimated one-rep max.
  exerciseE1rm('exercise_e1rm'),

  /// Daily expenditure.
  expenditure('expenditure'),

  /// Daily steps.
  steps('steps');

  new(this.value);

  @override
  final String value;
}

/// The unit a value is in. Weights are in the unit named, already
/// converted.
enum CoachUnit implements FirestoreEnum {
  /// Kilograms.
  kg('kg'),

  /// Pounds.
  lb('lb'),

  /// Kilograms a week.
  kgPerWeek('kg_per_week'),

  /// Pounds a week.
  lbPerWeek('lb_per_week'),

  /// Kilocalories.
  kcal('kcal'),

  /// Grams.
  g('g'),

  /// Steps.
  steps('steps');

  new(this.value);

  @override
  final String value;
}

/// A nutrient a [CoachTargetBars] row measures.
enum CoachNutrient implements FirestoreEnum {
  /// Energy.
  calories('calories'),

  /// Protein.
  protein('protein'),

  /// Carbohydrate.
  carbs('carbs'),

  /// Fat.
  fat('fat');

  new(this.value);

  @override
  final String value;
}

/// A figure a [CoachStatRow] shows.
enum CoachStatKey implements FirestoreEnum {
  /// The trend weight.
  weightTrend('weight_trend'),

  /// The trend's change a week.
  weightRatePerWeek('weight_rate_per_week'),

  /// The goal's target weight.
  goalWeight('goal_weight'),

  /// Estimated expenditure.
  expenditure('expenditure'),

  /// The calorie target.
  calorieTarget('calorie_target'),

  /// The protein target.
  proteinTarget('protein_target'),

  /// Calories eaten today.
  todayCalories('today_calories'),

  /// Protein eaten today.
  todayProtein('today_protein'),

  /// Average daily steps.
  stepsAverage('steps_average'),

  /// An exercise's estimated one-rep max: `exercise_e1rm:<exerciseId>`.
  exerciseE1rm('exercise_e1rm');

  new(this.value);

  @override
  final String value;
}

/// What a [CoachAction] does. Actions show and navigate; none writes.
enum CoachActionKind implements FirestoreEnum {
  /// Opens Log Weight.
  logWeight('log_weight'),

  /// Opens Log Meal.
  logMeal('log_meal'),

  /// Starts an empty workout.
  startWorkout('start_workout'),

  /// Opens an exercise.
  openExercise('open_exercise'),

  /// Opens a metric's detail.
  openMetric('open_metric'),

  /// Opens the weekly check-in.
  openCheckIn('open_check_in'),

  /// Opens the diet plan.
  openDietPlan('open_diet_plan');

  new(this.value);

  @override
  final String value;
}

/// A metric an [CoachActionKind.openMetric] action opens.
enum CoachMetric implements FirestoreEnum {
  /// Weight trend.
  weight('weight'),

  /// Expenditure.
  expenditure('expenditure'),

  /// Steps.
  steps('steps');

  new(this.value);

  @override
  final String value;
}

/// One reading on a [CoachTrendChart].
typedef CoachPoint = ({DateTime x, double y});

/// One row of a [CoachTargetBars].
typedef CoachTargetRow = ({
  CoachNutrient nutrient,
  double? value,
  double? target,
  CoachUnit unit,
});

/// One figure of a [CoachStatRow]; a null `value` is one the tools did not
/// have.
typedef CoachStat = ({
  CoachStatKey key,
  String? exerciseId,
  double? value,
  CoachUnit unit,
  String? exerciseName,
});

/// One button of a [CoachActions].
typedef CoachAction = ({
  CoachActionKind kind,
  String? exerciseId,
  String? exerciseName,
  CoachMetric? metric,
});

/// One component of the catalog, as a block draws it.
sealed class CoachComponent {
  const new();

  /// [block]'s root component, or null when it cannot be drawn: an invalid
  /// message, another catalog, an unknown component or data that is
  /// missing or of the wrong shape. The block then shows its fallback.
  static CoachComponent? of(CoachBlock block) {
    try {
      final surface = A2uiSurface.fromMessages(block.messages);
      final root = surface.root;
      if (surface.catalogId != coachCatalogId || root == null) return null;
      Object? prop(String name) => surface.resolve(root.props[name]);
      return switch (root.component) {
        'TrendChart' => CoachTrendChart._read(prop),
        'TargetBars' => CoachTargetBars._read(prop),
        'StatRow' => CoachStatRow(
          stats: [for (final stat in _list(prop('stats'))) _stat(stat)],
        ),
        'Actions' => CoachActions(
          actions: [
            for (final action in _list(prop('actions'))) _action(action),
          ],
        ),
        'FollowUps' => CoachFollowUps(
          questions: [
            for (final question in _list(prop('questions')))
              question! as String,
          ],
        ),
        _ => null,
      };
    } on Object {
      return null;
    }
  }
}

/// `TrendChart`: a metric over time, with its trend.
final class CoachTrendChart extends CoachComponent {
  /// Creates a [CoachTrendChart].
  const new({
    required this.metric,
    required this.points,
    required this.unit,
    this.trend,
    this.exerciseName,
  });

  new _read(Object? Function(String) prop)
    : this(
        metric: _enum(CoachTrendMetric.values, prop('metric')),
        points: _points(prop('points'))!,
        // The server binds a trend even when it has none to show.
        trend: switch (_points(prop('trend'))) {
          final List<CoachPoint> trend when trend.isNotEmpty => trend,
          _ => null,
        },
        unit: _enum(CoachUnit.values, prop('unit')),
        exerciseName: prop('exerciseName') as String?,
      );

  /// What it plots.
  final CoachTrendMetric metric;

  /// The readings, oldest first.
  final List<CoachPoint> points;

  /// The trend through them; null when there is none.
  final List<CoachPoint>? trend;

  /// Their unit.
  final CoachUnit unit;

  /// The exercise, for [CoachTrendMetric.exerciseE1rm].
  final String? exerciseName;
}

/// `TargetBars`: a day's calories and macros against their targets.
final class CoachTargetBars extends CoachComponent {
  /// Creates a [CoachTargetBars].
  const new({required this.rows, this.day});

  new _read(Object? Function(String) prop)
    : this(
        day: switch (prop('day')) {
          null || 'today' => null,
          final Object day => DateTime.parse(day as String),
        },
        rows: [
          for (final row in _list(prop('rows')))
            if (row
                case {
                      'nutrient': final String nutrient,
                      'value': final num? value,
                      'unit': final String unit,
                    } &&
                    final Map<Object?, Object?> map)
              (
                nutrient: enumFromValue(CoachNutrient.values, nutrient),
                value: value?.toDouble(),
                target: (map['target'] as num?)?.toDouble(),
                unit: enumFromValue(CoachUnit.values, unit),
              )
            else
              throw FormatException('Not a target row', row),
        ],
      );

  /// The day, or null for today.
  final DateTime? day;

  /// A row per nutrient.
  final List<CoachTargetRow> rows;
}

/// `StatRow`: up to three figures.
final class CoachStatRow extends CoachComponent {
  /// Creates a [CoachStatRow].
  const new({required this.stats});

  /// The figures.
  final List<CoachStat> stats;
}

/// `Actions`: buttons that open part of the app.
final class CoachActions extends CoachComponent {
  /// Creates a [CoachActions].
  const new({required this.actions});

  /// The buttons.
  final List<CoachAction> actions;
}

/// `FollowUps`: questions a tap sends as the next message.
final class CoachFollowUps extends CoachComponent {
  /// Creates a [CoachFollowUps].
  const new({required this.questions});

  /// The questions.
  final List<String> questions;
}

T _enum<T extends FirestoreEnum>(List<T> values, Object? raw) =>
    enumFromValue(values, raw! as String);

List<Object?> _list(Object? value) => value! as List<Object?>;

List<CoachPoint>? _points(Object? value) => value == null
    ? null
    : [
        for (final point in _list(value))
          if (point case {'x': final String x, 'y': final num y})
            (x: DateTime.parse(x), y: y.toDouble())
          else
            throw FormatException('Not a point', point),
      ];

CoachStat _stat(Object? stat) {
  if (stat
      case {'key': final String key, 'unit': final String unit} &&
          final Map<Object?, Object?> map) {
    final [name, ...id] = key.split(':');
    final statKey = enumFromValue(CoachStatKey.values, name);
    final exerciseId = id.isEmpty ? null : id.join(':');
    if ((statKey == CoachStatKey.exerciseE1rm) != (exerciseId != null)) {
      throw FormatException('An e1RM names its exercise; nothing else', key);
    }
    return (
      key: statKey,
      exerciseId: exerciseId,
      value: (map['value'] as num?)?.toDouble(),
      unit: enumFromValue(CoachUnit.values, unit),
      exerciseName: map['exerciseName'] as String?,
    );
  }
  throw FormatException('Not a stat', stat);
}

CoachAction _action(Object? action) {
  if (action
      case {'kind': final String kind} && final Map<Object?, Object?> map) {
    final result = (
      kind: enumFromValue(CoachActionKind.values, kind),
      exerciseId: map['exerciseId'] as String?,
      exerciseName: map['exerciseName'] as String?,
      metric: enumFromValueOrNull(CoachMetric.values, map['metric']),
    );
    final incomplete = switch (result.kind) {
      CoachActionKind.openExercise => result.exerciseId == null,
      CoachActionKind.openMetric => result.metric == null,
      _ => false,
    };
    if (!incomplete) return result;
  }
  throw FormatException('Not an action', action);
}
