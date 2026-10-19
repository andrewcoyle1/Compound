import 'package:app_ui/app_ui.dart';
import 'package:compound/training_analytics/view/workout_consistency_page.dart'
    show ContributionGrid;
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Swift QuickCharts' `ContributionChart` header, axes and callout.
void main() {
  // Wednesday 14 October 2026; weeks from Monday.
  final today = DateTime(2026, 10, 14);

  Future<void> pump(
    WidgetTester tester, {
    bool counted = true,
    bool graded = false,
    double textScale = 1,
  }) => tester.pumpApp(
    Scaffold(
      body: ContributionGrid(
        dates: [
          DateTime(2026, 10, 14, 7),
          DateTime(2026, 10, 14, 18),
          DateTime(2026, 10, 12, 9),
          DateTime(2026, 9, 1, 9),
        ],
        today: today,
        firstWeekday: DateTime.monday,
        color: const Color(0xFF34C759),
        semanticsLabel: '4 workouts',
        countText: counted
            ? (count) => count == 1 ? '1 workout' : '$count workouts'
            : null,
        graded: graded,
      ),
    ),
    textScale: textScale,
  );

  /// The centre of [day]'s square, in the week before last's column when
  /// [weeksBack] says.
  Offset cell(WidgetTester tester, {required int row, int weeksBack = 0}) {
    final grid = tester.getRect(
      find
          .descendant(
            of: find.byType(ContributionGrid),
            matching: find.byType(GestureDetector),
          )
          .last,
    );
    // The month row is a label's line and a small gap; the squares
    // stretch a little so whole weeks fill the width.
    const monthRow = 16 + AppSpacing.xs;
    final stretch =
        (grid.height - monthRow) /
        (7 * AppChartMark.heatCell + 6 * AppChartMark.heatGap);
    const step = AppChartMark.heatCell + AppChartMark.heatGap;
    return Offset(
      grid.right - (AppChartMark.heatCell / 2 + weeksBack * step) * stretch,
      grid.top + monthRow + (row * step + AppChartMark.heatCell / 2) * stretch,
    );
  }

  testWidgets('counts the days logged and names the weekdays', (tester) async {
    await pump(tester);
    expect(find.textContaining('of '), findsOneWidget);
    expect(find.textContaining('Days Logged, '), findsOneWidget);
    expect(find.textContaining('Oct 14, 2026'), findsOneWidget);
    // Monday to Sunday, by initial.
    expect(find.text('M'), findsOneWidget);
    expect(find.text('W'), findsOneWidget);
    expect(find.text('S'), findsNWidgets(2));
    expect(find.bySemanticsLabel('4 workouts'), findsOneWidget);
    // The header covers every week the grid shows, back past the first
    // entry's (31 August, 45 days to today) to fill the width.
    expect(find.textContaining('Days Logged, Aug 31,'), findsNothing);
    final span = RegExp(r'of (\d+) days').firstMatch(
      tester.widget<Text>(find.textContaining('of ')).textSpan!.toPlainText(),
    )!;
    expect(int.parse(span[1]!), greaterThan(45));
    expect(int.parse(span[1]!) % 7, 3);
  });

  testWidgets('holding a day reads out its count and date, then lets go', (
    tester,
  ) async {
    await pump(tester);
    final gesture = await tester.startGesture(cell(tester, row: 2));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('2 workouts'), findsOneWidget);
    expect(find.text('Wed, Oct 14, 2026'), findsOneWidget);
    // Floating over the header, kept inside the grid at its edge.
    await tester.pumpAndSettle();
    final callout = tester.getRect(find.byType(ChartCalloutSummary));
    expect(
      callout.right,
      lessThanOrEqualTo(tester.getRect(find.byType(ContributionGrid)).right),
    );
    expect(callout.bottom, lessThan(cell(tester, row: 0).dy));

    await gesture.moveTo(cell(tester, row: 1));
    await tester.pump();
    expect(find.text('No Data'), findsOneWidget);
    expect(find.text('Tue, Oct 13, 2026'), findsOneWidget);

    await gesture.moveTo(cell(tester, row: 0));
    await tester.pump();
    expect(find.text('1 workout'), findsOneWidget);

    // A day still to come has no square, and no readout.
    await gesture.moveTo(cell(tester, row: 5));
    await tester.pump();
    expect(find.textContaining('Days Logged, '), findsOneWidget);

    await gesture.moveTo(cell(tester, row: 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('1 workout'), findsNothing);
    expect(find.textContaining('Days Logged, '), findsOneWidget);
  });

  testWidgets('without a count text a day reads as logged', (tester) async {
    await pump(tester, counted: false);
    final gesture = await tester.startGesture(cell(tester, row: 2));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('Logged'), findsOneWidget);
    await gesture.up();
  });

  testWidgets('shades workouts by how many, keyed by a legend', (tester) async {
    await pump(tester);
    expect(find.byType(HeatGridLegend), findsNothing);
    expect(tester.widget<HeatGrid>(find.byType(HeatGrid)).levels, 2);

    await pump(tester, graded: true);
    // Two on the busiest day: none, one, and two or more.
    expect(tester.widget<HeatGrid>(find.byType(HeatGrid)).levels, 3);
    expect(
      tester.widget<HeatGridLegend>(find.byType(HeatGridLegend)).levels,
      3,
    );
    expect(find.text('Less'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('reads each week and what it holds', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(
      find.semantics.byLabel('Week of Oct 12, 2026: 3 workouts'),
      findsOne,
    );
    expect(find.semantics.byLabel('Week of Oct 5, 2026: 0 workouts'), findsOne);
    await pump(tester, counted: false);
    expect(
      find.semantics.byLabel('Week of Oct 12, 2026: 2 days logged'),
      findsOne,
    );
    handle.dispose();
  });

  testWidgets('grows the weekdays with the text instead of pinning them', (
    tester,
  ) async {
    await pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    final letter = tester.getSize(find.text('W'));
    expect(letter.height, greaterThanOrEqualTo(2 * 16));
    // Monday's row to Sunday's: six rows, each taller than its initial.
    final monday = tester.getRect(find.text('M')).top;
    final sunday = tester.getRect(find.text('S').last).top;
    expect(sunday - monday, greaterThan(6 * letter.height));
  });
}
