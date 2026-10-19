import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

const _pink = Color(0xFFCC4DBF);
const _green = Color(0xFF34C759);

/// Wednesday 14 October 2026.
final _today = DateTime(2026, 10, 14);

const double _cell = AppChartMark.heatCell;
const double _gap = AppChartMark.heatGap;
const double _step = _cell + _gap;

/// The month names' row at the default text size: the label's line, then
/// a small gap.
const double _top = 16 + AppSpacing.xs;

/// The weekday initials' column: the widest initial, then [AppSpacing.s].
final double _letters =
    [
      for (final letter in ['M', 'T', 'W', 'F', 'S'])
        (TextPainter(
          text: TextSpan(text: letter, style: AppTextStyles.label),
          textDirection: TextDirection.ltr,
        )..layout()).width,
    ].reduce((a, b) => a > b ? a : b) +
    AppSpacing.s;

/// A calendar grid [width] wide at the top left: by default room for the
/// weekday initials and 18 whole weeks, so the squares keep their size.
Widget _calendar({
  Map<DateTime, int> days = const {},
  int levels = 5,
  int firstWeekday = DateTime.monday,
  bool showsWeekdays = true,
  bool showsMonths = true,
  DateTime? selected,
  ValueChanged<DateTime?>? onSelected,
  Widget? callout,
  String Function(DateTime)? weekLabel,
  double? width,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: width ?? _letters + 18 * _step - _gap,
    child: HeatGrid(
      days: days,
      today: _today,
      levels: levels,
      color: _pink,
      firstWeekday: firstWeekday,
      showsWeekdays: showsWeekdays,
      showsMonths: showsMonths,
      selected: selected,
      onSelected: onSelected,
      callout: callout,
      weekLabel: weekLabel,
    ),
  ),
);

/// A card's grid of [values] in a [width] by [height] box.
Widget _packed(
  List<int> values, {
  int levels = 2,
  double width = 100,
  double height = 36,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: width,
    height: height,
    child: HeatGrid.packed(values: values, levels: levels, color: _pink),
  ),
);

/// [weeks] of training back from [_today], a level a day from a pattern.
Map<DateTime, int> _training(int weeks) => {
  for (var day = 0; day < weeks * 7; day++)
    if ((day * 7) % 5 case final level when level > 0 && day % 7 != 3)
      DateTime(_today.year, _today.month, _today.day - day): level % 5,
};

void main() {
  group(HeatGrid, () {
    Finder painter() => find.byWidgetPredicate(
      (w) => w is CustomPaint && '${w.painter.runtimeType}' == '_HeatPainter',
    );
    RenderObject grid(WidgetTester tester) => tester.renderObject(painter());
    Color shade(double t, {Color from = const Color(0xFFFFFFFF)}) =>
        Color.lerp(from, _pink, t)!;
    final empty = AppTheme.light.colorScheme.surfaceContainerHighest;

    /// [count] squares of any kind, as a pattern matches each call in turn.
    PaintPattern skip(int count) {
      var pattern = paints;
      for (var i = 0; i < count; i++) {
        pattern = pattern..rrect();
      }
      return pattern;
    }

    testWidgets('packs a card’s days down each column', (tester) async {
      await tester.pumpApp(_packed([1, 0, 1, 1]), disableAnimations: true);
      // Two columns of three in 100 × 36: squares 10 across.
      const radius = Radius.circular(AppChartMark.heatCorner * 10 / _cell);
      RRect at(double x, double y) =>
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 10, 10), radius);
      expect(
        grid(tester),
        paints
          ..rrect(rrect: at(0, 0), color: _pink)
          ..rrect(rrect: at(0, 13), color: empty)
          ..rrect(rrect: at(0, 26), color: _pink)
          ..rrect(rrect: at(13, 0), color: _pink),
      );
      expect(grid(tester), paintsExactlyCountTimes(#drawRRect, 4));
    });

    testWidgets('shades step from the surface to the colour', (tester) async {
      const t = AppChartMark.heatFirstShade;
      final levels = [0, 1, 2, 3, 4, 9, -1];
      await tester.pumpApp(
        _packed(levels, levels: 5, width: 400),
        disableAnimations: true,
      );
      PaintPattern shades(List<Color> colors) {
        var pattern = paints;
        for (final color in colors) {
          pattern = pattern..rrect(color: color);
        }
        return pattern;
      }

      final between = [t, t + (1 - t) / 3, t + 2 * (1 - t) / 3];
      expect(
        grid(tester),
        shades([empty, for (final s in between) shade(s), _pink, _pink, empty]),
      );

      final dark = AppTheme.dark.colorScheme;
      await tester.pumpApp(
        _packed(levels, levels: 5, width: 400),
        theme: AppTheme.dark,
        disableAnimations: true,
      );
      // MaterialApp eases into the new theme.
      await tester.pumpAndSettle();
      expect(
        grid(tester),
        shades([
          dark.surfaceContainerHighest,
          for (final s in between) shade(s, from: dark.surface),
          _pink,
        ]),
      );
    });

    testWidgets('a week to a column, filling the width', (tester) async {
      await tester.pumpApp(
        _calendar(days: {DateTime(2026, 9, 2): 1, _today: 2}),
        disableAnimations: true,
      );
      final viewport = tester.getSize(find.byType(SingleChildScrollView));
      final weeks = ((viewport.width + _gap) / _step).floor();
      expect(weeks, greaterThan(7));
      // Thursday to Sunday of this week are still to come.
      expect(grid(tester), paintsExactlyCountTimes(#drawRRect, weeks * 7 - 4));
      expect(
        tester.getSize(painter()),
        Size(weeks * _step - _gap, _top + 7 * _step - _gap),
      );
      // July, August, September and October are named.
      expect(grid(tester), paintsExactlyCountTimes(#drawParagraph, 4));
      // Today is the last column's Wednesday.
      final x = (weeks - 1) * _step;
      expect(
        grid(tester),
        skip((weeks - 1) * 7 + 2)..rrect(
          rrect: RRect.fromRectAndRadius(
            Rect.fromLTWH(x, _top + 2 * _step, _cell, _cell),
            const Radius.circular(AppChartMark.heatCorner),
          ),
          // Level 2 of 5: a third of the way from the faintest to full.
          color: shade(
            AppChartMark.heatFirstShade + (1 - AppChartMark.heatFirstShade) / 3,
          ),
        ),
      );
    });

    testWidgets('stretches the squares so whole weeks fill the width', (
      tester,
    ) async {
      await tester.pumpApp(_calendar(width: 400), disableAnimations: true);
      final grid = tester.getRect(painter());
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      expect(grid.left, closeTo(viewport.left, 0.01));
      expect(grid.right, viewport.right);
      expect(grid.width, closeTo(400 - _letters, 0.01));
      // Still 18 weeks, each a little wider.
      expect(grid.height - _top, greaterThan(7 * _step - _gap));
    });

    testWidgets('goes back to the first week logged, scrolled to this', (
      tester,
    ) async {
      // Monday 5 January: 41 weeks to this one.
      await tester.pumpApp(
        _calendar(days: {DateTime(2026, 1, 5): 1}),
        disableAnimations: true,
      );
      expect(tester.getSize(painter()).width, 41 * _step - _gap);
      expect(
        tester.getRect(painter()).right,
        tester.getRect(find.byType(SingleChildScrollView)).right,
      );
    });

    testWidgets('names the weekdays from the first, and the months', (
      tester,
    ) async {
      await tester.pumpApp(
        _calendar(firstWeekday: DateTime.sunday),
        disableAnimations: true,
      );
      final letters = [
        for (final e in find.byType(Text).evaluate()) (e.widget as Text).data,
      ];
      expect(letters, ['S', 'M', 'T', 'W', 'T', 'F', 'S']);

      await tester.pumpApp(
        _calendar(
          showsWeekdays: false,
          showsMonths: false,
          width: 18 * _step - _gap,
        ),
        disableAnimations: true,
      );
      expect(find.byType(Text), findsNothing);
      expect(grid(tester), paintsExactlyCountTimes(#drawParagraph, 0));
      expect(tester.getSize(painter()).height, 7 * _step - _gap);
    });

    testWidgets('grows with the text so every name fits', (tester) async {
      await tester.pumpApp(_calendar(), textScale: 2, disableAnimations: true);
      // The squares double, and so does the month row.
      expect(
        tester.getSize(painter()).height,
        greaterThanOrEqualTo(2 * 16 + AppSpacing.xs + 2 * (7 * _step - _gap)),
      );
      for (final e in find.byType(Text).evaluate()) {
        final text = tester.getRect(find.byWidget(e.widget));
        expect(text.height, lessThanOrEqualTo(2 * _cell));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws in as a wave, or at once with reduced motion', (
      tester,
    ) async {
      await tester.pumpApp(_packed([1, 1, 1, 1, 1, 1]));
      expect(grid(tester), paintsExactlyCountTimes(#drawRRect, 0));
      // The clock starts on the first frame after.
      await tester.pump();
      // A tenth of the way in, only the first two squares have begun.
      await tester.pump(AppMotion.progress.duration * 0.1);
      expect(grid(tester), paintsExactlyCountTimes(#drawRRect, 2));
      await tester.pumpAndSettle();
      expect(grid(tester), paintsExactlyCountTimes(#drawRRect, 6));

      await tester.pumpApp(_calendar(days: {_today: 4}));
      await tester.pumpAndSettle();
      final weeks = ((tester.getSize(painter()).width + _gap) / _step).round();
      expect(grid(tester), skip((weeks - 1) * 7 + 2)..rrect(color: _pink));

      await tester.pumpApp(_packed([1]), disableAnimations: true);
      expect(grid(tester), paintsExactlyCountTimes(#drawRRect, 1));
    });

    testWidgets('reads a week at a time', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        _calendar(weekLabel: (start) => 'Week of ${start.month}/${start.day}'),
        disableAnimations: true,
      );
      expect(find.semantics.byLabel('Week of 10/12'), findsOne);
      expect(find.semantics.byLabel('Week of 10/5'), findsOne);
      // The weekday letters are not read.
      expect(find.semantics.byLabel('W'), findsNothing);
      handle.dispose();
    });

    testWidgets('rings the day picked', (tester) async {
      await tester.pumpApp(
        _calendar(selected: _today, callout: const Text('2 workouts')),
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      final weeks = ((tester.getSize(painter()).width + _gap) / _step).round();
      expect(
        grid(tester),
        skip(weeks * 7 - 4)..rrect(
          rrect: RRect.fromRectAndRadius(
            Rect.fromLTWH(
              (weeks - 1) * _step,
              _top + 2 * _step,
              _cell,
              _cell,
            ).inflate(_gap / 2),
            const Radius.circular(AppChartMark.heatCorner + _gap / 2),
          ),
          style: PaintingStyle.stroke,
          strokeWidth: AppChartMark.heatRingWidth,
          color: AppTheme.light.colorScheme.onSurface,
        ),
      );
      expect(find.text('2 workouts'), findsOneWidget);
    });

    group('held', () {
      late List<AppHaptic> haptics;
      late List<DateTime?> picks;

      setUp(() {
        haptics = [];
        picks = [];
        AppHaptics.debugPlay = haptics.add;
      });
      tearDown(() => AppHaptics.debugPlay = null);

      Future<void> pump(WidgetTester tester, {int weeksBack = 0}) =>
          tester.pumpApp(
            StatefulBuilder(
              builder: (context, setState) {
                final selected = picks.isEmpty ? null : picks.last;
                return Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: _calendar(
                    days: {DateTime(2026, 1, 5): 1, _today: 2},
                    selected: selected,
                    onSelected: (day) => setState(() => picks.add(day)),
                    callout: selected == null
                        ? null
                        : Text('${selected.month}/${selected.day}'),
                  ),
                );
              },
            ),
            disableAnimations: true,
          );

      /// The centre of [row]'s square, [weeksBack] columns from the last
      /// one on screen.
      Offset cell(WidgetTester tester, int row, {int weeksBack = 0}) {
        final viewport = tester.getRect(find.byType(SingleChildScrollView));
        return Offset(
          viewport.right - _cell / 2 - weeksBack * _step,
          viewport.top + _top + row * _step + _cell / 2,
        );
      }

      testWidgets('picks a day, follows the finger, lets go', (tester) async {
        await pump(tester);
        final gesture = await tester.startGesture(cell(tester, 2));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        expect(picks, [_today]);
        expect(haptics, [AppHaptic.selection]);
        await tester.pumpAndSettle();
        // Over the day, above the grid.
        final callout = tester.getRect(find.text('10/14'));
        expect(callout.bottom, lessThan(cell(tester, 0).dy));
        expect(
          callout.right,
          lessThanOrEqualTo(tester.getRect(find.byType(HeatGrid)).right),
        );

        // Within the same square: nothing new.
        await gesture.moveBy(const Offset(2, 2));
        await tester.pump();
        expect(picks, hasLength(1));

        await gesture.moveTo(cell(tester, 1));
        await tester.pump();
        expect(picks.last, DateTime(2026, 10, 13));

        // A day still to come, or the month row, picks nothing.
        await gesture.moveTo(cell(tester, 5));
        await tester.pump();
        expect(picks.last, isNull);
        await gesture.moveTo(cell(tester, 0, weeksBack: 1));
        await tester.pump();
        await gesture.moveTo(cell(tester, 0) - const Offset(0, _cell));
        await tester.pump();
        expect(picks.last, isNull);
        expect(haptics, hasLength(3));

        await gesture.moveTo(cell(tester, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(picks.last, isNull);
        expect(find.text('10/12'), findsNothing);
      });

      testWidgets('places the callout over a week scrolled into view', (
        tester,
      ) async {
        await pump(tester);
        // Back some weeks.
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(8 * _step, 0),
        );
        await tester.pumpAndSettle();
        final at = cell(tester, 0, weeksBack: 3);
        final gesture = await tester.startGesture(at);
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        final day = picks.single!;
        expect(day.weekday, DateTime.monday);
        expect(day.isBefore(DateTime(2026, 9)), isTrue);
        expect(
          tester.getCenter(find.text('${day.month}/${day.day}')).dx,
          closeTo(at.dx, 1),
        );
        await gesture.up();
      });
    });

    testWidgets('needs two levels', (tester) async {
      await tester.pumpApp(_packed([1], levels: 1));
      expect(tester.takeException(), isAssertionError);
    });

    goldenStates('heat_grid', [
      (
        'a card’s month, 2 levels',
        SizedBox(
          width: 200,
          height: 36,
          child: HeatGrid.packed(
            values: [
              for (var i = 0; i < 30; i++)
                if ((i * 7) % 3 == 0) 0 else 1,
            ],
            levels: 2,
            color: _pink,
          ),
        ),
      ),
      (
        'a card’s month, 5 levels',
        SizedBox(
          width: 200,
          height: 36,
          child: HeatGrid.packed(
            values: [for (var i = 0; i < 30; i++) (i * 3) % 5],
            levels: 5,
            color: _green,
          ),
        ),
      ),
      (
        'with labels and a legend, 5 levels',
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: AppSpacing.xs,
          children: [
            HeatGrid(
              days: _training(16),
              today: _today,
              levels: 5,
              color: _pink,
            ),
            const HeatGridLegend(
              levels: 5,
              color: _pink,
              less: 'Less',
              more: 'More',
            ),
          ],
        ),
      ),
      (
        'without labels, 2 levels',
        HeatGrid(
          days: _training(12),
          today: _today,
          levels: 2,
          color: _green,
          showsWeekdays: false,
          showsMonths: false,
        ),
      ),
      (
        'a day picked, with its callout',
        Padding(
          // Room for the callout, which floats above the grid.
          padding: const EdgeInsets.only(top: 120),
          child: HeatGrid(
            days: _training(8),
            today: _today,
            levels: 5,
            color: _pink,
            selected: DateTime(2026, 10, 12),
            callout: const ChartCalloutSummary(
              rows: [
                (name: null, color: null, mark: null, value: '2 workouts'),
              ],
              footer: 'Mon, Oct 12, 2026',
              noData: 'No Data',
            ),
          ),
        ),
      ),
      (
        'empty',
        HeatGrid(days: const {}, today: _today, levels: 2, color: _pink),
      ),
    ]);
  });

  group(HeatGridLegend, () {
    Widget legend() => const Align(
      alignment: Alignment.topLeft,
      child: HeatGridLegend(
        levels: 3,
        color: _pink,
        less: 'Less',
        more: 'More',
      ),
    );

    testWidgets('names the ends around a swatch a shade', (tester) async {
      await tester.pumpApp(legend());
      expect(find.text('Less'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      final swatches = find.descendant(
        of: find.byType(HeatGridLegend),
        matching: find.byType(DecoratedBox),
      );
      expect(swatches, findsNWidgets(3));
      final colors = [
        for (final e in swatches.evaluate())
          ((e.widget as DecoratedBox).decoration as ShapeDecoration).color,
      ];
      expect(colors, [
        AppTheme.light.colorScheme.surfaceContainerHighest,
        Color.lerp(const Color(0xFFFFFFFF), _pink, AppChartMark.heatFirstShade),
        _pink,
      ]);
      expect(tester.getSize(swatches.first), const Size.square(AppSpacing.m));
    });

    testWidgets('grows with the text and is not read', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(legend(), textScale: 2);
      expect(
        tester.getSize(
          find
              .descendant(
                of: find.byType(HeatGridLegend),
                matching: find.byType(DecoratedBox),
              )
              .first,
        ),
        const Size.square(2 * AppSpacing.m),
      );
      expect(find.semantics.byLabel('Less'), findsNothing);
      handle.dispose();
    });
  });
}
