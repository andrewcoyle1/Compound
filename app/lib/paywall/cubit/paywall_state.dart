part of 'paywall_cubit.dart';

/// Where loading the plans has got to.
enum PaywallLoad {
  /// Asking the store.
  loading,

  /// The plans are in [PaywallState.products].
  loaded,

  /// The store returned no plans.
  empty,

  /// The store failed.
  failed,
}

/// Something the paywall tells the user once, as an alert.
enum PaywallNotice {
  /// Buying failed (`Unable to Complete Purchase`).
  purchaseFailed,

  /// A restore found nothing active (`Nothing to Restore`).
  nothingToRestore,

  /// Restoring failed (`Unable to Restore Purchases`).
  restoreFailed,

  /// Signing out failed (`Unable to Sign Out`).
  signOutFailed,
}

/// The paywall (Swift `PaywallPresenter`'s state).
final class const PaywallState({
  /// The paywall test's arm shown (Swift `paywallTest`), logged as
  /// `paywallVariant`.
  final PaywallTestOption variant = PaywallTestOption.custom,
  final PaywallLoad load = PaywallLoad.loading,
  final List<SubscriptionProduct> products = const [],

  /// The plan Subscribe buys: the first one once they load.
  final SubscriptionProduct? selected,

  /// Ask to Buy, or a pending Play payment: waiting for approval, said
  /// inline rather than as an error.
  final bool isPending = false,

  /// The last [PaywallNotice], and a count so the same one shows again.
  final PaywallNotice? notice,
  final int noticeId = 0,

  /// A purchase or restore granted an active entitlement.
  final bool isComplete = false,
}) extends Equatable {
  PaywallState copyWith({
    PaywallLoad? load,
    List<SubscriptionProduct>? products,
    SubscriptionProduct? Function()? selected,
    bool? isPending,
    PaywallNotice? notice,
    bool? isComplete,
  }) => PaywallState(
    variant: variant,
    load: load ?? this.load,
    products: products ?? this.products,
    selected: selected == null ? this.selected : selected(),
    isPending: isPending ?? this.isPending,
    notice: notice ?? this.notice,
    noticeId: notice == null ? noticeId : noticeId + 1,
    isComplete: isComplete ?? this.isComplete,
  );

  @override
  List<Object?> get props => [
    variant,
    load,
    products,
    selected,
    isPending,
    notice,
    noticeId,
    isComplete,
  ];
}
