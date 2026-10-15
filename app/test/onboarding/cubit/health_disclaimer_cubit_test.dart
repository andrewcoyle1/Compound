import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/onboarding/health_disclaimer/health_disclaimer_cubit.dart';
import 'package:compound_models/compound_models.dart' show UserModelKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';
import 'helpers.dart';

/// Mirrors `OnboardingHealthConsentPresenterTests`.
void main() {
  late UserRepository users;
  late RecordingAnalytics analytics;
  final now = DateTime.utc(2026, 10, 15, 9);

  setUpAll(() => registerFallbackValue(<UserFieldValue>[]));

  setUp(() {
    users = MockUserRepository();
    analytics = RecordingAnalytics();
    when(() => users.updateUserFields(any(), any())).thenAnswer((_) async {});
  });

  HealthDisclaimerCubit build() => HealthDisclaimerCubit(
    userRepository: users,
    analyticsRepository: analytics.repository,
    uid: 'uid',
    now: () => now,
  );

  blocTest<HealthDisclaimerCubit, HealthDisclaimerState>(
    'needs both acceptances',
    build: build,
    act: (cubit) async {
      cubit.termsChanged(accepted: true);
      await cubit.accept();
    },
    expect: () => [const HealthDisclaimerState(acceptedTerms: true)],
    verify: (_) => verifyNever(() => users.updateUserFields(any(), any())),
  );

  blocTest<HealthDisclaimerCubit, HealthDisclaimerState>(
    'stamps both current versions with one time, in one update',
    build: build,
    act: (cubit) async {
      cubit
        ..termsChanged(accepted: true)
        ..privacyChanged(accepted: true);
      await cubit.accept();
    },
    verify: (cubit) {
      final captured = verify(() => users.updateUserFields('uid', captureAny()))
          .captured;
      expect(fieldsOf(captured.single), {
        UserModelKeys.acceptedHealthDisclaimerVersion: '2025.10.05',
        UserModelKeys.acceptedHealthDisclaimerDate: now,
        UserModelKeys.acceptedHealthPrivacyPolicyVersion: '2025.10.05',
        UserModelKeys.acceptedHealthPrivacyPolicyDate: now,
      });
      expect(analytics.names, [
        'HealthDisclaimerView_Appear',
        'consent_health_confirm_start',
        'consent_health_confirm_success',
        'HealthDisclaimer_Navigate',
        'HealthDisclaimerView_Disappear',
      ]);
      expect(analytics.last('consent_health_confirm_success').parameters, {
        'disclaimer_version': '2025.10.05',
        'privacy_version': '2025.10.05',
        'accepted_at': now,
      });
      expect(cubit.state.status, HealthDisclaimerStatus.idle);
    },
  );

  blocTest<HealthDisclaimerCubit, HealthDisclaimerState>(
    'reports a failed save',
    setUp: () =>
        when(() => users.updateUserFields(any(), any()))
            .thenThrow(Exception('offline')),
    build: build,
    act: (cubit) async {
      cubit
        ..termsChanged(accepted: true)
        ..privacyChanged(accepted: true);
      await cubit.accept();
    },
    verify: (cubit) {
      expect(cubit.state.status, HealthDisclaimerStatus.failure);
      final fail = analytics.last('consent_health_confirm_fail');
      expect(fail.type, LogType.severe);
      expect(fail.parameters?['disclaimer_version'], '2025.10.05');
    },
  );

  test('accepting twice at once saves once', () async {
    final cubit = build()
      ..termsChanged(accepted: true)
      ..privacyChanged(accepted: true);
    await Future.wait([cubit.accept(), cubit.accept()]);
    verify(() => users.updateUserFields(any(), any())).called(1);
  });
}
