import 'package:compound/check_in/view/check_in_page.dart'
    show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Apple Health's words on iOS, Health Connect's on Android: the two
/// stores the health package reaches.
/// Whether this platform's store is Apple Health.
bool isAppleHealth(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };

extension HealthText on AppLocalizations {
  /// "Connect Apple Health", Today's getting-started step.
  String healthConnect(BuildContext context) =>
      isAppleHealth(context) ? healthConnectApple : healthConnectAndroid;

  /// "Sync from Apple Health".
  String healthSync(BuildContext context) =>
      isAppleHealth(context) ? healthSyncApple : healthSyncAndroid;

  /// "Fill from Apple Health", onboarding.
  String healthFill(BuildContext context) =>
      isAppleHealth(context) ? healthFillApple : healthFillAndroid;

  /// After a fill that found something.
  String healthFilled(BuildContext context) =>
      isAppleHealth(context) ? healthFilledApple : healthFilledAndroid;

  /// After a fill that found nothing.
  String healthNotFound(BuildContext context) =>
      isAppleHealth(context) ? healthNotFoundApple : healthNotFoundAndroid;
}

/// "Unable to Access Apple Health": step access was refused after a tap.
Future<void> showStepsAccessFailed(BuildContext context) {
  final l10n = context.l10n;
  final apple = isAppleHealth(context);
  return showFailureAlert(
    context,
    apple ? l10n.healthAccessFailedApple : l10n.healthAccessFailedAndroid,
    apple ? l10n.healthAllowStepsApple : l10n.healthAllowStepsAndroid,
  );
}
