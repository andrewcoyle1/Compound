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

    testWidgets('reads a chart under a number after the number', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppSummaryCard(
          title: 'Steps',
          value: '6,240',
          chart: _ring,
          semanticValue: 'Up from 5,100',
          footer: 'Today',
        ),
      );
      expect(
        tester.getSemantics(_card),
        matchesSemantics(label: 'Steps', value: '6,240, Up from 5,100, Today'),
      );
    });

    testWidgets("reads a chart's own figures after the number", (tester) async {
      await tester.pumpApp(
        const AppSummaryCard(
          title: 'Calories',
          value: '1,367',
          unit: 'of 2,250 kcal',
          chart: _ring,
          semanticValue: 'Protein, 104 of 165 g',
        ),
      );
      expect(
        tester.getSemantics(_card),
        matchesSemantics(
          label: 'Calories',
          value: '1,367 of 2,250 kcal, Protein, 104 of 165 g',
        ),
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

    testWidgets('moves a trailing chip under the title at large text', (
      tester,
    ) async {
      final card = AppSummaryCard(
        title: 'Weekly Check-In Ready',
        footer: 'Review the week and update your nutrition targets.',
        trailing: AppChip(label: 'Skip This Week', onPressed: () {}),
        onTap: () {},
      );
      await tester.pumpApp(card);
      expect(
        tester.getCenter(find.text('Skip This Week')).dy,
        moreOrLessEquals(
          tester.getCenter(find.text('WEEKLY CHECK-IN READY')).dy,
          epsilon: 1,
        ),
      );

      await tester.pumpApp(card, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('Skip This Week')).dy,
        greaterThan(
          tester.getBottomLeft(find.text('WEEKLY CHECK-IN READY')).dy,
        ),
      );
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

    testWidgets('sizes the value, the unit after or under it', (tester) async {
      await tester.pumpApp(
        const Column(
          children: [
            AppSummaryCard(
              title: 'Day',
              value: '3/4',
              unit: 'done',
              size: AppSummaryCardSize.hero,
            ),
            AppSummaryCard(
              title: 'Streak',
              value: '6',
              unit: 'weeks',
              size: AppSummaryCardSize.large,
            ),
            AppSummaryCard(title: 'Week', value: '12', unit: 'sets'),
          ],
        ),
      );
      expect(tester.widget<Text>(find.text('3/4')).style, AppTextStyles.hero);
      expect(tester.widget<Text>(find.text('6')).style, AppTextStyles.display);
      expect(
        tester.getTopLeft(find.text('DONE')).dy,
        greaterThan(tester.getBottomLeft(find.text('3/4')).dy - 1),
      );
      final regular = find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.textSpan?.toPlainText() == '12 SETS',
      );
      expect(
        tester.widget<Text>(regular).textSpan?.style,
        AppTextStyles.metricLarge,
      );
    });

    testWidgets('a hero number stops growing at 150%', (tester) async {
      await tester.pumpApp(
        const AppSummaryCard(
          title: 'Day',
          value: '3/4',
          size: AppSummaryCardSize.hero,
        ),
        textScale: 2,
      );
      final scaler = MediaQuery.textScalerOf(tester.element(find.text('3/4')));
      expect(scaler.scale(10), 15);
    });

    testWidgets('holds the rows it sums up, each its own element', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpApp(
        AppSummaryCard(
          title: 'Your Day',
          value: '1/2',
          rows: [
            AppListRowButton(
              title: 'Train',
              icon: AppSymbols.workout,
              onPressed: () => taps++,
            ),
            AppListRowButton(title: 'Steps', onPressed: () {}),
          ],
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
      await tester.tap(find.text('Train'));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(AppListRowButton).first),
        isSemantics(label: 'Train', isButton: true),
      );
      expect(
        tester.getSemantics(_card),
        matchesSemantics(label: 'Your Day', value: '1/2'),
      );
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

    testWidgets('puts its actions under the summary, each its own button', (
      tester,
    ) async {
      var opened = 0;
      var started = 0;
      await tester.pumpApp(
        AppSummaryCard(
          title: "Today's Workout",
          value: 'Push Day A',
          onTap: () => opened++,
          actions: AppCtaButton(
            label: 'Start Workout',
            size: AppCtaSize.compact,
            onPressed: () => started++,
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.text('Start Workout')).dy,
        greaterThan(tester.getBottomLeft(find.text('Push Day A')).dy),
      );
      await tester.tap(find.text('Start Workout'));
      expect((opened, started), (0, 1));
      await tester.tap(find.text('Push Day A'));
      expect((opened, started), (1, 1));
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
        'Hero, ring beside',
        Builder(
          builder: (context) => AppSummaryCard(
            title: 'Your Day',
            icon: AppSymbols.today,
            tint: context.appColors.accentInk,
            value: '3/4',
            unit: 'done',
            chart: _ring,
            chartBeside: true,
            size: AppSummaryCardSize.hero,
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
        'Rows',
        AppSummaryCard(
          title: 'Your Day',
          icon: AppSymbols.today,
          value: '1/2',
          unit: 'done',
          size: AppSummaryCardSize.hero,
          rows: [
            AppListRowButton(
              title: 'Train',
              subtitle: 'Push Day A',
              icon: AppSymbols.workout,
              onPressed: () {},
            ),
            AppListRowButton(
              title: 'Steps',
              icon: AppSymbols.steps,
              onPressed: () {},
            ),
          ],
        ),
      ),
      (
        'Chip trailing, button, no hero',
        AppSummaryCard(
          title: 'Weekly Check-In Ready',
          icon: AppSymbols.goal,
          footer: 'Review the week and update your nutrition targets.',
          trailing: AppChip(label: 'Skip This Week', onPressed: () {}),
          onTap: () {},
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
        'Large, goal met, high contrast',
        _highContrast(
          const AppSummaryCard(
            title: 'Weekly Streak',
            icon: AppSymbols.streak,
            size: AppSummaryCardSize.large,
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

  group('AppSummaryCard actions golden', () {
    goldenStates('app_summary_card_actions', [
      (
        'Button with actions',
        Builder(
          builder: (context) => AppSummaryCard(
            title: "Today's Workout",
            icon: AppSymbols.workout,
            tint: context.appColors.workouts,
            value: 'Push Day A',
            unit: 'Week 1 of 8 · Day 1',
            size: AppSummaryCardSize.large,
            footer: 'Bench Press · 80 kg × 8',
            onTap: () {},
            actions: Row(
              spacing: AppSpacing.m,
              children: [
                Expanded(
                  child: AppCtaButton(
                    label: 'Start Workout',
                    size: AppCtaSize.compact,
                    onPressed: () {},
                  ),
                ),
                AppTextButton(label: 'Skip', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    ]);
  });
}
