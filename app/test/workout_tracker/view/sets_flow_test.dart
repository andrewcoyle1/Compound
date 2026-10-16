@Timeout(Duration(seconds: 30))
library;

import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/workout_tracker/view/set_row_parts.dart';
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

import '../../helpers/library_fixtures.dart';

/// A clock the test moves by hand, for the cubit and the screen alike.
class _Clock {
  DateTime now = DateTime.now();

  DateTime call() => now;
}

/// Set editing through the whole app on the staging data: the set type
/// menu with drops and its questions, the rest picker, Split L/R and the
/// stopwatch.
void main() {
  const uid = sampleUserId;

  ExerciseModel own(String id, List<String> metrics) =>
      ExerciseModel.fromFirestore({
        ...fixtureLibraryExercise(id).toFirestore(),
        'author_id': uid,
        'trackable_metrics': metrics,
      });
  final oneArmRow = own('One-Arm Row', ['weight', 'repsPerSide']);
  final plank = own('Plank', ['duration']);

  late _Clock clock;

  Future<ActiveWorkoutCubit> start(WidgetTester tester) async {
    clock = _Clock();
    await tester.pumpWidget(
      App(
        purchasesRepository: FakePurchasesRepository(),
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: InMemoryUserRepository(
          users: {uid: sampleUser(now: clock.now)},
          settings: {uid: sampleUserSettings(now: clock.now)},
        ),
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(
          exercises: [oneArmRow, plank],
          workoutTemplates: sampleUserWorkoutTemplates,
          gymProfiles: sampleGymProfiles,
          workoutSettings: const [
            WorkoutSettings(authorId: uid, addSmartWarmUps: false),
          ],
        ),
        activeSessionStore: InMemoryActiveSessionStore(),
        trackerClock: TrackerClock(clock.call),
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

  Future<void> chooseType(
    WidgetTester tester,
    String setId,
    String type,
  ) async {
    await tester.tap(find.byKey(ValueKey('set-type-$setId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(type).last, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets('the set type menu makes drops, and asks before deleting '
      'what is logged', (tester) async {
    final cubit = await start(tester);
    final setId = (cubit.state.primaryAction! as r.LogSetAction).setId;
    cubit
      ..openKeypad(setId, SetField.weight)
      ..keypadKey('1')
      ..keypadKey('0')
      ..keypadKey('0')
      ..keypadNext()
      ..keypadKey('8')
      ..closeKeypad();
    await tester.pumpAndSettle();

    // Drop Set: its first drop appears under it, then another.
    await chooseType(tester, setId, 'Drop Set');
    expect(find.text('Drop'), findsOneWidget);
    await chooseType(tester, setId, 'Add Another Drop');
    expect(find.text('Drop'), findsNWidgets(2));
    final drops = [
      for (final set in cubit.state.exerciseHolding(setId)!.sets)
        if (set.parentSetId == setId) set.id,
    ];
    expect(drops, hasLength(2));
    expect(cubit.state.set(drops.first)!.weightKg, 80);

    // A logged drop is lost by going back to Standard: asked first.
    await tester.tap(find.byKey(ValueKey('cell-${drops.first}-reps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keypad-6')));
    await tester.tap(find.byKey(const ValueKey('keypad-done')));
    await tester.pumpAndSettle();
    expect(cubit.state.set(drops.first)!.completedAt, isNotNull);
    await chooseType(tester, setId, 'Standard');
    expect(find.text('Change Set 1 to Standard?'), findsOneWidget);
    expect(find.text('This deletes 1 logged row under it.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cubit.state.set(drops.first), isNotNull);

    // Deleting the set asks, as its drops go with it.
    await tester.longPress(find.byKey(ValueKey('cell-$setId-weight')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Set'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Set 1?'), findsOneWidget);
    expect(find.text('This also deletes its 2 drop sets.'), findsOneWidget);
    await tester.tap(find.text('Delete Set').last);
    await tester.pumpAndSettle();
    expect(cubit.state.set(setId), isNull);
    expect(cubit.state.set(drops.last), isNull);
  });

  testWidgets('the rest picker keeps a rest for one set', (tester) async {
    final cubit = await start(tester);
    final setId = (cubit.state.primaryAction! as r.LogSetAction).setId;
    final initial = cubit.state.card.single.restPicker[setId]!;

    await tester.longPress(find.byKey(ValueKey('cell-$setId-reps')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest Timer…'));
    await tester.pumpAndSettle();
    expect(find.byType(RestPickerSheet), findsOneWidget);
    expect(find.text('Set Rest'), findsOneWidget);

    // A minute more.
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
      Offset(0, -extent),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rest-save')));
    await tester.pumpAndSettle();
    expect(cubit.state.card.single.restPicker[setId], initial + 60);

    // Close changes nothing.
    await tester.longPress(find.byKey(ValueKey('cell-$setId-reps')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rest Timer…'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(cubit.state.card.single.restPicker[setId], initial + 60);
  });

  testWidgets('Split L/R logs each side apart, and the stopwatch times a '
      'set', (tester) async {
    final cubit = await start(tester);
    cubit.addExercises([oneArmRow, plank]);
    await tester.pumpAndSettle();

    final row = cubit.state.session!.exercises.firstWhere(
      (e) => e.name == 'One-Arm Row',
    );
    cubit.selectExercise(row.id);
    await tester.pumpAndSettle();
    final count = row.sets.length;
    await tester.tap(find.byTooltip('Exercise options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split L/R'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(cubit.state.exercise(row.id)!.sets, hasLength(count * 2));

    final hold = cubit.state.session!.exercises.firstWhere(
      (e) => e.name == 'Plank',
    );
    cubit.selectExercise(hold.id);
    await tester.pumpAndSettle();
    final setId = hold.sets.first.id;
    await tester.tap(find.byKey(ValueKey('stopwatch-$setId')));
    await tester.pump();
    expect(find.bySemanticsLabel('Stop timer'), findsOneWidget);
    clock.now = clock.now.add(const Duration(seconds: 42));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:42'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('stopwatch-$setId')));
    await tester.pumpAndSettle();
    expect(cubit.state.set(setId)!.durationSec, 42);
    expect(cubit.state.set(setId)!.completedAt, isNull);
    expect(find.text('0:42'), findsOneWidget);
  });
}
