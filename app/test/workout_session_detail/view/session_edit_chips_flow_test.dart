import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/workout_editor/view/set_target_page.dart';
import 'package:compound/workout_tracker/view/equipment_sheet.dart';
import 'package:compound/workout_tracker/view/exercise_settings_page.dart';
import 'package:compound/workout_tracker/view/swap_exercise_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

/// The finished workout's editor beyond the sets, end to end on the
/// staging flavor's in-memory data: an exercise folded away and its
/// warm-ups folded into one line, the tracker's keypad and unit heading,
/// Superset… and Remove Superset, Swap with its question, Targets,
/// Equipment and Exercise Settings.
void main() {
  const uid = sampleUserId;
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1, 7);
  final catalogue = PrebuiltCatalogue.instance.exercises;
  final bench = catalogue.firstWhere(
    (e) => e.id == 'system-barbell-bench-press',
  );
  final timed = catalogue.firstWhere(
    (e) => e.trackingMode != TrackingMode.weightReps && !e.isPerSide,
  );

  WorkoutSetModel set(String id, {int index = 1, bool isWarmup = false}) =>
      WorkoutSetModel(
        id: id,
        authorId: uid,
        index: index,
        isWarmup: isWarmup,
        reps: 8,
        weightKg: isWarmup ? 40 : 80,
        dateCreated: yesterday,
        completedAt: yesterday,
      );

  WorkoutExerciseModel exercise(
    String id,
    int index,
    List<WorkoutSetModel> sets,
  ) => WorkoutExerciseModel(
    id: id,
    authorId: uid,
    templateId: bench.id,
    name: id == 'bench' ? bench.name : 'Second Press',
    trackingMode: TrackingMode.weightReps,
    index: index,
    sets: sets,
    equipmentVariations: bench.equipmentVariations,
  );

  WorkoutSessionModel workout(List<WorkoutExerciseModel> exercises) =>
      WorkoutSessionModel(
        id: 'edit-me',
        authorId: uid,
        name: 'Push Day',
        dateCreated: yesterday,
        dateModified: yesterday,
        endedAt: yesterday.add(const Duration(minutes: 64)),
        exercises: exercises,
      );

  final both = workout([
    exercise('bench', 1, [
      set('w1', isWarmup: true),
      set('w2', index: 2, isWarmup: true),
      set('s1', index: 3),
      set('s2', index: 4),
    ]),
    exercise('second', 2, [set('t1')]),
  ]);

  late InMemoryWorkoutSessionRepository sessions;
  late UnitPreferenceStore units;
  late AnalyticsRecorder analytics;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
  }

  Future<void> open(WidgetTester tester, WorkoutSessionModel opened) async {
    sessions = InMemoryWorkoutSessionRepository(sessions: [opened]);
    units = UnitPreferenceStore();
    analytics = AnalyticsRecorder();
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
        workoutSessionRepository: sessions,
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(
          gymProfiles: sampleGymProfiles,
        ),
        analyticsRepository: analytics,
        unitPreferences: units,
      ),
    );
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .go('/training/history/edit-me');
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('session-edit')));
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<WorkoutSessionModel> stored(WidgetTester tester) async =>
      (await tester.runAsync(() => sessions.session(uid, 'edit-me')))!;

  testWidgets('folds warm-ups and exercises; the keypad and unit heading', (
    tester,
  ) async {
    await open(tester, both);

    // Done warm-ups fold into one line, opened on a tap.
    expect(find.text('2 warm-ups'), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-w1-reps')), findsNothing);
    await tap(tester, find.text('2 warm-ups'));
    expect(find.byKey(const ValueKey('cell-w1-reps')), findsOneWidget);
    expect(find.text('Set 2/2'), findsWidgets);

    // The tracker's keypad: + steps the weight on.
    await tap(tester, find.byKey(const ValueKey('cell-s1-weight')));
    await tap(tester, find.byKey(const ValueKey('keypad-up')));
    await tap(tester, find.byKey(const ValueKey('keypad-hide')));

    // The weight heading: pounds for this exercise everywhere.
    await tap(tester, find.byKey(const ValueKey('weight-unit-bench')));
    await tester.tap(find.text('Pounds').last, warnIfMissed: false);
    await settle(tester);
    await tap(tester, find.text('Display Only'));
    expect(units.of(uid, bench.id).weightUnit, ExerciseWeightUnit.pounds);

    // Folded away, and open again.
    await tap(tester, find.text(bench.name));
    expect(find.byKey(const ValueKey('cell-s1-reps')), findsNothing);
    await tap(tester, find.text(bench.name));
    expect(find.byKey(const ValueKey('cell-s1-reps')), findsOneWidget);

    await tap(tester, find.byKey(const ValueKey('session-save')));
    final saved = (await stored(tester)).exercises.first.sets;
    expect(saved[2].weightKg, greaterThan(80));
    expect(saved[2].completedAt, isNotNull);
  });

  testWidgets('Superset… pairs two exercises; Remove Superset parts them', (
    tester,
  ) async {
    await open(tester, both);

    await tap(tester, find.byKey(const ValueKey('chip-superset-bench')));
    expect(find.text('Add to Group'), findsOneWidget);
    expect(find.text("Pair '${bench.name}' with:"), findsOneWidget);
    await tap(tester, find.text('Second Press').last);
    expect(find.text('Remove Superset'), findsNWidgets(2));

    await tap(tester, find.byKey(const ValueKey('session-save')));
    final grouped = (await stored(tester)).exercises;
    expect(grouped.first.supersetGroupId, isNotNull);
    expect(grouped.last.supersetGroupId, grouped.first.supersetGroupId);

    await tap(tester, find.byKey(const ValueKey('session-edit')));
    await tap(tester, find.byKey(const ValueKey('chip-superset-second')));
    expect(find.text('Superset…'), findsNWidgets(2));
    await tap(tester, find.byKey(const ValueKey('session-save')));
    expect((await stored(tester)).exercises.map((e) => e.supersetGroupId), [
      null,
      null,
    ]);
  });

  testWidgets('with one exercise there is nothing to pair with', (
    tester,
  ) async {
    await open(
      tester,
      workout([
        exercise('bench', 1, [set('s1')]),
      ]),
    );
    await tap(tester, find.byKey(const ValueKey('chip-superset-bench')));
    expect(find.text('No Exercises Available'), findsOneWidget);
    await tap(tester, find.text('OK'));
    expect(find.text('Superset…'), findsOneWidget);
  });

  testWidgets('Swap to an exercise measured differently asks first', (
    tester,
  ) async {
    await open(tester, both);

    Future<void> pick() async {
      await tap(tester, find.byKey(const ValueKey('chip-swap-bench')));
      expect(find.byType(SwapExercisePicker), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, timed.name);
      await tester.pumpAndSettle();
      await tap(tester, find.text(timed.name).last);
    }

    await pick();
    expect(find.text('Discard Logged Sets?'), findsOneWidget);
    await tap(tester, find.text('Cancel'));
    expect(find.text(bench.name), findsOneWidget);

    await pick();
    await tap(tester, find.text('Swap and Discard Sets'));
    expect(find.text(timed.name), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('session-save')));
    final swapped = (await stored(tester)).exercises.first;
    expect(swapped.id, 'bench');
    expect(swapped.templateId, timed.id);
    expect(swapped.sets.every((s) => s.completedAt == null), isTrue);
    expect(analytics.names, contains('SetTracker_Swap_Opened'));
  });

  testWidgets('Targets, Equipment and Exercise Settings open', (tester) async {
    await open(tester, both);

    await tap(tester, find.byKey(const ValueKey('chip-targets-bench')));
    expect(find.byType(SetTargetPage), findsOneWidget);
    await tap(tester, find.byKey(const Key('SetTarget.addSet')));
    await tap(tester, find.byKey(const Key('SetTarget.save')));
    expect(find.byType(SetTargetPage), findsNothing);

    await tap(tester, find.byKey(const ValueKey('chip-equipment-bench')));
    expect(find.byType(EquipmentSheetView), findsOneWidget);
    await tap(tester, find.byTooltip('Close').last);

    await tap(tester, find.byKey(const ValueKey('exercise-menu-bench')));
    await tap(tester, find.text('Exercise Settings').last);
    expect(find.byType(ExerciseSettingsView), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    await tap(tester, find.byKey(const ValueKey('session-save')));
    expect((await stored(tester)).exercises.first.setTargets, hasLength(1));
    expect(
      analytics.names,
      containsAllInOrder([
        'SetTracker_Targets_Opened',
        'SetTracker_Equipment_Opened',
        'SetTracker_ExerciseSettings_Opened',
      ]),
    );
  });
}
