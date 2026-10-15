import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_models/compound_models.dart'
    show WorkoutSessionModelKeys;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

void main() {
  const uid = sampleUserId;
  final now = DateTime.now();

  testWidgets('starts a template, logs sets, finishes and shows the summary, '
      'with the session saved exactly', (tester) async {
    final sessions = InMemoryWorkoutSessionRepository(sessions: const []);
    final users = InMemoryUserRepository(
      users: {uid: sampleUser(now: now)},
      settings: {uid: sampleUserSettings(now: now)},
    );
    final store = InMemoryActiveSessionStore();
    await tester.pumpWidget(
      App(
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: users,
        workoutSessionRepository: sessions,
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(
          workoutTemplates: sampleUserWorkoutTemplates,
          gymProfiles: sampleGymProfiles,
          workoutSettings: const [
            WorkoutSettings(authorId: uid, addSmartWarmUps: false),
          ],
        ),
        activeSessionStore: store,
      ),
    );
    await tester.pumpAndSettle();

    // Training › Workouts › My Upper Body › Start Workout.
    await tester.tap(find.text('Training').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Upper Body'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Workout'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutTrackerView), findsOneWidget);

    final cubit = BlocProvider.of<ActiveWorkoutCubit>(
      tester.element(find.byType(WorkoutTrackerView)),
    );
    String nextSetId() => (cubit.state.primaryAction! as r.LogSetAction).setId;

    // The first set: 60 kg × 8 on the keypad, logged with its ✓.
    final first = nextSetId();
    await tester.tap(find.byKey(ValueKey('cell-$first-weight')));
    await tester.pumpAndSettle();
    for (final key in ['6', '0', 'next', '8', 'done']) {
      await tester.tap(find.byKey(ValueKey('keypad-$key')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(cubit.state.set(first)!.completedAt, isNotNull);

    // Corrected while its rest runs: a rep more.
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.byTooltip('Add a rep'));
    await tester.pumpAndSettle();
    expect(cubit.state.set(first)!.reps, 9);

    // Skip the rest, once the button's lockout after it changed is over:
    // the card moves on to the next exercise.
    Future<void> lockout() => tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 450)),
    );
    await lockout();
    await tester.tap(find.textContaining('Skip Rest'));
    await tester.pumpAndSettle();
    final second = nextSetId();
    expect(
      cubit.state.exerciseHolding(second)!.name,
      isNot('Barbell Bench Press'),
    );

    // The second set from its row's circle.
    await tester.tap(find.byKey(ValueKey('cell-$second-weight')));
    await tester.pumpAndSettle();
    for (final key in ['4', '0', 'next', '1', '0', 'hide']) {
      await tester.tap(find.byKey(ValueKey('keypad-$key')));
      await tester.pump();
    }
    await tester.tap(find.byKey(ValueKey('done-$second')));
    await tester.pumpAndSettle();
    expect(cubit.state.set(second)!.completedAt, isNotNull);

    // Finish… › Finish.
    await tester.tap(find.byTooltip('Workout options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish Workout…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Good session');
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    // The summary, in the tracker's place.
    expect(find.byType(WorkoutTrackerView), findsNothing);
    final summary = tester.widget<WorkoutSessionDetailPage>(
      find.byType(WorkoutSessionDetailPage),
    );
    expect(summary.isWorkoutSummary, isTrue);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('My Upper Body'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);

    // Exactly what was finished, with the streak stamped.
    final finished = summary.session!;
    final stored = await sessions.session(uid, finished.id);
    expect(stored!.toFirestore(), {
      ...finished.toFirestore(),
      WorkoutSessionModelKeys.weekStreakCount: stored.weekStreakCount,
    });
    expect(stored.weekStreakCount, isNotNull);
    expect(stored.notes, 'Good session');
    expect(stored.endedAt, isNotNull);
    final logged = [for (final exercise in stored.exercises) ...exercise.sets];
    expect([for (final set in logged) set.id], [first, second]);
    expect(logged.first.weightKg, 60);
    expect(logged.first.reps, 9);
    expect(logged.last.reps, 10);
    expect(logged.every((set) => set.completedAt != null), isTrue);
    expect(await store.load(), isNull);

    // Done closes it, back to the template.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Start Workout'), findsOneWidget);
  });

  testWidgets('a workout under way is resumed from the bar over the tabs', (
    tester,
  ) async {
    final store = InMemoryActiveSessionStore();
    await store.save(
      ActiveSessionState(
        session: emptySession(authorId: uid, now: now, newId: () => 'kept'),
      ),
    );
    await tester.pumpWidget(
      App(
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: InMemoryUserRepository(
          users: {uid: sampleUser(now: now)},
        ),
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
        activeSessionStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActiveWorkoutBar), findsOneWidget);
    expect(find.text('Workout In Progress'), findsOneWidget);
    await tester.tap(find.text('Workout In Progress'));
    await tester.pumpAndSettle();
    expect(find.text('No Exercises'), findsOneWidget);

    // Discarding asks first, then forgets it.
    await tester.tap(find.byTooltip('Workout options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard Workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutTrackerView), findsNothing);
    expect(find.text('Workout In Progress'), findsNothing);
    expect(await store.load(), isNull);
  });
}
