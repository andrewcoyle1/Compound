import 'package:equatable/equatable.dart';

/// The two Pro plans, as in the Swift app's `EntitlementOption`.
enum SubscriptionPlan {
  /// Pro Annual.
  yearly,

  /// Pro Monthly.
  monthly;

  /// The store product id. Development builds sell the `.dev.` products, as
  /// the Swift app's DEBUG builds do.
  String productId({required bool development}) =>
      'com.andrewcoyle.compound.${development ? 'dev.' : ''}$name';

  /// Every plan's product id, in the paywall's order (yearly first).
  static List<String> productIds({required bool development}) => [
    for (final plan in values) plan.productId(development: development),
  ];
}

/// How often a subscription renews.
enum ProductDuration {
  /// Yearly.
  year,

  /// Monthly.
  month,

  /// Weekly.
  week,

  /// Daily.
  day;

  /// The unit of an ISO 8601 period such as `P1M`, as the stores report it,
  /// or `null` for a one-off purchase. Like Swift, only the unit counts:
  /// `P3M` is a [month].
  static ProductDuration? fromIsoPeriod(String? period) =>
      switch (period?.isEmpty ?? true ? null : period![period.length - 1]) {
        'Y' => year,
        'M' => month,
        'W' => week,
        'D' => day,
        _ => null,
      };
}

/// {@template subscription_product}
/// A product the store will sell, as shown on the paywall. Mirrors
/// SwiftfulPurchasing's `AnyProduct`.
/// {@endtemplate}
class const SubscriptionProduct({
  required final String id,
  required final String title,
  required final String subtitle,
  required final String priceString,
  final ProductDuration? duration,
}) extends Equatable {
  /// {@macro subscription_product}
  this;

  @override
  List<Object?> get props => [id, title, subtitle, priceString, duration];
}

/// {@template purchased_entitlement}
/// One entitlement on the customer's account, active or lapsed. Mirrors
/// SwiftfulPurchasing's `PurchasedEntitlement`.
/// {@endtemplate}
class const PurchasedEntitlement({
  required final String id,
  required final String productId,
  required final bool isActive,
  final DateTime? expirationDate,
  final DateTime? originalPurchaseDate,
  final DateTime? latestPurchaseDate,
  final bool isSandbox = false,
}) extends Equatable {
  /// {@macro purchased_entitlement}
  this;

  @override
  List<Object?> get props => [
    id,
    productId,
    isActive,
    expirationDate,
    originalPurchaseDate,
    latestPurchaseDate,
    isSandbox,
  ];
}

/// {@template purchases_state}
/// What the store has said about the signed-in user: its [entitlements],
/// latest expiry first.
///
/// [isResolved] is `false` until the store has answered for the user passed
/// to `logIn`. Before then [entitlements] is empty or belongs to an
/// anonymous store account, so it can't be read as "not a subscriber".
/// {@endtemplate}
class const PurchasesState({
  final List<PurchasedEntitlement> entitlements = const [],
  final bool isResolved = false,
}) extends Equatable {
  /// {@macro purchases_state}
  this;

  /// Whether at least one entitlement is active (any entitlement id, as in
  /// Swift's `hasActiveEntitlement`).
  bool get hasActiveEntitlement => entitlements.any((e) => e.isActive);

  /// The premium gate for this state; see [isPremium].
  bool isPremiumWith({bool developmentOverride = false}) => isPremium(
    entitlements: entitlements,
    entitlementsAreResolved: isResolved,
    developmentOverride: developmentOverride,
  );

  @override
  List<Object?> get props => [entitlements, isResolved];
}

/// Whether the user is treated as a subscriber: the gate every premium check
/// runs through. A port of the Swift app's `PremiumAccess.isPremium`.
///
/// - [developmentOverride] ("Simulate Premium" in a development build) grants
///   access and never removes it.
/// - Until the store has answered ([entitlementsAreResolved] is `false`) the
///   answer is optimistic: an empty list then looks the same as a real
///   non-subscriber's, and sending a paying subscriber to the paywall because
///   the network was slow is the worse bug.
/// - Once resolved, any active entitlement grants access; none, or only
///   lapsed ones, does not.
bool isPremium({
  required List<PurchasedEntitlement> entitlements,
  required bool developmentOverride,
  bool entitlementsAreResolved = true,
}) =>
    developmentOverride ||
    !entitlementsAreResolved ||
    entitlements.any((e) => e.isActive);
