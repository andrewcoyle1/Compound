import 'dart:async';

import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

/// Also keeps the user properties it is given.
class _Recorder extends AnalyticsRecorder {
  final properties = <Map<String, Object?>>[];

  @override
  void addUserProperties(
    Map<String, Object?> properties, {
    bool isHighPriority = false,
  }) => this.properties.add(properties);
}

/// Answers [fetch] only when [answer] completes; refuses saves when
/// [refuses].
class _SlowRepository extends InMemoryAbTestRepository {
  new({this.refuses = false});

  final bool refuses;
  final answer = Completer<ActiveAbTests>();

  @override
  Future<ActiveAbTests> fetch() => answer.future;

  @override
  void save(ActiveAbTests tests) {
    if (refuses) throw UnsupportedError('remote');
    super.save(tests);
  }
}

void main() {
  const fetched = ActiveAbTests(
    notificationsTest: true,
    paywallTest: PaywallTestOption.revenueCat,
  );
  late _Recorder analytics;

  setUp(() => analytics = _Recorder());

  group(AbTestsCubit, () {
    blocTest<AbTestsCubit, ActiveAbTests>(
      "starts from the repository's tests and takes the fetched ones",
      build: () {
        final repository = _SlowRepository();
        repository.answer.complete(fetched);
        return AbTestsCubit(repository: repository, analytics: analytics);
      },
      act: (cubit) => cubit.started(),
      expect: () => const [fetched],
      verify: (cubit) {
        expect(analytics.names, ['ABMan_FetchRemote_Success']);
        expect(analytics.properties, [
          const ActiveAbTests().eventParameters,
          fetched.eventParameters,
        ]);
      },
    );

    blocTest<AbTestsCubit, ActiveAbTests>(
      'a failed fetch keeps the tests it has',
      build: () {
        final repository = _SlowRepository();
        repository.answer.completeError(Exception('offline'));
        return AbTestsCubit(repository: repository, analytics: analytics);
      },
      act: (cubit) => cubit.started(),
      expect: () => const <ActiveAbTests>[],
      verify: (_) => expect(analytics.names, ['ABMan_FetchRemote_Fail']),
    );

    test('an override made during the fetch wins over it', () async {
      final repository = _SlowRepository();
      final cubit = AbTestsCubit(repository: repository, analytics: analytics);
      final start = cubit.started();
      const override = ActiveAbTests(paywallTest: PaywallTestOption.storeKit);
      cubit.override(override);
      repository.answer.complete(fetched);
      await start;
      expect(cubit.state, override);
      expect(analytics.names, [
        'DevSettingsView_OverrideTest_Start',
        'DevSettingsView_OverrideTest_Success',
        'ABMan_FetchRemote_Success',
      ]);
      expect(analytics.properties.last, override.eventParameters);
      await cubit.close();
    });

    test('an override of the same tests does nothing', () async {
      final cubit = AbTestsCubit(
        repository: InMemoryAbTestRepository(),
        analytics: analytics,
      )..override(const ActiveAbTests());
      expect(analytics.names, isEmpty);
      await cubit.close();
    });

    test('a refused override keeps the tests and logs why', () async {
      final cubit = AbTestsCubit(
        repository: _SlowRepository(refuses: true),
        analytics: analytics,
      )..override(fetched);
      expect(cubit.state, const ActiveAbTests());
      expect(analytics.names, [
        'DevSettingsView_OverrideTest_Start',
        'DevSettingsView_OverrideTest_Fail',
      ]);
      await cubit.close();
    });

    test('a fetch landing after close changes nothing', () async {
      final repository = _SlowRepository();
      final cubit = AbTestsCubit(repository: repository, analytics: analytics);
      final start = cubit.started();
      await cubit.close();
      repository.answer.complete(fetched);
      await start;
      expect(cubit.state, const ActiveAbTests());
    });
  });
}
