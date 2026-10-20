import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

const _plotWidth = 300.0;
const _plotHeight = 80.0;
const _plotKey = Key('plot');

/// A plot [_plotWidth] wide with room above it for the callout, and the
/// callout over it at [anchorX].
Widget _plot(double anchorX, Widget? child) => Padding(
  padding: const EdgeInsets.only(top: 260),
  child: SizedBox(
    key: _plotKey,
    width: _plotWidth,
    height: _plotHeight,
    child: Builder(
      builder: (context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          Positioned.fill(
            child: ChartCallout(anchorX: anchorX, child: child),
          ),
        ],
      ),
    ),
  ),
);

ChartCalloutSummary _summary(List<ChartCalloutRow> rows) =>
    ChartCalloutSummary(rows: rows, footer: '12–18 Oct', noData: 'No Data');

const List<ChartCalloutRow> _twoSeries = [
  (
    name: 'Weight',
    color: Color(0xFF34C759),
    mark: ChartMark.dot,
    value: '82.5 kg',
  ),
  (
    name: 'Trend',
    color: Color(0xFF007AFF),
    mark: ChartMark.line,
    value: '82.1 kg',
  ),
];

const List<ChartCalloutRow> _oneUnnamed = [
  (name: null, color: null, mark: null, value: '4 workouts'),
];

void main() {
  group('ChartCallout', () {
    Future<void> pumpCallout(
      WidgetTester tester,
      double anchorX,
      Widget? child,
    ) async {
      await tester.pumpApp(Center(child: _plot(anchorX, child)));
      await tester.pumpAndSettle();
    }

    Rect plot(WidgetTester tester) => tester.getRect(find.byKey(_plotKey));

    Rect panel(WidgetTester tester) => tester.getRect(
      find.ancestor(
        of: find.byType(ChartCalloutSummary),
        matching: find.byType(ClipRRect),
      ),
    );

    testWidgets('shows nothing without a child', (tester) async {
      await pumpCallout(tester, 150, null);
      expect(
        find.descendant(
          of: find.byType(ChartCallout),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('sits a small gap above the plot, centred on its x', (
      tester,
    ) async {
      await pumpCallout(tester, 150, _summary(_twoSeries));
      expect(panel(tester).bottom, plot(tester).top - AppSpacing.s);
      expect(
        panel(tester).center.dx,
        moreOrLessEquals(plot(tester).left + 150),
      );
    });

    testWidgets('stays inside the plot at either edge', (tester) async {
      await pumpCallout(tester, 0, _summary(_twoSeries));
      expect(panel(tester).left, plot(tester).left);

      await pumpCallout(tester, _plotWidth, _summary(_twoSeries));
      expect(panel(tester).right, plot(tester).right);
    });

    testWidgets('jumps to a new x', (tester) async {
      await pumpCallout(tester, 0, _summary(_twoSeries));
      await tester.pumpApp(Center(child: _plot(150, _summary(_twoSeries))));
      await tester.pump();
      expect(
        panel(tester).center.dx,
        moreOrLessEquals(plot(tester).left + 150),
      );
    });

    testWidgets('keeps its content while it fades out, then lets go', (
      tester,
    ) async {
      await pumpCallout(tester, 150, _summary(_twoSeries));
      await tester.pumpApp(Center(child: _plot(150, null)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('82.5 kg'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(ChartCalloutSummary), findsNothing);
    });

    testWidgets('never takes a touch', (tester) async {
      await pumpCallout(tester, 150, _summary(_twoSeries));
      expect(find.text('82.5 kg').hitTestable(), findsNothing);
    });
  });

  group('ChartCalloutSummary', () {
    testWidgets('names each series in its colour over its value', (
      tester,
    ) async {
      await tester.pumpApp(_summary(_twoSeries));
      expect(
        tester.widget<Text>(find.text('Weight')).style?.color,
        const Color(0xFF34C759),
      );
      expect(find.text('82.1 kg'), findsOneWidget);
      expect(find.text('12–18 Oct'), findsOneWidget);
    });

    testWidgets('stacks the series when they do not fit side by side', (
      tester,
    ) async {
      Future<double> trendTop(double width) async {
        await tester.pumpApp(
          Center(
            child: SizedBox(width: width, child: _summary(_twoSeries)),
          ),
        );
        return tester.getTopLeft(find.text('Trend')).dy -
            tester.getTopLeft(find.text('Weight')).dy;
      }

      expect(await trendTop(400), 0);
      expect(await trendTop(100), greaterThan(0));
    });

    testWidgets('leaves out the name of an unnamed series', (tester) async {
      await tester.pumpApp(_summary(_oneUnnamed));
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('says there is no data without rows', (tester) async {
      await tester.pumpApp(_summary(const []));
      expect(find.text('No Data'), findsOneWidget);
    });
  });

  group('goldens', () {
    goldenStates('chart_callout', [
      ('two series, centred', _plot(150, _summary(_twoSeries))),
      ('one unnamed series, at the left edge', _plot(0, _summary(_oneUnnamed))),
      ('no data, at the right edge', _plot(_plotWidth, _summary(const []))),
    ]);
  });
}
