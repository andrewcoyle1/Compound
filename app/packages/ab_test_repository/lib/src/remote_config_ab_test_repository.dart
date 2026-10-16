import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// {@template remote_config_ab_test_repository}
/// An [AbTestRepository] on Firebase Remote Config, for the production flavor
/// (Swift `FirebaseABTestService`). Create it with [init].
/// {@endtemplate}
class RemoteConfigAbTestRepository implements AbTestRepository {
  new _(this._config);

  /// Sets Swift's defaults (so with no parameters in the console everyone
  /// gets them), fetches on every request as Swift does, and activates what
  /// an earlier launch fetched.
  static Future<RemoteConfigAbTestRepository> init(
    FirebaseRemoteConfig config,
  ) async {
    const defaults = ActiveAbTests();
    await config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: Duration.zero,
      ),
    );
    await config.setDefaults({
      ActiveAbTests.notificationsTestKey: defaults.notificationsTest,
      ActiveAbTests.paywallTestKey: defaults.paywallTest.name,
    });
    await config.activate();
    return RemoteConfigAbTestRepository._(config);
  }

  final FirebaseRemoteConfig _config;

  /// An unknown paywall value reads as the default, as in Swift.
  @override
  ActiveAbTests get activeTests => ActiveAbTests(
    notificationsTest: _config.getBool(ActiveAbTests.notificationsTestKey),
    paywallTest: ActiveAbTests.paywallOption(
      _config.getString(ActiveAbTests.paywallTestKey),
    ),
  );

  /// Throws when the fetch fails (Swift's `failedToFetch`).
  @override
  Future<ActiveAbTests> fetch() async {
    await _config.fetchAndActivate();
    return activeTests;
  }

  @override
  void save(ActiveAbTests tests) => throw UnsupportedError(
    'Remote Config A/B tests are not configurable from the client.',
  );
}
