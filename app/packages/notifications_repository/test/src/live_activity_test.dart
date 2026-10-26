import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';

class _Copy implements NotificationCopy {
  @override
  ({String title, String body}) reminder(LocalReminderKind kind) =>
      (title: 'Rest Complete', body: 'body');

  @override
  String channelName(NotificationChannel channel) => channel.name;
}

const _state = LiveActivityState(
  isActive: true,
  completedSetsCount: 5,
  totalSetsCount: 12,
  currentExerciseIndex: 1,
  totalExercisesCount: 4,
  currentExerciseCompletedSetsCount: 2,
  currentExerciseTotalSetsCount: 4,
  progress: 5 / 12,
  isAllSetsComplete: false,
  currentExerciseName: 'Bench Press',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(
    MethodChannelLiveActivityRepository.channelName,
  );

  group(LiveActivityPiece, () {
    test('counts its logged pieces into the progress, at most all', () {
      const piece = LiveActivityPiece(index: 2, count: 3, isDrop: true);
      expect(piece.progress(completedSets: 5, totalSets: 12), (5 + 1 / 3) / 12);
      expect(
        const LiveActivityPiece(
          index: 3,
          count: 3,
          isDrop: false,
        ).progress(completedSets: 1, totalSets: 1),
        1,
      );
      expect(piece.progress(completedSets: 0, totalSets: 0), 0);
    });

    test('is the Swift shape', () {
      expect(
        const LiveActivityPiece(
          index: 2,
          count: 2,
          isDrop: false,
          technique: LiveActivitySetKind.partials,
        ).toJson(),
        {'index': 2, 'count': 2, 'isDrop': false, 'technique': 'partials'},
      );
    });
  });

  group(LiveActivityState, () {
    test('sends every non-optional property and leaves out nulls', () {
      expect(_state.toJson(), {
        'isActive': true,
        'completedSetsCount': 5,
        'totalSetsCount': 12,
        'currentExerciseName': 'Bench Press',
        'currentExerciseIndex': 1,
        'totalExercisesCount': 4,
        'currentExerciseCompletedSetsCount': 2,
        'currentExerciseTotalSetsCount': 4,
        'targetIsWarmup': false,
        'weightUnit': 'kilograms',
        'progress': 5 / 12,
        'isWorkoutEnded': false,
        'isProcessingIntent': false,
        'isAllSetsComplete': false,
        'restLeadsToNewExercise': false,
        'canComplete': true,
      });
    });

    test('sends dates in seconds and the set plan', () {
      final json = LiveActivityState(
        isActive: true,
        completedSetsCount: 0,
        totalSetsCount: 1,
        currentExerciseIndex: 0,
        totalExercisesCount: 1,
        currentExerciseCompletedSetsCount: 0,
        currentExerciseTotalSetsCount: 1,
        progress: 0,
        isAllSetsComplete: false,
        restEndsAt: DateTime.fromMillisecondsSinceEpoch(1500, isUtc: true),
        distanceUnit: LiveActivityDistanceUnit.miles,
        targetKind: LiveActivitySetKind.drop,
        targetPiece: const LiveActivityPiece(index: 1, count: 2, isDrop: true),
      ).toJson();
      expect(json['restEndsAt'], 1.5);
      expect(json['distanceUnit'], 'miles');
      expect(json['targetKind'], 'drop');
      expect(json['targetPiece'], {'index': 1, 'count': 2, 'isDrop': true});
    });

    test("sends the logged set's own unit", () {
      for (final unit in LiveActivityWeightUnit.values) {
        final json = LiveActivityState(
          isActive: true,
          completedSetsCount: 1,
          totalSetsCount: 2,
          currentExerciseIndex: 1,
          totalExercisesCount: 2,
          currentExerciseCompletedSetsCount: 0,
          currentExerciseTotalSetsCount: 1,
          progress: 0.5,
          isAllSetsComplete: false,
          lastLoggedSetId: 'l',
          lastLoggedWeightKg: 80,
          lastLoggedWeightUnit: unit,
        ).toJson();
        expect(json['lastLoggedWeightKg'], 80);
        expect(json['lastLoggedWeightUnit'], unit.name);
      }
    });

    test('is a value', () {
      expect(_state, _state.copy());
    });
  });

  group(OngoingWorkoutSummary, () {
    test('sends the duration in seconds and leaves out what is missing', () {
      expect(
        const OngoingWorkoutSummary(
          duration: Duration(minutes: 52),
          completedSetsCount: 12,
          volumeKg: 4250,
        ).toJson(),
        {'durationSeconds': 3120.0, 'completedSetsCount': 12, 'volumeKg': 4250},
      );
      for (final unit in LiveActivityWeightUnit.values) {
        expect(
          OngoingWorkoutSummary(volumeKg: 4250, weightUnit: unit).toJson(),
          {'volumeKg': 4250, 'weightUnit': unit.name},
        );
      }
      expect(const OngoingWorkoutSummary().toJson(), isEmpty);
      expect(
        const OngoingWorkoutSummary(completedSetsCount: 1),
        const OngoingWorkoutSummary(completedSetsCount: 1),
      );
    });
  });

  group(LiveActivityAction, () {
    test('reads each button', () {
      expect(
        LiveActivityAction.fromJson(const {
          'type': 'completeSet',
          'setId': 's',
        }),
        const CompleteSetAction('s'),
      );
      expect(
        LiveActivityAction.fromJson(const {
          'type': 'adjustLastSetReps',
          'setId': 's',
          'delta': -1,
        }),
        const AdjustLastSetRepsAction('s', -1),
      );
      expect(
        LiveActivityAction.fromJson(const {
          'type': 'adjustRest',
          'seconds': 15,
        }),
        const AdjustRestAction(15),
      );
      expect(
        LiveActivityAction.fromJson(const {'type': 'skipRest'}),
        const SkipRestAction(),
      );
      expect(
        LiveActivityAction.fromJson(const {'type': 'completeWorkout'}),
        const CompleteWorkoutAction(),
      );
    });

    test('are values', () {
      expect(const CompleteSetAction('s').props, ['s']);
      expect(const AdjustRestAction(15).props, [15]);
      expect(const SkipRestAction().props, isEmpty);
      expect(const OngoingWorkoutSummary(volumeKg: 2).props, [
        null,
        null,
        2,
        null,
      ]);
      expect(const LiveActivityPiece(index: 1, count: 2, isDrop: true).props, [
        1,
        2,
        true,
        null,
      ]);
    });

    test('drops what it cannot read', () {
      for (final json in const [
        {'type': 'completeSet'},
        {'type': 'adjustLastSetReps', 'setId': 's'},
        {'type': 'adjustRest'},
        {'type': 'dance'},
      ]) {
        expect(LiveActivityAction.fromJson(json), isNull);
      }
    });
  });

  group(MethodChannelLiveActivityRepository, () {
    late List<MethodCall> calls;
    late Object? Function(MethodCall) answer;
    late List<Object> errors;

    MethodChannelLiveActivityRepository build() =>
        MethodChannelLiveActivityRepository(
          copy: _Copy(),
          onError: (error, _) => errors.add(error),
        );

    setUp(() {
      calls = [];
      errors = [];
      answer = (call) => call.method == 'isAvailable' || call.method == 'show';
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return answer(call);
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });

    const workout = OngoingWorkout(
      title: 'Push Day',
      body: 'Next: Bench Press',
      sessionId: 'session',
      activity: _state,
    );

    test('shows the workout once Live Activities are on', () async {
      final repository = build();
      expect(repository.showsOngoingWorkout, isFalse);
      await repository.showOngoingWorkout(workout);
      expect(calls, isEmpty);

      await repository.initialize();
      expect(repository.showsOngoingWorkout, isTrue);
      await repository.showOngoingWorkout(
        const OngoingWorkout(title: 'No state'),
      );
      await repository.showOngoingWorkout(workout);
      expect(calls.last.method, 'show');
      expect(calls.last.arguments, {
        'sessionId': 'session',
        'workoutName': 'Push Day',
        'state': _state.toJson(),
      });
    });

    test('announces the end of a rest with the reminder title', () async {
      final repository = build();
      await repository.initialize();
      await repository.showOngoingWorkout(
        const OngoingWorkout(title: 'Push Day', alert: true, activity: _state),
      );
      expect((calls.last.arguments as Map)['alert'], {
        'title': 'Rest Complete',
        'body': '',
      });
    });

    test('stops showing once the platform refuses', () async {
      final repository = build();
      await repository.initialize();
      answer = (call) => false;
      await repository.showOngoingWorkout(workout);
      expect(repository.showsOngoingWorkout, isFalse);
    });

    test('ends with the summary', () async {
      final repository = build();
      await repository.clearOngoingWorkout(
        summary: const OngoingWorkoutSummary(completedSetsCount: 3),
      );
      await repository.clearOngoingWorkout();
      expect(calls.map((c) => c.arguments), [
        {
          'summary': {'completedSetsCount': 3},
        },
        <String, Object?>{},
      ]);
    });

    test('reports a platform failure and carries on', () async {
      answer = (call) => throw PlatformException(code: 'nope');
      final repository = build();
      await repository.initialize();
      expect(repository.showsOngoingWorkout, isFalse);
      expect(errors, hasLength(1));
    });

    test('hands the buttons to the handler and says it is ready', () async {
      final repository = build();
      final actions = <LiveActivityAction>[];
      repository.setActionHandler((action) async => actions.add(action));
      await pumpEventQueue();
      expect(calls.single.method, 'ready');

      Future<void> send(MethodCall call) async {
        await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(call),
          (_) {},
        );
      }

      await send(const MethodCall('action', {'type': 'skipRest'}));
      await send(const MethodCall('action', {'type': 'unknown'}));
      await send(const MethodCall('other'));
      expect(actions, [const SkipRestAction()]);

      repository.setActionHandler(null);
      await send(const MethodCall('action', {'type': 'skipRest'}));
      expect(actions, hasLength(1));
    });

    test('does nothing off iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final repository = build();
      await repository.initialize();
      await repository.clearOngoingWorkout();
      repository.setActionHandler((_) async {});
      expect(calls, isEmpty);
      expect(repository.showsOngoingWorkout, isFalse);
    });
  });

  group(FakeLiveActivityRepository, () {
    test('keeps what would show and hands taps to the handler', () async {
      final repository = FakeLiveActivityRepository();
      await repository.initialize();
      await repository.showOngoingWorkout(const OngoingWorkout(title: 'a'));
      expect(repository.shown, isNull);
      repository.showsOngoingWorkout = true;
      await repository.showOngoingWorkout(const OngoingWorkout(title: 'a'));
      expect(repository.shown?.title, 'a');
      await repository.clearOngoingWorkout(
        summary: const OngoingWorkoutSummary(volumeKg: 1),
      );
      expect(repository.shown, isNull);
      expect(repository.ended, 1);
      expect(repository.endedWith, const OngoingWorkoutSummary(volumeKg: 1));

      await repository.tap(const SkipRestAction());
      final taps = <LiveActivityAction>[];
      repository.setActionHandler((action) async => taps.add(action));
      await repository.tap(const AdjustRestAction(15));
      expect(taps, [const AdjustRestAction(15)]);
    });
  });
}

extension on LiveActivityState {
  LiveActivityState copy() => LiveActivityState(
    isActive: isActive,
    completedSetsCount: completedSetsCount,
    totalSetsCount: totalSetsCount,
    currentExerciseIndex: currentExerciseIndex,
    totalExercisesCount: totalExercisesCount,
    currentExerciseCompletedSetsCount: currentExerciseCompletedSetsCount,
    currentExerciseTotalSetsCount: currentExerciseTotalSetsCount,
    progress: progress,
    isAllSetsComplete: isAllSetsComplete,
    currentExerciseName: currentExerciseName,
  );
}
