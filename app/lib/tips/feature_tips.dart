import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The one-time tips for features hidden behind a gesture: which this
/// device has seen, kept in [DeviceStore] by id, and their analytics.
class FeatureTips {
  /// Keeps what is seen in a [DeviceStore] and logs to analytics.
  new({required this._store, required this._analytics});

  final DeviceStore _store;
  final AnalyticsRepository _analytics;

  /// Metric detail: press and hold the chart, pinch to zoom.
  static const metricChart = 'metric_chart';

  /// Nutrition: swipe a food to log its meal again.
  static const mealSwipe = 'meal_swipe';

  /// Workout tracker: swipe a set for its own rest, or to delete it.
  static const setSwipe = 'set_swipe';

  /// Workout tracker: tap last time's figures to copy them into a set.
  static const setFillLast = 'set_fill_last';

  static const _prefix = 'tip_seen_';

  /// Whether this device has shown tip [id].
  bool isSeen(String id) => _store.getBool('$_prefix$id') ?? false;

  /// Tip [id] showed on [screen]: it is seen.
  void shown(String screen, String id) {
    _store.setBool('$_prefix$id', value: true);
    _track('${screen}_Tip_Shown', id);
  }

  /// Tip [id] on [screen] closed.
  void dismissed(String screen, String id) =>
      _track('${screen}_Tip_Dismissed', id);

  /// Forgets every tip seen, so each shows again (Developer Settings).
  void reset() {
    for (final key in _store.keys) {
      if (key.startsWith(_prefix)) _store.remove(key);
    }
  }

  void _track(String name, String id) =>
      _analytics.trackEvent(AnalyticsEvent(name, parameters: {'tip_id': id}));
}

/// [screen]'s tips, offered in the order of [tips] through an
/// [AppTipScope]; the [AppTip]s in [child] mark their targets. Without
/// [FeatureTips] above it (tests, onboarding), it is only [child].
class ScreenTips extends StatelessWidget {
  /// The tips of [screen], its analytics name (`NutritionView`).
  const new({
    required this.screen,
    required this.tips,
    required this.child,
    super.key,
  });

  /// The screen's analytics name, as its `_Appear` event has it.
  final String screen;

  /// Its tip ids ([FeatureTips.metricChart] and the rest), in order.
  final List<String> tips;

  /// The screen.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final book = context.read<FeatureTips?>();
    if (book == null) return child;
    return AppTipScope(
      tips: tips,
      isSeen: book.isSeen,
      onShown: (id) => book.shown(screen, id),
      onDismissed: (id) => book.dismissed(screen, id),
      dismissLabel: context.l10n.tipGotIt,
      child: child,
    );
  }
}
