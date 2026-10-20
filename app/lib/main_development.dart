import 'dart:io';

import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:compound/bootstrap.dart';
import 'package:compound/firebase_app.dart';
import 'package:compound/firebase_options_development.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

/// The Mixpanel project token, from a gitignored file:
/// `--dart-define-from-file=dart_defines.json` (see the README). Mixpanel is
/// off when it's empty. Never commit it.
const _mixpanelToken = String.fromEnvironment('MIXPANEL_TOKEN');

/// Strava's client id for the dev Strava app, from the same gitignored
/// file. Strava shows as unavailable when it's empty.
const _stravaClientId = String.fromEnvironment('STRAVA_CLIENT_ID');

/// RevenueCat's public SDK keys for the Flutter apps, from the same
/// gitignored file. Without the running platform's key the app never
/// starts RevenueCat and uses the premium fake instead.
const _revenueCatAppleKey = String.fromEnvironment('REVENUECAT_APPLE_API_KEY');
const _revenueCatGoogleKey = String.fromEnvironment(
  'REVENUECAT_GOOGLE_API_KEY',
);

/// The development flavor: the `compound-development` Firebase project.
Future<void> main() async {
  await bootstrap(
    () => firebaseApp(
      FirebaseFlavor(
        options: DefaultFirebaseOptions.currentPlatform,
        // Debug providers: the token is printed to the device log on first
        // run and must be registered in the compound-development console
        // before App Check is enforced.
        appleAppCheck: const AppleDebugProvider(),
        androidAppCheck: const AndroidDebugProvider(),
        logToConsole: true,
        mixpanelToken: _mixpanelToken,
        mixpanelBuildConfiguration: 'dev',
        stravaClientId: _stravaClientId,
        revenueCatKey: Platform.isIOS
            ? _revenueCatAppleKey
            : _revenueCatGoogleKey,
        bundleId: 'com.andrewcoyle.compound.dev',
        // A random draw kept on the device, as Swift's dev builds
        // (`LocalABTestService`); Developer Settings overrides it.
        abTests: LocalAbTestRepository.new,
        sessionWebLinkBase: 'https://compound-development.web.app/s',
      ),
    ),
  );
}
