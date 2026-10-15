import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/settings/training/cubit/exercise_rest_timers_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../../helpers/helpers.dart';

class _MockAnalytics extends Mock implements AnalyticsRepository;

class _FailingRepository extends InMemoryTrainingLibraryRepository {
  @override
  Future<void> saveExerciseSettings(
    String uid,
    ExerciseSettingsModel settings,
  ) async => throw StateError('offline');
}

const _uid = 'user-1';

void main() {
  late AnalyticsRepository analytics;
  late List<(String, LogType)> events;
  final bench = fixtureLibraryExercise('bench', name: 'Bench', system: true);
  final squat = fixtureLibraryExercise('squat', name: 'Squat');

  setUpAll(() => registerFallbackValue(const AnalyticsEvent('fallback')));

  setUp(() {
    analytics = _MockAnalytics();
    events = [];
    when(() => analytics.trackEvent(any())).thenAnswer((call) {
      final event = call.positionalArguments.single as LoggableEvent;
      events.add((event.eventName, event.type));
    });
  });

  Future<(ExerciseRestTimersCubit, InMemoryTrainingLibraryRepository)> build({
    List<ExerciseSettingsModel> settings = const [],
    InMemoryTrainingLibraryRepository? repository,
  }) async {
    final library =
        repository ??
        InMemoryTrainingLibraryRepository(
          exercises: [
            ExerciseModel.fromFirestore({
              ...squat.toFirestore(),
              ExerciseModelKeys.authorId: _uid,
            }),
          ],
          exerciseSettings: settings,
        );
    final cubit = ExerciseRestTimersCubit(
      repository: library,
      analytics: analytics,
      uid: _uid,
      systemExercises: [bench],
    )..subscribe();
    await Future<void>.delayed(Duration.zero);
    return (cubit, library);
  }

  group(ExerciseRestTimersCubit, () {
    test(
      'lists the exercises with a rest of their own, and the rest',
      () async {
        final (cubit, _) = await build(
          settings: const [
            ExerciseSettingsModel(
              id: 'squat',
              authorId: _uid,
              restDurationOverride: 150,
            ),
          ],
        );
        expect(cubit.state.overrides, [
          (id: 'squat', name: 'Squat', seconds: 150),
        ]);
        expect(cubit.state.withoutOverride.map((e) => e.id), ['bench']);
        expect(cubit.overrideFor('squat'), 150);
        expect(cubit.overrideFor('bench'), isNull);
        await cubit.close();
      },
    );

    test('a chosen duration is saved as entered', () async {
      final (cubit, library) = await build();
      await cubit.setOverride('bench', 75);
      expect(
        (await library.watchExerciseSettings(_uid).first)
            .single
            .restDurationOverride,
        75,
      );
      expect(cubit.state.overrides, [
        (id: 'bench', name: 'Bench', seconds: 75),
      ]);
      expect(events, [
        ('TimerDurationView_Save_Start', LogType.analytic),
        ('TimerDurationView_Save_Success', LogType.analytic),
      ]);
      await cubit.close();
    });

    test(
      'an empty picker clears the exercise override, keeping its note',
      () async {
        final (cubit, library) = await build(
          settings: const [
            ExerciseSettingsModel(
              id: 'squat',
              authorId: _uid,
              note: 'Belt',
              restDurationOverride: 150,
            ),
          ],
        );
        await cubit.setOverride('squat', 0);
        final stored = (await library.watchExerciseSettings(_uid).first).single;
        expect(stored.restDurationOverride, isNull);
        expect(stored.note, 'Belt');
        expect(cubit.state.overrides, isEmpty);
        await cubit.close();
      },
    );

    test(
      'an empty picker on an exercise with no override writes nothing',
      () async {
        final (cubit, library) = await build();
        await cubit.setOverride('bench', 0);
        expect(await library.watchExerciseSettings(_uid).first, isEmpty);
        expect(events, isEmpty);
        await cubit.close();
      },
    );

    test('removing an override deletes it', () async {
      final (cubit, _) = await build(
        settings: const [
          ExerciseSettingsModel(
            id: 'squat',
            authorId: _uid,
            restDurationOverride: 150,
          ),
        ],
      );
      await cubit.remove('squat');
      expect(cubit.state.overrides, isEmpty);
      await cubit.close();
    });

    test('a failed override save is reported once', () async {
      final (cubit, _) = await build(repository: _FailingRepository());
      await cubit.setOverride('bench', 60);
      expect(cubit.state.saveFailed, isTrue);
      expect(events, [
        ('TimerDurationView_Save_Start', LogType.analytic),
        ('TimerDurationView_Save_Fail', LogType.severe),
      ]);
      await cubit.close();
    });

    test('subscribing twice follows once', () async {
      final (cubit, _) = await build();
      cubit.subscribe();
      await cubit.close();
    });
  });
}
