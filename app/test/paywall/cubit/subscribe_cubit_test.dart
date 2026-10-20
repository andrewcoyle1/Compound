import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/paywall/paywall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

/// Swift `OnboardingSubscriptionPresenterTests`, case for case. Opening the
/// paywall is the view's (`paywall_flow_test.dart`); here, what each press
/// logs.
void main() {
  late MockAuthRepository auth;
  late AnalyticsRecorder analytics;

  setUp(() {
    auth = MockAuthRepository();
    analytics = AnalyticsRecorder();
  });

  SubscribeCubit build() => SubscribeCubit(auth: auth, analytics: analytics);

  test('continuing logs the move to the paywall, each time', () {
    build()
      ..continuePressed()
      ..continuePressed();
    expect(analytics.names, [
      'SubscriptionInfoView_Navigate',
      'SubscriptionInfoView_Navigate',
    ]);
  });

  test('tracks its lifecycle under its Swift names', () {
    build()
      ..appeared()
      ..disappeared();
    expect(analytics.names, [
      'SubscriptionView_Appear',
      'SubscriptionView_Disappear',
    ]);
  });

  test('the account is offered', () {
    build().accountPressed();
    expect(analytics.names, ['SubscriptionInfoView_Account_Press']);
  });

  blocTest<SubscribeCubit, int>(
    'signs out',
    setUp: () => when(auth.signOut).thenAnswer((_) async {}),
    build: build,
    act: (cubit) => cubit.signOutPressed(),
    expect: () => const <int>[],
    verify: (_) => expect(analytics.names, [
      'SubscriptionInfoView_SignOut_Start',
      'SubscriptionInfoView_SignOut_Success',
    ]),
  );

  blocTest<SubscribeCubit, int>(
    'a failed sign-out says so, each time',
    setUp: () => when(auth.signOut).thenThrow(const AuthFailure()),
    build: build,
    act: (cubit) async {
      await cubit.signOutPressed();
      await cubit.signOutPressed();
    },
    expect: () => const [1, 2],
    verify: (_) =>
        expect(analytics.names.last, 'SubscriptionInfoView_SignOut_Fail'),
  );
}
