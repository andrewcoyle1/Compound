import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/library_fixtures.dart';
import '../../onboarding/cubit/helpers.dart';

const String uid = sampleUserId;

/// Set editing on the tracker, as Swift's row and exercise presenters do it:
/// `SetKindUITests`, `SetSideTrackingTests`, the rest picker cases of
/// `WorkoutTrackingRowPresenterTests` and the stopwatch. The rules
/// themselves are `training_rules`' tests.
void main() {
  final now = DateTime(2026, 10, 15, 18);
  final l10n = lookupAppLocalizations(const Locale('en'));
  late RecordingAnalytics analytics;
  late ActiveWorkoutCubit cubit;
  var ids = 0;

  ExerciseModel own(String id, List<String> metrics) =>
      ExerciseModel.fromFirestore({
        ...fixtureLibraryExercise(id).toFirestore(),
        'author_id': uid,
        'trackable_metrics': metrics,
      });
  final oneArmRow = own('One-Arm Row', ['weight', 'repsPerSide']);
  final plank = own('Plank', ['duration']);

  setUp(() {
    ids = 0;
    analytics = RecordingAnalytics();
    cubit = ActiveWorkoutCubit(
      sessions: InMemoryWorkoutSessionRepository(sessions: const []),
      users: InMemoryUserRepository(users: {uid: sampleUser(now: now)}),
      library: InMemoryTrainingLibraryRepository(
        exercises: [oneArmRow, plank],
        workoutSettings: const [
          WorkoutSettings(authorId: uid, addSmartWarmUps: false),
        ],
      ),
      analytics: analytics.repository,
      store: InMemoryActiveSessionStore(),
      notifications: FakeNotificationsRepository(),
      copy: AppNotificationCopy(() => l10n),
      clock: () => now,
      newId: () => 'ID-${++ids}',
      wait: (_) async {},
    );
  });

  tearDown(() => cubit.close());

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// My Upper Body under way; the bench press's sets at 100 kg × 8.
  Future<List<String>> bench() async {
    await cubit.userChanged(uid);
    await settle();
    await cubit.start(
      template: sampleUserWorkoutTemplates.first,
      eventPrefix: 'x',
    );
    final benchId = cubit.state.session!.exercises.first.id;
    while (cubit.state.session!.exercises.first.sets.length < 3) {
      cubit.addSet(benchId);
    }
    final sets = cubit.state.session!.exercises.first.sets;
    for (final set in sets) {
      cubit
        ..openKeypad(set.id, SetField.weight)
        ..keypadKey('1')
        ..keypadKey('0')
        ..keypadKey('0')
        ..keypadNext()
        ..keypadKey('8')
        ..closeKeypad();
    }
    return [for (final set in sets) set.id];
  }

  List<WorkoutSetModel> benchSets() =>
      cubit.state.session!.exercises.first.sets;

  group('set types', () {
    test('a drop set gets its first drop, 20 % lighter', () async {
      final [s1, ...] = await bench();
      cubit.setSetType(s1, const r.SetTypeChoice.ofKind(r.SetKind.drop));
      final sets = benchSets();
      expect(sets[0].kind, SetKind.drop);
      expect(sets[1].parentSetId, s1);
      expect(sets[1].weightKg, 80);
      expect(cubit.state.effect, isA<SelectionEffect>());
      expect(analytics.last('SetTrackerRow_SetTypeChanged').parameters, {
        'set_type': 'drop',
      });

      // A repeat pick changes nothing.
      analytics.events.clear();
      cubit.setSetType(s1, const r.SetTypeChoice.ofKind(r.SetKind.drop));
      expect(benchSets(), sets);
      expect(analytics.names, isEmpty);
    });

    test('changing a type that loses logged rows is counted first', () async {
      final [s1, s2, ...] = await bench();
      cubit.setSetType(s1, const r.SetTypeChoice.ofKind(r.SetKind.drop));
      final drop = benchSets()[1].id;
      cubit
        ..openKeypad(drop, SetField.reps)
        ..keypadKey('6')
        ..closeKeypad()
        ..toggleSet(drop);
      expect(cubit.state.set(drop)!.completedAt, isNotNull);
      const standard = r.SetTypeChoice.ofKind(r.SetKind.standard);
      expect(cubit.state.loggedRowsLostBy(s1, standard), 1);
      // Nothing logged to lose: no question.
      expect(
        cubit.state.loggedRowsLostBy(
          s2,
          const r.SetTypeChoice.ofKind(r.SetKind.myo),
        ),
        0,
      );
      expect(cubit.state.loggedRowsLostBy('missing', standard), 0);

      cubit.setSetType(s1, standard);
      expect(cubit.state.set(drop), isNull);
    });

    test('the row adds a drop at the lighter weight, and a mini-set', () async {
      final [s1, s2, ...] = await bench();
      cubit
        ..addSubSet(s1, r.SubSetKind.drop)
        ..addSubSet(s2, r.SubSetKind.mini)
        ..addSubSet('missing', r.SubSetKind.drop);
      final sets = benchSets();
      expect(
        [for (final set in sets.take(4)) set.weightKg],
        [100, 80, 100, 100],
      );
      expect(sets[1].parentSetId, s1);
      expect(sets[3].parentSetId, s2);
      expect(
        [
          for (final event in analytics.events)
            if (event.eventName == 'SetTrackerRow_SubSetAdded')
              event.parameters?['kind'],
        ],
        ['drop', 'mini'],
      );
    });

    test('deleting a set with drops says how many go', () async {
      final [s1, s2, ...] = await bench();
      cubit
        ..setSetType(s1, const r.SetTypeChoice.ofKind(r.SetKind.drop))
        ..addSubSet(s1, r.SubSetKind.drop);
      final removed = cubit.state.subSetsRemovedBy(s1);
      expect(removed, (drops: 2, minis: 0));
      expect(
        TrackerText.subSetsDeleted(l10n, removed),
        'This also deletes its 2 drop sets.',
      );
      expect(cubit.state.subSetsRemovedBy(s2), (drops: 0, minis: 0));
      expect(cubit.state.subSetsRemovedBy('missing'), (drops: 0, minis: 0));

      cubit.deleteSet(s1);
      expect(benchSets().any((set) => set.parentSetId == s1), isFalse);
    });
  });

  test('the split chip toggles between rows and pairs', () async {
    await cubit.userChanged(uid);
    await settle();
    await cubit.start(eventPrefix: 'x');
    cubit.addExercises([oneArmRow]);
    final exercise = cubit.state.session!.exercises.single;
    final count = exercise.sets.length;

    cubit.toggleSides(exercise.id);
    var sets = cubit.state.session!.exercises.single.sets;
    expect(sets, hasLength(count * 2));
    expect(
      [for (final set in sets.take(2)) set.sideRawValue],
      ['left', 'right'],
    );
    expect(analytics.last('SetTracker_Sides_Split').parameters, {
      'split': true,
    });

    cubit.toggleSides(exercise.id);
    sets = cubit.state.session!.exercises.single.sets;
    expect(sets, hasLength(count));
    expect(analytics.last('SetTracker_Sides_Split').parameters, {
      'split': false,
    });
    cubit.toggleSides('missing');
  });

  group('the rest picker', () {
    test('opens on the rest that would run, and Save keeps it', () async {
      final [s1, ...] = await bench();
      final member = cubit.state.card.single;
      // The bench's standing rest in the sample settings, else the type's.
      final initial = member.restPicker[s1]!;
      expect(initial, greaterThan(0));

      cubit.setCustomRest(s1, 135);
      expect(cubit.state.card.single.restPicker[s1], 135);
      expect(analytics.last('SetTrackerRow_RestChanged').parameters, {
        'seconds': 135,
        'cleared': false,
      });
      // Logging the set rests that long.
      cubit.toggleSet(s1);
      expect(
        cubit.state.restEnd!.difference(now),
        const Duration(seconds: 135),
      );
    });

    test('saving zero clears the rest set by hand', () async {
      final [s1, ...] = await bench();
      final initial = cubit.state.card.single.restPicker[s1];
      cubit
        ..setCustomRest(s1, 45)
        ..setCustomRest(s1, null);
      expect(cubit.state.card.single.restPicker[s1], initial);
      expect(analytics.last('SetTrackerRow_RestChanged').parameters, {
        'seconds': 0,
        'cleared': true,
      });
    });
  });

  test('the stopwatch writes the seconds held, and never logs', () async {
    await cubit.userChanged(uid);
    await settle();
    await cubit.start(eventPrefix: 'x');
    cubit.addExercises([plank]);
    final set = cubit.state.session!.exercises.single.sets.first;
    cubit
      ..stopwatchStopped(set.id, 45)
      ..stopwatchStopped('missing', 10);
    expect(cubit.state.set(set.id)!.durationSec, 45);
    expect(cubit.state.set(set.id)!.completedAt, isNull);
  });

  test('nothing happens before a workout', () async {
    await cubit.userChanged(uid);
    cubit
      ..setSetType('s', r.SetTypeChoice.warmup)
      ..addSubSet('s', r.SubSetKind.drop)
      ..toggleSides('e')
      ..setCustomRest('s', 60)
      ..stopwatchStopped('s', 30);
    expect(cubit.state.isActive, isFalse);
  });

  group('wording', () {
    WorkoutSetModel row({
      String? kind,
      String? parent,
      int? targetReps,
      int? reps,
      bool warmup = false,
    }) => WorkoutSetModel(
      id: 'r',
      authorId: uid,
      index: 1,
      isWarmup: warmup,
      dateCreated: now,
      kindRawValue: kind,
      parentSetId: parent,
      targetReps: targetReps,
      reps: reps,
    );

    test('chips under the number', () {
      expect(
        TrackerText.kindChip(l10n, row(kind: 'drop', parent: 'p')),
        'Drop',
      );
      expect(TrackerText.kindChip(l10n, row(parent: 'p')), 'Mini');
      expect(
        TrackerText.kindChip(l10n, row(kind: 'hold', parent: 'p')),
        'Hold',
      );
      expect(TrackerText.kindChip(l10n, row(kind: 'amrap')), 'Failure');
      expect(
        TrackerText.kindChip(l10n, row(kind: 'amrap', targetReps: 8)),
        'Failure 8+',
      );
      expect(
        TrackerText.kindChip(l10n, row(kind: 'amrap', warmup: true)),
        isNull,
      );
      expect(TrackerText.kindChip(l10n, row()), isNull);
    });

    test("a set to failure hints at its target's reps", () {
      expect(
        TrackerText.targetPlaceholder(row(kind: 'amrap', targetReps: 8)),
        '8+',
      );
      expect(
        TrackerText.targetPlaceholder(
          row(kind: 'amrap', targetReps: 8, reps: 5),
        ),
        isNull,
      );
      expect(TrackerText.targetPlaceholder(row(kind: 'amrap')), isNull);
      expect(TrackerText.targetPlaceholder(row()), isNull);
    });

    test('delete titles and names', () {
      expect(TrackerText.deleteTitle(l10n, row()), 'Delete Set');
      expect(
        TrackerText.deleteTitle(l10n, row(kind: 'drop', parent: 'p')),
        'Delete Drop Set',
      );
      expect(
        TrackerText.deleteTitle(l10n, row(parent: 'p')),
        'Delete Mini-Set',
      );
      for (final (kind, title) in [
        ('partials', 'Delete Partials'),
        ('stretch', 'Delete Stretch'),
        ('hold', 'Delete Hold'),
      ]) {
        expect(
          TrackerText.deleteTitle(l10n, row(kind: kind, parent: 'p')),
          title,
        );
      }
      expect(TrackerText.setName(l10n, row(), '2'), 'Set 2');
      expect(TrackerText.setName(l10n, row(warmup: true), 'W'), 'Warm-up set');
      expect(
        TrackerText.subSetsDeleted(l10n, (drops: 0, minis: 1)),
        'This also deletes its mini-set.',
      );
      expect(
        TrackerText.subSetsDeleted(l10n, (drops: 1, minis: 2)),
        'This also deletes its 3 drop sets and mini-sets.',
      );
    });

    test('every set type has a name', () {
      expect(
        [
          TrackerText.setType(l10n, r.SetTypeChoice.warmup),
          for (final kind in r.SetKind.values)
            TrackerText.setType(l10n, r.SetTypeChoice.ofKind(kind)),
        ],
        [
          'Warm-up',
          'Standard',
          'Drop Set',
          'Failure Set',
          'Myo Set',
          'Rest-pause',
          'Cluster',
          'Lengthened partials',
          'Loaded stretch',
          'Static hold',
        ],
      );
    });
  });
}
