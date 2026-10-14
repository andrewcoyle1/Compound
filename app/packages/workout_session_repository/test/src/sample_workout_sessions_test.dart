import 'package:flutter_test/flutter_test.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

void main() {
  group('sampleWorkoutSessions', () {
    final now = DateTime(2026, 10, 14, 9);
    late List<WorkoutSessionModel> sessions;
    late List<WorkoutSetModel> sets;

    setUp(() {
      sessions = sampleWorkoutSessions(uid: 'me', now: now);
      sets = [
        for (final session in sessions)
          for (final exercise in session.exercises) ...exercise.sets,
      ];
    });

    test("is a finished week of the user's sessions before now", () {
      expect(sessions, hasLength(6));
      for (final session in sessions) {
        expect(session.authorId, 'me');
        expect(session.endedAt!.isBefore(now), isTrue);
        expect(now.difference(session.dateCreated).inDays, lessThan(7));
      }
    });

    test('are documents the Swift app can read', () {
      for (final session in sessions) {
        expect(
          WorkoutSessionModel.fromFirestore(session.toFirestore())
              .toFirestore(),
          equals(session.toFirestore()),
        );
      }
    });

    test('cover the shapes the history screens show', () {
      expect(sessions.where((s) => s.isRestDay), hasLength(1));
      expect(sets.where((set) => set.isWarmup), isNotEmpty);
      expect(sets.where((set) => set.kind == SetKind.drop), isNotEmpty);
      expect(sets.where((set) => set.side == SetSide.left), isNotEmpty);
      expect(sets.where((set) => set.durationSec != null), isNotEmpty);
      expect(sets.where((set) => set.distanceMeters != null), isNotEmpty);
      expect(
        sets.where((set) => set.weightUnit == ExerciseWeightUnit.pounds),
        isNotEmpty,
      );
      final exercises = [for (final s in sessions) ...s.exercises];
      expect(exercises.where((e) => e.supersetGroupId != null), hasLength(2));
      expect(
        exercises.map((e) => e.trackingMode).toSet(),
        TrackingMode.values.toSet(),
      );
    });

    test('drops point at a set in the same exercise', () {
      for (final session in sessions) {
        for (final exercise in session.exercises) {
          final ids = {for (final set in exercise.sets) set.id};
          for (final set in exercise.sets) {
            if (set.parentSetId != null) {
              expect(ids, contains(set.parentSetId));
            }
          }
        }
      }
    });
  });
}
