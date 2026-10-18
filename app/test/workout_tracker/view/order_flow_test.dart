@Timeout(Duration(seconds: 30))
library;

import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/settings/training/view/workout_settings_page.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/app_repositories.dart';

/// The workout's order and the card beyond its sets, through the whole app
/// on the staging data: the strip's menu, Do Later, the progression note,
/// Last tap-to-fill, last time's note, Workout Settings and the bar over
/// the tabs.
void main() {
  const uid = sampleUserId;

  /// Bench press, then a failure set the plan asks for.
  final planned = WorkoutTemplateModel.fromFirestore({
    ...sampleUserWorkoutTemplates.first.toFirestore(),
    'exercises': [
      for (final (index, exercise)
          in sampleUserWorkoutTemplates.first.exercises.indexed)
        if (index == 0)
          exercise
              .copyWith(
                setTargets: const [
                  SetTarget(id: 't1', setNumber: 1, minReps: 8, maxReps: 12),
                  SetTarget(
                    id: 't2',
                    setNumber: 2,
                    minReps: 8,
                    maxReps: 12,
                    setType: SetTargetSetType.failure,
                    amrapTargetReps: 8,
                  ),
                ],
              )
              .toFirestore()
        else
          exercise.toFirestore(),
    ],
  });

  Future<ActiveWorkoutCubit> start(
    WidgetTester tester, {
    bool setPlanning = false,
  }) async {
    final now = DateTime.now();
    final history = [
      for (final session in sampleWorkoutSessions(uid: uid, now: now))
        session.copyWith(
          exercises: [
            for (final exercise in session.exercises)
              if (exercise.templateId == 'system-barbell-bench-press')
                exercise.copyWith(notes: 'Elbows in')
              else
                exercise,
          ],
        ),
    ];
    await tester.pumpWidget(
      App(
        socialRepository: emptySocialRepository(),
        coachRepository: silentCoachRepository(),
        purchasesRepository: FakePurchasesRepository(),
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: InMemoryUserRepository(
          users: {uid: sampleUser(now: now)},
          settings: {uid: sampleUserSettings(now: now)},
        ),
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: history,
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(
          workoutTemplates: [planned],
          gymProfiles: sampleGymProfiles,
          workoutSettings: [
            WorkoutSettings(
              authorId: uid,
              addSmartWarmUps: false,
              setPlanning: setPlanning,
            ),
          ],
        ),
        activeSessionStore: InMemoryActiveSessionStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Training').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Workouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Upper Body'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Workout'));
    await tester.pumpAndSettle();
    return BlocProvider.of<ActiveWorkoutCubit>(
      tester.element(find.byType(WorkoutTrackerView)),
    );
  }

  List<String> order(ActiveWorkoutCubit cubit) => [
    for (final e in cubit.state.session!.exercises) e.templateId,
  ];

  testWidgets('the strip moves blocks; Do Later puts the card off', (
    tester,
  ) async {
    final cubit = await start(tester);
    final [bench, pulldown, press, ...] = cubit.state.session!.exercises;

    // Do Next on the third tile brings it straight after the card.
    await tester.longPress(find.byKey(ValueKey('strip-${press.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Do Later'), findsOneWidget);
    expect(find.text('Move Earlier'), findsOneWidget);
    await tester.tap(find.text('Do Next'));
    await tester.pumpAndSettle();
    expect(order(cubit).take(3), [
      bench.templateId,
      press.templateId,
      pulldown.templateId,
    ]);

    // The card's own tile offers only the steps.
    await tester.longPress(find.byKey(ValueKey('strip-${bench.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Do Next'), findsNothing);
    expect(find.text('Move Earlier'), findsNothing);
    await tester.tap(find.text('Move Later'));
    await tester.pumpAndSettle();
    expect(order(cubit).take(2), [press.templateId, bench.templateId]);
    expect(cubit.state.currentExerciseId, bench.id);

    // Do Later from the card's menu: the card moves on.
    await tester.tap(find.byTooltip('Exercise options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Do Later'));
    await tester.pumpAndSettle();
    expect(order(cubit).last, bench.templateId);
    expect(cubit.state.currentExerciseId, isNot(bench.id));
  });

  testWidgets('the plan note shows over the sets until tapped', (tester) async {
    final cubit = await start(tester, setPlanning: true);
    final note = find.byKey(const Key('ExerciseCard.progressionNote'));
    expect(note, findsOneWidget);
    expect(find.textContaining('Set 2 is to failure, target 8+.'), findsOne);
    expect(find.text('Tap to dismiss'), findsOneWidget);

    // The method opens beside the label and leaves the note up.
    await tester.tap(find.byTooltip('How Smart Progression is calculated'));
    await tester.pumpAndSettle();
    expect(find.byType(MethodInfoSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(MethodInfoSheet))).pop();
    await tester.pumpAndSettle();
    expect(note, findsOneWidget);

    await tester.tap(note);
    await tester.pumpAndSettle();
    expect(note, findsNothing);
    expect(cubit.state.card.single.showsProgressionNote, isFalse);
  });

  testWidgets("Last fills a set; the notes sheet shows last time's note", (
    tester,
  ) async {
    final cubit = await start(tester);
    final set = cubit.state.card.single.exercise.sets.first;
    cubit
      ..openKeypad(set.id, SetField.reps)
      ..keypadKey('3')
      ..closeKeypad();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('last-${set.id}')));
    await tester.pumpAndSettle();
    expect(cubit.state.set(set.id)!.reps, 8);
    expect(cubit.state.set(set.id)!.weightKg, 80);

    await tester.tap(find.byTooltip('Exercise options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes').last);
    await tester.pumpAndSettle();
    expect(find.text('Last time: Elbows in'), findsOneWidget);
  });

  testWidgets('Workout Settings opens from the menu', (tester) async {
    await start(tester);
    await tester.tap(find.byTooltip('Workout options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workout Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutSettingsPage), findsOneWidget);
  });

  testWidgets('the bar over the tabs shows progress and skips the rest', (
    tester,
  ) async {
    final cubit = await start(tester);
    final set = cubit.state.card.single.exercise.sets.first;
    cubit.toggleSet(set.id);
    await tester.pump();
    expect(cubit.state.slotAt(DateTime.now()), isA<r.SlotSkipRest>());

    await tester.tap(find.byTooltip('Minimize workout'));
    await tester.pumpAndSettle();
    final progress = cubit.state.setProgress;
    expect(progress.done, 1);
    expect(find.text('1/${progress.total} sets'), findsOneWidget);
    expect(find.text('Push Day'), findsNothing);
    await tester.tap(find.byKey(const Key('ActiveWorkoutBar.skipRest')));
    await tester.pump();
    expect(find.byKey(const Key('ActiveWorkoutBar.skipRest')), findsNothing);
    expect(cubit.state.slotAt(DateTime.now()), isNot(isA<r.SlotSkipRest>()));
  });
}
