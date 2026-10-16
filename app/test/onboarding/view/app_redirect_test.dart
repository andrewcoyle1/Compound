import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

void main() {
  const user = AuthUser(uid: 'uid', isAnonymous: true);
  String? at(AppState state, String location) =>
      appRedirect(state, Uri.parse(location));
  AppAuthenticated ready(UserModel profile) => AppAuthenticated(
    user,
    profile: profile,
    profileStatus: AppProfileStatus.ready,
  );
  final newUser = ready(const UserModel(userId: 'uid'));
  final onboarded = ready(
    const UserModel(userId: 'uid', didCompleteOnboarding: true),
  );

  test('signed out goes to sign-in', () {
    expect(at(const AppUnauthenticated(), '/today'), '/sign-in');
    expect(at(const AppUnauthenticated(), '/sign-in'), isNull);
  });

  test('while the profile loads, waits on the launch screen, remembering '
      'where it was going', () {
    const loading = AppAuthenticated(user);
    expect(at(loading, '/progress'), '/launch?from=%2Fprogress');
    expect(at(loading, '/sign-in'), '/launch');
    expect(at(loading, '/onboarding/goal'), '/launch');
    expect(at(loading, '/launch?from=%2Fprogress'), isNull);
    expect(
      at(
        const AppAuthenticated(user, profileStatus: AppProfileStatus.failure),
        '/today',
      ),
      '/launch?from=%2Ftoday',
    );
  });

  test('during onboarding, only the step it resumes at', () {
    expect(at(newUser, '/today'), '/onboarding/account');
    expect(at(newUser, '/launch'), '/onboarding/account');
    expect(at(newUser, '/onboarding/goal'), '/onboarding/account');
    expect(at(newUser, '/onboarding/account'), isNull);
    // Build My Own's day editor picks exercises over the program step.
    expect(at(newUser, '/exercise-picker'), isNull);
  });

  test('once onboarded, back where it was going, or to Today', () {
    expect(at(onboarded, '/launch?from=%2Fprogress'), '/progress');
    expect(at(onboarded, '/launch'), '/today');
    expect(at(onboarded, '/sign-in'), '/today');
    expect(at(onboarded, '/onboarding/diet'), '/today');
    expect(at(onboarded, '/profile'), isNull);
  });

  group('without a subscription (Swift: Auth and Welcome send the user to '
      'Subscription)', () {
    AppAuthenticated notPremium(UserModel profile, {required bool signedIn}) =>
        AppAuthenticated(
          user,
          profile: profile,
          profileStatus: AppProfileStatus.ready,
          isPremium: false,
          signedInThisRun: signedIn,
        );

    test('someone who just signed in is held at Subscription', () {
      final lapsed = notPremium(
        const UserModel(userId: 'uid', didCompleteOnboarding: true),
        signedIn: true,
      );
      expect(lapsed.needsSubscription, isTrue);
      expect(at(lapsed, '/today'), '/subscribe');
      expect(at(lapsed, '/launch'), '/subscribe');
      expect(at(lapsed, '/subscribe'), isNull);
      expect(at(lapsed, '/subscribe/plans'), isNull);
      expect(at(lapsed, '/subscribe/account'), isNull);
    });

    test('so is an account still in onboarding, even at launch', () {
      final onboarding = notPremium(
        const UserModel(userId: 'uid'),
        signedIn: false,
      );
      expect(at(onboarding, '/onboarding/account'), '/subscribe');
    });

    test('a finished user signed in at launch reaches the tabs, as Swift '
        'launches into the tab bar', () {
      final returning = notPremium(
        const UserModel(userId: 'uid', didCompleteOnboarding: true),
        signedIn: false,
      );
      expect(returning.needsSubscription, isFalse);
      expect(at(returning, '/today'), isNull);
    });

    test('once premium, Subscription moves on to onboarding or Today', () {
      expect(at(newUser, '/subscribe/plans'), '/onboarding/account');
      expect(at(onboarded, '/subscribe/plans'), '/today');
      expect(at(onboarded, '/subscribe'), '/today');
    });
  });
}
