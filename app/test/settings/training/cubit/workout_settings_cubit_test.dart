import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/settings/training/cubit/workout_settings_cubit.dart';
import 'package:compound/settings/training/logic/workout_settings_rules.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:training_library_repository/training_library_repository.dart';

class _MockRepository extends Mock implements TrainingLibraryRepository;

class _MockAnalytics extends Mock implements AnalyticsRepository;

const _uid = 'user-1';

void main() {
  late TrainingLibraryRepository repository;
  late AnalyticsRepository analytics;
  late List<(String, LogType)> events;
  late List<WorkoutSettings> saved;

  setUpAll(() {
    registerFallbackValue(const AnalyticsEvent('fallback'));
    registerFallbackValue(const WorkoutSettings(authorId: 'fallback'));
  });

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalytics();
    events = [];
    saved = [];
    void record(Invocation invocation) {
      final event = invocation.positionalArguments.single as LoggableEvent;
      events.add((event.eventName, event.type));
    }

    when(() => analytics.trackEvent(any())).thenAnswer(record);
    when(() => analytics.trackScreenView(any())).thenAnswer(record);
    when(() => repository.saveWorkoutSettings(any())).thenAnswer((call) async {
      saved.add(call.positionalArguments.single as WorkoutSettings);
    });
  });

  WorkoutSettingsCubit build(
    WorkoutSettings stored, {
    String screen = 'WorkoutSettingsView',
  }) {
    when(() => repository.watchWorkoutSettings(_uid))
        .thenAnswer((_) => Stream.value(stored));
    return WorkoutSettingsCubit(
      repository: repository,
      analytics: analytics,
      uid: _uid,
      screen: screen,
    );
  }

  /// [stored] with [fields] set, as the whole document that should be saved.
  Map<String, Object?> expected(
    WorkoutSettings stored,
    Map<String, Object?> fields,
  ) => withFields(stored, fields).toFirestore();

  const defaults = WorkoutSettings(authorId: _uid);

  group(WorkoutSettingsCubit, () {
    test('starts with nothing read, and saves nothing before', () async {
      final cubit = build(defaults);
      expect(cubit.state, const WorkoutSettingsState());
      await cubit.change({WorkoutSettingsKeys.rirTracking: true});
      verifyNever(() => repository.saveWorkoutSettings(any()));
    });

    blocTest<WorkoutSettingsCubit, WorkoutSettingsState>(
      'the toggles show what is stored',
      build: () => build(
        const WorkoutSettings(
          authorId: _uid,
          rirTracking: true,
          keepAlive: false,
        ),
      ),
      act: (cubit) => cubit.subscribe(),
      expect: () => const [
        WorkoutSettingsState(
          settings: WorkoutSettings(
            authorId: _uid,
            rirTracking: true,
            keepAlive: false,
          ),
        ),
      ],
    );

    for (final (key, value) in <(String, Object?)>[
      (WorkoutSettingsKeys.propagateChanges, false),
      (WorkoutSettingsKeys.rirTracking, true),
      (WorkoutSettingsKeys.supersetAutoScroll, false),
      (WorkoutSettingsKeys.exerciseAutoNext, false),
      (WorkoutSettingsKeys.keepAlive, false),
      (WorkoutSettingsKeys.showWorkoutTimer, false),
      (WorkoutSettingsKeys.showBodyweightContribution, true),
      (WorkoutSettingsKeys.showOnLockScreen, false),
      (WorkoutSettingsKeys.setPlanning, true),
      (WorkoutSettingsKeys.addSmartWarmUps, false),
      (WorkoutSettingsKeys.useRestTimers, false),
      (WorkoutSettingsKeys.restAfterLastWarmUp, false),
      (WorkoutSettingsKeys.restBetweenExercises, false),
      (WorkoutSettingsKeys.restBetweenSideSets, true),
      (WorkoutSettingsKeys.restTimerPlaySound, false),
      (WorkoutSettingsKeys.restTimerVibrate, false),
      (WorkoutSettingsKeys.amrapRaisesTarget, false),
      (WorkoutSettingsKeys.amrapAddsWeight, false),
      (WorkoutSettingsKeys.smartProgressionApplyInSession, true),
      (WorkoutSettingsKeys.smartProgressionInitialLogFill, 'previousValues'),
      (WorkoutSettingsKeys.smartProgressionAdjustmentMode, 'repsFirst'),
      (WorkoutSettingsKeys.previousWorkoutReference, 'anyExercise'),
      (WorkoutSettingsKeys.previousWorkoutReference, 'workoutsInProgram'),
      (WorkoutSettingsKeys.supersetTransitionRestSeconds, 30),
      (WorkoutSettingsKeys.warmUpRestScaling, 0.5),
      (WorkoutSettingsKeys.betweenExercisesRestScaling, 1.5),
      (WorkoutSettingsKeys.sideSetRestScaling, 2.0),
      (WorkoutSettingsKeys.intraSetRestMyoSeconds, 10),
      (WorkoutSettingsKeys.intraSetRestPauseSeconds, 30),
      (WorkoutSettingsKeys.intraSetRestClusterSeconds, 20),
      (WorkoutSettingsKeys.amrapAddsWeightAtTarget, 15),
    ]) {
      blocTest<WorkoutSettingsCubit, WorkoutSettingsState>(
        '$key = $value saves the whole document with only it changed',
        build: () => build(defaults),
        act: (cubit) async {
          cubit.subscribe();
          await Future<void>.delayed(Duration.zero);
          await cubit.change({key: value});
        },
        verify: (_) {
          expect(saved.single.toFirestore(), expected(defaults, {key: value}));
          expect(events, [
            ('WorkoutSettingsView_Save_Start', LogType.analytic),
            ('WorkoutSettingsView_Save_Success', LogType.analytic),
          ]);
        },
      );
    }

    blocTest<WorkoutSettingsCubit, WorkoutSettingsState>(
      "Off for the superset rest clears it, and the reset empties every type's "
      'rest',
      build: () => build(
        const WorkoutSettings(
          authorId: _uid,
          supersetTransitionRestSeconds: 15,
          restDurationsByExerciseType: {'core': 45},
        ),
      ),
      act: (cubit) async {
        cubit.subscribe();
        await Future<void>.delayed(Duration.zero);
        await cubit.change({
          WorkoutSettingsKeys.supersetTransitionRestSeconds: null,
        });
        await cubit.change({
          WorkoutSettingsKeys.restDurationsByExerciseType:
              const <String, int>{},
        });
      },
      verify: (_) {
        expect(saved.first.supersetTransitionRestSeconds, isNull);
        expect(saved.last.toFirestore(), defaults.toFirestore());
      },
    );

    blocTest<WorkoutSettingsCubit, WorkoutSettingsState>(
      'flipping one toggle leaves the others alone',
      build: () => build(
        const WorkoutSettings(
          authorId: _uid,
          rirTracking: true,
          setPlanning: true,
          warmUpRestScaling: 0.5,
          restDurationsByExerciseType: {'core': 45},
        ),
      ),
      act: (cubit) async {
        cubit.subscribe();
        await Future<void>.delayed(Duration.zero);
        await cubit.change({WorkoutSettingsKeys.keepAlive: false});
      },
      verify: (_) {
        final last = saved.single;
        expect(last.keepAlive, isFalse);
        expect(last.rirTracking, isTrue);
        expect(last.setPlanning, isTrue);
        expect(last.warmUpRestScaling, 0.5);
        expect(last.restDurationsByExerciseType, {'core': 45});
      },
    );

    blocTest<WorkoutSettingsCubit, WorkoutSettingsState>(
      'choosing what is already chosen saves nothing',
      build: () => build(
        const WorkoutSettings(authorId: _uid, intraSetRestMyoSeconds: 15),
      ),
      act: (cubit) async {
        cubit.subscribe();
        await Future<void>.delayed(Duration.zero);
        await cubit.change({WorkoutSettingsKeys.intraSetRestMyoSeconds: 15});
      },
      verify: (_) => verifyNever(() => repository.saveWorkoutSettings(any())),
    );

    blocTest<WorkoutSettingsCubit, WorkoutSettingsState>(
      'a failed save is reported, and logged as severe under the screen',
      setUp: () =>
          when(() => repository.saveWorkoutSettings(any()))
              .thenThrow(StateError('offline')),
      build: () => build(defaults, screen: 'RestTimerSettingsView'),
      act: (cubit) async {
        cubit.subscribe();
        await Future<void>.delayed(Duration.zero);
        await cubit.change({WorkoutSettingsKeys.useRestTimers: false});
      },
      skip: 1,
      expect: () => [
        WorkoutSettingsState(
          settings: withFields(defaults, {
            WorkoutSettingsKeys.useRestTimers: false,
          }),
        ),
        WorkoutSettingsState(
          settings: withFields(defaults, {
            WorkoutSettingsKeys.useRestTimers: false,
          }),
          saveFailed: true,
        ),
      ],
      verify: (_) => expect(events, [
        ('RestTimerSettingsView_Save_Start', LogType.analytic),
        ('RestTimerSettingsView_Save_Fail', LogType.severe),
      ]),
    );

    test('appearing is a screen view; leaving is tracked', () {
      build(defaults, screen: 'SmartProgressionSettingsView')
        ..appeared()
        ..disappeared();
      expect(events, [
        ('SmartProgressionSettingsView_Appear', LogType.analytic),
        ('SmartProgressionSettingsView_Disappear', LogType.analytic),
      ]);
      verify(() => analytics.trackScreenView(any())).called(1);
    });

    test('subscribing twice follows once', () {
      build(defaults)
        ..subscribe()
        ..subscribe();
      verify(() => repository.watchWorkoutSettings(_uid)).called(1);
    });
  });

  group('two screens on one document', () {
    test('returning from another settings screen keeps its changes, and '
        'settings changed elsewhere are not undone', () async {
      final shared = InMemoryTrainingLibraryRepository(
        workoutSettings: const [WorkoutSettings(authorId: _uid)],
      );
      WorkoutSettingsCubit screen(String name) => WorkoutSettingsCubit(
        repository: shared,
        analytics: analytics,
        uid: _uid,
        screen: name,
      )..subscribe();
      final workout = screen('WorkoutSettingsView');
      final restTimer = screen('RestTimerSettingsView');
      final smart = screen('SmartProgressionSettingsView');
      await Future<void>.delayed(Duration.zero);

      await restTimer.change({WorkoutSettingsKeys.restTimerVibrate: false});
      await smart.change({
        WorkoutSettingsKeys.smartProgressionAdjustmentMode: 'repsFirst',
      });
      await workout.change({WorkoutSettingsKeys.rirTracking: true});

      final stored = await shared.watchWorkoutSettings(_uid).first;
      expect(stored.restTimerVibrate, isFalse);
      expect(
        stored.smartProgressionAdjustmentMode,
        ProgressionAdjustmentMode.repsFirst,
      );
      expect(stored.rirTracking, isTrue);
      await Future.wait([workout.close(), restTimer.close(), smart.close()]);
    });
  });
}
