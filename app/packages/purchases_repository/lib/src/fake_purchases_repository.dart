import 'dart:async';

import 'package:purchases_repository/purchases_repository.dart';

/// {@template fake_purchases_repository}
/// A [PurchasesRepository] with no store, for the staging (mock) flavor and
/// tests.
///
/// The store account owns an active Pro Annual entitlement when `premium` is
/// `true` (the default, as the Swift Mock build starts with "Simulate
/// Premium" on). Buying adds an entitlement for that product; restoring
/// returns what the account owns. Set [failure] to make the next purchase or
/// restore throw it, to show the cancelled, pending or failed paywall states.
/// {@endtemplate}
class FakePurchasesRepository implements PurchasesRepository {
  /// {@macro fake_purchases_repository}
  new({bool premium = true, this.products = sampleProducts, this.failure}) {
    if (premium) _buy(sampleProducts.first.id);
    _state = PurchasesState(entitlements: List.unmodifiable(_owned));
  }

  /// The development products from the Swift app's StoreKit configuration
  /// (`CompoundStorekitConfiguration-Dev.storekit`), yearly first.
  static const sampleProducts = [
    SubscriptionProduct(
      id: 'com.andrewcoyle.compound.dev.yearly',
      title: 'Pro Annual',
      subtitle: 'Unlock workout, AI nutrition, and weight tracking.',
      priceString: '£29.99',
      duration: ProductDuration.year,
    ),
    SubscriptionProduct(
      id: 'com.andrewcoyle.compound.dev.monthly',
      title: 'Pro Monthly',
      subtitle: 'Unlock workout, AI nutrition, and weight tracking.',
      priceString: '£4.99',
      duration: ProductDuration.month,
    ),
  ];

  /// What the store sells.
  final List<SubscriptionProduct> products;

  /// Thrown by the next [purchase] or [restore], then cleared.
  PurchasesFailure? failure;

  final _owned = <PurchasedEntitlement>[];
  final _controller = StreamController<PurchasesState>.broadcast();
  late PurchasesState _state;
  String? _userId;

  @override
  PurchasesState get state => _state;

  @override
  Stream<PurchasesState> get states => Stream.multi((listener) {
    listener.add(_state);
    final subscription = _controller.stream.listen(listener.add);
    listener.onCancel = subscription.cancel;
  });

  List<PurchasedEntitlement> _emit() {
    final entitlements = List<PurchasedEntitlement>.unmodifiable(_owned);
    _controller.add(
      _state = PurchasesState(
        entitlements: entitlements,
        isResolved: _userId != null,
      ),
    );
    return entitlements;
  }

  void _buy(String productId) {
    final now = DateTime.now();
    final yearly = productId.endsWith('yearly');
    _owned
      ..removeWhere((e) => e.productId == productId)
      ..insert(
        0,
        PurchasedEntitlement(
          id: 'pro',
          productId: productId,
          isActive: true,
          expirationDate: now.add(Duration(days: yearly ? 365 : 30)),
          originalPurchaseDate: now,
          latestPurchaseDate: now,
          isSandbox: true,
        ),
      );
  }

  void _throwFailure() {
    final failure = this.failure;
    this.failure = null;
    if (failure != null) throw failure;
  }

  @override
  Future<List<PurchasedEntitlement>> logIn(
    String userId, {
    String? email,
    String? mixpanelDistinctId,
    String? firebaseAppInstanceId,
  }) async {
    _userId = userId;
    return _emit();
  }

  @override
  Future<void> logOut() async {
    _userId = null;
    _emit();
  }

  @override
  Future<List<SubscriptionProduct>> getProducts(
    List<String> productIds,
  ) async => [
    for (final product in products)
      if (productIds.contains(product.id)) product,
  ];

  @override
  Future<List<PurchasedEntitlement>> purchase(
    SubscriptionProduct product,
  ) async {
    _throwFailure();
    if (!products.contains(product)) throw ProductNotFound(product.id);
    _buy(product.id);
    return _emit();
  }

  @override
  Future<List<PurchasedEntitlement>> restore() async {
    _throwFailure();
    return _emit();
  }

  @override
  Future<List<PurchasedEntitlement>> refresh() async => _emit();

  @override
  Future<void> close() => _controller.close();
}
