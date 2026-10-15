import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/metric_detail/metric_detail.dart';
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

  group('niceBounds', () {
    test('gives whole numbers at least two apart with a whole middle', () {
      expect(niceBounds(70.3, 70.3), (69.0, 71.0));
      expect(niceBounds(70.1, 74.6), (70.0, 76.0));
      expect(niceBounds(70.1, 72.6), (70.0, 74.0));
      // A ratio steps in tenths.
      expect(readingBounds(0.44, 0.5), (0.4, 0.6));
      expect(readingBounds(70.3, 70.3), (69.0, 71.0));
      expect(readingBounds(-0.5, 0.5), niceBounds(-0.5, 0.5));
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
      expect(find.text('Highest: Oct 13'), findsOneWidget);
      expect(find.text('Lowest: Yesterday'), findsOneWidget);
      expect(find.text('72.4 kg'), findsWidgets);
      expect(find.byType(MetricChart), findsOneWidget);
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
      expect(find.byType(MetricChart), findsNothing);
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
      await tester.ensureVisible(find.text('Show All Data'));
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
      expect(find.text('DAILY AVERAGE'), findsOneWidget);
      expect(find.text('Daily Average'), findsOneWidget);
      // 5.5 sets today, rounded.
      expect(find.text('6'), findsWidgets);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.byType(MetricChart), findsOneWidget);
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
      expect(find.byType(MetricChart), findsOneWidget);
    });

    testWidgets('draws every range', (tester) async {
      for (final range in MetricRange.values) {
        await pumpDetail(tester, [scale], range: range);
        expect(find.byType(MetricChart), findsOneWidget, reason: range.name);
      }
    });
  });
}
