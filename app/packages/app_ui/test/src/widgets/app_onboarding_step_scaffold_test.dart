import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void _goldenTap() {}

void main() {
  group('AppOnboardingStepScaffold', () {
    testWidgets('lays out title, progress, content and buttons', (
      tester,
    ) async {
      var primary = 0;
      var secondary = 0;
      await tester.pumpApp(
        AppOnboardingStepScaffold(
          title: 'About You',
          subtitle: 'Select your gender',
          progress: 0.4,
          progressLabel: 'Onboarding progress',
          primaryLabel: 'Continue',
          onPrimaryPressed: () => primary++,
          secondaryLabel: 'Skip for now',
          onSecondaryPressed: () => secondary++,
          actions: const [Icon(AppSymbols.info)],
          children: const [
            AppSection(children: [AppListRow(title: 'Female')]),
          ],
        ),
        scaffold: false,
      );
      expect(find.text('About You'), findsWidgets);
      expect(find.text('Select your gender'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.byIcon(AppSymbols.info), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.4,
      );
      expect(find.bySemanticsLabel('Onboarding progress'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.tap(find.text('Skip for now'));
      expect((primary, secondary), (1, 1));
    });

    testWidgets('draws its title large, then in the bar once scrolled', (
      tester,
    ) async {
      await tester.pumpApp(
        AppOnboardingStepScaffold(
          title: 'About You',
          primaryLabel: 'Continue',
          onPrimaryPressed: null,
          children: [for (var i = 0; i < 30; i++) Text('Option $i')],
        ),
        scaffold: false,
      );
      final large = find.descendant(
        of: find.byType(NestedScrollView),
        matching: find.text('About You'),
      );
      expect(
        tester.widget<Text>(large).style?.fontSize,
        AppTextStyles.display.fontSize,
      );
      double barTitleOpacity() => tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      expect(barTitleOpacity(), 0);
      await tester.drag(find.text('Option 5'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(barTitleOpacity(), 1);
    });

    testWidgets('keeps its button above the keyboard', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpApp(
        const AppOnboardingStepScaffold(
          title: 'Name',
          primaryLabel: 'Continue',
          onPrimaryPressed: null,
        ),
        scaffold: false,
      );
      final bottom = tester.getBottomLeft(find.byType(AppCtaButton)).dy;
      final screen =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        bottom,
        lessThanOrEqualTo(screen - 900 / tester.view.devicePixelRatio),
      );
    });

    testWidgets('shows a back button when given onBack', (tester) async {
      var back = 0;
      await tester.pumpApp(
        AppOnboardingStepScaffold(
          title: 'Height',
          primaryLabel: 'Continue',
          onPrimaryPressed: null,
          onBack: () => back++,
        ),
        scaffold: false,
      );
      await tester.tap(find.byType(BackButton));
      expect(back, 1);
    });

    testWidgets('without extras shows only the primary button', (tester) async {
      await tester.pumpApp(
        const AppOnboardingStepScaffold(
          title: 'Welcome',
          primaryLabel: 'Get started',
          onPrimaryPressed: null,
          isPrimaryLoading: true,
          loadingLabel: 'Loading',
        ),
        scaffold: false,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(AppCtaButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AppOnboardingStepScaffold golden', () {
    const options = AppSection(
      children: [
        AppSelectableRow(
          title: 'Lose fat',
          selected: true,
          onPressed: _goldenTap,
        ),
        AppSelectableRow(
          title: 'Build muscle',
          selected: false,
          onPressed: _goldenTap,
        ),
      ],
    );
    goldenStates(
      'app_onboarding_step_scaffold',
      [
        (
          'A step',
          const AppOnboardingStepScaffold(
            title: 'Your goal',
            subtitle: 'You can change it later in Settings.',
            progress: 0.4,
            progressLabel: 'Step 2 of 5',
            primaryLabel: 'Continue',
            onPrimaryPressed: _goldenTap,
            secondaryLabel: 'Skip',
            onSecondaryPressed: _goldenTap,
            onBack: _goldenTap,
            children: [options],
          ),
        ),
        (
          'Saving',
          const AppOnboardingStepScaffold(
            title: 'Your goal',
            progress: 0.4,
            primaryLabel: 'Continue',
            onPrimaryPressed: _goldenTap,
            isPrimaryLoading: true,
            children: [options],
          ),
        ),
      ],
      width: 375,
      height: 640,
      padded: false,
      pumpBeforeTest: pumpOnceSettled,
    );
  });
}
