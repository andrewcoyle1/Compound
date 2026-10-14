import 'package:app_ui/app_ui.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound/today/view/day_checklist_card.dart';
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
      expect(find.text('176.4 lb'), findsOneWidget);
      expect(find.textContaining('Step goal'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Weigh In')), findsOneWidget);
    });
  });
}
