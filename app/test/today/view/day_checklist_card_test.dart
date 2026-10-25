import 'package:app_ui/app_ui.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound/today/view/day_checklist_card.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(DayChecklistCard, () {
    testWidgets('marks a complete day, without the step footer', (
      tester,
    ) async {
      await tester.pumpApp(
        const SingleChildScrollView(
          child: DayChecklistCard(
            checklist: TodayChecklist([
              NutritionItem(calories: 600, proteinGrams: 30, mealsLogged: 1),
              WeighInItem(isToday: true, latestKg: 80),
            ]),
            stepGoal: 8000,
            unit: AppWeightUnit.pounds,
          ),
        ),
      );
      expect(find.text('Day Complete'), findsOneWidget);
      expect(find.text('176.4\u00a0lb'), findsOneWidget);
      expect(find.textContaining('Step goal'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Weigh In')), findsOneWidget);
    });

    testWidgets(
      'as the hero: done out of all, a ring and the items in one card',
      (tester) async {
        await tester.pumpApp(
          const SingleChildScrollView(
            child: DayChecklistCard(
              showsHero: true,
              checklist: TodayChecklist([
                WeighInItem(isToday: true, latestKg: 80),
                TrainingItem(),
                StepsItem(today: 100, goal: 8000),
              ]),
              stepGoal: 8000,
              unit: AppWeightUnit.kilograms,
            ),
          ),
        );
        expect(find.text('YOUR DAY'), findsOneWidget);
        expect(find.text('Your Day'), findsNothing);
        expect(find.text('1/3'), findsOneWidget);
        expect(find.text('DONE'), findsOneWidget);
        // One card: the items sit under the number, not in a section of
        // their own.
        expect(find.byType(AppSection), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AppSummaryCard),
            matching: find.text('Train'),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<ProgressArc>(find.byType(ProgressArc)).value,
          1 / 3,
        );
        expect(find.text('Day Complete'), findsNothing);
      },
    );

    testWidgets('as the hero, complete: the ring closes and the day is '
        'marked in the accent', (tester) async {
      await tester.pumpApp(
        const SingleChildScrollView(
          child: DayChecklistCard(
            showsHero: true,
            checklist: TodayChecklist([
              WeighInItem(isToday: true, latestKg: 80),
            ]),
            stepGoal: 8000,
            unit: AppWeightUnit.kilograms,
          ),
        ),
      );
      expect(tester.widget<ProgressArc>(find.byType(ProgressArc)).value, 1);
      final chip = tester.widget<AppChip>(
        find.widgetWithText(AppChip, 'Day Complete'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('as the hero with nothing to do, the ring is empty', (
      tester,
    ) async {
      await tester.pumpApp(
        const SingleChildScrollView(
          child: DayChecklistCard(
            showsHero: true,
            checklist: TodayChecklist([]),
            stepGoal: 8000,
            unit: AppWeightUnit.kilograms,
          ),
        ),
      );
      expect(tester.widget<ProgressArc>(find.byType(ProgressArc)).value, 0);
    });

    testWidgets('shows the weigh-in slot under the weigh-in until it is '
        'done', (tester) async {
      for (final isToday in [false, true]) {
        await tester.pumpApp(
          SingleChildScrollView(
            child: DayChecklistCard(
              checklist: TodayChecklist([
                const TrainingItem(),
                WeighInItem(isToday: isToday, latestKg: 80),
              ]),
              stepGoal: 8000,
              unit: AppWeightUnit.kilograms,
              weighIn: const Text('Quick weigh-in'),
            ),
          ),
        );
        expect(
          find.text('Quick weigh-in'),
          isToday ? findsNothing : findsOneWidget,
        );
      }
    });

    testWidgets('keeps the footnotes as one footer, each ⓘ opening its '
        'sources', (tester) async {
      await tester.pumpApp(
        const SingleChildScrollView(
          child: DayChecklistCard(
            checklist: TodayChecklist([StepsItem(today: 100, goal: 8000)]),
            stepGoal: 8000,
            unit: AppWeightUnit.kilograms,
          ),
        ),
      );
      final footer = find.textContaining('Step goal: 8,000 a day.');
      expect(footer, findsOneWidget);
      expect(
        find.textContaining('Calories count as on target'),
        findsOneWidget,
      );
      // Both lines are one paragraph, set close.
      expect(tester.getSize(footer).height, lessThan(AppControlSize.row));
      final text = tester
          .widget<Text>(footer)
          .textSpan!
          .toPlainText(includeSemanticsLabels: false);
      final glyph = String.fromCharCode(AppSymbols.info.codePoint);
      expect(glyph.allMatches(text), hasLength(2));
      final links = <TapGestureRecognizer>[];
      tester.widget<Text>(footer).textSpan!.visitChildren((span) {
        if (span case TextSpan(recognizer: final TapGestureRecognizer tap)) {
          links.add(tap);
        }
        return true;
      });
      expect(links, hasLength(2));
      links.last.onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(MethodInfoSheet), findsOneWidget);
    });

    testWidgets('at 200% text an open item keeps its circle centred at the '
        'trailing edge, and the count stays on one line', (tester) async {
      await tester.pumpApp(
        const SingleChildScrollView(
          child: DayChecklistCard(
            checklist: TodayChecklist([
              TrainingItem(),
              WeighInItem(isToday: true, latestKg: 80),
            ]),
            stepGoal: 8000,
            unit: AppWeightUnit.kilograms,
          ),
        ),
        textScale: 2,
      );
      final circle = find.byIcon(AppSymbols.choiceUnselected);
      final row = find.ancestor(of: circle, matching: find.byType(AppListRow));
      final title = find.descendant(of: row, matching: find.byType(Text));
      expect(
        tester.getTopLeft(circle).dx,
        greaterThan(tester.getTopRight(title.first).dx),
      );
      expect(tester.getCenter(circle).dy, tester.getCenter(row).dy);
      // The count's words are held together by no-break spaces.
      expect(find.text('1\u00a0of\u00a02 done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
