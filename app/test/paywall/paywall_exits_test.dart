import 'package:compound/paywall/paywall.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("manage subscriptions opens each store's own page", () {
    expect(
      manageSubscriptionsUri(TargetPlatform.iOS),
      Uri.parse('https://apps.apple.com/account/subscriptions'),
    );
    expect(
      manageSubscriptionsUri(TargetPlatform.android),
      Uri.parse('https://play.google.com/store/account/subscriptions'),
    );
  });
}
