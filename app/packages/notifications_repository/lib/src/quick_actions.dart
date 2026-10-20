import 'dart:async';

import 'package:quick_actions/quick_actions.dart' as plugin;

/// The home-screen quick actions: a long press on the app's icon.
enum QuickAction {
  /// Today's workout, or the tracker when one is under way.
  startWorkout,

  /// Log Weight.
  logWeight,

  /// The meal logger.
  logMeal;

  /// The platform resource drawn beside the title: an image set in the
  /// Runner's asset catalog on iOS, a drawable on Android.
  String get icon => switch (this) {
    startWorkout => 'quick_action_start_workout',
    logWeight => 'quick_action_log_weight',
    logMeal => 'quick_action_log_meal',
  };
}

/// The quick actions offered and the taps on them.
abstract interface class QuickActionsRepository {
  /// Hands every tap, the one that launched the app included, to [handler].
  /// Call once.
  Future<void> initialize(void Function(QuickAction action) handler);

  /// Offers [titles]' actions, in that order, under those titles.
  Future<void> show(Map<QuickAction, String> titles);

  /// Offers none, on sign-out.
  Future<void> clear();
}

/// {@template plugin_quick_actions_repository}
/// The quick actions through `quick_actions`, on iOS and Android.
/// {@endtemplate}
class PluginQuickActionsRepository implements QuickActionsRepository {
  /// {@macro plugin_quick_actions_repository}
  new([this._quickActions = const plugin.QuickActions()]);

  final plugin.QuickActions _quickActions;

  @override
  Future<void> initialize(void Function(QuickAction action) handler) =>
      _quickActions.initialize((type) {
        final action = QuickAction.values.asNameMap()[type];
        if (action != null) handler(action);
      });

  @override
  Future<void> show(Map<QuickAction, String> titles) =>
      _quickActions.setShortcutItems([
        for (final MapEntry(key: action, value: title) in titles.entries)
          plugin.ShortcutItem(
            type: action.name,
            localizedTitle: title,
            icon: action.icon,
          ),
      ]);

  @override
  Future<void> clear() => _quickActions.clearShortcutItems();
}

/// {@template fake_quick_actions_repository}
/// [QuickActionsRepository] with no platform: [titles] is what is offered,
/// and [tap] plays a tap.
/// {@endtemplate}
class FakeQuickActionsRepository implements QuickActionsRepository {
  /// {@macro fake_quick_actions_repository}
  new();

  void Function(QuickAction action)? _handler;

  /// The actions offered, with their titles.
  Map<QuickAction, String> titles = const {};

  @override
  Future<void> initialize(void Function(QuickAction action) handler) async =>
      _handler = handler;

  @override
  Future<void> show(Map<QuickAction, String> titles) async =>
      this.titles = titles;

  @override
  Future<void> clear() async => titles = const {};

  /// Taps [action].
  void tap(QuickAction action) => _handler?.call(action);
}
