import 'package:app_ui/app_ui.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound/today/view/day_checklist_card.dart';
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
