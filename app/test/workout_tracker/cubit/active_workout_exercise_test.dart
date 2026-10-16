import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/library_fixtures.dart';
import '../../onboarding/cubit/helpers.dart';

const String uid = sampleUserId;

/// The exercise's menu on the tracker (`ExerciseTrackerPresenter`): the
/// unit menus of SetTrackerPresenterTests, Swap (`insertSwappedExercise`)
/// and the session's Targets.
void main() {
  final now = DateTime(2026, 10, 15, 18);
  final l10n = lookupAppLocalizations(const Locale('en'));
  late RecordingAnalytics analytics;
  late UnitPreferenceStore units;
  late ActiveWorkoutCubit cubit;
  var ids = 0;

  final run = ExerciseModel.fromFirestore({
    ...fixtureLibraryExercise('Run').toFirestore(),
    'author_id': uid,
    'trackable_metrics': ['distanceLong', 'duration'],
  });

  setUp(() {
    ids = 0;
    analytics = RecordingAnalytics();
    units = UnitPreferenceStore();
    cubit = ActiveWorkoutCubit(
      sessions: InMemoryWorkoutSessionRepository(sessions: const []),
      users: InMemoryUserRepository(users: {uid: sampleUser(now: now)}),
      library: InMemoryTrainingLibraryRepository(
        exercises: [run],
        workoutSettings: const [
          WorkoutSettings(authorId: uid, addSmartWarmUps: false),
        ],
      ),
      analytics: analytics.repository,
      store: InMemoryActiveSessionStore(),
      notifications: FakeNotificationsRepository(),
      copy: AppNotificationCopy(() => l10n),
      units: units,
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

  /// My Upper Body under way; the bench press's first set at 100 kg × 8.
  Future<WorkoutExerciseModel> bench() async {
    await cubit.userChanged(uid);
    await settle();
    await cubit.start(
      template: sampleUserWorkoutTemplates.first,
      eventPrefix: 'x',
    );
    final set = cubit.state.session!.exercises.first.sets.first;
    cubit
      ..openKeypad(set.id, SetField.weight)
      ..keypadKey('1')
      ..keypadKey('0')
      ..keypadKey('0')
      ..keypadNext()
      ..keypadKey('8')
      ..closeKeypad();
    return cubit.state.session!.exercises.first;
  }

  WorkoutExerciseModel first() => cubit.state.session!.exercises.first;

  group('units', () {
    test(
      'Display Only changes the unit everywhere and leaves the weights',
      () async {
        final exercise = await bench();
        expect(
          cubit.state.card.single.weightUnit,
          ExerciseWeightUnit.kilograms,
        );

        cubit.changeWeightUnit(
          exercise.id,
          ExerciseWeightUnit.pounds,
          convert: false,
        );
        expect(first().weightUnit, ExerciseWeightUnit.pounds);
        expect(first().sets.first.weightKg, 100);
        expect(cubit.state.card.single.weightUnit, ExerciseWeightUnit.pounds);
        expect(
          units.of(uid, exercise.templateId).weightUnit,
          ExerciseWeightUnit.pounds,
        );
        expect(units.of(uid, exercise.templateId).weightUnitIsChosen, isTrue);
        expect(cubit.state.effect, isA<SelectionEffect>());
        expect(analytics.last('SetTracker_Unit_Changed').parameters, {
          'unit': 'pounds',
        });
      },
    );

    test('Convert Values rounds the open weights in the new unit', () async {
      final exercise = await bench();
      cubit.changeWeightUnit(
        exercise.id,
        ExerciseWeightUnit.pounds,
        convert: true,
      );
      final pounds = first().sets.first.weightKg! / 0.45359237;
      expect(pounds, closeTo(pounds.roundToDouble(), 0.001));
      expect(first().sets.first.weightKg, isNot(100));
      expect(analytics.names, isNot(contains('SetTracker_Unit_Changed')));
    });

    test('an exercise never set reads the profile units', () async {
      await cubit.userChanged(uid);
      await settle();
      units.setWeightUnit(
        uid,
        'system-barbell-bench-press',
        ExerciseWeightUnit.pounds,
      );
      await cubit.start(
        template: sampleUserWorkoutTemplates.first,
        eventPrefix: 'x',
      );
      // Chosen for the bench press, so a new session enters pounds.
      expect(first().weightUnit, ExerciseWeightUnit.pounds);
    });

    test('a distance unit is kept, and converts the open distances', () async {
      await cubit.userChanged(uid);
      await settle();
      await cubit.start(eventPrefix: 'x');
      cubit.addExercises([run]);
      final exercise = first();
      final set = exercise.sets.first;
      cubit
        ..openKeypad(set.id, SetField.distance)
        ..keypadKey('5')
        ..keypadKey('4')
        ..keypadKey('3')
        ..keypadKey('2')
        ..closeKeypad();
      expect(cubit.state.set(set.id)!.distanceMeters, 5432);

      cubit.changeDistanceUnit(exercise.id, DistanceUnit.miles, convert: false);
      expect(cubit.state.card.single.distanceUnit, DistanceUnit.miles);
      expect(cubit.state.set(set.id)!.distanceMeters, 5432);
      expect(analytics.last('SetTracker_Unit_Changed').parameters, {
        'unit': 'miles',
      });

      // The keypad types miles now.
      cubit.openKeypad(set.id, SetField.distance);
      expect(cubit.state.keypad!.text, '3.38');
      cubit
        ..keypadKey('1')
        ..closeKeypad();
      expect(cubit.state.set(set.id)!.distanceMeters, 1609.344);

      cubit.changeDistanceUnit(exercise.id, DistanceUnit.meters, convert: true);
      expect(cubit.state.set(set.id)!.distanceMeters, 1609);
      expect(units.of(uid, run.id).distanceUnit, DistanceUnit.meters);
    });

    test('nothing changes without a workout or with an unknown exercise', () {
      cubit
        ..changeWeightUnit('x', ExerciseWeightUnit.pounds, convert: true)
        ..changeDistanceUnit('x', DistanceUnit.miles, convert: true)
        ..swapExercise('x', run)
        ..setTargets('x', const []);
      expect(units.of(uid, 'x').weightUnitIsChosen, isFalse);
      expect(cubit.state.session, isNull);
    });
  });

  group('swap and targets', () {
    test(
      'a swap keeps logged sets and moves the card to the replacement',
      () async {
        final exercise = await bench();
        cubit
          ..swapOpened()
          ..toggleSet(exercise.sets.first.id)
          ..swapExercise(exercise.id, run);
        final exercises = cubit.state.session!.exercises;
        expect(exercises[0].id, exercise.id);
        expect(exercises[0].sets, hasLength(1));
        expect(exercises[1].templateId, run.id);
        expect(cubit.state.currentExerciseId, exercises[1].id);
        expect(analytics.names, contains('SetTracker_Swap_Opened'));
        expect(analytics.last('WorkoutTracker_Exercise_Swapped').parameters, {
          'kept_logged_sets': true,
        });
      },
    );

    test("Targets sets this workout's targets", () async {
      final exercise = await bench();
      cubit
        ..targetsOpened()
        ..setTargets(exercise.id, [
          const SetTarget(id: 't1', setNumber: 1, minReps: 5, maxReps: 5),
        ])
        ..exerciseSettingsOpened();
      expect(first().setTargets.single.maxReps, 5);
      expect(
        analytics.names,
        containsAll([
          'SetTracker_Targets_Opened',
          'SetTracker_ExerciseSettings_Opened',
        ]),
      );
    });
  });
}
