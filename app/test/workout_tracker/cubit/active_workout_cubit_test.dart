import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

class _MockAnalytics extends Mock implements AnalyticsRepository;

class _FakeEvent extends Fake implements LoggableEvent;

/// A clock the test moves by hand.
class _Clock {
  DateTime now = DateTime(2026, 10, 15, 18);

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

const String uid = sampleUserId;

void main() {
  setUpAll(() => registerFallbackValue(_FakeEvent()));

  late _Clock clock;
  late InMemoryWorkoutSessionRepository sessions;
  late InMemoryUserRepository users;
  late InMemoryTrainingLibraryRepository library;
  late InMemoryActiveSessionStore store;
  late _MockAnalytics analytics;
  late ActiveWorkoutCubit cubit;
  var ids = 0;

  final template = sampleUserWorkoutTemplates.first;

  ActiveWorkoutCubit build() => ActiveWorkoutCubit(
    sessions: sessions,
    users: users,
    library: library,
    analytics: analytics,
    store: store,
    clock: clock.call,
    newId: () => 'ID-${++ids}',
    wait: (_) async {},
  );

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  List<String> events() => [
    for (final call in verify(
      () => analytics.trackEvent(captureAny()),
    ).captured)
      (call as LoggableEvent).eventName,
  ];

  setUp(() {
    clock = _Clock();
    ids = 0;
    sessions = InMemoryWorkoutSessionRepository(sessions: const []);
    users = InMemoryUserRepository(users: {uid: sampleUser(now: clock.now)});
    library = InMemoryTrainingLibraryRepository(
      workoutSettings: const [
        WorkoutSettings(authorId: uid, addSmartWarmUps: false),
      ],
    );
    store = InMemoryActiveSessionStore();
    analytics = _MockAnalytics();
    cubit = build();
  });

  tearDown(() => cubit.close());

  /// Types 60 kg × 8 into the next set, as a set with no history starts
  /// empty.
  void fillNext() {
    final action = cubit.state.primaryAction;
    if (action is! r.LogSetAction) return;
    cubit
      ..openKeypad(action.setId, SetField.weight)
      ..keypadKey('6')
      ..keypadKey('0')
      ..keypadNext()
      ..keypadKey('8')
      ..closeKeypad();
  }

  /// Logs the next set with the bottom button, past its tap lockout, and
  /// skips the rest that follows.
  void logNext() {
    clock.advance(const Duration(minutes: 1));
    final action = cubit.state.slotAt(clock.now);
    expect(action, isA<r.SlotLog>());
    fillNext();
    cubit.pressPrimary();
    clock.advance(const Duration(seconds: 1));
    if (cubit.state.slotAt(clock.now) is r.SlotSkipRest) cubit.skipRest();
  }

  group(ActiveWorkoutCubit, () {
    test('starts with nothing under way, then follows the user', () async {
      expect(cubit.state.status, ActiveWorkoutStatus.none);
      await cubit.userChanged(uid);
      expect(cubit.state.status, ActiveWorkoutStatus.none);
      await cubit.userChanged(null);
      expect(cubit.state, const ActiveWorkoutState());
    });

    test('starts a workout from a template, prefilled and kept', () async {
      await cubit.userChanged(uid);
      await settle();
      await cubit.start(
        template: template,
        eventPrefix: 'WorkoutTemplateDetailView_StartWorkout',
      );

      final state = cubit.state;
      expect(state.isActive, isTrue);
      expect(state.session!.workoutTemplateId, template.workoutId);
      expect(state.session!.exercises, hasLength(template.exercises.length));
      expect(
        state.card.single.exercise.name,
        template.exercises.first.exercise.name,
      );
      expect(state.primaryAction, isA<r.LogSetAction>());
      expect(state.strip, hasLength(template.exercises.length));
      expect((await store.load())!.session.id, state.session!.id);
      expect(
        events(),
        containsAllInOrder([
          'WorkoutTemplateDetailView_StartWorkout_Start',
          'WorkoutTemplateDetailView_StartWorkout_Success',
        ]),
      );
    });

    test('starts an empty workout', () async {
      await cubit.userChanged(uid);
      await cubit.start(eventPrefix: 'TodayView_StartBlankWorkout');
      expect(cubit.state.session!.exercises, isEmpty);
      expect(cubit.state.session!.name, 'Workout');
      expect(cubit.state.primaryAction, isNull);
    });

    test('logs a set: stamped, rest started, kept, reported', () async {
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      final setId = (cubit.state.primaryAction! as r.LogSetAction).setId;

      clock.advance(const Duration(minutes: 1));
      fillNext();
      cubit.pressPrimary();

      final logged = cubit.state.set(setId)!;
      expect(logged.completedAt, clock.now);
      expect(cubit.state.effect, isA<SetLoggedEffect>());
      expect(cubit.state.restEnd, isNotNull);
      expect(cubit.state.slotAt(clock.now), isA<r.SlotSkipRest>());
      expect(cubit.state.correction?.setId, setId);
      await settle();
      final kept = await store.load();
      expect(
        kept!.session.exercises.first.sets
            .firstWhere((s) => s.id == setId)
            .completedAt
            ?.isAtSameMomentAs(clock.now),
        isTrue,
      );
      expect(events(), contains('SetTrackerRow_SetCompleted'));
    });

    test('drops a tap made just after the button changed', () async {
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      clock.advance(const Duration(minutes: 1));
      fillNext();
      cubit.pressPrimary();
      final restEnd = cubit.state.restEnd;

      clock.advance(const Duration(milliseconds: 100));
      cubit.pressPrimary();

      expect(cubit.state.restEnd, restEnd);
    });

    test('refuses a set with no reps', () async {
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      final setId = (cubit.state.primaryAction! as r.LogSetAction).setId;
      cubit
        ..openKeypad(setId, SetField.reps)
        ..keypadBackspace()
        ..keypadDone();

      expect(cubit.state.effect, const LogRefusedEffect(r.SetProblem.noReps));
      expect(cubit.state.set(setId)!.completedAt, isNull);
      expect(cubit.state.keypad, isNotNull);
    });

    test('the keypad types into the set and logs it on ✓', () async {
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      final setId = (cubit.state.primaryAction! as r.LogSetAction).setId;

      cubit
        ..openKeypad(setId, SetField.weight)
        ..keypadKey('6')
        ..keypadKey('2')
        ..keypadKey('.')
        ..keypadKey('5');
      expect(cubit.state.set(setId)!.weightKg, 62.5);
      expect(cubit.state.keypad!.text, '62.5');

      cubit.keypadNext();
      expect(cubit.state.keypad!.field, SetField.reps);
      cubit
        ..keypadKey('9')
        ..keypadRir(2);
      expect(cubit.state.set(setId)!.reps, 9);
      expect(cubit.state.set(setId)!.rpe, 8);

      cubit.keypadDone();
      expect(cubit.state.keypad, isNull);
      expect(cubit.state.set(setId)!.completedAt, isNotNull);
    });

    test('steps the weight on the equipment', () async {
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      final setId = (cubit.state.primaryAction! as r.LogSetAction).setId;
      cubit
        ..openKeypad(setId, SetField.weight)
        ..keypadBackspace()
        ..keypadStep(up: true);
      final first = cubit.state.set(setId)!.weightKg!;
      cubit.keypadStep(up: true);
      expect(cubit.state.set(setId)!.weightKg, greaterThan(first));
      cubit.keypadStep(up: false);
      expect(cubit.state.set(setId)!.weightKg, first);
      cubit.closeKeypad();
      expect(cubit.state.keypad, isNull);
    });

    test('corrects the set just logged, and undoes it', () async {
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      final setId = (cubit.state.primaryAction! as r.LogSetAction).setId;
      clock.advance(const Duration(minutes: 1));
      fillNext();
      cubit.pressPrimary();
      final reps = cubit.state.set(setId)!.reps!;

      cubit.correctReps(setId, 1);
      expect(cubit.state.set(setId)!.reps, reps + 1);
      cubit.setRir(setId, 1);
      expect(cubit.state.set(setId)!.rpe, 9);
      expect(cubit.state.correction!.selectedRir, 1);

      cubit.undo();
      expect(cubit.state.set(setId)!.reps, reps);
      cubit.undo();
      expect(cubit.state.set(setId)!.completedAt, isNull);
      expect(cubit.state.restEnd, isNull);
      expect(
        events(),
        containsAll([
          'WorkoutTracker_Correction_Reps',
          'WorkoutTracker_Correction_RIR',
          'WorkoutTracker_Correction_Undo',
        ]),
      );
    });

    test('adds and deletes sets and exercises', () async {
      await cubit.userChanged(uid);
      await cubit.start(eventPrefix: 'x');
      final bench = PrebuiltCatalogue.instance.exercises.first;
      cubit.addExercises([bench]);
      final exercise = cubit.state.session!.exercises.single;
      expect(exercise.templateId, bench.id);
      expect(exercise.sets, hasLength(1));

      cubit.addSet(exercise.id);
      expect(cubit.state.exercise(exercise.id)!.sets, hasLength(2));
      cubit.deleteSet(cubit.state.exercise(exercise.id)!.sets.last.id);
      expect(cubit.state.effect, isA<SetDeletedEffect>());
      expect(cubit.state.exercise(exercise.id)!.sets, hasLength(1));
      cubit.undo();
      expect(cubit.state.exercise(exercise.id)!.sets, hasLength(2));

      cubit.deleteExercise(exercise.id);
      expect(cubit.state.session!.exercises, isEmpty);
    });

    test("saves notes: the session's, and the exercise's for every "
        'workout', () async {
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      final exercise = cubit.state.session!.exercises.first;

      cubit.setWorkoutNotes('  Felt strong ');
      expect(cubit.state.session!.notes, 'Felt strong');
      await cubit.saveExerciseNotes(
        exercise.id,
        sessionNote: 'Elbows in',
        exerciseNote: 'Seat 4',
      );
      await settle();

      expect(cubit.state.exercise(exercise.id)!.notes, 'Elbows in');
      final saved = await library.watchExerciseSettings(uid).first;
      expect(saved.single.id, exercise.templateId);
      expect(saved.single.note, 'Seat 4');
      expect(cubit.state.card.first.exerciseNote, 'Seat 4');
    });

    test('pauses and resumes the clock', () async {
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      clock.advance(const Duration(minutes: 10));
      cubit.togglePause();
      expect(cubit.state.slotAt(clock.now), isA<r.SlotResume>());
      clock.advance(const Duration(minutes: 5));
      expect(cubit.state.elapsedAt(clock.now), const Duration(minutes: 10));
      cubit.pressPrimary();
      expect(cubit.state.isPaused, isFalse);
      expect(cubit.state.elapsedAt(clock.now), const Duration(minutes: 10));
    });

    test('finishing saves exactly the logged sets, then the streak', () async {
      await cubit.userChanged(uid);
      await settle();
      await cubit.start(template: template, eventPrefix: 'x');
      logNext();
      logNext();
      final logged = [
        for (final e in cubit.state.session!.exercises)
          for (final s in e.sets)
            if (s.completedAt != null) s.id,
      ];
      expect(logged, hasLength(2));
      clock.advance(const Duration(minutes: 5));
      final end = clock.now;

      await cubit.finish(firstWeekday: DateTime.monday);
      await settle();

      final finished = cubit.state.finishedSession!;
      expect(finished.endedAt, end);
      expect([
        for (final e in finished.exercises)
          for (final s in e.sets) s.id,
      ], logged);
      final stored = await sessions.session(uid, finished.id);
      expect(stored!.toFirestore(), {
        ...finished.toFirestore(),
        // One session in a week still under way: no full week yet.
        WorkoutSessionModelKeys.weekStreakCount: 0,
      });
      final settings = await users.watchPrivateSettings(uid).first;
      expect(settings!.weekSessions, 1);
      expect(settings.lastTrainedAt, finished.dateCreated);
      expect(await store.load(), isNull);
      expect(cubit.state.isActive, isFalse);
      expect(
        events(),
        containsAllInOrder([
          'WorkoutTrackerView_FinishWorkout_Start',
          'Workout_Finished',
          'WorkoutTrackerView_FinishWorkout_Success',
        ]),
      );

      cubit.summaryShown();
      expect(cubit.state.finishedSession, isNull);
    });

    test('a failed save keeps the workout on the device to resume', () async {
      final failing = _FailingSessions();
      cubit = ActiveWorkoutCubit(
        sessions: failing,
        users: users,
        library: library,
        analytics: analytics,
        store: store,
        clock: clock.call,
        wait: (_) async {},
      );
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      logNext();

      await cubit.finish(firstWeekday: DateTime.monday);
      await settle();

      expect(cubit.state.saveNotice, SaveProgress.failed);
      expect(await store.load(), isNotNull);
      expect(cubit.state.isActive, isTrue);
      expect(events(), contains('WorkoutTrackerView_FinishWorkout_Fail'));
    });

    test('discarding forgets the workout', () async {
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      await cubit.discard();
      expect(cubit.state.isActive, isFalse);
      expect(await store.load(), isNull);
      expect(await sessions.watchSessions(uid).first, isEmpty);
    });

    test(
      'carries on the workout kept on the device after a relaunch',
      () async {
        await cubit.userChanged(uid);
        await cubit.start(template: template, eventPrefix: 'x');
        logNext();
        final id = cubit.state.session!.id;
        cubit.flush();
        await settle();
        await cubit.close();

        cubit = build();
        await cubit.userChanged(uid);
        expect(cubit.state.isActive, isTrue);
        expect(cubit.state.session!.id, id);
        expect(cubit.state.hasLoggedSet, isTrue);
      },
    );

    test("leaves someone else's workout alone", () async {
      await cubit.userChanged('someone-else');
      await cubit.start(template: template, eventPrefix: 'x');
      await cubit.close();

      cubit = build();
      await cubit.userChanged(uid);
      expect(cubit.state.isActive, isFalse);
    });

    testWidgets('ends the rest when it runs out, with a moment of grace', (
      tester,
    ) async {
      await cubit.userChanged(uid);
      await cubit.start(template: template, eventPrefix: 'x');
      clock.advance(const Duration(minutes: 1));
      fillNext();
      cubit.pressPrimary();
      final end = cubit.state.restEnd!;
      final setId = cubit.state.correction!.setId;
      final card = cubit.state.currentExerciseId;

      final loggedAt = clock.now;
      clock.now = end;
      await tester.pump(end.difference(loggedAt));
      expect(cubit.state.restEnd, isNull);
      expect(cubit.state.restStartedAt, isNotNull);
      expect(cubit.state.isInGraceAt(end), isTrue);
      // The exercise is done, so the card moves on, and the set logged
      // last is no longer on it: no correction bar.
      expect(cubit.state.currentExerciseId, isNot(card));
      expect(cubit.state.correction, isNull);
      cubit.selectExercise(card!);
      expect(cubit.state.correction?.setId, setId);

      await tester.pump(const Duration(seconds: 1));
      expect(cubit.state.graceEnd, isNull);
    });
  });
}

class _FailingSessions extends InMemoryWorkoutSessionRepository {
  new() : super(sessions: const []);

  @override
  Future<void> saveSession(String uid, WorkoutSessionModel session) =>
      Future.error(Exception('denied'));
}
