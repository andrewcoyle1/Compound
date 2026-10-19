import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/settings/account/view/edit_profile_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../../helpers/helpers.dart';

void main() {
  const authUser = AuthUser(uid: 'user-1', isAnonymous: false);
  late AppBloc appBloc;
  late InMemoryUserRepository users;

  UserModel stored() => const UserModel(
    userId: 'user-1',
    submittedFirstName: 'Andrew',
    submittedLastName: 'Coyle',
    submittedHeightCentimeters: 182.5,
    submittedGender: Gender.male,
    username: 'andrew',
  );

  setUp(() {
    appBloc = MockAppBloc();
    users = InMemoryUserRepository(users: {'user-1': stored()});
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Future<void> pumpPage(WidgetTester tester, {UserModel? profile}) async {
    when(() => appBloc.state).thenReturn(
      AppAuthenticated(
        authUser,
        profile: profile ?? stored(),
        profileStatus: AppProfileStatus.ready,
      ),
    );
    tester.view.physicalSize = const Size(2400, 9000);
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      userRepository: users,
      router: GoRouter(
        initialLocation: '/profile/edit',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => const Text('profile'),
            routes: [
              GoRoute(
                path: EditProfilePage.path,
                name: EditProfilePage.name,
                builder: (_, _) => const EditProfilePage(),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<UserModel?> profile() => users.watchUser('user-1').first;

  group(EditProfilePage, () {
    testWidgets('shows the stored profile', (tester) async {
      await pumpPage(tester);
      expect(find.text('Andrew'), findsOneWidget);
      expect(find.text('Coyle'), findsOneWidget);
      expect(find.text('182.5'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('@andrew'), findsOneWidget);
      expect(find.text('Not specified'), findsNWidgets(3));
    });

    testWidgets('Save writes the edits and closes the screen', (tester) async {
      await pumpPage(tester);
      await tester.enterText(find.byType(TextField).at(1), 'C');
      await tester.tap(find.text('Daily Activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sedentary'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      expect(find.text('profile'), findsOneWidget);
      final saved = (await profile())!;
      expect(saved.submittedLastName, 'C');
      expect(saved.submittedDailyActivityLevel, ActivityLevel.sedentary);
      expect(saved.submittedHeightCentimeters, 182.5);
    });

    testWidgets('a picker can go back to not specified', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Sex'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not specified').last);
      await tester.pumpAndSettle();
      expect(find.text('Male'), findsNothing);
    });

    testWidgets('Save is off without a first name', (tester) async {
      await pumpPage(tester);
      await tester.enterText(find.byType(TextField).first, '  ');
      await tester.pump();
      final save = tester.widget<AppToolbarButton>(
        find.widgetWithIcon(AppToolbarButton, AppSymbols.confirm),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('the privacy switch writes as it flips', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Private profile'));
      await tester.pumpAndSettle();
      expect((await profile())!.isPrivate, isTrue);
    });

    testWidgets('the date of birth is picked from a calendar', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Date of birth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Not Set'), findsNothing);
    });

    testWidgets('Close leaves without writing', (tester) async {
      await pumpPage(tester);
      await tester.enterText(find.byType(TextField).at(1), 'C');
      await tester.tap(find.byIcon(AppSymbols.close));
      await tester.pumpAndSettle();
      expect(find.text('profile'), findsOneWidget);
      expect((await profile())!.submittedLastName, 'Coyle');
    });

    testWidgets('a failed save says so and stays', (tester) async {
      users = InMemoryUserRepository();
      await pumpPage(tester);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Save Profile'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfilePage), findsOneWidget);
    });

    testWidgets('a privacy switch that cannot be written says so', (
      tester,
    ) async {
      users = InMemoryUserRepository();
      await pumpPage(tester);
      await tester.tap(find.text('Private profile'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Change Privacy'), findsOneWidget);
    });

    testWidgets('shows a blank profile once signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(
        const EditProfilePage(),
        appBloc: appBloc,
        userRepository: users,
      );
      expect(find.text('Andrew'), findsNothing);
    });
  });
}
