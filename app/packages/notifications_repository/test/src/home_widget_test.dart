import 'dart:convert';

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
  day: DateTime.utc(2001, 1, 1, 0, 0, 1),
  currentStreak: 12,
  sessionsThisWeek: 2,
  weeklyGoal: 4,
  updatedAt: DateTime.utc(2001, 1, 1, 0, 0, 2, 500),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('home_widget');

  group(WidgetSnapshot, () {
    test('is a value', () {
      expect(_snapshot.props, hasLength(7));
      expect(_snapshot.todaysWorkout!.props, ['Push Day', 6, false, false]);
    });

    test('is the Swift shape, dates in seconds since 2001', () {
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

  group(PluginHomeWidgetRepository, () {
    late Map<String, Object?> store;
    late List<MethodCall> calls;
    late PluginHomeWidgetRepository repository;
    late List<Object> errors;

    List<String> reloads() => [
      for (final call in calls)
        if (call.method == 'updateWidget')
          (call.arguments as Map<Object?, Object?>)['ios']! as String,
    ];

    setUp(() {
      store = {};
      calls = [];
      errors = [];
      repository = PluginHomeWidgetRepository(
        appGroupId: 'group.test',
        onError: (error, _) => errors.add(error),
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        final arguments = call.arguments as Map<Object?, Object?>;
        if (call.method != 'updateWidget') {
          expect(arguments['appGroupId'], 'group.test');
        }
        final id = arguments['id'] as String?;
        switch (call.method) {
          case 'getWidgetData':
            return store[id];
          case 'saveWidgetData':
            final data = arguments['data'];
            data == null ? store.remove(id) : store[id!] = data;
        }
        return true;
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });

    Map<String, Object?> stored() => jsonDecode(
      utf8.decode(store[PluginHomeWidgetRepository.key]! as Uint8List),
    ) as Map<String, Object?>;

    test('keeps the JSON in the App Group and reloads the widgets', () async {
      await repository.write(_snapshot);
      expect(stored(), _snapshot.toJson());
      expect(reloads(), PluginHomeWidgetRepository.kinds);
    });

    test('reloads only when what the widgets show changed', () async {
      await repository.write(_snapshot);
      calls.clear();
      final later = WidgetSnapshot(
        todaysWorkout: _snapshot.todaysWorkout,
        upcomingWorkout: null,
        day: _snapshot.day,
        currentStreak: 12,
        sessionsThisWeek: 2,
        weeklyGoal: 4,
        updatedAt: DateTime.utc(2001, 1, 2),
      );
      await repository.write(later);
      expect(stored(), later.toJson());
      expect(reloads(), isEmpty);

      await repository.write(
        WidgetSnapshot(
          todaysWorkout: null,
          upcomingWorkout: _snapshot.todaysWorkout,
          day: _snapshot.day,
          currentStreak: 13,
          sessionsThisWeek: 3,
          weeklyGoal: 4,
          updatedAt: DateTime.utc(2001, 1, 3),
        ),
      );
      expect(reloads(), PluginHomeWidgetRepository.kinds);
    });

    test('clears a snapshot, and does nothing without one', () async {
      await repository.clear();
      expect(calls.map((c) => c.method), ['getWidgetData']);

      await repository.write(_snapshot);
      calls.clear();
      await repository.clear();
      expect(store, isEmpty);
      expect(reloads(), PluginHomeWidgetRepository.kinds);
    });

    test('reports a failure', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'nope'),
      );
      await repository.write(_snapshot);
      await repository.clear();
      expect(errors, hasLength(2));
      await PluginHomeWidgetRepository(appGroupId: 'group.test').clear();
    });

    test('does nothing off iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await repository.write(_snapshot);
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
