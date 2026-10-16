import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/paywall/paywall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_repository/purchases_repository.dart';

import '../../helpers/helpers.dart';

class _MockPurchasesRepository extends Mock implements PurchasesRepository;

/// Swift `PaywallPresenterTests`, case for case. Not ported: the RevenueCat
/// and StoreKit variants' cases (only the default, custom paywall is
/// built), the variant read from the A/B test (no A/B tests yet), and the
/// error sorting (`RevenueCatPurchasesRepository`'s own tests sort
/// RevenueCat's codes). Where a purchase lands (back where the user was, or
/// the onboarding step the profile implies) is the router's, in
/// `app_redirect_test.dart` and `paywall_flow_test.dart`.
void main() {
  const monthly = SubscriptionProduct(
    id: 'monthly',
    title: 'Pro Monthly',
    subtitle: 'Unlock everything.',
    priceString: '£4.99',
    duration: ProductDuration.month,
  );
  const yearly = SubscriptionProduct(
    id: 'yearly',
    title: 'Pro Annual',
    subtitle: 'Unlock everything.',
    priceString: '£29.99',
    duration: ProductDuration.year,
  );
  const active = PurchasedEntitlement(
    id: 'pro',
    productId: 'monthly',
    isActive: true,
  );
  const lapsed = PurchasedEntitlement(
    id: 'pro',
    productId: 'monthly',
    isActive: false,
  );
  const productIds = ['yearly', 'monthly'];

  late _MockPurchasesRepository purchases;
  late MockAuthRepository auth;
  late AnalyticsRecorder analytics;

  setUpAll(() => registerFallbackValue(monthly));

  setUp(() {
    purchases = _MockPurchasesRepository();
    auth = MockAuthRepository();
    analytics = AnalyticsRecorder();
    when(() => purchases.getProducts(any()))
        .thenAnswer((_) async => const [monthly, yearly]);
  });

  PaywallCubit build() => PaywallCubit(
    purchases: purchases,
    auth: auth,
    analytics: analytics,
    productIds: productIds,
  );

  group('what the paywall offers', () {
    blocTest<PaywallCubit, PaywallState>(
      'shows the products the store returns, the first one chosen',
      build: build,
      act: (cubit) => cubit.loadProducts(),
      expect: () => const [
        PaywallState(),
        PaywallState(
          load: PaywallLoad.loaded,
          products: [monthly, yearly],
          selected: monthly,
        ),
      ],
      verify: (_) {
        verify(() => purchases.getProducts(productIds)).called(1);
        expect(analytics.names, [
          'PaywallView_Load_Start',
          'PaywallView_Load_Success',
        ]);
        expect(analytics.parameters('PaywallView_Load_Success'), {
          'productCount': 2,
          'paywallVariant': 'custom',
        });
      },
    );

    blocTest<PaywallCubit, PaywallState>(
      'an empty store response explains itself, with no alert',
      setUp: () =>
          when(() => purchases.getProducts(any()))
              .thenAnswer((_) async => const []),
      build: build,
      act: (cubit) => cubit.loadProducts(),
      expect: () => const [
        PaywallState(),
        PaywallState(load: PaywallLoad.empty),
      ],
      verify: (_) => expect(analytics.names.last, 'PaywallView_Load_Fail'),
    );

    blocTest<PaywallCubit, PaywallState>(
      'a failed load stops spinning and says why, with no alert',
      setUp: () =>
          when(() => purchases.getProducts(any()))
              .thenThrow(const PurchasesFailure()),
      build: build,
      act: (cubit) => cubit.loadProducts(),
      expect: () => const [
        PaywallState(),
        PaywallState(load: PaywallLoad.failed),
      ],
      verify: (_) => expect(analytics.names.last, 'PaywallView_Load_Fail'),
    );

    test('a successful retry clears the earlier error', () async {
      when(() => purchases.getProducts(any()))
          .thenThrow(const PurchasesFailure());
      final cubit = build();
      await cubit.loadProducts();
      expect(cubit.state.load, PaywallLoad.failed);
      when(() => purchases.getProducts(any()))
          .thenAnswer((_) async => const [yearly]);
      await cubit.loadProducts();
      expect(cubit.state.load, PaywallLoad.loaded);
      expect(cubit.state.products, [yearly]);
      await cubit.close();
    });

    test('a reload keeps the plan chosen while it is still offered', () async {
      final cubit = build();
      await cubit.loadProducts();
      cubit.productSelected(yearly);
      await cubit.loadProducts();
      expect(cubit.state.selected, yearly);
      await cubit.close();
    });
  });

  group('buying', () {
    blocTest<PaywallCubit, PaywallState>(
      'Subscribe without a chosen plan buys nothing',
      build: build,
      act: (cubit) => cubit.subscribePressed(),
      expect: () => const <PaywallState>[],
      verify: (_) {
        verifyNever(() => purchases.purchase(any()));
        expect(analytics.names, isEmpty);
      },
    );

    blocTest<PaywallCubit, PaywallState>(
      'Subscribe buys the chosen plan',
      setUp: () =>
          when(() => purchases.purchase(any()))
              .thenAnswer((_) async => const [active]),
      build: build,
      act: (cubit) async {
        cubit.productSelected(yearly);
        await cubit.subscribePressed();
      },
      expect: () => const [
        PaywallState(selected: yearly),
        PaywallState(selected: yearly, isComplete: true),
      ],
      verify: (_) {
        verify(() => purchases.purchase(yearly)).called(1);
        expect(analytics.parameters('PaywallView_Purchase_Start'), {
          'product_id': 'yearly',
          'product_title': 'Pro Annual',
          'product_subtitle': 'Unlock everything.',
          'product_price_string': '£29.99',
          'product_product_duration': 'year',
        });
      },
    );

    blocTest<PaywallCubit, PaywallState>(
      'a purchase with an entitlement moves the user on',
      setUp: () =>
          when(() => purchases.purchase(any()))
              .thenAnswer((_) async => const [active]),
      build: build,
      act: (cubit) => cubit.purchase(monthly),
      expect: () => const [PaywallState(isComplete: true)],
      verify: (_) => expect(analytics.names, [
        'PaywallView_Purchase_Start',
        'PaywallView_Purchase_Success',
      ]),
    );

    blocTest<PaywallCubit, PaywallState>(
      'a purchase granting nothing does not let the user through',
      setUp: () =>
          when(() => purchases.purchase(any()))
              .thenAnswer((_) async => const [lapsed]),
      build: build,
      act: (cubit) => cubit.purchase(monthly),
      expect: () => const <PaywallState>[],
      verify: (_) =>
          expect(analytics.names.last, 'PaywallView_Purchase_Success'),
    );

    blocTest<PaywallCubit, PaywallState>(
      'a purchase returning no entitlements keeps the paywall up',
      setUp: () =>
          when(() => purchases.purchase(any()))
              .thenAnswer((_) async => const []),
      build: build,
      act: (cubit) => cubit.purchase(monthly),
      expect: () => const <PaywallState>[],
    );

    blocTest<PaywallCubit, PaywallState>(
      'a failed purchase is reported to the user',
      setUp: () =>
          when(() => purchases.purchase(any()))
              .thenThrow(const PurchasesFailure('declined')),
      build: build,
      act: (cubit) => cubit.purchase(monthly),
      expect: () => const [
        PaywallState(notice: PaywallNotice.purchaseFailed, noticeId: 1),
      ],
      verify: (_) {
        expect(analytics.names.last, 'PaywallView_Purchase_Fail');
        expect(
          analytics.parameters('PaywallView_Purchase_Fail'),
          containsPair('error_description', contains('PurchasesFailure')),
        );
      },
    );

    blocTest<PaywallCubit, PaywallState>(
      'buying a plan already owned restores it instead of failing',
      setUp: () {
        when(() => purchases.purchase(any()))
            .thenThrow(const ProductAlreadyOwned());
        when(purchases.restore).thenAnswer((_) async => const [active]);
      },
      build: build,
      act: (cubit) => cubit.purchase(monthly),
      expect: () => const [PaywallState(isComplete: true)],
      verify: (_) {
        verify(purchases.restore).called(1);
        expect(analytics.names, [
          'PaywallView_Purchase_Start',
          'PaywallView_Purchase_AlreadyOwned',
          'PaywallView_Restore_Success',
        ]);
      },
    );

    blocTest<PaywallCubit, PaywallState>(
      'cancelling a purchase says nothing',
      setUp: () =>
          when(() => purchases.purchase(any()))
              .thenThrow(const PurchaseCancelled()),
      build: build,
      act: (cubit) => cubit.purchase(monthly),
      expect: () => const <PaywallState>[],
      verify: (_) =>
          expect(analytics.names.last, 'PaywallView_Purchase_Cancelled'),
    );

    blocTest<PaywallCubit, PaywallState>(
      'a purchase waiting for approval says so inline',
      setUp: () =>
          when(() => purchases.purchase(any()))
              .thenThrow(const PurchasePending()),
      build: build,
      act: (cubit) => cubit.purchase(monthly),
      expect: () => const [PaywallState(isPending: true)],
      verify: (_) =>
          expect(analytics.names.last, 'PaywallView_Purchase_Pending'),
    );
  });

  group('restoring', () {
    blocTest<PaywallCubit, PaywallState>(
      'an active subscription lets the user back in',
      setUp: () =>
          when(purchases.restore).thenAnswer((_) async => const [active]),
      build: build,
      act: (cubit) => cubit.restorePressed(),
      expect: () => const [PaywallState(isComplete: true)],
      verify: (_) => expect(analytics.names, [
        'PaywallView_Restore_Start',
        'PaywallView_Restore_Success',
      ]),
    );

    blocTest<PaywallCubit, PaywallState>(
      'nothing active does not let the user through, and says why',
      setUp: () =>
          when(purchases.restore).thenAnswer((_) async => const [lapsed]),
      build: build,
      act: (cubit) => cubit.restorePressed(),
      expect: () => const [
        PaywallState(notice: PaywallNotice.nothingToRestore, noticeId: 1),
      ],
      verify: (_) => expect(analytics.names.last, 'PaywallView_Restore_Empty'),
    );

    blocTest<PaywallCubit, PaywallState>(
      'restoring nothing at all tells the user why, each time',
      setUp: () => when(purchases.restore).thenAnswer((_) async => const []),
      build: build,
      act: (cubit) async {
        await cubit.restorePressed();
        await cubit.restorePressed();
      },
      expect: () => const [
        PaywallState(notice: PaywallNotice.nothingToRestore, noticeId: 1),
        PaywallState(notice: PaywallNotice.nothingToRestore, noticeId: 2),
      ],
    );

    blocTest<PaywallCubit, PaywallState>(
      'a failed restore is reported to the user',
      setUp: () => when(purchases.restore).thenThrow(const PurchasesFailure()),
      build: build,
      act: (cubit) => cubit.restorePressed(),
      expect: () => const [
        PaywallState(notice: PaywallNotice.restoreFailed, noticeId: 1),
      ],
      verify: (_) => expect(analytics.names.last, 'PaywallView_Restore_Fail'),
    );
  });

  group('leaving without subscribing', () {
    blocTest<PaywallCubit, PaywallState>(
      'the paywall offers the account and signing out',
      setUp: () => when(auth.signOut).thenAnswer((_) async {}),
      build: build,
      act: (cubit) async {
        cubit.accountPressed();
        await cubit.signOutPressed();
      },
      expect: () => const <PaywallState>[],
      verify: (_) {
        verify(auth.signOut).called(1);
        expect(analytics.names, [
          'PaywallView_Account_Press',
          'PaywallView_SignOut_Start',
          'PaywallView_SignOut_Success',
        ]);
      },
    );

    blocTest<PaywallCubit, PaywallState>(
      'a failed sign-out says so',
      setUp: () => when(auth.signOut).thenThrow(const AuthFailure()),
      build: build,
      act: (cubit) => cubit.signOutPressed(),
      expect: () => const [
        PaywallState(notice: PaywallNotice.signOutFailed, noticeId: 1),
      ],
      verify: (_) => expect(analytics.names.last, 'PaywallView_SignOut_Fail'),
    );
  });

  test('tracks its own lifecycle and close button', () async {
    build()
      ..appeared()
      ..disappeared()
      ..closePressed();
    expect(analytics.names, [
      'PaywallView_Appear',
      'PaywallView_Disappear',
      'PaywallView_BackButton_Pressed',
    ]);
  });

  test('a product with no billing period logs none', () {
    expect(
      productParameters(
        const SubscriptionProduct(
          id: 'id',
          title: 't',
          subtitle: 's',
          priceString: '£1',
        ),
      ),
      isNot(contains('product_product_duration')),
    );
  });
}
