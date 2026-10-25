import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// A stand-in for a ring from compound_charts, which app_ui can't use.
const _ring = SizedBox.square(
  dimension: 72,
  child: CircularProgressIndicator(value: 0.75, strokeWidth: 10),
);

/// [child] under Increase Contrast in light mode, as MaterialApp gives it.
Widget _highContrast(Widget child) => Builder(
  builder: (context) => Theme.of(context).brightness == Brightness.dark
      ? child
      : MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: true),
          child: Theme(data: AppTheme.lightHighContrast, child: child),
        ),
);

/// The card's own semantics node, inside its [AppCard].
final Finder _card = find
    .descendant(
      of: find.byType(AppSummaryCard),
      matching: find.byType(Semantics),
    )
    .first;

void main() {
  group('AppSummaryCard', () {
    testWidgets('reads as one element: title, value unit, delta, footer', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppSummaryCard(
          title: 'Protein',
          icon: AppSymbols.protein,
          value: '104 / 165',
          unit: 'g',
          delta: AppChip(label: '12 this week'),
          footer: '61 g to go',
        ),
      );
      expect(
        tester.getSemantics(_card),
        matchesSemantics(
          label: 'Protein',
          value: '104 / 165 g, 12 this week, 61 g to go',
        ),
      );
      expect(find.text('PROTEIN'), findsOneWidget);
      expect(find.byIcon(AppSymbols.disclosure), findsNothing);
    });

    testWidgets('reads its semantic value when the hero is a chart', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppSummaryCard(
          title: 'Rings',
          chart: _ring,
          semanticValue: '75%',
        ),
      );
      expect(
        tester.getSemantics(_card),
        matchesSemantics(label: 'Rings', value: '75%'),
      );
    });

    testWidgets('as a button: one tap target, a haptic and a chevron', (
      tester,
    ) async {
      final haptics = <AppHaptic>[];
      AppHaptics.debugPlay = haptics.add;
      addTearDown(() => AppHaptics.debugPlay = null);
      var taps = 0;
      await tester.pumpApp(
        AppSummaryCard(title: 'Steps', value: '8,000', onTap: () => taps++),
      );
      expect(find.byIcon(AppSymbols.disclosure), findsOneWidget);
      expect(
        tester.getSemantics(_card),
        matchesSemantics(
          label: 'Steps',
          value: '8,000',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.text('8,000'));
      expect(taps, 1);
      expect(haptics, [AppHaptic.light]);
    });

    testWidgets('keeps a trailing button reachable', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        AppSummaryCard(
          title: 'Streak',
          value: '6',
          trailing: AppChip(label: 'Info', onPressed: () => taps++),
        ),
      );
      await tester.tap(find.text('Info'));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Info')),
        isSemantics(label: 'Info', isButton: true, hasTapAction: true),
      );
    });

    testWidgets('draws a prominent value in the display style', (tester) async {
      await tester.pumpApp(
        const Column(
          children: [
            AppSummaryCard(title: 'Day', value: '3/4', prominent: true),
            AppSummaryCard(title: 'Week', value: '12'),
          ],
        ),
      );
      TextStyle? style(String text) => tester
          .widget<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text && widget.textSpan?.toPlainText() == text,
            ),
          )
          .textSpan
          ?.style;
      expect(style('3/4'), AppTextStyles.display);
      expect(style('12'), AppTextStyles.metricLarge);
    });

    testWidgets('puts a chart beside the number, under it at large text', (
      tester,
    ) async {
      const card = AppSummaryCard(
        title: 'Day',
        value: '3/4',
        chart: _ring,
        chartBeside: true,
      );
      await tester.pumpApp(card);
      final number = tester.getCenter(find.text('3/4', findRichText: true));
      final ring = tester.getCenter(find.byType(CircularProgressIndicator));
      expect(ring.dx, greaterThan(number.dx));

      await tester.pumpApp(card, textScale: 2);
      final big = tester.getRect(find.text('3/4', findRichText: true));
      final under = tester.getRect(find.byType(CircularProgressIndicator));
      expect(under.top, greaterThanOrEqualTo(big.bottom));
    });

    testWidgets('puts a chart under the number by default', (tester) async {
      await tester.pumpApp(
        const AppSummaryCard(title: 'Day', value: '3/4', chart: _ring),
      );
      final number = tester.getRect(find.text('3/4', findRichText: true));
      final ring = tester.getRect(find.byType(CircularProgressIndicator));
      expect(ring.top, greaterThanOrEqualTo(number.bottom));
    });

    testWidgets('can show only a header', (tester) async {
      await tester.pumpApp(const AppSummaryCard(title: 'Empty'));
      expect(tester.getSemantics(_card), matchesSemantics(label: 'Empty'));
    });
  });

  group('AppChip under Increase Contrast', () {
    testWidgets('outlines a volt fill in light mode', (tester) async {
      await tester.pumpApp(
        _highContrast(const AppChip(label: 'Done', selected: true)),
      );
      final shape =
          (tester
                      .widget<DecoratedBox>(find.byType(DecoratedBox).last)
                      .decoration
                  as ShapeDecoration)
              .shape;
      expect(
        (shape as StadiumBorder).side.color,
        AppTheme.light.colorScheme.onPrimary,
      );
    });
  });

  group('AppSummaryCard golden', () {
    goldenStates('app_summary_card', [
      (
        'Number, unit, goal met, footer, button',
        Builder(
          builder: (context) => AppSummaryCard(
            title: 'Protein',
            icon: AppSymbols.protein,
            tint: context.appColors.protein,
            value: '165 / 165',
            unit: 'g',
            delta: const AppChip(
              label: 'Goal Met',
              icon: AppSymbols.success,
              selected: true,
            ),
            footer: 'Hit 5 days in a row',
            onTap: () {},
          ),
        ),
      ),
      (
        'Prominent, ring beside',
        Builder(
          builder: (context) => AppSummaryCard(
            title: 'Your Day',
            icon: AppSymbols.today,
            tint: context.appColors.accentInk,
            value: '3/4',
            unit: 'done',
            chart: _ring,
            chartBeside: true,
            prominent: true,
            footer: 'Next: Steps',
          ),
        ),
      ),
      (
        'Chart under, info trailing',
        Builder(
          builder: (context) => AppSummaryCard(
            title: 'Steps',
            icon: AppSymbols.steps,
            tint: context.appColors.steps,
            value: '6,240',
            unit: 'steps',
            delta: const AppChip(label: '+1,200', icon: AppSymbols.increase),
            chart: LinearProgressIndicator(
              value: 0.78,
              color: context.appColors.steps,
            ),
            trailing: AppIconButton(
              icon: AppSymbols.info,
              semanticLabel: 'About',
              onPressed: () {},
            ),
          ),
        ),
      ),
      (
        'Chart only',
        const AppSummaryCard(
          title: 'Rings',
          chart: _ring,
          semanticValue: '75%',
        ),
      ),
      (
        'Goal met, high contrast',
        _highContrast(
          const AppSummaryCard(
            title: 'Weekly Streak',
            icon: AppSymbols.streak,
            value: '6',
            unit: 'weeks',
            delta: AppChip(
              label: 'Goal Met',
              icon: AppSymbols.success,
              selected: true,
            ),
          ),
        ),
      ),
    ]);
  });
}
