import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// {@template app_intent_refusal}
/// Why an intent could not do what was asked, as the sentence Siri says
/// (Swift `AppIntentsError`).
/// {@endtemplate}
class AppIntentRefusal implements Exception {
  /// {@macro app_intent_refusal}
  const new(this.sentence);

  /// What Siri says.
  final String sentence;
}

/// {@template intent_workout}
/// A workout Siri can start (Swift `WorkoutTemplateEntity`).
/// {@endtemplate}
class const IntentWorkout({
  required final String id,
  required final String name,
}) extends Equatable {
  /// {@macro intent_workout}
  this;

  /// The shape the Runner reads.
  Map<String, Object?> toJson() => {'id': id, 'name': name};

  @override
  List<Object?> get props => [id, name];
}

/// What Siri and Shortcuts ask the app (Swift `AppIntentsInteractor`): each
/// answers with the sentence Siri says, or throws [AppIntentRefusal].
abstract interface class AppIntentHandler {
  /// The workouts Start Workout offers.
  Future<List<IntentWorkout>> workouts();

  /// Starts the workout with [id] and opens the tracker.
  Future<String> startWorkout(String id);

  /// Logs a weigh-in of [value], in pounds when [pounds] is true, kilograms
  /// when false, and the user's own unit when null.
  Future<String> logWeight(double value, {bool? pounds});

  /// The workouts finished this week.
  Future<({int count, String sentence})> workoutsThisWeek();

  /// Today's workout in the active mesocycle, if it has one.
  Future<({IntentWorkout? workout, String sentence})> todaysWorkout();

  /// Opens the recipes.
  Future<void> browseRecipes();
}

/// Siri and Shortcuts (iOS App Intents).
abstract interface class AppIntentsRepository {
  /// Hands the intents to [handler]; `null` stops.
  void setHandler(AppIntentHandler? handler);
}

/// {@template method_channel_app_intents_repository}
/// The intents through the Runner's `AppIntentsChannel`. Nothing off iOS.
/// {@endtemplate}
class MethodChannelAppIntentsRepository implements AppIntentsRepository {
  /// {@macro method_channel_app_intents_repository}
  new({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  /// The Runner's channel.
  static const channelName = 'com.andrewcoyle.compound/app_intents';

  final MethodChannel _channel;

  @override
  void setHandler(AppIntentHandler? handler) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (handler == null) return _channel.setMethodCallHandler(null);
    _channel.setMethodCallHandler((call) => _answer(handler, call));
    unawaited(_channel.invokeMethod<void>('ready'));
  }

  static Future<Object?> _answer(
    AppIntentHandler handler,
    MethodCall call,
  ) async {
    final arguments = (call.arguments as Map<Object?, Object?>?) ?? const {};
    try {
      switch (call.method) {
        case 'workouts':
          return {
            'workouts': [for (final w in await handler.workouts()) w.toJson()],
          };
        case 'startWorkout':
          return {
            'sentence': await handler.startWorkout(arguments['id']! as String),
          };
        case 'logWeight':
          final unit = arguments['unit'];
          return {
            'sentence': await handler.logWeight(
              (arguments['value']! as num).toDouble(),
              pounds: unit == null ? null : unit == 'pounds',
            ),
          };
        case 'workoutsThisWeek':
          final answer = await handler.workoutsThisWeek();
          return {'count': answer.count, 'sentence': answer.sentence};
        case 'todaysWorkout':
          final answer = await handler.todaysWorkout();
          return {
            'workout': ?answer.workout?.toJson(),
            'sentence': answer.sentence,
          };
        case 'browseRecipes':
          await handler.browseRecipes();
          return const <String, Object?>{};
      }
    } on AppIntentRefusal catch (refusal) {
      throw PlatformException(code: 'refused', message: refusal.sentence);
    }
    throw MissingPluginException(call.method);
  }
}

/// {@template fake_app_intents_repository}
/// An [AppIntentsRepository] with no platform: the handler set is
/// [handler], for a test to call as Siri would.
/// {@endtemplate}
class FakeAppIntentsRepository implements AppIntentsRepository {
  /// {@macro fake_app_intents_repository}
  new();

  /// The handler the app set.
  AppIntentHandler? handler;

  @override
  void setHandler(AppIntentHandler? handler) => this.handler = handler;
}
