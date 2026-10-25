import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/paywall/paywall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_repository/purchases_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  /// Tall enough that each list builds every row.
  void tall(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(800, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('PaywallPage.paywallVariant', () {
    test('is the test arm, but custom for RevenueCat without RevenueCat', () {
      final fake = FakePurchasesRepository();
      expect(
        PaywallPage.paywallVariant(PaywallTestOption.storeKit, fake),
        PaywallTestOption.storeKit,
      );
      expect(
        PaywallPage.paywallVariant(PaywallTestOption.custom, fake),
        PaywallTestOption.custom,
      );
      expect(
        PaywallPage.paywallVariant(PaywallTestOption.revenueCat, fake),
        PaywallTestOption.custom,
      );
    });

    test('is custom when RevenueCat has no key', () async {
      final unconfigured = await RevenueCatPurchasesRepository.init(apiKey: '');
      expect(
        PaywallPage.paywallVariant(PaywallTestOption.revenueCat, unconfigured),
        PaywallTestOption.custom,
      );
    });
  });

  testWidgets('the storeKit arm shows the plans under the header', (
    tester,
  ) async {
    tall(tester);
    final analytics = AnalyticsRecorder();
    await tester.pumpApp(
      const PaywallPage(isOnboarding: false),
      authRepository: MockAuthRepository(),
      purchasesRepository: FakePurchasesRepository(),
      abTestRepository: InMemoryAbTestRepository(
        const ActiveAbTests(paywallTest: PaywallTestOption.storeKit),
      ),
      analyticsRepository: analytics,
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(PaywallView)).l10n;
    expect(find.text(l10n.paywallTitle), findsOneWidget);
    expect(find.text(l10n.paywallSubscribe), findsOneWidget);
    // Each plan's billed price, biggest, with its period beside it.
    expect(find.text('£29.99'), findsOneWidget);
    expect(find.text('/ 1 year'), findsOneWidget);
    expect(find.text('/ 1 month'), findsOneWidget);
    // The custom arm's feature list is not part of the store's screen.
    expect(find.text(l10n.paywallIncluded), findsNothing);
    expect(find.byType(AppFeatureRow), findsNothing);
    expect(
      analytics.parameters('PaywallView_Load_Success')?['paywallVariant'],
      'storeKit',
    );
  });

  testWidgets('the custom arm lists what is included', (tester) async {
    tall(tester);
    await tester.pumpApp(
      const PaywallPage(isOnboarding: false),
      authRepository: MockAuthRepository(),
      purchasesRepository: FakePurchasesRepository(),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(PaywallView)).l10n;
    expect(find.text(l10n.paywallIncluded), findsOneWidget);
    expect(find.byType(AppFeatureRow), findsNWidgets(5));
    expect(find.byType(AppPlanCard), findsNWidgets(2));
  });
}
