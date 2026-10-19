import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

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
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
}
