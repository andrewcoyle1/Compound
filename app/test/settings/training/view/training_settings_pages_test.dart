import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/settings/settings.dart';
import 'package:compound/settings/training/view/rest_timer_settings_page.dart';
import 'package:compound/settings/training/view/smart_progression_settings_page.dart';
import 'package:compound/settings/training/view/timer_duration_page.dart';
import 'package:compound/settings/training/view/workout_settings_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../../helpers/helpers.dart';

const _uid = 'user-1';

class _FailingRepository extends InMemoryTrainingLibraryRepository {
  new({super.workoutSettings, super.exerciseSettings});

  @override
  Future<void> saveWorkoutSettings(WorkoutSettings settings) async =>
      throw StateError('offline');

  @override
  Future<void> saveExerciseSettings(
    String uid,
    ExerciseSettingsModel settings,
  ) async => throw StateError('offline');
}

void main() {
  late AppBloc appBloc;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(
        AuthUser(uid: _uid, isAnonymous: false),
        profileStatus: AppProfileStatus.ready,
      ),
    );
  });

  Future<InMemoryTrainingLibraryRepository> pump(
    WidgetTester tester,
    String location, {
    WorkoutSettings settings = const WorkoutSettings(authorId: _uid),
    InMemoryTrainingLibraryRepository? repository,
  }) async {
    final library =
        repository ??
        InMemoryTrainingLibraryRepository(workoutSettings: [settings]);
    tester.view.physicalSize = const Size(2400, 12000);
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      trainingLibraryRepository: library,
      router: GoRouter(
        initialLocation: '/profile/settings/$location',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => const SizedBox(),
            routes: profileRoutes,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return library;
  }

  Future<WorkoutSettings> stored(InMemoryTrainingLibraryRepository library) =>
      library.watchWorkoutSettings(_uid).first;

  Future<void> pickFromMenu(
    WidgetTester tester,
    String row,
    String option,
  ) async {
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text(option),
      ),
    );
    await tester.pumpAndSettle();
  }

  group(WorkoutSettingsPage, () {
    testWidgets('each change is saved as it is made', (tester) async {
      final library = await pump(tester, 'workout');
      expect(find.text('Workout Settings'), findsOneWidget);

      await tester.tap(find.text('Effort (RPE)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any workout'));
      await tester.pumpAndSettle();
      await pickFromMenu(tester, 'Rest between superset partners', '15 s');

      final settings = await stored(library);
      expect(settings.rirTracking, isTrue);
      expect(settings.setPlanning, isTrue);
      expect(
        settings.previousWorkoutReference,
        PreviousWorkoutReferenceOption.anyExercise,
      );
      expect(settings.supersetTransitionRestSeconds, 15);

      await pickFromMenu(tester, 'Rest between superset partners', 'Off');
      expect((await stored(library)).supersetTransitionRestSeconds, isNull);
    });

    testWidgets('each row opens its own settings screen', (tester) async {
      await pump(tester, 'workout');
      await tester.tap(find.text('Rest Timer'));
      await tester.pumpAndSettle();
      expect(find.byType(RestTimerSettingsPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Progression'));
      await tester.pumpAndSettle();
      expect(find.byType(SmartProgressionSettingsPage), findsOneWidget);
    });

    testWidgets('a failed save says so', (tester) async {
      await pump(
        tester,
        'workout',
        repository: _FailingRepository(
          workoutSettings: const [WorkoutSettings(authorId: _uid)],
        ),
      );
      await tester.tap(find.text('Keep Screen On'));
      await tester.pump();
      expect(find.text('Unable to Save Settings'), findsOneWidget);
    });

    testWidgets('shows nothing once signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const WorkoutSettingsPage(), appBloc: appBloc);
      expect(find.text('Workout Settings'), findsNothing);
    });
  });

  group(RestTimerSettingsPage, () {
    testWidgets('the set plan sections follow the switch', (tester) async {
      await pump(tester, 'workout/rest-timer');
      expect(find.text('Within a Set'), findsNothing);
      expect(find.text('Failure Sets'), findsNothing);
    });

    testWidgets('toggles, scalings, rests within a set and the AMRAP rule '
        'are saved', (tester) async {
      final library = await pump(
        tester,
        'workout/rest-timer',
        settings: const WorkoutSettings(authorId: _uid, setPlanning: true),
      );
      await tester.tap(find.text('Vibrate'));
      await tester.pumpAndSettle();
      await pickFromMenu(tester, 'After Warm-Ups', '50%');
      await tester.tap(find.bySemanticsLabel('Rest-pause, 30 s'));
      await tester.pumpAndSettle();
      // Choosing the rest already chosen changes nothing.
      await tester.tap(find.bySemanticsLabel('Myo-reps, 15 s'));
      await tester.pumpAndSettle();
      expect(find.text('Once the target reaches 12'), findsOneWidget);
      await tester.tap(find.byIcon(AppSymbols.add).last);
      await tester.pumpAndSettle();
      expect(find.text('Once the target reaches 13'), findsOneWidget);
      await tester.tap(find.byIcon(AppSymbols.decrease));
      await tester.pumpAndSettle();

      var settings = await stored(library);
      expect(settings.restTimerVibrate, isFalse);
      expect(settings.warmUpRestScaling, 0.5);
      expect(settings.intraSetRestPauseSeconds, 30);
      expect(settings.intraSetRestMyoSeconds, isNull);
      expect(settings.amrapAddsWeightAtTarget, 12);

      await tester.tap(find.text('Add Weight Instead'));
      await tester.pumpAndSettle();
      expect(find.text('Off: the target keeps rising'), findsOneWidget);
      await tester.tap(find.text('Raise the Target'));
      await tester.pumpAndSettle();
      settings = await stored(library);
      expect(settings.amrapAddsWeight, isFalse);
      expect(settings.amrapRaisesTarget, isFalse);
    });

    testWidgets('the durations row opens the durations screen', (tester) async {
      await pump(tester, 'workout/rest-timer');
      await tester.tap(find.text('Timer Duration'));
      await tester.pumpAndSettle();
      expect(find.byType(TimerDurationPage), findsOneWidget);
    });
  });

  group(SmartProgressionSettingsPage, () {
    testWidgets('each choice is saved', (tester) async {
      final library = await pump(tester, 'workout/smart-progression');
      await pickFromMenu(tester, 'Initial log fill', 'Leave empty');
      await pickFromMenu(tester, 'Adjustment Mode', 'Reps-first');
      await tester.tap(find.text('Apply in session'));
      await tester.pumpAndSettle();
      final settings = await stored(library);
      expect(
        settings.smartProgressionInitialLogFill,
        InitialLogFillOption.empty,
      );
      expect(
        settings.smartProgressionAdjustmentMode,
        ProgressionAdjustmentMode.repsFirst,
      );
      expect(settings.smartProgressionApplyInSession, isTrue);
    });
  });

  group(TimerDurationPage, () {
    const location = 'workout/rest-timer/durations';

    testWidgets("a type's rest is chosen on the wheels and saved", (
      tester,
    ) async {
      final library = await pump(tester, location);
      expect(find.text('2:00'), findsNWidgets(2));
      await tester.tap(find.text('Core'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('1 min'), const Offset(0, -40));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final rest = (await stored(library)).restDurationsByExerciseType['core'];
      expect(rest, isNot(60));
      expect(rest, greaterThan(60));
    });

    testWidgets('closing the wheels saves nothing', (tester) async {
      final library = await pump(tester, location);
      await tester.tap(find.text('Core'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect((await stored(library)).restDurationsByExerciseType, isEmpty);
    });

    testWidgets('resetting the default timers asks first', (tester) async {
      final library = await pump(
        tester,
        location,
        settings: const WorkoutSettings(
          authorId: _uid,
          restDurationsByExerciseType: {'core': 45},
        ),
      );
      await tester.tap(find.text('Reset Default Timers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await stored(library)).restDurationsByExerciseType, {'core': 45});

      await tester.tap(find.text('Reset Default Timers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset Timers'));
      await tester.pumpAndSettle();
      expect((await stored(library)).restDurationsByExerciseType, isEmpty);
    });

    testWidgets('an exercise timer is added, then removed', (tester) async {
      final library = await pump(tester, location);
      await tester.tap(find.text('Add Exercise Timer'));
      await tester.pumpAndSettle();
      final first = PrebuiltCatalogue.instance.exercises
          .map((e) => e.name)
          .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
      await tester.tap(find.text(first));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(first), findsOneWidget);
      final overrides = await library.watchExerciseSettings(_uid).first;
      expect(overrides.single.restDurationOverride, 90);

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(find.text(first), findsNothing);
    });

    testWidgets('an existing exercise timer is edited, and a failed save says '
        'so', (tester) async {
      final exercise = PrebuiltCatalogue.instance.exercises.first;
      await pump(
        tester,
        location,
        repository: _FailingRepository(
          workoutSettings: const [WorkoutSettings(authorId: _uid)],
          exerciseSettings: [
            ExerciseSettingsModel(
              id: exercise.id,
              authorId: _uid,
              restDurationOverride: 60,
            ),
          ],
        ),
      );
      await tester.tap(find.text(exercise.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Unable to Save Settings'), findsOneWidget);
    });
  });
}
