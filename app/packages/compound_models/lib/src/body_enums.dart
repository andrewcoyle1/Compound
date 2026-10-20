import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';

/// Where a body measurement came from (Swift `WeightSource`).
enum WeightSource implements FirestoreEnum {
  /// `manual`: logged in Compound.
  manual('manual'),

  /// `healthkit`: imported from, or exported to, Apple Health.
  healthkit('healthkit'),

  /// `imported`.
  imported('imported');

  new(this.value);

  @override
  final String value;
}

/// Where a day's step count came from (Swift `StepsSource`).
enum StepsSource implements FirestoreEnum {
  /// `manual`: entered in Compound.
  manual('manual'),

  /// `healthkit`: Apple Health's total for the day.
  healthkit('healthkit'),

  /// `imported`.
  imported('imported');

  new(this.value);

  @override
  final String value;
}

/// Where a weight goal stands (Swift `WeightGoal.GoalStatus`).
enum GoalStatus implements FirestoreEnum {
  /// `active`.
  active('active'),

  /// `completed`.
  completed('completed'),

  /// `abandoned`: replaced by a fresh start.
  abandoned('abandoned'),

  /// `paused`.
  paused('paused');

  new(this.value);

  @override
  final String value;
}

/// What a weight goal aims at (Swift `OverarchingObjective`).
///
/// Swift's enum has no raw type, so it is stored as a **keyed map** whose
/// only key is the case name, `{"loseWeight": {}}`; [value] is that key.
/// A plain string would fail to decode on iOS and drop the goal.
enum OverarchingObjective implements FirestoreEnum {
  /// `loseWeight`.
  loseWeight('loseWeight'),

  /// `maintain`.
  maintain('maintain'),

  /// `gainWeight`.
  gainWeight('gainWeight');

  new(this.value);

  @override
  final String value;

  /// Decodes as Swift's synthesized decoder does: [raw] must be a map with
  /// exactly one known case name as a key, whose value is itself a map
  /// (its contents are ignored). Keys that are not case names are ignored,
  /// as Swift leaves them out of `allKeys`. Anything else throws.
  static OverarchingObjective fromFirestore(Object? raw) {
    final map = readMap(raw);
    final known = [
      for (final objective in values)
        if (map.containsKey(objective.value)) objective,
    ];
    if (known.length != 1) {
      throw FormatException('Not one OverarchingObjective case', raw);
    }
    readMap(map[known.single.value]);
    return known.single;
  }

  /// The keyed map Swift writes, `{"loseWeight": {}}`.
  Map<String, Object?> toFirestore() => {value: <String, Object?>{}};
}
