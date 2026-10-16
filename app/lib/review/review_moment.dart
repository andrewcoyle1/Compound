import 'package:compound/nutrition/logic/meal_day.dart' show startOfDay;
import 'package:device_store/device_store.dart';
import 'package:in_app_review/in_app_review.dart';

/// When to ask for a store rating (Swift `ReviewMoment`, decision 10d): the
/// system's prompt only, never a card of our own, and only after something
/// went well.
sealed class ReviewMoment {
  const new();

  /// No second request inside this window, whether the first came from a
  /// moment or from Settings' Rate row (`ReviewPromptPolicy.cooldown`).
  static const cooldown = Duration(days: 120);

  /// The day of food logging in a row that asks.
  static const foodStreakDays = 7;

  /// Whether this moment is worth asking at. Only the workout that reaches
  /// the goal counts, not the ones after it, and only the seventh day, not
  /// every day after; never inside [cooldown] of [lastRequestedAt].
  bool shouldAsk({required DateTime? lastRequestedAt, required DateTime now}) {
    if (lastRequestedAt != null && now.difference(lastRequestedAt) < cooldown) {
      return false;
    }
    return switch (this) {
      ReviewWorkoutFinished(:final sessionsThisWeek, :final weeklyGoal) =>
        weeklyGoal > 0 && sessionsThisWeek == weeklyGoal,
      ReviewFoodLogged(:final daysInARow) => daysInARow == foodStreakDays,
    };
  }

  /// How many days in a row, ending with [today], have something logged.
  /// Zero when today has nothing.
  static int daysInARow({
    required DateTime today,
    required Iterable<DateTime> loggedDays,
  }) {
    final days = {for (final day in loggedDays) startOfDay(day)};
    var day = startOfDay(today);
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }
}

/// A workout was just finished; [sessionsThisWeek] includes it.
final class const ReviewWorkoutFinished({
  required final int sessionsThisWeek,
  required final int weeklyGoal,
}) extends ReviewMoment;

/// Food was just logged; [daysInARow] counts today.
final class const ReviewFoodLogged(final int daysInARow) extends ReviewMoment;

/// The system's rating prompt, behind a class the app provides so tests can
/// stand in for the platform (Swift `AppStoreRatingsHelper`).
class StoreReview {
  const new();

  /// Asks the store to show its prompt; it may show nothing (the system
  /// limits how often), and nothing happens where there is no store.
  Future<void> request() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) await review.requestReview();
  }
}

/// Asks for a rating at Swift's moments, and from Settings' Rate row. Both
/// stamp one date, so neither asks again inside the cooldown.
class ReviewPrompter {
  /// Keeps the last request in [store]; in memory when left out.
  new({
    this._review = const StoreReview(),
    this._now = DateTime.now,
    DeviceStore? store,
  }) : _store = store ?? InMemoryDeviceStore();

  final StoreReview _review;
  final DateTime Function() _now;
  final DeviceStore _store;

  /// SwiftfulUtilities' `AppStoreRatingsHelper` key. Swift keeps a `Date`;
  /// this keeps an ISO 8601 string, so Swift's value reads as never asked.
  static const lastRequestKey = 'last_ratings_request_date';

  /// When a rating was last asked for on this device.
  DateTime? get lastRequestedAt =>
      DateTime.tryParse(_store.getString(lastRequestKey) ?? '');

  /// Settings' Rate row: straight to the prompt (`onRatingsButtonPressed`).
  Future<void> request() async {
    _store.setString(lastRequestKey, _now().toUtc().toIso8601String());
    await _review.request();
  }

  /// Asks if [moment] has earned it (`requestReviewIfEarned`).
  Future<void> requestIfEarned(ReviewMoment moment) async {
    if (!moment.shouldAsk(lastRequestedAt: lastRequestedAt, now: _now())) {
      return;
    }
    await request();
  }
}
