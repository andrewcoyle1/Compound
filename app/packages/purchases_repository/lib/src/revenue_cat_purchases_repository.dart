import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_repository/purchases_repository.dart';

/// {@template revenue_cat_purchases_repository}
/// A [PurchasesRepository] on RevenueCat (`purchases_flutter`): Google Play on
/// Android, the App Store on iOS. Create it with [init].
///
/// Entitlements are read as Swift reads them: any active entitlement, under
/// any identifier, counts.
/// {@endtemplate}
class RevenueCatPurchasesRepository implements PurchasesRepository {
  new _({required this._configured, required this._state, this._userId});

  /// Starts RevenueCat with the platform's public SDK [apiKey] (`appl_…` on
  /// iOS, `goog_…` on Android), as [appUserId] (the Firebase uid) when one is
  /// already signed in, otherwise anonymously until [logIn].
  ///
  /// An empty [apiKey] means the build has none: nothing is configured,
  /// [state] is resolved with no entitlements (so not premium), and buying,
  /// restoring or loading products throws [PurchasesNotConfigured].
  static Future<RevenueCatPurchasesRepository> init({
    required String apiKey,
    String? appUserId,
  }) async {
    if (apiKey.isEmpty) {
      return RevenueCatPurchasesRepository._(
        configured: false,
        state: const PurchasesState(isResolved: true),
      );
    }
    await Purchases.configure(
      PurchasesConfiguration(apiKey)..appUserID = appUserId,
    );
    final repository = RevenueCatPurchasesRepository._(
      configured: true,
      state: const PurchasesState(),
      userId: appUserId,
    );
    Purchases.addCustomerInfoUpdateListener(repository._apply);
    return repository;
  }

  final bool _configured;

  /// Whether RevenueCat was started, so its own paywall can show.
  bool get isConfigured => _configured;

  /// The app user RevenueCat is identified as; `null` while anonymous. An
  /// answer counts as resolved only while it is set.
  String? _userId;

  /// The store products from the last [getProducts], by id, to buy from.
  final _products = <String, StoreProduct>{};

  final _controller = StreamController<PurchasesState>.broadcast();
  PurchasesState _state;

  @override
  PurchasesState get state => _state;

  @override
  Stream<PurchasesState> get states => Stream.multi((listener) {
    listener.add(_state);
    final subscription = _controller.stream.listen(listener.add);
    listener.onCancel = subscription.cancel;
  });

  void _emit(PurchasesState state) {
    if (state == _state) return;
    _controller.add(_state = state);
  }

  List<PurchasedEntitlement> _apply(CustomerInfo info) {
    final entitlements = info.entitlements.all.values.map(_entitlement).toList()
      ..sort(
        (a, b) => (b.expirationDate ?? _distantPast).compareTo(
          a.expirationDate ?? _distantPast,
        ),
      );
    _emit(
      PurchasesState(entitlements: entitlements, isResolved: _userId != null),
    );
    return entitlements;
  }

  void _requireConfigured() {
    if (!_configured) throw const PurchasesNotConfigured();
  }

  @override
  Future<List<PurchasedEntitlement>> logIn(
    String userId, {
    String? email,
    String? mixpanelDistinctId,
    String? firebaseAppInstanceId,
  }) => _guard(() async {
    if (!_configured) return const [];
    final result = await Purchases.logIn(userId);
    _userId = userId;
    final entitlements = _apply(result.customerInfo);
    if (email != null) await Purchases.setEmail(email);
    if (mixpanelDistinctId != null) {
      await Purchases.setMixpanelDistinctID(mixpanelDistinctId);
    }
    if (firebaseAppInstanceId != null) {
      await Purchases.setFirebaseAppInstanceId(firebaseAppInstanceId);
    }
    return entitlements;
  });

  @override
  Future<void> logOut() async {
    if (!_configured) return;
    // Cleared before asking RevenueCat, so a failure can't leave this user's
    // entitlements in place for the next one.
    _userId = null;
    _products.clear();
    _emit(const PurchasesState());
    try {
      await Purchases.logOut();
    } on PlatformException catch (error) {
      // Already anonymous: there is nobody to log out.
      if (_code(error) == PurchasesErrorCode.logOutWithAnonymousUserError) {
        return;
      }
      throw PurchasesFailure(error);
    }
  }

  @override
  Future<List<SubscriptionProduct>> getProducts(List<String> productIds) =>
      _guard(() async {
        _requireConfigured();
        final products = await Purchases.getProducts(productIds);
        for (final product in products) {
          _products[product.identifier] = product;
        }
        return products.map(_product).toList();
      });

  @override
  Future<List<PurchasedEntitlement>> purchase(SubscriptionProduct product) =>
      _guard(() async {
        _requireConfigured();
        final storeProduct =
            _products[product.id] ??
            (await Purchases.getProducts([product.id]))
                .where((p) => p.identifier == product.id)
                .firstOrNull;
        if (storeProduct == null) throw ProductNotFound(product.id);
        final result = await Purchases.purchase(
          PurchaseParams.storeProduct(storeProduct),
        );
        return _apply(result.customerInfo);
      });

  @override
  Future<List<PurchasedEntitlement>> restore() => _guard(() async {
    _requireConfigured();
    return _apply(await Purchases.restorePurchases());
  });

  @override
  Future<List<PurchasedEntitlement>> refresh() => _guard(() async {
    if (!_configured) return const [];
    return _apply(await Purchases.getCustomerInfo());
  });

  @override
  Future<void> close() async {
    if (_configured) Purchases.removeCustomerInfoUpdateListener(_apply);
    await _controller.close();
  }

  /// Runs [body], turning RevenueCat's errors into [PurchasesFailure]s.
  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (error) {
      throw switch (_code(error)) {
        PurchasesErrorCode.purchaseCancelledError => PurchaseCancelled(error),
        PurchasesErrorCode.paymentPendingError => PurchasePending(error),
        PurchasesErrorCode.productAlreadyPurchasedError => ProductAlreadyOwned(
          error,
        ),
        _ => PurchasesFailure(error),
      };
    }
  }

  /// RevenueCat's error code, which arrives as the enum's index in
  /// [PlatformException.code]. Unlike `PurchasesErrorHelper.getErrorCode`,
  /// a code that isn't a number is [PurchasesErrorCode.unknownError] rather
  /// than a `FormatException`.
  static PurchasesErrorCode _code(PlatformException error) {
    final index = int.tryParse(error.code);
    if (index == null || index < 0) return PurchasesErrorCode.unknownError;
    return PurchasesErrorCode.values.elementAtOrNull(index) ??
        PurchasesErrorCode.unknownError;
  }
}

final _distantPast = DateTime.utc(1);

PurchasedEntitlement _entitlement(EntitlementInfo info) => PurchasedEntitlement(
  id: info.identifier,
  productId: info.productIdentifier,
  isActive: info.isActive,
  expirationDate: _date(info.expirationDate),
  originalPurchaseDate: _date(info.originalPurchaseDate),
  latestPurchaseDate: _date(info.latestPurchaseDate),
  isSandbox: info.isSandbox,
);

SubscriptionProduct _product(StoreProduct product) => SubscriptionProduct(
  id: product.identifier,
  title: product.title,
  subtitle: product.description,
  priceString: product.priceString,
  duration: ProductDuration.fromIsoPeriod(product.subscriptionPeriod),
);

DateTime? _date(String? value) =>
    value == null ? null : DateTime.tryParse(value);
