import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/home/home.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(App, () {
    testWidgets('signs in, then out, through the router', (tester) async {
      await tester.pumpWidget(App(authRepository: InMemoryAuthRepository()));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);

      await tester.tap(find.text('Continue without an account'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('User ID: in-memory-anonymous'), findsOneWidget);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('starts signed in as the sample user, as staging does, and '
        'signs back in with Google after signing out', (tester) async {
      await tester.pumpWidget(
        App(
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('User ID: mock_user_123'), findsOneWidget);
      expect(find.text('Email: alice@example.com'), findsOneWidget);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('User ID: mock_user_123'), findsOneWidget);
    });
  });
}
