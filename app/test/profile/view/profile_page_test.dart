import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const authUser = AuthUser(uid: 'uid', isAnonymous: false);
  late AppBloc appBloc;
  late UserRepository userRepository;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(const AppAuthenticated(authUser));
    userRepository = MockUserRepository();
  });

  Future<void> pumpProfile(WidgetTester tester, UserModel? user) {
    when(() => userRepository.watchUser('uid'))
        .thenAnswer((_) => Stream.value(user));
    return tester.pumpApp(
      const ProfilePage(),
      appBloc: appBloc,
      userRepository: userRepository,
    );
  }

  group(ProfilePage, () {
    testWidgets('shows the profile', (tester) async {
      await pumpProfile(
        tester,
        UserModel(
          userId: 'uid',
          email: 'ada@example.com',
          displayName: 'Ada Lovelace',
          username: 'ada',
          creationDate: DateTime.utc(2025, 3, 4, 12),
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
          submittedLengthUnitPreference: LengthUnitPreference.inches,
          submittedDistanceUnitPreference: DistanceUnitPreference.miles,
          weeklySessionGoal: 4,
        ),
      );
      await tester.pump();

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('@ada'), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(find.text('March 2025'), findsOneWidget);
      expect(find.text('4 sessions a week'), findsOneWidget);
      expect(find.text('Pounds'), findsOneWidget);
      expect(find.text('Inches'), findsOneWidget);
      expect(find.text('Miles'), findsOneWidget);
    });

    testWidgets('shows the metric units and a one-session goal', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        const UserModel(
          userId: 'uid',
          submittedWeightUnitPreference: WeightUnitPreference.kilograms,
          submittedLengthUnitPreference: LengthUnitPreference.centimeters,
          submittedDistanceUnitPreference: DistanceUnitPreference.kilometers,
          weeklySessionGoal: 1,
        ),
      );
      await tester.pump();

      expect(find.text('Kilograms'), findsOneWidget);
      expect(find.text('Centimeters'), findsOneWidget);
      expect(find.text('Kilometers'), findsOneWidget);
      expect(find.text('1 session a week'), findsOneWidget);
    });

    testWidgets('falls back to the first and last names, and to Not Set', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        const UserModel(
          userId: 'uid',
          submittedFirstName: 'Augusta',
          lastName: 'King',
          submittedEmail: 'augusta@example.com',
        ),
      );
      await tester.pump();

      expect(find.text('Augusta King'), findsOneWidget);
      expect(find.text('augusta@example.com'), findsOneWidget);
      // Username, member since, weekly goal and the three units.
      expect(find.text('Not Set'), findsNWidgets(6));
    });

    testWidgets('says so when there is no name at all', (tester) async {
      await pumpProfile(tester, const UserModel(userId: 'uid'));
      await tester.pump();

      expect(find.text('No Name'), findsOneWidget);
    });

    testWidgets('shows the photo, and the placeholder when it fails', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        const UserModel(userId: 'uid', photoUrl: 'https://example.com/a.jpg'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      // Network images fail in widget tests, so the placeholder shows.
      expect(find.byIcon(Icons.account_circle_rounded), findsOneWidget);
    });

    testWidgets('says when the profile cannot be loaded', (tester) async {
      await pumpProfile(tester, null);
      await tester.pump();

      expect(find.text("Your profile couldn't be loaded."), findsOneWidget);
    });

    testWidgets('shows progress until the profile arrives', (tester) async {
      when(() => userRepository.watchUser('uid'))
          .thenAnswer((_) => const Stream.empty());
      await tester.pumpApp(
        const ProfilePage(),
        appBloc: appBloc,
        userRepository: userRepository,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('signs out', (tester) async {
      await pumpProfile(tester, null);
      await tester.pump();

      await tester.tap(find.text('Sign Out'));
      verify(() => appBloc.add(const AppSignOutPressed())).called(1);
    });

    testWidgets('shows nothing once signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const ProfilePage(), appBloc: appBloc);

      expect(find.byType(ProfileView), findsNothing);
    });
  });
}
