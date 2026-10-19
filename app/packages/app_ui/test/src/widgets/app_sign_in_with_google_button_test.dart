import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppSignInWithGoogleButton', () {
    Material material(WidgetTester tester, Type button) =>
        tester.widget<Material>(
          find.descendant(
            of: find.byType(button),
            matching: find.byType(Material),
          ),
        );

    TextStyle title(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style!;

    testWidgets("uses Google's light theme and calls back when tapped", (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpApp(
        AppSignInWithGoogleButton(
          label: 'Continue with Google',
          onPressed: () => taps++,
        ),
      );
      final button = material(tester, AppSignInWithGoogleButton);
      expect(button.color, Colors.white);
      expect(
        button.shape,
        const StadiumBorder(side: BorderSide(color: Color(0xFF747775))),
      );
      expect(
        title(tester, 'Continue with Google').color,
        const Color(0xFF1F1F1F),
      );
      expect(find.bySemanticsLabel('Continue with Google'), findsOneWidget);
      await tester.tap(find.byType(AppSignInWithGoogleButton));
      expect(taps, 1);
    });

    testWidgets("uses Google's dark theme in dark mode", (tester) async {
      await tester.pumpApp(
        AppSignInWithGoogleButton(
          label: 'Continue with Google',
          onPressed: () {},
        ),
      );
      await tester.pumpApp(
        AppSignInWithGoogleButton(
          label: 'Continue with Google',
          onPressed: () {},
        ),
        theme: AppTheme.dark,
      );
      await tester.pumpAndSettle();
      final button = material(tester, AppSignInWithGoogleButton);
      expect(button.color, AppSignInWithGoogleButton.darkFill);
      expect(
        button.shape,
        const StadiumBorder(side: BorderSide(color: Color(0xFF8E918F))),
      );
      expect(
        title(tester, 'Continue with Google').color,
        const Color(0xFFE3E3E3),
      );
    });

    testWidgets('shows a spinner and ignores taps while loading', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpApp(
        AppSignInWithGoogleButton(
          label: 'Continue with Google',
          onPressed: () => taps++,
          isLoading: true,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      await tester.tap(find.byType(AppSignInWithGoogleButton));
      expect(taps, 0);
    });

    for (final (platform, googleHeight) in [
      (TargetPlatform.android, 40.0),
      (TargetPlatform.iOS, 44.0),
    ]) {
      testWidgets('matches the Apple button on ${platform.name}', (
        tester,
      ) async {
        await tester.pumpApp(
          Column(
            children: [
              AppSignInWithAppleButton(
                label: 'Continue with Apple',
                onPressed: () {},
              ),
              AppSignInWithGoogleButton(
                label: 'Continue with Google',
                onPressed: () {},
              ),
            ],
          ),
          theme: AppTheme.light.copyWith(platform: platform),
          textScale: 2,
        );
        final apple = find.byType(AppSignInWithAppleButton);
        final google = find.byType(AppSignInWithGoogleButton);
        expect(tester.getSize(google), tester.getSize(apple));
        expect(tester.getSize(google).height, 56);
        expect(
          material(tester, AppSignInWithGoogleButton).shape,
          isA<StadiumBorder>(),
        );
        expect(
          material(tester, AppSignInWithAppleButton).shape,
          isA<StadiumBorder>(),
        );
        final appleTitle = title(tester, 'Continue with Apple');
        final googleTitle = title(tester, 'Continue with Google');
        expect(googleTitle.fontSize, appleTitle.fontSize);
        expect(googleTitle.fontWeight, appleTitle.fontWeight);
        expect(
          tester.widget<Text>(find.text('Continue with Google')).textScaler,
          TextScaler.noScaling,
        );
        // Google's 20-point logo, scaled with the button from Google's
        // own height for the platform.
        final logo = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              '${widget.painter.runtimeType}' == '_GoogleLogoPainter',
        );
        expect(tester.getSize(logo), Size.square(20 * 56 / googleHeight));
      });
    }
  });

  group('AppSignInWithGoogleButton golden', () {
    final button = AppSignInWithGoogleButton(
      label: 'Sign in with Google',
      onPressed: () {},
    );
    goldenStates('app_sign_in_with_google_button', [
      ('Android', button),
      ('iOS', onIos(button)),
      (
        'Loading',
        AppSignInWithGoogleButton(
          label: 'Sign in with Google',
          onPressed: () {},
          isLoading: true,
        ),
      ),
    ], pumpBeforeTest: pumpOnceSettled);
  });
}
