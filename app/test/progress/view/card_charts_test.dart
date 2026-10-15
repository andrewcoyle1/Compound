import 'package:app_ui/app_ui.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  final day = DateTime(2026, 10, 15);

  Future<void> pumpChart(WidgetTester tester, Widget chart) => tester.pumpApp(
    Center(child: SizedBox(width: 160, height: 36, child: chart)),
  );

  group(CardChart, () {
    testWidgets('draws a single reading and repaints on new data', (
      tester,
    ) async {
      await pumpChart(
        tester,
        Sparkline(points: [(date: day, value: 72)], color: Colors.purple),
      );
      await pumpChart(
        tester,
        Sparkline(points: [(date: day, value: 73)], color: Colors.purple),
      );
      await pumpChart(
        tester,
        const StackedBars(
          stacks: [
            [1],
          ],
          colors: [Colors.orange],
        ),
      );
      await pumpChart(
        tester,
        const StackedBars(
          stacks: [
            [2],
          ],
          colors: [Colors.orange],
        ),
      );
      await pumpChart(
        tester,
        const ProgressBarChart(
          current: 40,
          maximum: 0,
          target: 50,
          color: Colors.red,
        ),
      );
      await pumpChart(
        tester,
        const ProgressBarChart(
          current: 60,
          maximum: 180,
          target: 150,
          color: Colors.red,
        ),
      );
      await pumpChart(
        tester,
        const HabitGridChart(days: [true, false], color: Colors.pink),
      );
      await pumpChart(
        tester,
        const HabitGridChart(days: [false, true], color: Colors.pink),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('carries its summary', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpChart(
        tester,
        const HabitGridChart(
          days: [true],
          color: Colors.pink,
          semanticsLabel: 'Weigh In',
          semanticsValue: '1 of the last 30 days',
        ),
      );
      expect(
        tester.getSemantics(find.byType(HabitGridChart)),
        matchesSemantics(label: 'Weigh In', value: '1 of the last 30 days'),
      );
      handle.dispose();
    });
  });
}
