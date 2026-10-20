@Timeout(Duration(seconds: 30))
library;

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/create_exercise/create_exercise.dart';
import 'package:compound/settings/training/view/rest_timer_settings_page.dart';
import 'package:compound/workout_editor/view/set_target_page.dart';
import 'package:compound/workout_tracker/view/exercise_settings_page.dart';
import 'package:compound/workout_tracker/view/swap_exercise_picker.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/app_repositories.dart';
import '../../helpers/library_fixtures.dart';
import '../../helpers/social_world.dart';

/// The exercise's menu through the whole app on the staging data: Swap,
/// Targets, the unit headings and Exercise Settings.
void main() {
  const uid = sampleUserId;

  final row = ExerciseModel.fromFirestore({
    ...fixtureLibraryExercise('One-Arm Row').toFirestore(),
    'author_id': uid,
    'trackable_metrics': ['weight', 'repsPerSide'],
    'description': 'Brace on a bench.',
  });

  late InMemoryTrainingLibraryRepository library;
  late UnitPreferenceStore units;

  Future<ActiveWorkoutCubit> start(WidgetTester tester) async {
    library = InMemoryTrainingLibraryRepository(
      exercises: [row],
      workoutTemplates: sampleUserWorkoutTemplates,
      gymProfiles: sampleGymProfiles,
      workoutSettings: const [
        WorkoutSettings(
          authorId: uid,
          addSmartWarmUps: false,
          restBetweenSideSets: true,
        ),
      ],
    );
    units = UnitPreferenceStore();
    await tester.pumpWidget(
      App(
        socialRepository: emptySocialRepository(),
        coachRepository: silentCoachRepository(),
        purchasesRepository: FakePurchasesRepository(),
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: InMemoryUserRepository(
          users: {uid: sampleUser(now: DateTime.now())},
          settings: {uid: sampleUserSettings(now: DateTime.now())},
        ),
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: library,
        activeSessionStore: InMemoryActiveSessionStore(),
        unitPreferences: units,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Training').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Workouts'));
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

  Future<void> menu(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Exercise options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Swap puts another exercise on the card', (tester) async {
    final cubit = await start(tester);
    final first = cubit.state.card.single.exercise;

    await menu(tester, 'Swap');
    expect(find.byType(SwapExercisePicker), findsOneWidget);
    expect(find.text('Swap Exercise'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'one-arm');
    await tester.pumpAndSettle();
    await tester.tap(find.text('One-Arm Row'));
    await tester.pumpAndSettle();

    expect(find.byType(SwapExercisePicker), findsNothing);
    final swapped = cubit.state.card.single.exercise;
    expect(swapped.templateId, row.id);
    expect(swapped.id, first.id);
    expect(find.text('One-Arm Row'), findsWidgets);
  });

  testWidgets("Targets edits this workout's targets only", (tester) async {
    final cubit = await start(tester);
    final exercise = cubit.state.card.single.exercise;
    expect(exercise.setTargets, hasLength(1));

    await menu(tester, 'Targets');
    expect(find.byType(SetTargetPage), findsOneWidget);
    // The session keeps no rest-timers switch.
    expect(find.text('Set Rest Timers'), findsNothing);
    await tester.tap(find.byKey(const Key('SetTarget.addSet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('SetTarget.save')));
    await tester.pumpAndSettle();

    expect(find.byType(SetTargetPage), findsNothing);
    expect(cubit.state.card.single.exercise.setTargets, hasLength(2));
  });

  testWidgets('the weight heading changes the unit, asking how', (
    tester,
  ) async {
    final cubit = await start(tester);
    final exercise = cubit.state.card.single.exercise;
    final heading = find.byKey(ValueKey('weight-unit-${exercise.id}'));

    // The unit in use asks nothing.
    await tester.tap(heading);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kilograms').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Change Weight Unit'), findsNothing);

    // Cancel changes nothing.
    await tester.tap(heading);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pounds').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Change Weight Unit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cubit.state.card.single.weightUnit, ExerciseWeightUnit.kilograms);

    await tester.tap(heading);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pounds').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Display Only'));
    await tester.pumpAndSettle();
    expect(cubit.state.card.single.weightUnit, ExerciseWeightUnit.pounds);
    expect(
      units.of(uid, exercise.templateId).weightUnit,
      ExerciseWeightUnit.pounds,
    );
    expect(find.text('lb'), findsWidgets);
  });

  testWidgets('Exercise Settings keeps units, rest and note', (tester) async {
    final cubit = await start(tester);
    cubit.swapExercise(cubit.state.card.single.exercise.id, row);
    await tester.pumpAndSettle();

    await menu(tester, 'Exercise Settings');
    expect(find.byType(ExerciseSettingsView), findsOneWidget);
    expect(find.text('Brace on a bench.'), findsOneWidget);
    // A one-arm row is worked a side at a time.
    expect(find.text('50% of the rest timer'), findsOneWidget);
    expect(find.text('Default (1:30)'), findsOneWidget);

    // Distance unit, on the device.
    await tester.tap(find.byKey(const Key('ExerciseSettings.distanceUnit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Miles').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(units.of(uid, row.id).distanceUnit, DistanceUnit.miles);

    // A rest of its own, then cleared.
    await tester.tap(find.byKey(const Key('ExerciseSettings.rest')));
    await tester.pumpAndSettle();
    final extent = tester
        .widget<ListWheelScrollView>(
          find.descendant(
            of: find.byKey(const ValueKey('rest-minutes')),
            matching: find.byType(ListWheelScrollView),
          ),
        )
        .itemExtent;
    await tester.drag(
      find.byKey(const ValueKey('rest-minutes')),
      Offset(0, -2 * extent),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rest-save')));
    await tester.pumpAndSettle();
    expect(find.text('Custom (2:00)'), findsOneWidget);
    var stored = await library.watchExerciseSettings(uid).first;
    expect(stored.single.restDurationOverride, 120);

    await tester.tap(find.byKey(const Key('ExerciseSettings.rest')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('rest-minutes')),
      Offset(0, 2 * extent),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rest-save')));
    await tester.pumpAndSettle();
    expect(find.text('Default (1:30)'), findsOneWidget);
    stored = await library.watchExerciseSettings(uid).first;
    expect(stored.single.restDurationOverride, isNull);

    // The note.
    await tester.tap(find.byKey(const Key('ExerciseSettings.note')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Slow\nNo jerking');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Slow'), findsOneWidget);
    stored = await library.watchExerciseSettings(uid).first;
    expect(stored.single.note, 'Slow\nNo jerking');

    // Edit Duplicate opens the create flow on a copy.
    await tester.tap(find.byKey(const Key('ExerciseSettings.duplicate')));
    await tester.pumpAndSettle();
    expect(find.byType(CreateExerciseView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('CreateExercise.name')),
        matching: find.text('One-Arm Row (Copy)'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Rest Between Left/Right Sets opens the rest timer settings', (
    tester,
  ) async {
    final cubit = await start(tester);
    cubit.swapExercise(cubit.state.card.single.exercise.id, row);
    await tester.pumpAndSettle();
    await menu(tester, 'Exercise Settings');
    await tester.tap(find.byKey(const Key('ExerciseSettings.sideRest')));
    await tester.pumpAndSettle();
    expect(find.byType(RestTimerSettingsPage), findsOneWidget);
  });
}
