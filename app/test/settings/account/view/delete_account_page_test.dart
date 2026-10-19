import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/settings/account/view/delete_account_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../../helpers/helpers.dart';

void main() {
  const appleUser = AuthUser(
    uid: 'user-1',
    isAnonymous: false,
    providers: {SignInProvider.apple},
  );
  late AppBloc appBloc;
  late AuthRepository auth;
  late UserRepository users;

  setUp(() {
    appBloc = MockAppBloc();
    auth = MockAuthRepository();
    users = MockUserRepository();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => users.deleteUser(any())).thenAnswer((_) async {});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    AuthUser user = appleUser,
    LinkRecorder? links,
  }) {
    when(() => appBloc.state).thenReturn(AppAuthenticated(user));
    tester.view.physicalSize = const Size(2400, 9000);
    addTearDown(tester.view.reset);
    return tester.pumpApp(
      const DeleteAccountPage(),
      appBloc: appBloc,
      authRepository: auth,
      userRepository: users,
      linkOpener: links ?? LinkRecorder(),
    );
  }

  group(DeleteAccountPage, () {
    testWidgets('says what is deleted and that the person signs in again', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('Meals, foods and recipes'), findsOneWidget);
      expect(
        find.text("You'll be asked to sign in again to confirm."),
        findsOneWidget,
      );
    });

    testWidgets("Manage Subscription opens the store's subscriptions page", (
      tester,
    ) async {
      final links = LinkRecorder();
      await pumpPage(tester, links: links);
      await tester.tap(find.text('Manage Subscription'));
      await tester.pump();
      expect(links.opened, [
        Uri.parse('https://play.google.com/store/account/subscriptions'),
      ]);
    });

    testWidgets('an anonymous account is not told to sign in again', (
      tester,
    ) async {
      await pumpPage(
        tester,
        user: const AuthUser(uid: 'user-1', isAnonymous: true),
      );
      expect(
        find.text("You'll be asked to sign in again to confirm."),
        findsNothing,
      );
    });

    testWidgets('deleting removes the profile and announces it', (
      tester,
    ) async {
      when(
        () => auth.deleteAccount(beforeDelete: any(named: 'beforeDelete')),
      ).thenAnswer((invocation) async {
        final beforeDelete =
            invocation.namedArguments[#beforeDelete] as Future<void> Function();
        await beforeDelete();
      });
      await pumpPage(tester);
      await tester.tap(find.widgetWithText(AppListRowButton, 'Delete Account'));
      await tester.pump();
      await tester.pump();

      verify(() => users.deleteUser('user-1')).called(1);
      expect(find.textContaining('Account Deleted'), findsOneWidget);
    });

    testWidgets('a failed deletion says so', (tester) async {
      when(() => auth.deleteAccount(beforeDelete: any(named: 'beforeDelete')))
          .thenThrow(const AuthFailure('network'));
      await pumpPage(tester);
      await tester.tap(find.widgetWithText(AppListRowButton, 'Delete Account'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Delete Account'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Delete Account'), findsNothing);
    });

    testWidgets('shows a spinner while deleting, with no way back', (
      tester,
    ) async {
      when(() => auth.deleteAccount(beforeDelete: any(named: 'beforeDelete')))
          .thenAnswer((_) => Future.delayed(const Duration(seconds: 1)));
      await pumpPage(tester);
      await tester.tap(find.widgetWithText(AppListRowButton, 'Delete Account'));
      await tester.pump();
      expect(find.byType(AppSpinner), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('shows nothing once signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const DeleteAccountPage(), appBloc: appBloc);
      expect(find.text('Delete Account'), findsNothing);
    });
  });
}
