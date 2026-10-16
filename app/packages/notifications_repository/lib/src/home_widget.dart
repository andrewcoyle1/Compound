import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// The Swift `Codable` shape, dates in seconds since 1970.
  Map<String, Object?> toJson() => {
    'todaysWorkout': ?todaysWorkout?.toJson(),
    'upcomingWorkout': ?upcomingWorkout?.toJson(),
    'day': day.microsecondsSinceEpoch / 1e6,
    'currentStreak': currentStreak,
    'sessionsThisWeek': sessionsThisWeek,
    'weeklyGoal': weeklyGoal,
    'updatedAt': updatedAt.microsecondsSinceEpoch / 1e6,
  };

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

/// {@template method_channel_home_widget_repository}
/// The widgets through the Runner's `WorkoutActivityChannel`, which keeps
/// the snapshot in the flavor's App Group. Nothing off iOS; a platform
/// failure goes to `onError` and is otherwise dropped.
/// {@endtemplate}
class MethodChannelHomeWidgetRepository implements HomeWidgetRepository {
  /// {@macro method_channel_home_widget_repository}
  new({MethodChannel? channel, this._onError})
    : _channel = channel ?? const MethodChannel(channelName);

  /// The Runner's channel.
  static const channelName = 'com.andrewcoyle.compound/home_widgets';

  final MethodChannel _channel;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  @override
  Future<void> write(WidgetSnapshot snapshot) =>
      _call('write', snapshot.toJson());

  @override
  Future<void> clear() => _call('clear');

  Future<void> _call(String method, [Object? arguments]) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
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
