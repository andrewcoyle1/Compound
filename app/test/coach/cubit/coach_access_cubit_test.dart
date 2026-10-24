import 'package:bloc_test/bloc_test.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/coach/coach.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockCoachRepository extends Mock implements CoachRepository;

void main() {
  const uid = 'user-1';
  late InMemoryUserRepository users;
  late CoachRepository coach;
  late FakePurchasesRepository purchases;
  late AnalyticsRecorder analytics;

  setUp(() {
    users = InMemoryUserRepository();
    coach = CoachRepository(
      firestore: FakeFirebaseFirestore(),
      users: users,
      coachChat: (_, {chatId, context, regenerate = false}) =>
          const Stream.empty(),
    );
    purchases = FakePurchasesRepository();
    analytics = AnalyticsRecorder();
  });

  CoachAccessCubit build({CoachRepository? repository}) => CoachAccessCubit(
    coach: repository ?? coach,
    purchases: purchases,
    analytics: analytics,
  );

  group(CoachAccess, () {
    test('is on only when premium and enabled', () {
      expect(const CoachAccess().isOn, isTrue);
      expect(const CoachAccess(premium: false).isOn, isFalse);
      expect(const CoachAccess(enabled: false).isOn, isFalse);
    });
  });

  group(CoachAccessCubit, () {
    test('starts on for a subscriber, with no one signed in', () async {
      final cubit = build();
      expect(cubit.state, const CoachAccess());
      await cubit.close();
    });

    blocTest<CoachAccessCubit, CoachAccess>(
      "follows the user's switch, and forgets it on signing out",
      setUp: () => users.mergePrivateSettings(
        uid,
        const PrivateUserSettings(coachEnabled: false),
      ),
      build: build,
      act: (cubit) async {
        cubit.userChanged(uid);
        await pumpEventQueue();
        // The same user again changes nothing.
        cubit
          ..userChanged(uid)
          ..userChanged(null);
      },
      // The store's answer first, as it was.
      expect: () => const [
        CoachAccess(),
        CoachAccess(enabled: false),
        CoachAccess(),
      ],
    );

    blocTest<CoachAccessCubit, CoachAccess>(
      'goes off once the store says the user is not premium',
      setUp: () => purchases = FakePurchasesRepository(premium: false),
      build: build,
      act: (cubit) => purchases.logIn(uid),
      expect: () => const [CoachAccess(), CoachAccess(premium: false)],
    );

    test('the switch is written with its analytics, and read back', () async {
      final cubit = build()..userChanged(uid);
      await pumpEventQueue();

      await cubit.enabledChanged(enabled: false);
      await pumpEventQueue();

      expect(cubit.state, const CoachAccess(enabled: false));
      expect(analytics.parameters('SettingsView_Coach_Toggle'), {
        'enabled': false,
      });
      expect(await coach.watchConsent(uid).first, isFalse);
      await cubit.close();
    });

    test('the switch does nothing while signed out', () async {
      final cubit = build();
      await cubit.enabledChanged(enabled: false);
      expect(analytics.names, isEmpty);
      await cubit.close();
    });

    test('a failed write is reported', () async {
      final repository = _MockCoachRepository();
      when(() => repository.watchEnabled(uid))
          .thenAnswer((_) => Stream.error(Exception('read')));
      when(() => repository.setEnabled(uid, enabled: false))
          .thenThrow(Exception('write'));
      final cubit = build(repository: repository)..userChanged(uid);
      await pumpEventQueue();

      await cubit.enabledChanged(enabled: false);

      expect(analytics.names, contains('SettingsView_Coach_Toggle_Fail'));
      expect(cubit.state, const CoachAccess());
      await cubit.close();
    });
  });
}
