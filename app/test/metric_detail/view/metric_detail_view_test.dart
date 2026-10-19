import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/semantics.dart'
    show CustomSemanticsAction, SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/helpers.dart';

void main() {
  final today = DateTime(2026, 10, 15);
  final l10n = lookupAppLocalizations(const Locale('en'));

  MetricPoint at(int daysAgo, double value) =>
      (date: DateTime(2026, 10, 15 - daysAgo, 7), value: value);

  Future<void> pumpDetail(
    WidgetTester tester,
    List<MetricChartSeries> series, {
    MetricRange range = MetricRange.week,
    void Function(MetricRange)? onRangeSelected,
    void Function()? onShowAllData,
    String unit = 'kg',
    Widget? summary,
  }) => tester.pumpApp(
    Scaffold(
      body: MetricDetailView(
        title: 'Weight',
        unit: unit,
        summary: summary,
        series: series,
        range: range,
        today: today,
        onRangeSelected: onRangeSelected ?? (_) {},
        onShowAllData: onShowAllData ?? () {},
      ),
    ),
  );

  setUpAll(() => initializeDateFormatting('en'));

  group('metricDayText', () {
    test('names recent days and dates older ones', () {
      expect(metricDayText(l10n, at(0, 0).date, today, 'en'), 'Today');
      expect(metricDayText(l10n, at(1, 0).date, today, 'en'), 'Yesterday');
      expect(metricDayText(l10n, at(10, 0).date, today, 'en'), 'Oct 5');
      expect(
        metricDayText(l10n, DateTime(2025, 9, 12), today, 'en'),
        'Sep 12, 2025',
      );
    });
  });

  group(MetricDetailView, () {
    final scale = MetricChartSeries(
      label: 'Scale',
      points: [at(2, 73), at(1, 72), at(0, 72.4)],
      color: const Color(0xFF000000),
    );

    testWidgets('lists Latest, Highest, Lowest and Average', (tester) async {
      await pumpDetail(tester, [
        scale,
        MetricChartSeries(
          label: 'Trend',
          points: [at(2, 72.8), at(0, 72.5)],
          color: const Color(0xFF000000),
          isLine: true,
        ),
      ]);
      expect(find.text('Latest: Today'), findsOneWidget);
      expect(find.text('72.4 kg'), findsWidgets);
      // The rest are in Show More's sheet.
      expect(find.text('Highest: Oct 13'), findsNothing);
      await reveal(tester, find.text('Show More Weight Data'));
      await tester.tap(find.text('Show More Weight Data'));
      await tester.pumpAndSettle();
      expect(find.text('Highest: Oct 13'), findsOneWidget);
      expect(find.text('Lowest: Yesterday'), findsOneWidget);
      expect(find.text('Average'), findsOneWidget);
      // Readings as dots, the trend as a line, on a close-fitting axis.
      final data = tester
          .widget<CartesianChart>(find.byType(CartesianChart))
          .data;
      expect(data.series.map((s) => s.mark), [ChartMark.dot, ChartMark.line]);
      expect(data.yFit, ChartYFit.tight);
      // Each series in the header, the readings first.
      expect(find.text('Trend'), findsOneWidget);
    });

    testWidgets('hides Highest and Lowest for a flat metric', (tester) async {
      await pumpDetail(tester, [
        scale.withPoints([at(1, 72), at(0, 72)]),
      ]);
      expect(find.textContaining('Highest'), findsNothing);
      expect(find.textContaining('Lowest'), findsNothing);
    });

    testWidgets('says so when the range holds nothing', (tester) async {
      await pumpDetail(tester, [
        scale.withPoints([at(20, 72)]),
      ]);
      expect(find.text('No data in this range'), findsOneWidget);
      expect(find.byType(CartesianChart), findsNothing);
    });

    testWidgets('reports the range picked and the tap on all data', (
      tester,
    ) async {
      MetricRange? picked;
      var opened = false;
      await pumpDetail(
        tester,
        [scale],
        onRangeSelected: (range) => picked = range,
        onShowAllData: () => opened = true,
      );
      await tester.tap(find.text('6M'));
      expect(picked, MetricRange.sixMonths);
      await reveal(tester, find.text('Show All Data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show All Data'));
      expect(opened, isTrue);
    });

    testWidgets('a bar total reads in whole numbers and daily averages', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        [
          MetricChartSeries(
            label: 'Sets',
            points: [at(1, 4), at(0, 3), at(0, 2.5)],
            color: const Color(0xFF000000),
            isBar: true,
          ),
        ],
        unit: '',
        summary: const Text('Summary'),
      );
      expect(find.textContaining('Daily Average, '), findsOneWidget);
      // 5.5 sets today, rounded.
      expect(find.text('6'), findsWidgets);
      // Bars stand on zero.
      final data = tester
          .widget<CartesianChart>(find.byType(CartesianChart))
          .data;
      expect(data.series.single.mark, ChartMark.bar);
      expect(data.series.single.points.last, (x: today, y: 5.5));
      expect(data.yFit, ChartYFit.zero);
      await reveal(tester, find.text('Summary'));
      expect(find.text('Summary'), findsOneWidget);
      await tester.tap(find.text('Show More Weight Data'));
      await tester.pumpAndSettle();
      expect(find.text('Daily Average'), findsOneWidget);
    });

    testWidgets('draws a lone reading on a line', (tester) async {
      await pumpDetail(tester, [
        MetricChartSeries(
          label: '1RM',
          points: [at(0, 100)],
          color: const Color(0xFF000000),
          isLine: true,
        ),
      ]);
      expect(find.byType(CartesianChart), findsOneWidget);
    });

    testWidgets('draws every range', (tester) async {
      for (final range in MetricRange.values) {
        await pumpDetail(tester, [scale], range: range);
        expect(find.byType(CartesianChart), findsOneWidget, reason: range.name);
      }
    });

    // Swift QuickCharts' scrolling: a week back at a time, as #98's rolling
    // windows page.
    testWidgets('swipes back a window and forward again', (tester) async {
      final weeks = MetricChartSeries(
        label: 'Scale',
        points: [at(16, 80), at(9, 79), at(2, 78)],
        color: const Color(0xFF000000),
      );
      await pumpDetail(tester, [weeks]);
      expect(find.text('Average, Oct 9, 2026 – Oct 15, 2026'), findsOneWidget);
      expect(find.text('78 kg'), findsWidgets);

      await tester.fling(
        find.byType(CartesianChart),
        const Offset(300, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(find.text('Average, Oct 2, 2026 – Oct 8, 2026'), findsOneWidget);
      expect(find.text('79 kg'), findsWidgets);

      await tester.fling(
        find.byType(CartesianChart),
        const Offset(300, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(find.text('Average, Sep 25, 2026 – Oct 1, 2026'), findsOneWidget);

      // Nothing older: it stays.
      await tester.fling(
        find.byType(CartesianChart),
        const Offset(300, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(find.text('Average, Sep 25, 2026 – Oct 1, 2026'), findsOneWidget);

      await tester.fling(
        find.byType(CartesianChart),
        const Offset(-300, 0),
        800,
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(CartesianChart),
        const Offset(-300, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(find.text('Average, Oct 9, 2026 – Oct 15, 2026'), findsOneWidget);

      // Nothing newer than today.
      await tester.fling(
        find.byType(CartesianChart),
        const Offset(-300, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(find.text('Average, Oct 9, 2026 – Oct 15, 2026'), findsOneWidget);

      // A new range starts again at today.
      await tester.fling(
        find.byType(CartesianChart),
        const Offset(300, 0),
        800,
      );
      await tester.pumpAndSettle();
      await pumpDetail(tester, [weeks], range: MetricRange.month);
      expect(find.text('Average, Sep 16, 2026 – Oct 15, 2026'), findsOneWidget);
    });

    void perform(WidgetTester tester, Finder finder, String label) {
      final node = tester.getSemantics(finder);
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(
          CustomSemanticsAction(label: label),
        ),
      );
    }

    testWidgets('screen readers page with actions', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpDetail(tester, [
        MetricChartSeries(
          label: 'Scale',
          points: [at(9, 79), at(2, 78)],
          color: const Color(0xFF000000),
        ),
      ]);
      final chart = find.bySemanticsLabel(RegExp('^Weight chart, '));
      expect(
        tester.getSemantics(chart).getSemanticsData().customSemanticsActionIds,
        hasLength(1),
      );
      perform(tester, chart, 'Previous period');
      await tester.pumpAndSettle();
      expect(find.text('Average, Oct 2, 2026 – Oct 8, 2026'), findsOneWidget);
      perform(tester, chart, 'Next period');
      await tester.pumpAndSettle();
      expect(find.text('Average, Oct 9, 2026 – Oct 15, 2026'), findsOneWidget);
      handle.dispose();
    });

    // Swift QuickCharts' `chartXSelection`.
    testWidgets('holding the chart reads out the bucket under it', (
      tester,
    ) async {
      await pumpDetail(tester, [
        MetricChartSeries(
          label: 'Scale',
          points: [at(6, 80), at(0, 78)],
          color: const Color(0xFF000000),
        ),
      ]);
      final chart = tester.getRect(find.byType(CartesianChart));
      final gesture = await tester.startGesture(
        chart.centerLeft + const Offset(4, 0),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      // In a callout above the plot, kept inside the chart at its edge,
      // with the header hidden beneath it.
      final callout = find.byType(ChartCalloutSummary);
      expect(
        find.descendant(of: callout, matching: find.text('Fri, Oct 9')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: callout, matching: find.text('Scale')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: callout, matching: find.text('80 kg')),
        findsOneWidget,
      );
      final rect = tester.getRect(callout);
      expect(rect.left, greaterThanOrEqualTo(chart.left));
      expect(rect.bottom, lessThan(chart.top));
      final header = find.ancestor(
        of: find.textContaining('Average, '),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(header.first).opacity, 0);

      await gesture.moveTo(chart.centerRight - const Offset(60, 0));
      await tester.pump();
      expect(find.text('Thu, Oct 15'), findsOneWidget);
      expect(tester.getRect(callout).right, lessThanOrEqualTo(chart.right));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(header.first).opacity, 1);
      expect(find.text('Thu, Oct 15'), findsNothing);
    });

    testWidgets('bars that are not totals average like readings', (
      tester,
    ) async {
      await pumpDetail(tester, [
        MetricChartSeries(
          label: 'Intake',
          points: [at(1, 2000), at(0, 2500)],
          color: const Color(0xFF000000),
          isBar: true,
          total: false,
        ),
        MetricChartSeries(
          label: 'Expenditure',
          points: [at(1, 2400), at(0, 2400)],
          color: const Color(0xFF000000),
          isLine: true,
        ),
      ], unit: 'kcal');
      expect(find.textContaining('Average, '), findsOneWidget);
      expect(find.textContaining('Daily Average'), findsNothing);
      expect(find.text('2,250 kcal'), findsWidgets);
      expect(find.byType(CartesianChart), findsOneWidget);
    });
  });

  group('bucketText', () {
    test('a day, a week or a month', () {
      final bucket = DateTime(2026, 9, 14);
      expect(bucketText(MetricRange.week, bucket, 'en'), 'Mon, Sep 14');
      expect(bucketText(MetricRange.month, bucket, 'en'), 'Mon, Sep 14');
      expect(
        bucketText(MetricRange.sixMonths, bucket, 'en'),
        'Sep 14 – Sep 20',
      );
      expect(
        bucketText(MetricRange.year, DateTime(2026, 9), 'en'),
        'September 2026',
      );
    });
  });

  group(MetricChartSeries, () {
    test('bars are totals unless told otherwise', () {
      const black = Color(0xFF000000);
      expect(
        const MetricChartSeries(
          label: 'a',
          points: [],
          color: black,
          isBar: true,
        ).isTotal,
        isTrue,
      );
      expect(
        const MetricChartSeries(
          label: 'a',
          points: [],
          color: black,
          isBar: true,
          total: false,
        ).withPoints(const []).isTotal,
        isFalse,
      );
      expect(
        const MetricChartSeries(label: 'a', points: [], color: black).isTotal,
        isFalse,
      );
    });
  });
}
