import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';

final _snapshot = WidgetSnapshot(
  todaysWorkout: const WidgetWorkout(
    name: 'Push Day',
    exerciseCount: 6,
    isRestDay: false,
    isCompleted: false,
  ),
  upcomingWorkout: null,
  day: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
  currentStreak: 12,
  sessionsThisWeek: 2,
  weeklyGoal: 4,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(2500, isUtc: true),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(MethodChannelHomeWidgetRepository.channelName);

  group(WidgetSnapshot, () {
    test('is a value', () {
      expect(_snapshot.props, hasLength(7));
      expect(_snapshot.todaysWorkout!.props, ['Push Day', 6, false, false]);
    });

    test('is the Swift shape, dates in seconds', () {
      expect(_snapshot.toJson(), {
        'todaysWorkout': {
          'name': 'Push Day',
          'exerciseCount': 6,
          'isRestDay': false,
          'isCompleted': false,
        },
        'day': 1.0,
        'currentStreak': 12,
        'sessionsThisWeek': 2,
        'weeklyGoal': 4,
        'updatedAt': 2.5,
      });
    });
  });

  group(MethodChannelHomeWidgetRepository, () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'clear') throw PlatformException(code: 'nope');
        return null;
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('writes and clears the snapshot, reporting a failure', () async {
      final errors = <Object>[];
      final repository = MethodChannelHomeWidgetRepository(
        onError: (error, _) => errors.add(error),
      );
      await repository.write(_snapshot);
      await repository.clear();
      expect(calls.first.arguments, _snapshot.toJson());
      expect(calls.map((c) => c.method), ['write', 'clear']);
      expect(errors, hasLength(1));
    });

    test('does nothing off iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await MethodChannelHomeWidgetRepository().write(_snapshot);
      expect(calls, isEmpty);
    });
  });

  group(FakeHomeWidgetRepository, () {
    test('keeps the snapshot until cleared', () async {
      final repository = FakeHomeWidgetRepository();
      await repository.write(_snapshot);
      expect(repository.snapshot, _snapshot);
      await repository.clear();
      expect(repository.snapshot, isNull);
    });
  });
}
