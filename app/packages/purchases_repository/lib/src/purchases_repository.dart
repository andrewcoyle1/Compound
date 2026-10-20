import 'package:purchases_repository/purchases_repository.dart';

/// {@template purchases_failure}
/// A store call failed. [error] is the underlying SDK error. The subclasses
/// are the outcomes a paywall treats differently from a plain failure.
/// {@endtemplate}
class const PurchasesFailure([final Object? error]) implements Exception {
  /// {@macro purchases_failure}
  this;
}

/// {@template purchases_not_configured}
/// The build has no store API key, so nothing can be bought or restored.
/// {@endtemplate}
class const PurchasesNotConfigured() extends PurchasesFailure {
  /// {@macro purchases_not_configured}
  this;
}

/// {@template purchase_cancelled}
/// The user closed the store's purchase sheet: a choice, not an error.
/// {@endtemplate}
class const PurchaseCancelled([super.error]) extends PurchasesFailure {
  /// {@macro purchase_cancelled}
  this;
}

/// {@template purchase_pending}
/// The purchase is waiting for approval (Ask to Buy, or a pending payment on
/// Google Play). Show it inline; the entitlement arrives later through
/// `states`.
/// {@endtemplate}
class const PurchasePending([super.error]) extends PurchasesFailure {
  /// {@macro purchase_pending}
  this;
}

/// {@template product_already_owned}
/// The store account already has this subscription. Restoring is what the
/// user wants (the Swift paywall restores in this case).
/// {@endtemplate}
class const ProductAlreadyOwned([super.error]) extends PurchasesFailure {
  /// {@macro product_already_owned}
  this;
}

/// {@template product_not_found}
/// The store doesn't sell a product with this id.
/// {@endtemplate}
class const ProductNotFound([super.error]) extends PurchasesFailure {
  /// {@macro product_not_found}
  this;
}

/// Subscriptions: products, purchases, restores and the signed-in user's
/// entitlements. Mirrors SwiftfulPurchasing's `PurchaseManager`; the store
/// account is keyed on the Firebase uid, as in the Swift app and the coach's
/// premium check.
///
/// Methods throw a [PurchasesFailure] (or one of its subclasses) on failure.
abstract interface class PurchasesRepository {
  /// What the store has said so far.
  PurchasesState get state;

  /// [state] on listen, then every change.
  Stream<PurchasesState> get states;

  /// Identifies the store account as [userId] (the Firebase uid) and returns
  /// its entitlements; [state] is resolved from then on. The optional
  /// attributes go to the customer profile, as Swift's `logIn` sends them.
  Future<List<PurchasedEntitlement>> logIn(
    String userId, {
    String? email,
    String? mixpanelDistinctId,
    String? firebaseAppInstanceId,
  });

  /// Forgets the signed-in user. [state] goes back to unresolved at once, so
  /// the next user never inherits this one's entitlements.
  Future<void> logOut();

  /// The products the store sells with these ids. Ids it doesn't know are
  /// left out.
  Future<List<SubscriptionProduct>> getProducts(List<String> productIds);

  /// Buys [product] and returns the entitlements afterwards.
  ///
  /// Throws [PurchaseCancelled], [PurchasePending], [ProductAlreadyOwned] or
  /// [ProductNotFound] for those outcomes.
  Future<List<PurchasedEntitlement>> purchase(SubscriptionProduct product);

  /// Restores the store account's purchases and returns the entitlements. An
  /// empty or inactive list (nothing to restore) is not an error.
  Future<List<PurchasedEntitlement>> restore();

  /// Asks the store for the latest entitlements (for example when the app
  /// returns to the foreground).
  Future<List<PurchasedEntitlement>> refresh();

  /// Stops listening to the store.
  Future<void> close();
}
