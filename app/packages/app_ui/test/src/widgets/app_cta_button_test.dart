import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void _goldenTap() {}

void main() {
  group('AppCtaButton', () {
    testWidgets('primary is a full-width filled button', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        AppCtaButton(label: 'Continue', onPressed: () => taps++),
      );
      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
      expect(tester.getSize(find.byType(FilledButton)).width, 800);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(AppControlSize.cta),
      );
    });

    testWidgets('secondary is a filled button and plain is text', (
      tester,
    ) async {
      await tester.pumpApp(
        Column(
          children: [
            AppCtaButton(
              label: 'Later',
              onPressed: () {},
              variant: AppCtaVariant.secondary,
            ),
            AppCtaButton(
              label: 'Skip for now',
              onPressed: () {},
              variant: AppCtaVariant.plain,
            ),
          ],
        ),
      );
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    for (final variant in AppCtaVariant.values) {
      testWidgets('compact ${variant.name} is as wide as its label, with a '
          '44 pt target', (tester) async {
        var taps = 0;
        await tester.pumpApp(
          Center(
            child: AppCtaButton(
              label: 'Accept',
              onPressed: () => taps++,
              variant: variant,
              size: AppCtaSize.compact,
            ),
          ),
        );
        final size = tester.getSize(find.byType(AppCtaButton));
        expect(size.width, lessThan(400));
        expect(size.height, greaterThanOrEqualTo(AppControlSize.row));
        await tester.tap(find.text('Accept'));
        expect(taps, 1);
      });
    }

    testWidgets('compact grows with large text', (tester) async {
      await tester.pumpApp(
        Center(
          child: AppCtaButton(
            label: 'Accept',
            onPressed: () {},
            size: AppCtaSize.compact,
          ),
        ),
        textScale: 2,
      );
      final fill = find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      );
      expect(tester.getSize(fill).height, greaterThan(AppControlSize.compact));
    });

    for (final variant in AppCtaVariant.values) {
      testWidgets('loading ${variant.name} spins, disables and says so', (
        tester,
      ) async {
        await tester.pumpApp(
          AppCtaButton(
            label: 'Continue',
            onPressed: () {},
            variant: variant,
            isLoading: true,
            loadingLabel: 'Loading',
          ),
        );
        expect(find.byType(AppSpinner), findsOneWidget);
        expect(
          tester
              .widget<ButtonStyleButton>(
                find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester.getSemantics(find.byType(AppCtaButton)),
          isSemantics(label: 'Continue', value: 'Loading'),
        );
      });
    }
  });

  group('AppBottomCta', () {
    testWidgets('stacks its buttons', (tester) async {
      await tester.pumpApp(
        AppBottomCta(
          children: [
            AppCtaButton(label: 'Continue', onPressed: () {}),
            AppCtaButton(
              label: 'Skip',
              onPressed: () {},
              variant: AppCtaVariant.plain,
            ),
          ],
        ),
      );
      expect(
        tester.getTopLeft(find.text('Skip')).dy,
        greaterThan(tester.getBottomLeft(find.text('Continue')).dy),
      );
    });

    testWidgets('takes no room without buttons', (tester) async {
      await tester.pumpApp(const AppBottomCta(children: []));
      expect(tester.getSize(find.byType(AppBottomCta)), Size.zero);
    });
  });

  group('AppCtaButton golden', () {
    goldenStates('app_cta_button', [
      ('Primary', const AppCtaButton(label: 'Continue', onPressed: _goldenTap)),
      (
        'Primary, disabled',
        const AppCtaButton(label: 'Continue', onPressed: null),
      ),
      (
        'Primary, loading',
        const AppCtaButton(
          label: 'Continue',
          onPressed: _goldenTap,
          isLoading: true,
        ),
      ),
      (
        'Long label',
        const AppCtaButton(
          label: 'Restart the macrocycle from week one',
          onPressed: _goldenTap,
        ),
      ),
      (
        'Secondary',
        const AppCtaButton(
          label: 'Add to Library',
          onPressed: _goldenTap,
          variant: AppCtaVariant.secondary,
        ),
      ),
      (
        'Secondary, disabled',
        const AppCtaButton(
          label: 'Add to Library',
          onPressed: null,
          variant: AppCtaVariant.secondary,
        ),
      ),
      (
        'Plain',
        const AppCtaButton(
          label: 'Skip for now',
          onPressed: _goldenTap,
          variant: AppCtaVariant.plain,
        ),
      ),
      (
        'Compact primary and secondary',
        const Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            AppCtaButton(
              label: 'Follow',
              onPressed: _goldenTap,
              size: AppCtaSize.compact,
            ),
            AppCtaButton(
              label: 'Edit Profile',
              onPressed: _goldenTap,
              size: AppCtaSize.compact,
              variant: AppCtaVariant.secondary,
            ),
          ],
        ),
      ),
      (
        'Compact, loading',
        const AppCtaButton(
          label: 'Follow',
          onPressed: _goldenTap,
          size: AppCtaSize.compact,
          isLoading: true,
        ),
      ),
    ], pumpBeforeTest: pumpOnceSettled);
  });

  group('AppBottomCta golden', () {
    goldenStates('app_bottom_cta', [
      (
        'One action',
        const AppBottomCta(
          children: [
            AppCtaButton(label: 'Start Workout', onPressed: _goldenTap),
          ],
        ),
      ),
      (
        'With a plain second action',
        const AppBottomCta(
          children: [
            AppCtaButton(label: 'Continue', onPressed: _goldenTap),
            AppCtaButton(
              label: 'Not now',
              onPressed: _goldenTap,
              variant: AppCtaVariant.plain,
            ),
          ],
        ),
      ),
    ], padded: false);
  });
}
