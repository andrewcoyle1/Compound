import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig;

void main() {
  late _MockRemoteConfig config;

  setUpAll(() {
    registerFallbackValue(
      RemoteConfigSettings(
        fetchTimeout: Duration.zero,
        minimumFetchInterval: Duration.zero,
      ),
    );
  });

  setUp(() {
    config = _MockRemoteConfig();
    when(() => config.setConfigSettings(any())).thenAnswer((_) async {});
    when(() => config.setDefaults(any())).thenAnswer((_) async {});
    when(() => config.activate()).thenAnswer((_) async => true);
    when(() => config.getBool(any())).thenReturn(false);
    when(() => config.getString(any())).thenReturn('custom');
  });

  group(RemoteConfigAbTestRepository, () {
    test("sets Swift's settings and defaults, then activates", () async {
      await RemoteConfigAbTestRepository.init(config);
      final settings =
          verify(() => config.setConfigSettings(captureAny())).captured.single
              as RemoteConfigSettings;
      expect(settings.minimumFetchInterval, Duration.zero);
      expect(settings.fetchTimeout, const Duration(minutes: 1));
      verify(
        () => config.setDefaults({
          '_20251205_notifications_test': false,
          '_20241205_PaywallTest': 'custom',
        }),
      ).called(1);
      verify(() => config.activate()).called(1);
    });

    test('reads the parameters, an unknown paywall as custom', () async {
      when(() => config.getBool('_20251205_notifications_test'))
          .thenReturn(true);
      when(() => config.getString('_20241205_PaywallTest'))
          .thenReturn('storeKit');
      final repository = await RemoteConfigAbTestRepository.init(config);
      expect(
        repository.activeTests,
        const ActiveAbTests(
          notificationsTest: true,
          paywallTest: PaywallTestOption.storeKit,
        ),
      );
      when(() => config.getString('_20241205_PaywallTest')).thenReturn('');
      expect(repository.activeTests.paywallTest, PaywallTestOption.custom);
    });

    test('fetches and activates, and throws when that fails', () async {
      final repository = await RemoteConfigAbTestRepository.init(config);
      when(() => config.fetchAndActivate()).thenAnswer((_) async => true);
      expect(await repository.fetch(), const ActiveAbTests());
      when(() => config.fetchAndActivate()).thenThrow(Exception('offline'));
      await expectLater(repository.fetch(), throwsException);
    });

    test('refuses an override', () async {
      final repository = await RemoteConfigAbTestRepository.init(config);
      expect(
        () => repository.save(const ActiveAbTests()),
        throwsUnsupportedError,
      );
    });
  });
}
