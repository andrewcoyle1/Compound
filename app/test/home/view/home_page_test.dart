import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/home/home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  group(HomePage, () {
    late AppBloc appBloc;

    setUp(() {
      appBloc = MockAppBloc();
      when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    testWidgets('shows the uid and email', (tester) async {
      when(() => appBloc.state).thenReturn(
        const AppAuthenticated(
          AuthUser(uid: 'abc', isAnonymous: false, email: 'a@b.com'),
        ),
      );
      await tester.pumpApp(const HomePage(), appBloc: appBloc);
      expect(find.text('User ID: abc'), findsOneWidget);
      expect(find.text('Email: a@b.com'), findsOneWidget);
    });

    testWidgets('shows a dash for an account with no email', (tester) async {
      when(() => appBloc.state).thenReturn(
        const AppAuthenticated(AuthUser(uid: 'abc', isAnonymous: false)),
      );
      await tester.pumpApp(const HomePage(), appBloc: appBloc);
      expect(find.text('Email: –'), findsOneWidget);
    });

    testWidgets('says when the account is anonymous', (tester) async {
      when(() => appBloc.state).thenReturn(
        const AppAuthenticated(AuthUser(uid: 'abc', isAnonymous: true)),
      );
      await tester.pumpApp(const HomePage(), appBloc: appBloc);
      expect(find.text('Signed in without an account'), findsOneWidget);
    });

    testWidgets('signs out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const HomePage(), appBloc: appBloc);
      await tester.tap(find.text('Sign Out'));
      verify(() => appBloc.add(const AppSignOutPressed())).called(1);
    });
  });
}
