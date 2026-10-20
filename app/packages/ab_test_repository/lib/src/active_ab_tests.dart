import 'package:equatable/equatable.dart';

/// Which paywall a user sees (Swift `PaywallTestOption`); the names are
/// Swift's raw values, in Remote Config and on the device.
enum PaywallTestOption {
  /// The store's own subscription screen (Swift's StoreKit
  /// `SubscriptionStoreView`).
  storeKit,

  /// Compound's own paywall: the default.
  custom,

  /// RevenueCat's remotely designed paywall.
  revenueCat,
}

/// The tests this user is in (Swift `ActiveABTests`). The defaults are
/// Swift's, so a user with no assignment sees what the Swift app shows.
class const ActiveAbTests({
  /// `_20251205_notifications_test`.
  final bool notificationsTest = false,

  /// `_20241205_PaywallTest`.
  final PaywallTestOption paywallTest = PaywallTestOption.custom,
}) extends Equatable {
  /// Creates [ActiveAbTests]; the defaults are Swift's.
  this;

  /// The Remote Config parameter and device key for [notificationsTest].
  static const notificationsTestKey = '_20251205_notifications_test';

  /// The Remote Config parameter and device key for [paywallTest].
  static const paywallTestKey = '_20241205_PaywallTest';

  /// [name]'s option, or the default for anything else.
  static PaywallTestOption paywallOption(String? name) =>
      PaywallTestOption.values.asNameMap()[name] ?? PaywallTestOption.custom;

  /// The assignments as analytics user properties, under Swift's names
  /// (`test` and the key).
  Map<String, Object> get eventParameters => {
    'test$notificationsTestKey': notificationsTest,
    'test$paywallTestKey': paywallTest.name,
  };

  /// These tests with the given ones changed.
  ActiveAbTests copyWith({
    bool? notificationsTest,
    PaywallTestOption? paywallTest,
  }) => ActiveAbTests(
    notificationsTest: notificationsTest ?? this.notificationsTest,
    paywallTest: paywallTest ?? this.paywallTest,
  );

  @override
  List<Object> get props => [notificationsTest, paywallTest];
}
