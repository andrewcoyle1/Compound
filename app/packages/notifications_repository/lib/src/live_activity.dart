import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:notifications_repository/src/local_reminders.dart';
import 'package:notifications_repository/src/notifications_repository.dart';

/// The units the Live Activity shows a weight in (`LiveActivityWeightUnit`).
enum LiveActivityWeightUnit {
  /// kg.
  kilograms,

  /// lb.
  pounds,
}

/// The units it shows a distance in (`LiveActivityDistanceUnit`).
enum LiveActivityDistanceUnit {
  /// m and km.
  meters,

  /// mi.
  miles,
}

/// A set's kind beside its number, with the set plan on
/// (`LiveActivitySetKind`); a plain set has none.
enum LiveActivitySetKind {
  /// Drop.
  drop,

  /// Failure.
  amrap,

  /// Myo-reps.
  myo,

  /// Rest-pause.
  restPause,

  /// Cluster.
  cluster,

  /// Partials.
  partials,

  /// Stretch.
  stretch,

  /// Hold.
  hold,
}

/// {@template live_activity_piece}
/// Where the target is in a set worked in pieces (`SetPiece`): the set is
/// piece 1, its drops or mini-sets the pieces after it.
/// {@endtemplate}
class const LiveActivityPiece({
  /// From 1, the set itself being 1.
  required final int index,

  /// The set and all its drops or mini-sets.
  required final int count,

  /// The pieces after the first are drops rather than mini-sets.
  required final bool isDrop,

  /// The partials, stretch or hold this piece is, named as itself.
  final LiveActivitySetKind? technique,
}) extends Equatable {
  /// {@macro live_activity_piece}
  this;

  /// Whole-workout progress with this set's logged pieces counted in.
  double progress({required int completedSets, required int totalSets}) {
    if (totalSets <= 0 || count <= 0) return 0;
    final value = (completedSets + (index - 1) / count) / totalSets;
    return value > 1 ? 1 : value;
  }

  /// The Swift `Codable` shape.
  Map<String, Object?> toJson() => {
    'index': index,
    'count': count,
    'isDrop': isDrop,
    'technique': ?technique?.name,
  };

  @override
  List<Object?> get props => [index, count, isDrop, technique];
}

/// {@template live_activity_state}
/// What the Live Activity shows of the workout under way
/// (`WorkoutActivityAttributes.ContentState`), rebuilt from the session on
/// every change, as Swift's `LiveActivityManager.makeContentState`. The
/// end-of-workout fields and the buttons' loading state are the platform's.
/// {@endtemplate}
class const LiveActivityState({
  /// Not paused.
  required final bool isActive,

  /// Working sets done, a pair once both sides are.
  required final int completedSetsCount,
  required final int totalSetsCount,
  required final int currentExerciseIndex,
  required final int totalExercisesCount,

  /// Counted within the target's group: warm-ups while a warm-up is next.
  required final int currentExerciseCompletedSetsCount,
  required final int currentExerciseTotalSetsCount,

  /// 0 to 1.
  required final double progress,
  required final bool isAllSetsComplete,
  final String? currentExerciseName,

  /// A bundled picture's name, such as `BarbellBenchPress`.
  final String? currentExerciseImageName,
  final bool targetIsWarmup = false,
  final String? targetSetId,
  final double? targetWeightKg,
  final int? targetReps,
  final double? targetDistanceMeters,
  final int? targetDurationSec,
  final LiveActivityWeightUnit weightUnit = LiveActivityWeightUnit.kilograms,
  final LiveActivityDistanceUnit? distanceUnit,

  /// When the running rest ends.
  final DateTime? restEndsAt,

  /// The set logged last, whose reps can be corrected while it rests.
  final String? lastLoggedSetId,
  final int? lastLoggedReps,
  final double? lastLoggedWeightKg,

  /// The unit of the exercise the logged set belongs to, which is not
  /// [weightUnit] when the rest leads into an exercise kept in the other.
  final LiveActivityWeightUnit? lastLoggedWeightUnit,
  final bool restLeadsToNewExercise = false,

  /// "L" or "R" for one side of a split pair.
  final String? targetSide,

  /// Whether the target holds what its tracking mode needs to be logged.
  final bool canComplete = true,
  final LiveActivitySetKind? targetKind,
  final LiveActivityPiece? targetPiece,
}) extends Equatable {
  /// {@macro live_activity_state}
  this;

  /// The Swift `Codable` shape, dates in seconds since 1970. Every
  /// non-optional Swift property is present.
  Map<String, Object?> toJson() => {
    'isActive': isActive,
    'completedSetsCount': completedSetsCount,
    'totalSetsCount': totalSetsCount,
    'currentExerciseName': ?currentExerciseName,
    'currentExerciseImageName': ?currentExerciseImageName,
    'currentExerciseIndex': currentExerciseIndex,
    'totalExercisesCount': totalExercisesCount,
    'currentExerciseCompletedSetsCount': currentExerciseCompletedSetsCount,
    'currentExerciseTotalSetsCount': currentExerciseTotalSetsCount,
    'targetIsWarmup': targetIsWarmup,
    'targetSetId': ?targetSetId,
    'targetWeightKg': ?targetWeightKg,
    'targetReps': ?targetReps,
    'targetDistanceMeters': ?targetDistanceMeters,
    'targetDurationSec': ?targetDurationSec,
    'weightUnit': weightUnit.name,
    'restEndsAt': ?_seconds(restEndsAt),
    'progress': progress,
    'isWorkoutEnded': false,
    'isProcessingIntent': false,
    'isAllSetsComplete': isAllSetsComplete,
    'lastLoggedSetId': ?lastLoggedSetId,
    'lastLoggedReps': ?lastLoggedReps,
    'lastLoggedWeightKg': ?lastLoggedWeightKg,
    'lastLoggedWeightUnit': ?lastLoggedWeightUnit?.name,
    'restLeadsToNewExercise': restLeadsToNewExercise,
    'distanceUnit': ?distanceUnit?.name,
    'targetSide': ?targetSide,
    'canComplete': canComplete,
    'targetKind': ?targetKind?.name,
    'targetPiece': ?targetPiece?.toJson(),
  };

  @override
  List<Object?> get props => [
    isActive,
    completedSetsCount,
    totalSetsCount,
    currentExerciseIndex,
    totalExercisesCount,
    currentExerciseCompletedSetsCount,
    currentExerciseTotalSetsCount,
    progress,
    isAllSetsComplete,
    currentExerciseName,
    currentExerciseImageName,
    targetIsWarmup,
    targetSetId,
    targetWeightKg,
    targetReps,
    targetDistanceMeters,
    targetDurationSec,
    weightUnit,
    distanceUnit,
    restEndsAt,
    lastLoggedSetId,
    lastLoggedReps,
    lastLoggedWeightKg,
    lastLoggedWeightUnit,
    restLeadsToNewExercise,
    targetSide,
    canComplete,
    targetKind,
    targetPiece,
  ];
}

double? _seconds(DateTime? date) =>
    date == null ? null : date.microsecondsSinceEpoch / 1e6;

/// {@template ongoing_workout_summary}
/// What a finished workout's Live Activity shows for half an hour.
/// {@endtemplate}
class const OngoingWorkoutSummary({
  final Duration? duration,
  final int? completedSetsCount,
  final double? volumeKg,

  /// The unit the volume is shown in: the one most sets were logged in.
  final LiveActivityWeightUnit? weightUnit,
}) extends Equatable {
  /// {@macro ongoing_workout_summary}
  this;

  /// The Swift side's arguments.
  Map<String, Object?> toJson() => {
    'durationSeconds': ?duration == null
        ? null
        : duration!.inMicroseconds / 1e6,
    'completedSetsCount': ?completedSetsCount,
    'volumeKg': ?volumeKg,
    'weightUnit': ?weightUnit?.name,
  };

  @override
  List<Object?> get props => [
    duration,
    completedSetsCount,
    volumeKg,
    weightUnit,
  ];
}

/// A button tapped on the Live Activity (`LiveActivityIntentHandling`).
sealed class LiveActivityAction extends Equatable {
  /// Subclasses only.
  const new();

  /// The action the platform sent, or `null` for one this build does not
  /// know.
  static LiveActivityAction? fromJson(Map<Object?, Object?> json) =>
      switch (json['type']) {
        'completeSet' => switch (json['setId']) {
          final String id => CompleteSetAction(id),
          _ => null,
        },
        'adjustLastSetReps' => switch ((json['setId'], json['delta'])) {
          (final String id, final int delta) => AdjustLastSetRepsAction(
            id,
            delta,
          ),
          _ => null,
        },
        'adjustRest' => switch (json['seconds']) {
          final int seconds => AdjustRestAction(seconds),
          _ => null,
        },
        'skipRest' => const SkipRestAction(),
        'completeWorkout' => const CompleteWorkoutAction(),
        _ => null,
      };

  @override
  List<Object?> get props => [];
}

/// Complete: log the set with its own values and start its rest.
final class const CompleteSetAction(final String setId)
    extends LiveActivityAction {
  /// Logs [setId].
  this;

  @override
  List<Object?> get props => [setId];
}

/// − or + on the set just logged, during its rest.
final class const AdjustLastSetRepsAction(final String setId, final int delta)
    extends LiveActivityAction {
  /// [delta] reps on [setId].
  this;

  @override
  List<Object?> get props => [setId, delta];
}

/// +15s on the running rest.
final class const AdjustRestAction(final int seconds)
    extends LiveActivityAction {
  /// [seconds] more rest.
  this;

  @override
  List<Object?> get props => [seconds];
}

/// Skip, ending the rest now.
final class const SkipRestAction() extends LiveActivityAction {
  /// Ends the rest.
  this;
}

/// Finish, as the tracker's Finish button.
final class const CompleteWorkoutAction() extends LiveActivityAction {
  /// Finishes the workout.
  this;
}

/// What does the work of a [LiveActivityAction]. Its future completes once
/// the work, and the push that shows it, are done.
typedef LiveActivityActionHandler = Future<void> Function(
  LiveActivityAction action,
);

/// Where the workout under way shows outside the app: Android's ongoing
/// notification (`NotificationsRepository`) and iOS's Live Activity
/// ([LiveActivityRepository]). The tracker feeds each the same
/// `OngoingWorkout`.
abstract interface class OngoingWorkoutSurface {
  /// Whether this one shows on this device.
  bool get showsOngoingWorkout;

  /// Shows, or updates, the workout; nothing where [showsOngoingWorkout]
  /// is false.
  Future<void> showOngoingWorkout(OngoingWorkout workout);

  /// Withdraws it. With [summary] (a finished workout) a surface that can
  /// keeps showing it for a while.
  Future<void> clearOngoingWorkout({OngoingWorkoutSummary? summary});
}

/// The Live Activity and Dynamic Island (iOS): the workout under way on the
/// Lock Screen, with buttons that work the tracker.
abstract class LiveActivityRepository implements OngoingWorkoutSurface {
  /// Asks the platform whether Live Activities are on. Call once at launch.
  Future<void> initialize();

  /// Hands the buttons' taps to [handler]; `null` stops.
  void setActionHandler(LiveActivityActionHandler? handler);
}

/// {@template method_channel_live_activity_repository}
/// The Live Activity through the Runner's `WorkoutActivityChannel`. The
/// rest-over alert's title is the rest-over reminder's, from the copy; a
/// platform failure goes to `onError` and is otherwise dropped, as the
/// workout carries on without it.
/// {@endtemplate}
class MethodChannelLiveActivityRepository implements LiveActivityRepository {
  /// {@macro method_channel_live_activity_repository}
  new({required this._copy, MethodChannel? channel, this._onError})
    : _channel = channel ?? const MethodChannel(channelName);

  /// The Runner's channel.
  static const channelName = 'com.andrewcoyle.compound/live_activity';

  final MethodChannel _channel;
  final NotificationCopy _copy;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  bool _available = false;

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get showsOngoingWorkout => _available;

  @override
  Future<void> initialize() async {
    if (!_isIos) return;
    _available =
        await _guard(() => _channel.invokeMethod<bool>('isAvailable')) ?? false;
  }

  /// Answers whether one is showing, so a refusal (Live Activities turned
  /// off since launch) hands the rest-over alert back to the notification.
  @override
  Future<void> showOngoingWorkout(OngoingWorkout workout) async {
    final state = workout.activity;
    if (!_available || state == null) return;
    final shown = await _guard(
      () => _channel.invokeMethod<bool>('show', {
        'sessionId': workout.sessionId,
        'workoutName': workout.title,
        'state': state.toJson(),
        if (workout.alert)
          'alert': {
            'title': _copy.reminder(LocalReminderKind.restOver).title,
            'body': workout.body ?? '',
          },
      }),
    );
    if (shown == false) _available = false;
  }

  @override
  Future<void> clearOngoingWorkout({OngoingWorkoutSummary? summary}) async {
    if (!_isIos) return;
    await _guard(
      () => _channel.invokeMethod<void>('end', {'summary': ?summary?.toJson()}),
    );
  }

  @override
  void setActionHandler(LiveActivityActionHandler? handler) {
    if (!_isIos) return;
    if (handler == null) return _channel.setMethodCallHandler(null);
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'action') return;
      final action = LiveActivityAction.fromJson(
        call.arguments as Map<Object?, Object?>,
      );
      if (action != null) await handler(action);
    });
    unawaited(_guard(() => _channel.invokeMethod<void>('ready')));
  }

  Future<T?> _guard<T>(Future<T?> Function() call) async {
    try {
      return await call();
    } on Object catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
      return null;
    }
  }
}

/// {@template fake_live_activity_repository}
/// A [LiveActivityRepository] with no platform, for tests: what would show
/// is kept in [shown], the last end's summary in [endedWith], and [tap]
/// stands in for a button.
/// {@endtemplate}
class FakeLiveActivityRepository implements LiveActivityRepository {
  /// {@macro fake_live_activity_repository}
  new({this.showsOngoingWorkout = false});

  @override
  bool showsOngoingWorkout;

  /// The workout showing, or `null`.
  OngoingWorkout? shown;

  /// How many times it was ended.
  int ended = 0;

  /// The summary it last ended with.
  OngoingWorkoutSummary? endedWith;

  LiveActivityActionHandler? _handler;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showOngoingWorkout(OngoingWorkout workout) async {
    if (showsOngoingWorkout) shown = workout;
  }

  @override
  Future<void> clearOngoingWorkout({OngoingWorkoutSummary? summary}) async {
    shown = null;
    ended++;
    endedWith = summary;
  }

  @override
  void setActionHandler(LiveActivityActionHandler? handler) =>
      _handler = handler;

  /// A tap on the Live Activity's button for [action]; completes when the
  /// handler has.
  Future<void> tap(LiveActivityAction action) async {
    await _handler?.call(action);
  }
}
