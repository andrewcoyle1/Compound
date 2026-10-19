import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// {@template widget_workout}
/// A day's workout as the home-screen widgets show it
/// (`WidgetSnapshot.TodaysWorkout`).
/// {@endtemplate}
class const WidgetWorkout({
  required final String name,
  required final int exerciseCount,
  required final bool isRestDay,
  required final bool isCompleted,
}) extends Equatable {
  /// {@macro widget_workout}
  this;

  /// The Swift `Codable` shape.
  Map<String, Object?> toJson() => {
    'name': name,
    'exerciseCount': exerciseCount,
    'isRestDay': isRestDay,
    'isCompleted': isCompleted,
  };

  @override
  List<Object?> get props => [name, exerciseCount, isRestDay, isCompleted];
}

/// {@template widget_snapshot}
/// What the home-screen widgets show (`WidgetSnapshot`): Today's Workout,
/// the streak and the weekly ring, written when the app goes to the
/// background.
/// {@endtemplate}
class const WidgetSnapshot({
  /// Today's day plan, for [day] only.
  required final WidgetWorkout? todaysWorkout,

  /// What the queue holds for any later day.
  required final WidgetWorkout? upcomingWorkout,

  /// The start of the day [todaysWorkout] belongs to.
  required final DateTime day,

  /// The weekly streak, in weeks.
  required final int currentStreak,

  /// Finished sessions in the week containing [day].
  required final int sessionsThisWeek,
  required final int weeklyGoal,
  required final DateTime updatedAt,
}) extends Equatable {
  /// {@macro widget_snapshot}
  this;

  /// The Swift `Codable` shape, dates as `JSONEncoder` writes them by
  /// default: seconds since 1 January 2001.
  Map<String, Object?> toJson() => {
    'todaysWorkout': ?todaysWorkout?.toJson(),
    'upcomingWorkout': ?upcomingWorkout?.toJson(),
    'day': _swiftSeconds(day),
    'currentStreak': currentStreak,
    'sessionsThisWeek': sessionsThisWeek,
    'weeklyGoal': weeklyGoal,
    'updatedAt': _swiftSeconds(updatedAt),
  };

  static double _swiftSeconds(DateTime date) =>
      date.microsecondsSinceEpoch / 1e6 - _swiftEpoch;

  /// 1 January 2001 in seconds since 1970, where Swift's `Date` counts from.
  static const _swiftEpoch = 978307200;

  @override
  List<Object?> get props => [
    todaysWorkout,
    upcomingWorkout,
    day,
    currentStreak,
    sessionsThisWeek,
    weeklyGoal,
    updatedAt,
  ];
}

/// The home-screen widgets (iOS): Today's Workout, Streak and Weekly Goal.
abstract interface class HomeWidgetRepository {
  /// Keeps [snapshot] for the widgets, reloading them when it changed.
  Future<void> write(WidgetSnapshot snapshot);

  /// Forgets it on sign-out, so the home screen stops showing that account.
  Future<void> clear();
}

/// {@template plugin_home_widget_repository}
/// The widgets through `home_widget`: the snapshot is kept as JSON bytes
/// under [key] in the flavor's App Group ([appGroupId]), where the widget
/// extension's `WidgetSnapshotStore` reads it, and the widgets reload only
/// when something they show changed. Nothing off iOS; a platform failure
/// goes to `onError` and is otherwise dropped.
/// {@endtemplate}
class PluginHomeWidgetRepository implements HomeWidgetRepository {
  /// {@macro plugin_home_widget_repository}
  new({required this.appGroupId, this._onError});

  /// The App Group the widget extension reads (`APP_GROUP_ID`).
  final String appGroupId;

  final void Function(Object error, StackTrace stackTrace)? _onError;

  /// The App Group key, shared with the Swift app's widgets.
  static const key = 'widget.snapshot.v1';

  /// The widgets' kinds (`HomeWidgets.swift`).
  static const kinds = [
    'TodaysWorkoutWidget',
    'StreakWidget',
    'WeeklyRingWidget',
  ];

  @override
  Future<void> write(WidgetSnapshot snapshot) => _run(() async {
    final stored = await _read();
    final json = snapshot.toJson();
    await _save(utf8.encode(jsonEncode(json)));
    if (stored != null) {
      // What the widgets show is unchanged when only the time written is.
      final previous = jsonDecode(utf8.decode(stored)) as Map<String, Object?>;
      json['updatedAt'] = previous['updatedAt'];
      if (jsonEncode(json) == jsonEncode(previous)) return;
    }
    await _reload();
  });

  @override
  Future<void> clear() => _run(() async {
    if (await _read() == null) return;
    await _save(null);
    await _reload();
  });

  Future<Uint8List?> _read() =>
      HomeWidget.getWidgetData<Uint8List>(key, appGroupId: appGroupId);

  Future<void> _save(Uint8List? bytes) => HomeWidget.saveWidgetData(
    key,
    bytes,
    appGroupId: appGroupId,
    deleteFile: false,
  );

  Future<void> _reload() => Future.wait([
    for (final kind in kinds) HomeWidget.updateWidget(iOSName: kind),
  ]);

  Future<void> _run(Future<void> Function() body) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await body();
    } on Object catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }
}

/// {@template fake_home_widget_repository}
/// A [HomeWidgetRepository] with no platform: the snapshot kept is
/// [snapshot].
/// {@endtemplate}
class FakeHomeWidgetRepository implements HomeWidgetRepository {
  /// {@macro fake_home_widget_repository}
  new();

  /// What the widgets would show, or `null`.
  WidgetSnapshot? snapshot;

  @override
  Future<void> write(WidgetSnapshot snapshot) async => this.snapshot = snapshot;

  @override
  Future<void> clear() async => snapshot = null;
}
