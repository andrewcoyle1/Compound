import 'package:compound_models/src/body_enums.dart';
import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';

/// Field names of `users/{uid}/goals/{goal_id}`, exactly as the Swift
/// `CodingKeys` spell them.
///
/// Partial updates take their field names only from here. The rules freeze
/// [goalId], [userId], [startingWeightKg] and [createdAt] once written.
abstract final class WeightGoalKeys {
  /// `goal_id`.
  static const goalId = 'goal_id';

  /// `user_id`.
  static const userId = 'user_id';

  /// `objective`.
  static const objective = 'objective';

  /// `starting_weight_kg`.
  static const startingWeightKg = 'starting_weight_kg';

  /// `target_weight_kg`.
  static const targetWeightKg = 'target_weight_kg';

  /// `weekly_change_kg`.
  static const weeklyChangeKg = 'weekly_change_kg';

  /// `created_at`.
  static const createdAt = 'created_at';

  /// `status`.
  static const status = 'status';

  /// `completed_at`.
  static const completedAt = 'completed_at';

  /// Every field, in declaration order.
  static const List<String> all = [
    goalId,
    userId,
    objective,
    startingWeightKg,
    targetWeightKg,
    weeklyChangeKg,
    createdAt,
    status,
    completedAt,
  ];
}

/// A weight goal at `users/{uid}/goals/{goal_id}` (Swift `WeightGoal`).
///
/// The user's `currentGoalId` names the running one; goals saved before goal
/// ids live under the user id and have no `goal_id`.
class const WeightGoal({
  /// The goal's id, and the document id.
  required final String goalId,

  /// The user it belongs to.
  required final String userId,

  /// What it aims at.
  required final OverarchingObjective objective,

  /// The weight it started from, in kilograms.
  required final double startingWeightKg,

  /// The weight it aims for, in kilograms.
  required final double targetWeightKg,

  /// The planned rate, in kilograms a week (unsigned).
  required final double weeklyChangeKg,

  /// When it was set.
  required final DateTime createdAt,

  /// Where it stands.
  required final GoalStatus status,

  /// When it was completed.
  final DateTime? completedAt,
}) {
  /// Creates a [WeightGoal].
  this;

  /// Decodes as Swift's `init(from:)` does: a missing or null `goal_id`
  /// reads as `user_id`; everything else but `completed_at` is required,
  /// and `objective` must be a keyed map (see [OverarchingObjective]).
  /// Integers read as doubles.
  factory fromFirestore(Map<String, Object?> data) {
    final userId = data[WeightGoalKeys.userId]! as String;
    return WeightGoal(
      goalId: data[WeightGoalKeys.goalId] as String? ?? userId,
      userId: userId,
      objective: OverarchingObjective.fromFirestore(
        data[WeightGoalKeys.objective],
      ),
      startingWeightKg: readDouble(data[WeightGoalKeys.startingWeightKg]),
      targetWeightKg: readDouble(data[WeightGoalKeys.targetWeightKg]),
      weeklyChangeKg: readDouble(data[WeightGoalKeys.weeklyChangeKg]),
      createdAt: data[WeightGoalKeys.createdAt]! as DateTime,
      status: enumFromValue(
        GoalStatus.values,
        data[WeightGoalKeys.status]! as String,
      ),
      completedAt: data[WeightGoalKeys.completedAt] as DateTime?,
    );
  }

  /// The Firestore-shaped map Swift writes: `goal_id` always, and a null
  /// `completed_at` left out.
  Map<String, Object?> toFirestore() => {
    WeightGoalKeys.goalId: goalId,
    WeightGoalKeys.userId: userId,
    WeightGoalKeys.objective: objective.toFirestore(),
    WeightGoalKeys.startingWeightKg: startingWeightKg,
    WeightGoalKeys.targetWeightKg: targetWeightKg,
    WeightGoalKeys.weeklyChangeKg: weeklyChangeKg,
    WeightGoalKeys.createdAt: createdAt,
    WeightGoalKeys.status: status.value,
    WeightGoalKeys.completedAt: ?completedAt,
  };
}
