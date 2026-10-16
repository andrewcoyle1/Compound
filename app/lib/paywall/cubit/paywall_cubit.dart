import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/paywall/paywall_exits.dart';
import 'package:equatable/equatable.dart';
import 'package:purchases_repository/purchases_repository.dart';

part 'paywall_state.dart';

/// The paywall (Swift `PaywallPresenter`): the plans, buying one,
/// restoring, and, during onboarding, the way out for someone who will not
/// subscribe. Swift's event names throughout.
///
/// Only Swift's default A/B variant, its own (`custom`) paywall, is built;
/// `paywallVariant` is always `custom`.
///
/// It never navigates. A purchase or restore that grants an entitlement sets
/// [PaywallState.isComplete]: outside onboarding the page then closes, and
/// during onboarding the router moves on once the store says the user is
/// premium (Swift's `handleNavigation`).
class PaywallCubit extends Cubit<PaywallState> {
  new({
    required this._purchases,
    required this._auth,
    required this._analytics,
    required this._productIds,
  }) : super(const PaywallState());

  final PurchasesRepository _purchases;
  final AuthRepository _auth;
  final AnalyticsRepository _analytics;

  /// The plans to ask the store for (`EntitlementOption.allProductIds`).
  final List<String> _productIds;

  static const _screen = 'PaywallView';
  static const _variant = {'paywallVariant': 'custom'};

  /// `PaywallView_Appear`.
  void appeared() => _analytics.appear(_screen);

  /// `PaywallView_Disappear`.
  void disappeared() => _analytics.disappear(_screen);

  /// `PaywallView_BackButton_Pressed`, before the page closes.
  void closePressed() => _analytics.analytic('${_screen}_BackButton_Pressed');

  /// Asks the store for the plans; a failure, or no plans, is said on the
  /// screen rather than as an alert. The first plan starts chosen, unless
  /// the chosen one is still offered.
  Future<void> loadProducts() async {
    emit(state.copyWith(load: PaywallLoad.loading));
    _analytics.analytic('${_screen}_Load_Start', _variant);
    try {
      final products = await _purchases.getProducts(_productIds);
      if (isClosed) return;
      final selected = products.contains(state.selected)
          ? state.selected
          : products.firstOrNull;
      emit(
        state.copyWith(
          load: products.isEmpty ? PaywallLoad.empty : PaywallLoad.loaded,
          products: products,
          selected: () => selected,
        ),
      );
      if (products.isEmpty) {
        _analytics.severe(
          '${_screen}_Load_Fail',
          'No products returned from the store.',
          _variant,
        );
      } else {
        _analytics.analytic('${_screen}_Load_Success', {
          'productCount': products.length,
          ..._variant,
        });
      }
    } on Object catch (error) {
      if (isClosed) return;
      emit(state.copyWith(load: PaywallLoad.failed));
      _analytics.severe('${_screen}_Load_Fail', error, _variant);
    }
  }

  /// Chooses the plan Subscribe buys.
  void productSelected(SubscriptionProduct product) =>
      emit(state.copyWith(selected: () => product));

  /// Buys the chosen plan; nothing without one.
  Future<void> subscribePressed() async {
    final selected = state.selected;
    if (selected == null) return;
    await purchase(selected);
  }

  /// Buys [product]. A cancel says nothing, a pending purchase says so
  /// inline, a plan the store account already has is restored, and any
  /// other failure is an alert. A purchase that grants nothing active
  /// leaves the paywall up.
  Future<void> purchase(SubscriptionProduct product) async {
    final parameters = productParameters(product);
    _analytics.analytic('${_screen}_Purchase_Start', parameters);
    try {
      final entitlements = await _purchases.purchase(product);
      _analytics.analytic('${_screen}_Purchase_Success', parameters);
      _complete(entitlements);
    } on PurchaseCancelled {
      _analytics.analytic('${_screen}_Purchase_Cancelled', parameters);
    } on PurchasePending {
      _analytics.analytic('${_screen}_Purchase_Pending', parameters);
      if (!isClosed) emit(state.copyWith(isPending: true));
    } on ProductAlreadyOwned {
      _analytics.analytic('${_screen}_Purchase_AlreadyOwned', parameters);
      await _restore();
    } on Object catch (error) {
      _analytics.severe('${_screen}_Purchase_Fail', error);
      _notify(PaywallNotice.purchaseFailed);
    }
  }

  /// Restore Subscription.
  Future<void> restorePressed() {
    _analytics.analytic('${_screen}_Restore_Start');
    return _restore();
  }

  Future<void> _restore() async {
    try {
      final entitlements = await _purchases.restore();
      if (entitlements.any((e) => e.isActive)) {
        _analytics.analytic('${_screen}_Restore_Success');
        _complete(entitlements);
      } else {
        // Not an error: the commonest restore outcome (another store
        // account, or a lapsed subscription), and it must still say so.
        _analytics.info('${_screen}_Restore_Empty');
        _notify(PaywallNotice.nothingToRestore);
      }
    } on Object catch (error) {
      _analytics.severe('${_screen}_Restore_Fail', error);
      _notify(PaywallNotice.restoreFailed);
    }
  }

  void _complete(List<PurchasedEntitlement> entitlements) {
    if (isClosed || !entitlements.any((e) => e.isActive)) return;
    emit(state.copyWith(isComplete: true));
  }

  void _notify(PaywallNotice notice) {
    if (!isClosed) emit(state.copyWith(notice: notice));
  }

  /// Onboarding only: `PaywallView_Account_Press`, before Edit Profile
  /// opens.
  void accountPressed() => accountPressedFrom(_analytics, _screen);

  /// Onboarding only: signs out, and the router returns to sign-in.
  Future<void> signOutPressed() async {
    if (!await signOutFrom(_screen, auth: _auth, analytics: _analytics)) {
      _notify(PaywallNotice.signOutFailed);
    }
  }
}

/// SwiftfulPurchasing's `AnyProduct.eventParameters`.
Map<String, Object?> productParameters(SubscriptionProduct product) => {
  'product_id': product.id,
  'product_title': product.title,
  'product_subtitle': product.subtitle,
  'product_price_string': product.priceString,
  if (product.duration case final duration?)
    'product_product_duration': duration.name,
};
