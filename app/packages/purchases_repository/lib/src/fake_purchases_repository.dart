import 'dart:async';

import 'package:purchases_repository/purchases_repository.dart';

/// {@template fake_purchases_repository}
/// A [PurchasesRepository] with no store, for the staging (mock) flavor and
/// tests.
///
/// The store account owns an active Pro Annual entitlement when `premium` is
/// `true` (the default, as the Swift Mock build starts with "Simulate
/// Premium" on). Buying adds an entitlement for that product; restoring
/// returns what the account owns. Queue [failures] to make the next
/// purchases or restores throw them in turn, and set [failedLoads] to make
/// the next product loads fail, so every paywall state can be shown.
/// {@endtemplate}
class FakePurchasesRepository implements PurchasesRepository {
  /// {@macro fake_purchases_repository}
  new({
    bool premium = true,
    this.products = sampleProducts,
    Iterable<PurchasesFailure> failures = const [],
    this.failedLoads = 0,
  }) : failures = [...failures] {
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

  /// Thrown in turn by the next [purchase]s and [restore]s, one each. A
  /// purchase failing with [ProductAlreadyOwned] leaves the account owning
  /// the product, as the store's would, so restoring then finds it.
  final List<PurchasesFailure> failures;

  /// How many of the next [getProducts] calls throw a [PurchasesFailure].
  int failedLoads;

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

  /// Whether the account owns anything. Setting it buys the yearly plan or
  /// forgets every purchase, for the development tools' "Simulate Premium"
  /// (Swift `PremiumOverride`).
  bool get premium => _owned.isNotEmpty;

  set premium(bool value) {
    if (value == premium) return;
    if (value) {
      _buy(sampleProducts.first.id);
    } else {
      _owned.clear();
    }
    _emit();
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
    if (failures.isNotEmpty) throw failures.removeAt(0);
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
  Future<List<SubscriptionProduct>> getProducts(List<String> productIds) async {
    if (failedLoads > 0) {
      failedLoads--;
      throw const PurchasesFailure('The store did not answer.');
    }
    return [
      for (final product in products)
        if (productIds.contains(product.id)) product,
    ];
  }

  @override
  Future<List<PurchasedEntitlement>> purchase(
    SubscriptionProduct product,
  ) async {
    if (failures.firstOrNull is ProductAlreadyOwned) _buy(product.id);
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
