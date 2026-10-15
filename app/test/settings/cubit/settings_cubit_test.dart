import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/settings/cubit/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository;

class _MockAuthRepository extends Mock implements AuthRepository;

void main() {
  late AnalyticsRepository analytics;
  late AuthRepository auth;
  late List<(String, LogType)> events;

  setUpAll(() => registerFallbackValue(const AnalyticsEvent('fallback')));

  setUp(() {
    analytics = _MockAnalyticsRepository();
    auth = _MockAuthRepository();
    events = [];
    void record(Invocation invocation) {
      final event = invocation.positionalArguments.single as LoggableEvent;
      events.add((event.eventName, event.type));
    }

    when(() => analytics.trackEvent(any())).thenAnswer(record);
    when(() => analytics.trackScreenView(any())).thenAnswer(record);
  });

  SettingsCubit build() => SettingsCubit(analytics: analytics, auth: auth);

  group(SignInMethod, () {
    test('says how the person signs in, Apple before Google', () {
      expect(
        SignInMethod.of(const AuthUser(uid: 'a', isAnonymous: true)),
        SignInMethod.notSaved,
      );
      expect(
        SignInMethod.of(
          const AuthUser(
            uid: 'a',
            isAnonymous: false,
            providers: {SignInProvider.google, SignInProvider.apple},
          ),
        ),
        SignInMethod.apple,
      );
      expect(
        SignInMethod.of(
          const AuthUser(
            uid: 'a',
            isAnonymous: false,
            providers: {SignInProvider.google},
          ),
        ),
        SignInMethod.google,
      );
      expect(
        SignInMethod.of(const AuthUser(uid: 'a', isAnonymous: false)),
        SignInMethod.unknown,
      );
    });
  });

  group(SettingsCubit, () {
    test('starts idle', () => expect(build().state, SettingsStatus.idle));

    test('tracks the screen and its rows under the Swift names', () {
      build()
        ..appeared()
        ..notificationSettingsPressed()
        ..supportPressed()
        ..deleteAccountPressed()
        ..disappeared();
      expect(events, [
        ('ProfileView_Appear', LogType.analytic),
        ('ProfileView_NotificationSettings_Press', LogType.analytic),
        ('ProfileView_Support_Press', LogType.analytic),
        ('Settings_DeleteAccount_Start', LogType.analytic),
        ('ProfileView_Disappear', LogType.analytic),
      ]);
    });

    test('pressing Delete Account deletes nothing', () {
      build().deleteAccountPressed();
      verifyZeroInteractions(auth);
    });

    blocTest<SettingsCubit, SettingsStatus>(
      'signs out',
      setUp: () => when(auth.signOut).thenAnswer((_) async {}),
      build: build,
      act: (cubit) => cubit.signOutPressed(),
      expect: () => [SettingsStatus.signingOut, SettingsStatus.idle],
      verify: (_) {
        verify(auth.signOut).called(1);
        expect(events, [
          ('Settings_SignOut_Start', LogType.analytic),
          ('Settings_SignOut_Success', LogType.analytic),
        ]);
      },
    );

    blocTest<SettingsCubit, SettingsStatus>(
      'a failed sign out leaves the user signed in and says so',
      setUp: () => when(auth.signOut).thenThrow(const AuthFailure('offline')),
      build: build,
      act: (cubit) => cubit.signOutPressed(),
      expect: () => [SettingsStatus.signingOut, SettingsStatus.signOutFailure],
      verify: (_) => expect(events, [
        ('Settings_SignOut_Start', LogType.analytic),
        ('Settings_SignOut_Fail', LogType.severe),
      ]),
    );

    blocTest<SettingsCubit, SettingsStatus>(
      'ignores a second press while signing out',
      setUp: () => when(auth.signOut).thenAnswer((_) async {}),
      build: build,
      seed: () => SettingsStatus.signingOut,
      act: (cubit) => cubit.signOutPressed(),
      expect: () => const <SettingsStatus>[],
      verify: (_) => verifyNever(auth.signOut),
    );
  });
}
