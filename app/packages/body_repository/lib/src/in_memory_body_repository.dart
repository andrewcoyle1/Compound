import 'dart:async';

import 'package:body_repository/src/body_repository.dart';
import 'package:body_repository/src/body_rules.dart';
import 'package:body_repository/src/sample_body.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:compound_models/compound_models.dart';

/// [BodyRepository] in memory, for the staging flavor and tests. Seed it
/// with [sampleBodyMeasurements], [sampleSteps] and [sampleWeightGoal].
///
/// Writes behave as Firestore's do, so staging behaves as the real app:
/// saves merge over the stored document field by field, an update of a
/// missing goal or entry fails with `not-found`, and every watcher sees the
/// change.
class InMemoryBodyRepository implements BodyRepository {
  /// Creates an [InMemoryBodyRepository] holding `measurements`, `steps`,
  /// `goals` (stored, like Firestore's, under their `goalId`) and
  /// `analyticsSettings`.
  new({
    List<BodyMeasurementEntry> measurements = const [],
    List<StepsModel> steps = const [],
    List<WeightGoal> goals = const [],
    this._analyticsSettings,
  }) : _measurements = List.of(measurements),
       _steps = List.of(steps),
       _goals = List.of(goals);

  final List<BodyMeasurementEntry> _measurements;
  final List<StepsModel> _steps;
  final List<WeightGoal> _goals;
  final AnalyticsSettings? _analyticsSettings;
  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<List<BodyMeasurementEntry>> watchMeasurements(String uid) => _watch(
    () => liveOldestFirst(
      _measurements.where((entry) => entry.authorId == uid),
      date: (entry) => entry.date,
      deletedAt: (entry) => entry.deletedAt,
    ),
  );

  @override
  Stream<List<StepsModel>> watchSteps(String uid) => _watch(
    () => liveOldestFirst(
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
    return _watch(() => _goals.where(_isGoal(uid, id)).firstOrNull);
  }

  @override
  Future<void> saveMeasurement(BodyMeasurementEntry entry) async {
    _merge(
      _measurements,
      entry,
      (stored) => stored.authorId == entry.authorId && stored.id == entry.id,
      BodyMeasurementEntry.fromFirestore,
      (model) => model.toFirestore(),
    );
  }

  @override
  Future<void> clearMeasurementFields(
    String uid,
    String entryId,
    Set<String> fields,
  ) async {
    checkClearable(fields);
    final index = _measurements.indexWhere(
      (stored) => stored.authorId == uid && stored.id == entryId,
    );
    if (index < 0) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'No document to update: users/$uid/body_measurements/$entryId',
      );
    }
    _measurements[index] = BodyMeasurementEntry.fromFirestore(
      _measurements[index].toFirestore()
        ..removeWhere((key, _) => fields.contains(key)),
    );
    _changes.add(null);
  }

  @override
  Future<void> saveSteps(StepsModel steps) async {
    _merge(
      _steps,
      steps,
      (stored) => stored.authorId == steps.authorId && stored.id == steps.id,
      StepsModel.fromFirestore,
      (model) => model.toFirestore(),
    );
  }

  @override
  Future<void> saveGoal(WeightGoal goal) async {
    _merge(
      _goals,
      goal,
      _isGoal(goal.userId, goal.goalId),
      WeightGoal.fromFirestore,
      (model) => model.toFirestore(),
    );
  }

  @override
  Future<void> abandonGoal(String uid, String goalId) async {
    final index = _goals.indexWhere(_isGoal(uid, goalId));
    if (index < 0) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'No document to update: users/$uid/goals/$goalId',
      );
    }
    _goals[index] = WeightGoal.fromFirestore({
      ..._goals[index].toFirestore(),
      WeightGoalKeys.status: GoalStatus.abandoned.value,
    });
    _changes.add(null);
  }

  bool Function(WeightGoal) _isGoal(String uid, String goalId) =>
      (goal) => goal.userId == uid && goal.goalId == goalId;

  /// Writes [model] into [documents] as a Firestore merge does: over the
  /// document [isSame] finds, field by field, or as a new one.
  void _merge<T>(
    List<T> documents,
    T model,
    bool Function(T) isSame,
    T Function(Map<String, Object?>) decode,
    Map<String, Object?> Function(T) encode,
  ) {
    final index = documents.indexWhere(isSame);
    if (index < 0) {
      documents.add(model);
    } else {
      documents[index] = decode({
        ...encode(documents[index]),
        ...encode(model),
      });
    }
    _changes.add(null);
  }

  /// [read] now and after every write, as a Firestore listener emits.
  Stream<T> _watch<T>(T Function() read) => Stream.multi((listener) {
    listener.add(read());
    final subscription = _changes.stream.listen((_) => listener.add(read()));
    // Not `subscription.cancel` itself: `first` would wait on the Future
    // that returns, which never completes under a widget test's fake clock.
    listener.onCancel = () => unawaited(subscription.cancel());
  });
}
