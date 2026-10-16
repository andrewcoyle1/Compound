import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ActiveAbTests, () {
    test("defaults to Swift's: not in the notifications test, custom", () {
      expect(const ActiveAbTests().paywallTest, PaywallTestOption.custom);
      expect(const ActiveAbTests().notificationsTest, isFalse);
    });

    test("names the user properties as Swift's eventParameters", () {
      expect(
        const ActiveAbTests(
          notificationsTest: true,
          paywallTest: PaywallTestOption.revenueCat,
        ).eventParameters,
        {
          'test_20251205_notifications_test': true,
          'test_20241205_PaywallTest': 'revenueCat',
        },
      );
    });

    test('copyWith changes only what it is given', () {
      const tests = ActiveAbTests();
      expect(tests.copyWith(), tests);
      expect(
        tests.copyWith(notificationsTest: true),
        const ActiveAbTests(notificationsTest: true),
      );
      expect(
        tests.copyWith(paywallTest: PaywallTestOption.storeKit),
        const ActiveAbTests(paywallTest: PaywallTestOption.storeKit),
      );
    });

    test("reads Swift's raw values, and anything else as custom", () {
      expect(
        ActiveAbTests.paywallOption('storeKit'),
        PaywallTestOption.storeKit,
      );
      expect(
        ActiveAbTests.paywallOption('revenueCat'),
        PaywallTestOption.revenueCat,
      );
      expect(ActiveAbTests.paywallOption('other'), PaywallTestOption.custom);
      expect(ActiveAbTests.paywallOption(null), PaywallTestOption.custom);
    });
  });
}
