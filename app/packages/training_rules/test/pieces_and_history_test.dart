// Ports ActiveWorkoutPiecesTests (the decisions, not the wording) and
// WorkoutTrackerHistoryKeyTests (the pure parts).
import 'package:test/test.dart';
import 'package:training_rules/training_rules.dart';

final start = DateTime.fromMillisecondsSinceEpoch(1000000000, isUtc: true);

WorkoutSet set(
  String id, {
  double? weight = 100,
  int? reps = 8,
  int? duration,
  SetKind kind = SetKind.standard,
  String? parent,
  int? target,
  bool logged = false,
}) => WorkoutSet(
  id: id,
  reps: reps,
  weightKg: weight,
  durationSec: duration,
  kind: kind,
  parentSetId: parent,
  targetReps: target,
  completedAt: logged ? start : null,
);

WorkoutExercise exercise(List<WorkoutSet> sets) =>
    WorkoutExercise(id: 'e1', templateId: 't1', sets: sets);

void main() {
  const settings = WorkoutSettings();

  group('pieces', () {
    final dropSet = [
      set('s1', logged: true),
      set('s2', logged: true),
      set('s3', kind: SetKind.drop),
      set('d1', weight: 80, reps: null, kind: SetKind.drop, parent: 's3'),
      set('d2', weight: 64, reps: null, kind: SetKind.drop, parent: 's3'),
      set('s4', kind: SetKind.amrap, target: 8),
    ];

    test('a drop follows with no rest', () {
      final bench = exercise(dropSet);
      expect(
        ActiveWorkout.nextPiece('s3', bench, settings),
        NextPiece(piece: dropSet[3], ordinal: 1, restSeconds: 0),
      );
      expect(
        ActiveWorkout.nextPiece('d1', bench, settings),
        NextPiece(piece: dropSet[4], ordinal: 2, restSeconds: 0),
      );
    });

    test("a mini-set follows after its kind's breath", () {
      final sets = [
        set('s1', weight: 160, kind: SetKind.myo),
        set('m1', weight: 160, reps: 5, parent: 's1'),
        set('m2', weight: 160, reps: 5, parent: 's1'),
      ];
      final hint = ActiveWorkout.nextPiece(
        'm1',
        exercise(sets),
        const WorkoutSettings(intraSetRestMyoSeconds: 15),
      );
      expect(hint?.ordinal, 2);
      expect(hint?.restSeconds, 15);
      final restPause = [...sets]
        ..[0] = sets[0].copyWith(kind: SetKind.restPause);
      expect(
        ActiveWorkout.nextPiece(
          's1',
          exercise(restPause),
          settings,
        )?.restSeconds,
        20,
      );
      final orphan = exercise([set('s1'), set('m1', parent: 'gone')]);
      expect(ActiveWorkout.nextPiece('s1', orphan, settings)?.restSeconds, 0);
    });

    test('no hint before a set of its own', () {
      final bench = exercise(dropSet);
      for (final id in ['s2', 'd2', 's4', 'missing']) {
        expect(ActiveWorkout.nextPiece(id, bench, settings), isNull);
      }
    });

    test('a logged piece is passed over', () {
      final sets = [...dropSet]..[3] = dropSet[3].copyWith(completedAt: start);
      expect(
        ActiveWorkout.nextPiece('s3', exercise(sets), settings)?.piece.id,
        'd2',
      );
    });

    test('partials, a stretch and a hold follow with no breath', () {
      for (final kind in [SetKind.partials, SetKind.stretch, SetKind.hold]) {
        final piece = set(
          'p1',
          reps: null,
          duration: 30,
          kind: kind,
          parent: 's1',
        );
        final hint = ActiveWorkout.nextPiece(
          's1',
          exercise([set('s1', kind: kind), piece]),
          settings,
        );
        expect(hint, NextPiece(piece: piece, ordinal: 1));
      }
    });
  });

  group('history', () {
    final today = [
      const WorkoutExercise(id: 'heavy', templateId: 'bench', index: 1),
      const WorkoutExercise(id: 'row', templateId: 'row', index: 2),
      const WorkoutExercise(id: 'backoff', templateId: 'bench', index: 3),
    ];

    test('each appearance has its own key', () {
      final session = WorkoutSession(exercises: today);
      expect(ActiveWorkout.historyKey(today[0], session), 'bench#0');
      expect(ActiveWorkout.historyKey(today[1], session), 'row#0');
      expect(ActiveWorkout.historyKey(today[2], session), 'bench#1');
      expect(
        ActiveWorkout.historyKey(const WorkoutExercise(id: 'x'), session),
        'x#0',
      );
    });

    test('the planner suggests for each appearance from its own history', () {
      final rounding = ProgressionRounding(
        round: WeightRoundingRule(
          step: WeightStep.fallback(WeightUnit.kilograms),
          preferredUnit: WeightUnit.kilograms,
        ).round,
        minimumIncrementKg: 2.5,
      );
      final history = [
        WorkoutSession(
          exercises: [
            WorkoutExercise(
              id: 'last-heavy',
              templateId: 'bench',
              index: 1,
              sets: [
                WorkoutSet(
                  id: 'h1',
                  reps: 8,
                  weightKg: 100,
                  rpe: 8,
                  completedAt: start,
                ),
              ],
            ),
            WorkoutExercise(
              id: 'last-backoff',
              templateId: 'bench',
              index: 2,
              sets: [
                WorkoutSet(
                  id: 'b1',
                  reps: 15,
                  weightKg: 60,
                  completedAt: start,
                ),
              ],
            ),
          ],
        ),
      ];
      final suggestions = ProgressionPlanner.suggestions(
        contexts: [
          ProgressionContext(
            templateId: 'bench',
            trackingMode: TrackingMode.weightReps,
            setTargets: const [SetTarget(minReps: 6, maxReps: 8)],
            rounding: rounding,
          ),
          ProgressionContext(
            templateId: 'bench',
            trackingMode: TrackingMode.weightReps,
            setTargets: const [SetTarget(minReps: 20, maxReps: 20)],
            rounding: rounding,
            occurrence: 1,
          ),
        ],
        history: history,
        adjustmentMode: ProgressionAdjustmentMode.weightFirst,
      );
      expect(suggestions.keys.toList()..sort(), ['bench#0', 'bench#1']);
      expect(suggestions['bench#0']?.rationale, Rationale.progressWeight);
      expect(
        suggestions['bench#1']?.rationale,
        isNot(Rationale.progressWeight),
      );
      expect(suggestions['bench#1']?.sets.first.weightKg, 60);
    });

    test('filling a row from last time follows the tracking mode', () {
      const previous = WorkoutSet(
        id: 'p',
        reps: 10,
        weightKg: 60,
        durationSec: 45,
        distanceMeters: 400,
        bands: ['Red'],
      );
      const row = WorkoutSet(id: 'r', weightKg: 50, reps: 1);
      expect(
        ActiveWorkout.fillingFromPrevious(
          row,
          previous,
          TrackingMode.weightReps,
        ),
        row.copyWith(weightKg: 60, reps: 10, bands: ['Red']),
      );
      expect(
        ActiveWorkout.fillingFromPrevious(
          row,
          previous.copyWith(weightKg: null),
          TrackingMode.weightReps,
        ).weightKg,
        50,
      );
      expect(
        ActiveWorkout.fillingFromPrevious(row, previous, TrackingMode.repsOnly),
        row.copyWith(reps: 10),
      );
      expect(
        ActiveWorkout.fillingFromPrevious(row, previous, TrackingMode.timeOnly),
        row.copyWith(durationSec: 45),
      );
      expect(
        ActiveWorkout.fillingFromPrevious(
          row,
          previous,
          TrackingMode.distanceTime,
        ),
        row.copyWith(durationSec: 45, distanceMeters: 400),
      );
    });

    test('filling a row from a suggestion leaves what it does not name', () {
      const row = WorkoutSet(id: 'r', weightKg: 50, reps: 1, durationSec: 3);
      expect(
        ActiveWorkout.fillingFromSuggestion(
          row,
          const SuggestedSet(weightKg: 52.5, distanceMeters: 100),
        ),
        row.copyWith(weightKg: 52.5, distanceMeters: 100),
      );
      expect(
        ActiveWorkout.fillingFromSuggestion(
          row,
          const SuggestedSet(reps: 9, durationSec: 30),
        ),
        row.copyWith(reps: 9, durationSec: 30),
      );
    });
  });
}
