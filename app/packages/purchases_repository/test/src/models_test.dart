import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_repository/purchases_repository.dart';

PurchasedEntitlement _entitlement({required bool isActive}) =>
    PurchasedEntitlement(
      id: 'pro',
      productId: 'com.andrewcoyle.compound.monthly',
      isActive: isActive,
    );

void main() {
  group(SubscriptionPlan, () {
    test("uses the Swift app's product ids", () {
      expect(SubscriptionPlan.productIds(development: false), [
        'com.andrewcoyle.compound.yearly',
        'com.andrewcoyle.compound.monthly',
      ]);
      expect(SubscriptionPlan.productIds(development: true), [
        'com.andrewcoyle.compound.dev.yearly',
        'com.andrewcoyle.compound.dev.monthly',
      ]);
    });
  });

  group(ProductDuration, () {
    test('reads the unit of an ISO 8601 period', () {
      expect(ProductDuration.fromIsoPeriod('P1Y'), ProductDuration.year);
      expect(ProductDuration.fromIsoPeriod('P1M'), ProductDuration.month);
      expect(ProductDuration.fromIsoPeriod('P3M'), ProductDuration.month);
      expect(ProductDuration.fromIsoPeriod('P1W'), ProductDuration.week);
      expect(ProductDuration.fromIsoPeriod('P3D'), ProductDuration.day);
    });

    test('is null for a one-off purchase or an unknown unit', () {
      expect(ProductDuration.fromIsoPeriod(null), isNull);
      expect(ProductDuration.fromIsoPeriod(''), isNull);
      expect(ProductDuration.fromIsoPeriod('PT1H'), isNull);
    });
  });

  group('value types', () {
    test('compare by value', () {
      expect(
        const SubscriptionProduct(
          id: 'a',
          title: 't',
          subtitle: 's',
          priceString: '£1',
        ),
        const SubscriptionProduct(
          id: 'a',
          title: 't',
          subtitle: 's',
          priceString: '£1',
        ),
      );
      expect(
        _entitlement(isActive: true),
        isNot(_entitlement(isActive: false)),
      );
      expect(
        PurchasesState(entitlements: [_entitlement(isActive: true)]),
        PurchasesState(entitlements: [_entitlement(isActive: true)]),
      );
    });
  });

  // A port of the Swift app's PremiumAccessTests.
  group('isPremium', () {
    test('an entitled user is premium', () {
      expect(
        isPremium(
          entitlements: [_entitlement(isActive: true)],
          developmentOverride: false,
        ),
        isTrue,
      );
    });

    test('a user with no entitlements is not premium', () {
      expect(isPremium(entitlements: [], developmentOverride: false), isFalse);
    });

    test('a lapsed subscriber is not premium', () {
      expect(
        isPremium(
          entitlements: [_entitlement(isActive: false)],
          developmentOverride: false,
        ),
        isFalse,
      );
    });

    test('one active entitlement among expired ones is enough', () {
      expect(
        isPremium(
          entitlements: [
            _entitlement(isActive: false),
            _entitlement(isActive: true),
          ],
          developmentOverride: false,
        ),
        isTrue,
      );
    });

    test('the development override grants premium and never removes it', () {
      expect(isPremium(entitlements: [], developmentOverride: true), isTrue);
      expect(
        isPremium(
          entitlements: [_entitlement(isActive: true)],
          developmentOverride: true,
        ),
        isTrue,
      );
    });

    test('an unresolved answer grants access even with no entitlements', () {
      expect(
        isPremium(
          entitlements: [],
          entitlementsAreResolved: false,
          developmentOverride: false,
        ),
        isTrue,
      );
    });

    test('a resolved non-entitled or lapsed user is sent to the paywall', () {
      expect(isPremium(entitlements: [], developmentOverride: false), isFalse);
      expect(
        isPremium(
          entitlements: [_entitlement(isActive: false)],
          developmentOverride: false,
        ),
        isFalse,
      );
    });

    test('the override wins whether or not entitlements are resolved', () {
      for (final resolved in [true, false]) {
        expect(
          isPremium(
            entitlements: [],
            entitlementsAreResolved: resolved,
            developmentOverride: true,
          ),
          isTrue,
        );
      }
    });
  });

  group(PurchasesState, () {
    test('starts unresolved with no entitlements, so optimistic', () {
      const state = PurchasesState();
      expect(state.isResolved, isFalse);
      expect(state.hasActiveEntitlement, isFalse);
      expect(state.isPremiumWith(), isTrue);
    });

    test('gates on active entitlements once resolved', () {
      final lapsed = PurchasesState(
        entitlements: [_entitlement(isActive: false)],
        isResolved: true,
      );
      final active = PurchasesState(
        entitlements: [_entitlement(isActive: true)],
        isResolved: true,
      );
      expect(lapsed.hasActiveEntitlement, isFalse);
      expect(lapsed.isPremiumWith(), isFalse);
      expect(lapsed.isPremiumWith(developmentOverride: true), isTrue);
      expect(active.hasActiveEntitlement, isTrue);
      expect(active.isPremiumWith(), isTrue);
    });
  });
}
