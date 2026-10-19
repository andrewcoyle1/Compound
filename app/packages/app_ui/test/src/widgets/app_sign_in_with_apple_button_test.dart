import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppSignInWithAppleButton', () {
    Color fill(WidgetTester tester) => tester
        .widget<Material>(
          find.descendant(
            of: find.byType(AppSignInWithAppleButton),
            matching: find.byType(Material),
          ),
        )
        .color!;

    testWidgets('is black in light mode and calls back when tapped', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpApp(
        AppSignInWithAppleButton(
          label: 'Continue with Apple',
          onPressed: () => taps++,
        ),
      );
      expect(fill(tester), Colors.black);
      expect(
        tester.getSize(find.byType(AppSignInWithAppleButton)).height,
        AppSignInWithAppleButton.height,
      );
      expect(find.bySemanticsLabel('Continue with Apple'), findsOneWidget);
      await tester.tap(find.byType(AppSignInWithAppleButton));
      expect(taps, 1);
    });

    testWidgets('turns white in dark mode', (tester) async {
      await tester.pumpApp(
        AppSignInWithAppleButton(
          label: 'Continue with Apple',
          onPressed: () {},
        ),
      );
      await tester.pumpApp(
        AppSignInWithAppleButton(
          label: 'Continue with Apple',
          onPressed: () {},
        ),
        theme: AppTheme.dark,
      );
      await tester.pumpAndSettle();
      expect(fill(tester), Colors.white);
    });

    testWidgets('shows a spinner and ignores taps while loading', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpApp(
        AppSignInWithAppleButton(
          label: 'Continue with Apple',
          onPressed: () => taps++,
          isLoading: true,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
      await tester.tap(find.byType(AppSignInWithAppleButton));
      expect(taps, 0);
    });
  });

  group('AppSignInWithAppleButton golden', () {
    goldenStates('app_sign_in_with_apple_button', [
      (
        'Enabled',
        AppSignInWithAppleButton(label: 'Sign in with Apple', onPressed: () {}),
      ),
      (
        'Loading',
        AppSignInWithAppleButton(
          label: 'Sign in with Apple',
          onPressed: () {},
          isLoading: true,
        ),
      ),
    ], pumpBeforeTest: pumpOnceSettled);
  });
}
