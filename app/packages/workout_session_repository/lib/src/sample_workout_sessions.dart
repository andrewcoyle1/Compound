import 'package:compound_models/compound_models.dart';

/// A week of [uid]'s training ending the day before [now], for the staging
/// flavor: barbell lifts with warm-ups, a superset, drop sets, dumbbells
/// and a lift logged in pounds, bodyweight and one-side-at-a-time sets,
/// timed and distance work, and a rest day. Newest last.
List<WorkoutSessionModel> sampleWorkoutSessions({
  required String uid,
  required DateTime now,
}) {
  DateTime at(int daysAgo, int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

  return [
    _session(
      uid,
      id: 'sample-session-push-a',
      name: 'Push A',
      start: at(6, 7),
      minutes: 64,
      likedBy: const ['sample-friend-1', 'sample-friend-2'],
      exercises: [
        _exercise(
          uid,
          'system-barbell-bench-press',
          'Barbell Bench Press',
          sets: [
            _warmUp(40, 10),
            _warmUp(60, 5),
            _working(80, 8, rpe: 7.5),
            _working(80, 8, rpe: 8),
            _working(80, 7, rpe: 9),
          ],
          restSeconds: 180,
        ),
        _exercise(
          uid,
          'system-45-degree-incline-dumbbell-press',
          '45° Incline Dumbbell Press',
          sets: [
            for (final reps in [10, 9, 8])
              _working(26, reps, rpe: 8, loadCount: 2),
          ],
          loadsPerSet: 2,
        ),
        _exercise(
          uid,
          'system-standing-lateral-raise-cable',
          'Standing Lateral Raise (Cable)',
          sets: [
            for (final reps in [15, 14, 12]) _working(7.5, reps),
          ],
          supersetGroupId: 'sample-superset-push-a',
        ),
        _exercise(
          uid,
          'system-cable-pushdown-straight-bar',
          'Cable Pushdown (Straight Bar)',
          sets: [
            _working(35, 12, rpe: 8),
            _working(35, 11, rpe: 9, id: 'drop-parent'),
            _working(25, 8, kind: SetKind.drop, parentSetId: 'drop-parent'),
            _working(17.5, 6, kind: SetKind.drop, parentSetId: 'drop-parent'),
          ],
          supersetGroupId: 'sample-superset-push-a',
          setTargets: const [
            SetTarget(id: 'pushdown-1', setNumber: 1, minReps: 10, maxReps: 12),
            SetTarget(
              id: 'pushdown-2',
              setNumber: 2,
              minReps: 10,
              maxReps: 12,
              setType: SetTargetSetType.drop,
              dropCount: 2,
              dropStepPercent: 30,
            ),
          ],
        ),
      ],
    ),
    _session(
      uid,
      id: 'sample-session-pull-a',
      name: 'Pull A',
      start: at(5, 18, 15),
      minutes: 58,
      exercises: [
        _exercise(
          uid,
          'system-barbell-sumo-deadlift',
          'Barbell Sumo Deadlift',
          sets: [
            _warmUp(60, 8),
            _warmUp(100, 3),
            _working(140, 5, rpe: 8),
            _working(140, 5, rpe: 8.5),
            _working(140, 4, rpe: 9.5),
          ],
          restSeconds: 240,
        ),
        _exercise(
          uid,
          'system-wide-grip-pull-up',
          'Wide Grip Pull-up',
          trackingMode: TrackingMode.repsOnly,
          sets: [
            for (final reps in [10, 8, 7]) _working(null, reps, rpe: 9),
          ],
        ),
        _exercise(
          uid,
          'system-bent-over-barbell-row',
          'Bent-Over Barbell Row',
          sets: [
            for (final reps in [10, 10, 9]) _working(70, reps, rpe: 8),
          ],
        ),
        _exercise(
          uid,
          'system-dumbbell-curl',
          'Dumbbell Curl',
          // Lifted in pounds: 30 lb is 13.607771 kg.
          weightUnit: ExerciseWeightUnit.pounds,
          loadsPerSet: 2,
          sets: [
            for (final reps in [12, 10, 9])
              _working(13.607771, reps, loadCount: 2, unit: 'pounds'),
          ],
        ),
      ],
    ),
    _session(
      uid,
      id: 'sample-session-rest',
      name: 'Rest day',
      start: at(4, 9),
      minutes: 0,
      isRestDay: true,
      exercises: const [],
    ),
    _session(
      uid,
      id: 'sample-session-legs',
      name: 'Legs',
      start: at(3, 17, 30),
      minutes: 72,
      pausedSeconds: 240,
      exercises: [
        _exercise(
          uid,
          'system-barbell-squat',
          'Barbell Squat',
          sets: [
            _warmUp(20, 10),
            _warmUp(60, 5),
            _warmUp(90, 2),
            _working(110, 6, rpe: 8),
            _working(110, 6, rpe: 8.5),
            _working(110, 5, rpe: 9),
          ],
          restSeconds: 210,
        ),
        _exercise(
          uid,
          'system-bulgarian-split-squat',
          'Bulgarian Split Squat',
          sets: [
            for (final side in ['left', 'right', 'left', 'right'])
              _working(20, 10, side: side, loadCount: 2),
          ],
          loadsPerSet: 2,
        ),
        _exercise(
          uid,
          'system-45-degree-leg-press',
          '45° Leg Press',
          sets: [
            _working(180, 12, rpe: 8),
            _working(180, 10, rpe: 9.5, id: 'leg-press-drop'),
            _working(
              120,
              10,
              kind: SetKind.drop,
              parentSetId: 'leg-press-drop',
            ),
          ],
        ),
        _exercise(
          uid,
          'sample-plank',
          'Plank',
          trackingMode: TrackingMode.timeOnly,
          sets: [
            for (final seconds in [60, 50])
              _working(null, null, seconds: seconds),
          ],
        ),
      ],
    ),
    _session(
      uid,
      id: 'sample-session-conditioning',
      name: 'Conditioning',
      start: at(2, 6, 45),
      minutes: 30,
      exercises: [
        _exercise(
          uid,
          'sample-row-erg',
          'Row Erg',
          trackingMode: TrackingMode.distanceTime,
          sets: [
            _working(null, null, seconds: 465, meters: 2000),
            _working(null, null, seconds: 112, meters: 500),
          ],
        ),
        _exercise(
          uid,
          'system-captains-chair-knee-raise',
          'Captain’s Chair Knee Raise',
          trackingMode: TrackingMode.repsOnly,
          sets: [
            for (final reps in [15, 12]) _working(null, reps),
          ],
        ),
      ],
    ),
    _session(
      uid,
      id: 'sample-session-push-b',
      name: 'Push B',
      start: at(1, 12, 10),
      minutes: 55,
      likedBy: const ['sample-friend-3'],
      stravaActivityId: 16023457789,
      exercises: [
        _exercise(
          uid,
          'system-dumbbell-seated-shoulder-press',
          'Dumbbell Seated Shoulder Press',
          loadsPerSet: 2,
          sets: [
            _warmUp(12, 10, loadCount: 2),
            for (final reps in [10, 9, 8])
              _working(24, reps, rpe: 8.5, loadCount: 2),
          ],
        ),
        _exercise(
          uid,
          'system-chest-dip',
          'Chest Dip',
          sets: [_working(0, 12), _working(10, 8, rpe: 9)],
        ),
        _exercise(
          uid,
          'system-cable-y-raise',
          'Cable Y-Raise',
          sets: [
            for (final reps in [15, 12, 12]) _working(5, reps),
          ],
        ),
      ],
    ),
  ];
}

/// [weeks] weeks of Push, Pull and Legs before [sampleWorkoutSessions]'
/// week, a little lighter each week further back, for the staging flavor's
/// training analytics: one-rep max trends, weekly sets per muscle, planned
/// sets done and last week's review. One planned set is missed now and then.
/// Newest last.
List<WorkoutSessionModel> sampleEarlierWorkoutSessions({
  required String uid,
  required DateTime now,
  int weeks = 5,
}) {
  DateTime at(int daysAgo, int hour) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour);

  List<SetTarget> targets(String id, int count, int min, int max) => [
    for (var i = 1; i <= count; i++)
      SetTarget(id: '$id-$i', setNumber: i, minReps: min, maxReps: max),
  ];

  _ExerciseDraft lift(
    String templateId,
    String name,
    double kg,
    List<int> reps, {
    required int planned,
    required int min,
    required int max,
    double rpe = 8,
  }) => _exercise(
    uid,
    templateId,
    name,
    sets: [for (final r in reps) _working(kg, r, rpe: rpe)],
    setTargets: targets(templateId, planned, min, max),
  );

  return [
    for (var week = weeks; week >= 1; week--) ...[
      _session(
        uid,
        id: 'sample-earlier-push-$week',
        name: 'Push A',
        start: at(7 * week + 6, 7),
        minutes: 60,
        exercises: [
          lift(
            'system-barbell-bench-press',
            'Barbell Bench Press',
            80 - 2.5 * week,
            [8, 8, 7],
            planned: 3,
            min: 6,
            max: 8,
          ),
          lift(
            'system-45-degree-incline-dumbbell-press',
            '45° Incline Dumbbell Press',
            26 - week.toDouble(),
            [10, 9, 8],
            planned: 3,
            min: 8,
            max: 10,
          ),
          lift(
            'system-cable-pushdown-straight-bar',
            'Cable Pushdown (Straight Bar)',
            35 - 2.5 * week,
            // A set skipped every other week.
            week.isEven ? [12, 11] : [12, 11, 10],
            planned: 3,
            min: 10,
            max: 12,
          ),
        ],
      ),
      _session(
        uid,
        id: 'sample-earlier-pull-$week',
        name: 'Pull A',
        start: at(7 * week + 5, 18),
        minutes: 55,
        exercises: [
          lift(
            'system-barbell-sumo-deadlift',
            'Barbell Sumo Deadlift',
            140 - 5 * week.toDouble(),
            [5, 5, 5],
            planned: 3,
            min: 4,
            max: 6,
            rpe: 8.5,
          ),
          lift(
            'system-bent-over-barbell-row',
            'Bent-Over Barbell Row',
            70 - 2.5 * week,
            [10, 10, 9],
            planned: 3,
            min: 8,
            max: 10,
          ),
        ],
      ),
      _session(
        uid,
        id: 'sample-earlier-legs-$week',
        name: 'Legs',
        start: at(7 * week + 3, 17),
        minutes: 65,
        exercises: [
          lift(
            'system-barbell-squat',
            'Barbell Squat',
            110 - 5 * week.toDouble(),
            [6, 6, 6],
            planned: 3,
            min: 5,
            max: 6,
          ),
          lift(
            'system-45-degree-leg-press',
            '45° Leg Press',
            180 - 10 * week.toDouble(),
            [12, 11, 10],
            planned: 3,
            min: 10,
            max: 12,
          ),
        ],
      ),
    ],
  ];
}

WorkoutSessionModel _session(
  String uid, {
  required String id,
  required String name,
  required DateTime start,
  required int minutes,
  required List<_ExerciseDraft> exercises,
  bool isRestDay = false,
  List<String> likedBy = const [],
  double? pausedSeconds,
  int? stravaActivityId,
}) {
  final end = start.add(Duration(minutes: minutes));
  return WorkoutSessionModel(
    id: id,
    authorId: uid,
    name: name,
    dateCreated: start,
    dateModified: end,
    endedAt: end,
    exercises: [
      for (final (index, draft) in exercises.indexed)
        draft(id, index + 1, start.add(Duration(minutes: index * 12))),
    ],
    isRestDay: isRestDay,
    likedByUserIds: likedBy,
    pausedSeconds: pausedSeconds,
    stravaActivityId: stravaActivityId,
  );
}

/// An exercise waiting for its session id, place and start time.
typedef _ExerciseDraft = WorkoutExerciseModel Function(
  String sessionId,
  int index,
  DateTime start,
);

/// A set waiting for its exercise id, number and time.
typedef _SetDraft = WorkoutSetModel Function(
  String uid,
  String exerciseId,
  int index,
  DateTime at,
);

_ExerciseDraft _exercise(
  String uid,
  String templateId,
  String name, {
  required List<_SetDraft> sets,
  TrackingMode trackingMode = TrackingMode.weightReps,
  int? restSeconds,
  int? loadsPerSet,
  String? supersetGroupId,
  ExerciseWeightUnit? weightUnit,
  List<SetTarget> setTargets = const [],
}) => (sessionId, index, start) {
  final id = '$sessionId-$templateId';
  return WorkoutExerciseModel(
    id: id,
    authorId: uid,
    templateId: templateId,
    name: name,
    trackingMode: trackingMode,
    index: index,
    sets: [
      for (final (number, draft) in sets.indexed)
        draft(uid, id, number + 1, start.add(Duration(minutes: 2 * number))),
    ],
    setTargets: setTargets,
    restSeconds: restSeconds,
    loadsPerSet: loadsPerSet,
    supersetGroupId: supersetGroupId,
    weightUnit: weightUnit,
  );
};

_SetDraft _warmUp(double weightKg, int reps, {int? loadCount}) =>
    _working(weightKg, reps, loadCount: loadCount, isWarmup: true);

_SetDraft _working(
  double? weightKg,
  int? reps, {
  double? rpe,
  int? seconds,
  double? meters,
  int? loadCount,
  SetKind? kind,
  String? id,
  String? parentSetId,
  String? side,
  String unit = 'kilograms',
  bool isWarmup = false,
}) =>
    (uid, exerciseId, index, at) => WorkoutSetModel(
      id: '$exerciseId-${id ?? 'set-$index'}',
      authorId: uid,
      index: index,
      isWarmup: isWarmup,
      dateCreated: at,
      completedAt: at.add(const Duration(minutes: 1)),
      reps: reps,
      weightKg: weightKg,
      durationSec: seconds,
      distanceMeters: meters,
      rpe: rpe,
      sideRawValue: side,
      kindRawValue: kind?.value,
      parentSetId: parentSetId == null ? null : '$exerciseId-$parentSetId',
      loadCount: loadCount,
      weightUnitRawValue: weightKg == null ? null : unit,
    );
