import 'package:body_repository/src/body_repository.dart';
import 'package:body_repository/src/body_rules.dart';
import 'package:body_repository/src/sample_body.dart';
import 'package:compound_models/compound_models.dart';

/// [BodyRepository] over fixed data, for the staging flavor and tests.
/// Seed it with [sampleBodyMeasurements], [sampleSteps] and
/// [sampleWeightGoal].
class InMemoryBodyRepository implements BodyRepository {
  /// Creates an [InMemoryBodyRepository] holding `measurements`, `steps`,
  /// `goals` (stored, like Firestore's, under their `goalId`) and
  /// `analyticsSettings`.
  new({
    List<BodyMeasurementEntry> measurements = const [],
    List<StepsModel> steps = const [],
    List<WeightGoal> goals = const [],
    this._analyticsSettings,
  }) : _measurements = List.unmodifiable(measurements),
       _steps = List.unmodifiable(steps),
       _goals = List.unmodifiable(goals);

  final List<BodyMeasurementEntry> _measurements;
  final List<StepsModel> _steps;
  final List<WeightGoal> _goals;
  final AnalyticsSettings? _analyticsSettings;

  @override
  Stream<List<BodyMeasurementEntry>> watchMeasurements(String uid) =>
      Stream.value(
        liveOldestFirst(
          _measurements.where((entry) => entry.authorId == uid),
          date: (entry) => entry.date,
          deletedAt: (entry) => entry.deletedAt,
        ),
      );

  @override
  Stream<List<StepsModel>> watchSteps(String uid) => Stream.value(
    liveOldestFirst(
      _steps.where((steps) => steps.authorId == uid),
      date: (steps) => steps.date,
      deletedAt: (steps) => steps.deletedAt,
    ),
  );

  @override
  Stream<AnalyticsSettings> watchAnalyticsSettings(String uid) => Stream.value(
    _analyticsSettings?.authorId == uid
        ? _analyticsSettings!
        : AnalyticsSettings(authorId: uid),
  );

  @override
  Stream<WeightGoal?> watchCurrentGoal(String uid, {String? currentGoalId}) {
    final id = currentGoalDocumentId(uid, currentGoalId);
    return Stream.value(
      _goals
          .where((goal) => goal.userId == uid && goal.goalId == id)
          .firstOrNull,
    );
  }
}
