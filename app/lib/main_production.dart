import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:compound/bootstrap.dart';
import 'package:compound/firebase_app.dart';
import 'package:compound/firebase_options_production.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// The Swift app's production keys (`Keys.swift`), from the gitignored
/// `--dart-define-from-file=dart_defines.json`. Never commit them.
const _mixpanelToken = String.fromEnvironment('MIXPANEL_TOKEN_PROD');
const _stravaClientId = String.fromEnvironment('STRAVA_CLIENT_ID_PROD');
const _revenueCatAppleKey = String.fromEnvironment(
  'REVENUECAT_APPLE_API_KEY_PROD',
);

/// The production flavor: the `dialed-c3cb5` Firebase project, iOS only,
/// as the Swift app's `.prod` arm of `Dependencies`.
Future<void> main() async {
  // Without the key the app would fall back to the premium fake, which
  // would give everyone premium: refuse to start instead.
  if (_revenueCatAppleKey.isEmpty) {
    throw StateError(
      'REVENUECAT_APPLE_API_KEY_PROD is not set: build with '
      '--dart-define-from-file=dart_defines.json',
    );
  }
  await bootstrap(
    () => firebaseApp(
      FirebaseFlavor(
        options: DefaultFirebaseOptions.currentPlatform,
        // App Attest with DeviceCheck where it is unavailable, as Swift's
        // `MyAppCheckProviderFactory`. Never a debug provider here.
        appleAppCheck: const AppleAppAttestWithDeviceCheckFallbackProvider(),
        androidAppCheck: const AndroidPlayIntegrityProvider(),
        // Swift's production logger leaves the console out.
        logToConsole: false,
        mixpanelToken: _mixpanelToken,
        mixpanelBuildConfiguration: 'prod',
        stravaClientId: _stravaClientId,
        revenueCatKey: _revenueCatAppleKey,
        bundleId: 'com.andrewcoyle.compound',
        // Firebase Remote Config, as Swift's `FirebaseABTestService`.
        abTests: (_) =>
            RemoteConfigAbTestRepository.init(FirebaseRemoteConfig.instance),
        sessionWebLinkBase: 'https://dialed-c3cb5.web.app/s',
      ),
    ),
  );
}
