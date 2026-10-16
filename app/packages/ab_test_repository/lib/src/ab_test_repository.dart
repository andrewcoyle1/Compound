import 'dart:math';

import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:device_store/device_store.dart';

/// Where this user's A/B tests come from (Swift `ABTestService`).
abstract interface class AbTestRepository {
  /// The tests as last fetched or saved; the defaults before either.
  ActiveAbTests get activeTests;

  /// Asks for the latest assignment and returns it.
  Future<ActiveAbTests> fetch();

  /// Keeps [tests] as this device's assignment, from Developer Settings.
  /// Throws [UnsupportedError] where the server assigns them.
  void save(ActiveAbTests tests);
}

/// {@template in_memory_ab_test_repository}
/// An [AbTestRepository] in memory, for the staging flavor and tests (Swift
/// `MockABTestService`): the defaults unless it is given others.
/// {@endtemplate}
class InMemoryAbTestRepository implements AbTestRepository {
  /// {@macro in_memory_ab_test_repository}
  new([ActiveAbTests tests = const ActiveAbTests()]) : activeTests = tests;

  @override
  ActiveAbTests activeTests;

  @override
  Future<ActiveAbTests> fetch() async => activeTests;

  @override
  void save(ActiveAbTests tests) => activeTests = tests;
}

/// {@template local_ab_test_repository}
/// An [AbTestRepository] kept on the device, for the development flavor
/// (Swift `LocalABTestService`). Each test is drawn at random the first time
/// it is read and kept under its Remote Config key, so the device stays in
/// its group; Developer Settings overrides it.
/// {@endtemplate}
class LocalAbTestRepository implements AbTestRepository {
  /// {@macro local_ab_test_repository}
  new(this._store, {Random? random}) : _random = random ?? Random();

  final DeviceStore _store;
  final Random _random;

  @override
  ActiveAbTests get activeTests {
    const options = PaywallTestOption.values;
    final paywall = _store.getString(ActiveAbTests.paywallTestKey);
    final tests = ActiveAbTests(
      notificationsTest:
          _store.getBool(ActiveAbTests.notificationsTestKey) ??
          _random.nextBool(),
      paywallTest:
          options.asNameMap()[paywall] ??
          options[_random.nextInt(options.length)],
    );
    // Keeps a first draw, as Swift's wrappers store their starting value.
    save(tests);
    return tests;
  }

  @override
  Future<ActiveAbTests> fetch() async => activeTests;

  @override
  void save(ActiveAbTests tests) {
    _store
      ..setBool(
        ActiveAbTests.notificationsTestKey,
        value: tests.notificationsTest,
      )
      ..setString(ActiveAbTests.paywallTestKey, tests.paywallTest.name);
  }
}
