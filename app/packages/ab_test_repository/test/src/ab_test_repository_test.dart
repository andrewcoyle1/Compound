import 'dart:math';

import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A draw that always picks [flag] and the option at [index].
class _FixedRandom implements Random {
  new({required this.flag, required this.index});

  final bool flag;
  final int index;

  @override
  bool nextBool() => flag;

  @override
  int nextInt(int max) => index;

  @override
  double nextDouble() => 0;
}

void main() {
  group(InMemoryAbTestRepository, () {
    test('starts at the defaults, or the tests it is given', () async {
      expect(InMemoryAbTestRepository().activeTests, const ActiveAbTests());
      const tests = ActiveAbTests(notificationsTest: true);
      expect(await InMemoryAbTestRepository(tests).fetch(), tests);
    });

    test('keeps what is saved', () async {
      final repository = InMemoryAbTestRepository();
      const tests = ActiveAbTests(paywallTest: PaywallTestOption.storeKit);
      repository.save(tests);
      expect(repository.activeTests, tests);
      expect(await repository.fetch(), tests);
    });
  });

  group(LocalAbTestRepository, () {
    test('draws each test once and keeps it under its key', () async {
      final store = InMemoryDeviceStore();
      final repository = LocalAbTestRepository(
        store,
        random: _FixedRandom(flag: true, index: 2),
      );
      const drawn = ActiveAbTests(
        notificationsTest: true,
        paywallTest: PaywallTestOption.revenueCat,
      );
      expect(repository.activeTests, drawn);
      expect(store.getBool('_20251205_notifications_test'), isTrue);
      expect(store.getString('_20241205_PaywallTest'), 'revenueCat');
      // A new draw would differ; the kept one wins.
      expect(
        await LocalAbTestRepository(
          store,
          random: _FixedRandom(flag: false, index: 0),
        ).fetch(),
        drawn,
      );
    });

    test('redraws a paywall value it cannot read', () {
      final store = InMemoryDeviceStore({
        '_20251205_notifications_test': false,
        '_20241205_PaywallTest': 'gone',
      });
      expect(
        LocalAbTestRepository(
          store,
          random: _FixedRandom(flag: true, index: 0),
        ).activeTests,
        const ActiveAbTests(paywallTest: PaywallTestOption.storeKit),
      );
      expect(store.getString('_20241205_PaywallTest'), 'storeKit');
    });

    test('saves an override', () {
      final store = InMemoryDeviceStore();
      const tests = ActiveAbTests(notificationsTest: true);
      LocalAbTestRepository(store).save(tests);
      expect(LocalAbTestRepository(store).activeTests, tests);
    });

    test('draws with a real random source by default', () {
      expect(
        PaywallTestOption.values,
        contains(
          LocalAbTestRepository(InMemoryDeviceStore()).activeTests.paywallTest,
        ),
      );
    });
  });
}
