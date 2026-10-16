import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../onboarding/cubit/helpers.dart';

const String uid = sampleUserId;

/// The workout's order and the card beyond its sets
/// (`WorkoutTrackerPresenter+Exercises`, `+Card`, `TrainingAccessory`):
/// Do Next, Do Later and the strip's moves, the progression note, Last
/// tap-to-fill, the bar's progress and Skip Rest, and Workout Settings.
void main() {
  final now = DateTime(2026, 10, 15, 18);
  final l10n = lookupAppLocalizations(const Locale('en'));
  late RecordingAnalytics analytics;
  late ActiveWorkoutCubit cubit;
  var ids = 0;
  var clock = now;

  setUp(() {
    ids = 0;
    clock = now;
    analytics = RecordingAnalytics();
    cubit = ActiveWorkoutCubit(
      sessions: InMemoryWorkoutSessionRepository(sessions: const []),
      users: InMemoryUserRepository(users: {uid: sampleUser(now: now)}),
      library: InMemoryTrainingLibraryRepository(
        workoutSettings: const [
          WorkoutSettings(authorId: uid, addSmartWarmUps: false),
        ],
      ),
      analytics: analytics.repository,
      store: InMemoryActiveSessionStore(),
      notifications: FakeNotificationsRepository(),
      copy: AppNotificationCopy(() => l10n),
      clock: () => clock,
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

  Future<void> start() async {
    await cubit.userChanged(uid);
    await settle();
    await cubit.start(
      template: sampleUserWorkoutTemplates.first,
      eventPrefix: 'x',
    );
  }

  List<String> order() => [
    for (final e in cubit.state.session!.exercises) e.templateId,
  ];

  /// Logs [setId] at 100 kg × 8.
  void log(String setId) {
    cubit
      ..openKeypad(setId, SetField.weight)
      ..keypadKey('1')
      ..keypadKey('0')
      ..keypadKey('0')
      ..keypadNext()
      ..keypadKey('8')
      ..keypadDone();
  }

  group('order', () {
    test('Do Later sends the card on; Do Next brings one up', () async {
      await start();
      final [bench, pulldown, press, ...] = cubit.state.session!.exercises;
      expect(cubit.state.card.single.canDoLater, isTrue);

      cubit.doLater(bench.id);
      expect(order().first, pulldown.templateId);
      expect(order().last, bench.templateId);
      expect(cubit.state.currentExerciseId, pulldown.id);
      expect(cubit.state.effect, isA<SelectionEffect>());
      expect(analytics.last('WorkoutTracker_Exercise_Moved').parameters, {
        'to': 'later',
      });

      cubit.doNext(bench.id);
      expect(order().take(2), [pulldown.templateId, bench.templateId]);
      expect(analytics.last('WorkoutTracker_Exercise_Moved').parameters, {
        'to': 'next',
      });
      expect(press.id, isNotEmpty);
    });

    test('Move Earlier and Later step a block, its place announced', () async {
      await start();
      final [bench, pulldown, ...] = cubit.state.session!.exercises;
      cubit.moveBlock(pulldown.id, 0);
      expect(order().first, pulldown.templateId);
      // The card stays on the exercise it showed.
      expect(cubit.state.currentExerciseId, bench.id);
      expect(cubit.state.effect, const BlockMovedEffect(1, 5));
      expect(analytics.last('WorkoutTracker_Exercise_Reordered').parameters, {
        'from': 1,
        'to': 0,
      });

      // A move that changes nothing says nothing.
      analytics.events.clear();
      cubit.moveBlock(pulldown.id, 0);
      expect(analytics.names, isEmpty);
    });
  });

  group('the card', () {
    test('the progression note shows until read or started', () async {
      await start();
      expect(cubit.state.card.single.showsProgressionNote, isTrue);
      cubit.acknowledgeProgressionNote();
      expect(cubit.state.card.single.showsProgressionNote, isFalse);
      expect(
        analytics.names,
        contains('WorkoutTracker_ProgressionNote_Acknowledged'),
      );

      // The next exercise starts with its own; a logged set ends it.
      final pulldown = cubit.state.session!.exercises[1];
      cubit.selectExercise(pulldown.id);
      expect(cubit.state.card.single.showsProgressionNote, isTrue);
      log(pulldown.sets.first.id);
      cubit.selectExercise(pulldown.id);
      expect(cubit.state.card.single.showsProgressionNote, isFalse);
    });

    test('a tap on Last fills an open set with last time', () async {
      await start();
      final bench = cubit.state.session!.exercises.first;
      log(bench.sets.first.id);
      await cubit.finish(firstWeekday: DateTime.monday);
      await settle();

      clock = now.add(const Duration(days: 1));
      await cubit.start(
        template: sampleUserWorkoutTemplates.first,
        eventPrefix: 'x',
      );
      await settle();
      final set = cubit.state.session!.exercises.first.sets.first;
      expect(cubit.state.card.single.previous, isNotNull);
      cubit
        ..openKeypad(set.id, SetField.reps)
        ..keypadKey('3')
        ..closeKeypad()
        ..fillFromPrevious(set.id);
      expect(cubit.state.set(set.id)!.reps, 8);
      expect(cubit.state.set(set.id)!.weightKg, 100);
      expect(analytics.last('SetTrackerRow_SetFilled').parameters, {
        'source': 'last',
      });

      // Not a logged set, nor one with no last time.
      log(set.id);
      cubit
        ..openKeypad(set.id, SetField.reps)
        ..keypadKey('5')
        ..keypadDone()
        ..fillFromPrevious(set.id)
        ..fillFromPrevious('missing');
      expect(cubit.state.set(set.id)!.reps, 5);
      final pulldown = cubit.state.session!.exercises[1].sets.first;
      analytics.events.clear();
      cubit.fillFromPrevious(pulldown.id);
      expect(analytics.names, isEmpty);
    });
  });

  group('the bar over the tabs', () {
    test('counts working sets, and skips the rest', () async {
      await start();
      expect(cubit.state.setProgress, (done: 0, total: 5));
      log(cubit.state.session!.exercises.first.sets.first.id);
      expect(cubit.state.setProgress, (done: 1, total: 5));
      expect(cubit.state.restEnd, isNotNull);

      cubit.skipRestFromBar();
      expect(cubit.state.slotAt(clock), isNot(isA<r.SlotSkipRest>()));
      expect(analytics.names, contains('TrainingAccessory_SkipRest'));
      expect(analytics.names, isNot(contains('WorkoutTracker_Rest_Skipped')));
    });

    test('nothing without a workout', () {
      cubit
        ..skipRestFromBar()
        ..doLater('x')
        ..moveBlock('x', 0)
        ..acknowledgeProgressionNote()
        ..workoutSettingsOpened();
      expect(cubit.state.setProgress, (done: 0, total: 0));
      expect(analytics.names, ['WorkoutTracker_WorkoutSettings_Opened']);
    });
  });
}
