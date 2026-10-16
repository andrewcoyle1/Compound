import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:flutter/foundation.dart';

// The way out for someone who will not subscribe (Swift `PaywallExits`):
// Subscription and the onboarding paywall offer their account, and signing
// out, so nobody is held there with an account they cannot leave or delete.

/// `<screen>_Account_Press`.
void accountPressedFrom(AnalyticsRepository analytics, String screen) =>
    analytics.analytic('${screen}_Account_Press');

/// Signs out from [screen], logging `<screen>_SignOut_Start`, `_Success` or
/// `_Fail`, and returns whether it worked. The router then goes to sign-in.
Future<bool> signOutFrom(
  String screen, {
  required AuthRepository auth,
  required AnalyticsRepository analytics,
}) async {
  analytics.analytic('${screen}_SignOut_Start');
  try {
    await auth.signOut();
    analytics.analytic('${screen}_SignOut_Success');
    return true;
  } on Object catch (error) {
    analytics.severe('${screen}_SignOut_Fail', error);
    return false;
  }
}

/// The store's own page for managing subscriptions (the plan, renewal and
/// cancelling), which Swift opens as Apple's Manage Subscriptions sheet.
Uri manageSubscriptionsUri(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => Uri.parse(
    'https://apps.apple.com/account/subscriptions',
  ),
  _ => Uri.parse('https://play.google.com/store/account/subscriptions'),
};
