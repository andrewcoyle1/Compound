import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

const _orange = Color(0xFFFF9500);
const _green = Color(0xFF34C759);

const _width = 200.0;
const double _thick = AppChartMark.bulletWidth;
const double _half = _thick / 2;
const double _gap = AppChartMark.tickOverhang;
const double _caret = AppChartMark.caretSize;

/// A [_width]-long bar, centred.
Widget _bar({
  double value = 0.6,
  double from = 0,
  double maximum = 1,
  double? target,
  bool? over,
  Axis direction = Axis.horizontal,
  double width = _width,
  double height = 100,
}) => Center(
  child: SizedBox(
    width: width,
    height: height,
    child: BulletBar(
      value: value,
      from: from,
      maximum: maximum,
      target: target,
      over: over,
      direction: direction,
      color: _orange,
      semanticLabel: 'Protein',
    ),
  ),
);

void main() {
  group(BulletBar, () {
    RenderObject barOf(WidgetTester tester) => tester.renderObject(
      find.descendant(
        of: find.byType(BulletBar),
        matching: find.byType(CustomPaint),
      ),
    );
    Size sizeOf(WidgetTester tester) => tester.getSize(
      find.descendant(
        of: find.byType(BulletBar),
        matching: find.byType(CustomPaint),
      ),
    );

    testWidgets('fills from the start over a rounded track', (tester) async {
      await tester.pumpApp(_bar(), disableAnimations: true);
      expect(sizeOf(tester), const Size(_width, _thick));
      expect(
        barOf(tester),
        paints
          ..rrect(
            rrect: RRect.fromLTRBR(
              0,
              0,
              _width,
              _thick,
              const Radius.circular(_half),
            ),
            color: AppTheme.light.colorScheme.outlineVariant,
          )
          ..clipRRect()
          ..rrect(
            rrect: RRect.fromLTRBR(
              0,
              0,
              _width * 0.6,
              _thick,
              const Radius.circular(_half),
            ),
            color: _orange,
          ),
      );
    });

    testWidgets('draws only the track when empty, or with no maximum', (
      tester,
    ) async {
      await tester.pumpApp(_bar(value: 0), disableAnimations: true);
      expect(barOf(tester), paintsExactlyCountTimes(#drawRRect, 1));
      await tester.pumpApp(_bar(value: 5, maximum: 0), disableAnimations: true);
      expect(barOf(tester), paintsExactlyCountTimes(#drawRRect, 1));
    });

    testWidgets('stops a value past the maximum at the end', (tester) async {
      await tester.pumpApp(
        _bar(value: 300, maximum: 200),
        disableAnimations: true,
      );
      expect(
        barOf(tester),
        paints
          ..rrect()
          ..rrect(
            rrect: RRect.fromLTRBR(
              0,
              0,
              _width,
              _thick,
              const Radius.circular(_half),
            ),
          ),
      );
    });

    testWidgets('keeps a small fill under the rounded end', (tester) async {
      await tester.pumpApp(_bar(value: 0.01), disableAnimations: true);
      expect(
        barOf(tester),
        paints
          ..rrect()
          ..rrect(
            rrect: RRect.fromLTRBR(
              _width * 0.01 - _thick,
              0,
              _width * 0.01,
              _thick,
              const Radius.circular(_half),
            ),
          ),
      );
    });

    testWidgets('fills from part way along to show what is left', (
      tester,
    ) async {
      await tester.pumpApp(_bar(from: 0.25, value: 1), disableAnimations: true);
      expect(
        barOf(tester),
        paints
          ..rrect()
          ..rrect(
            rrect: RRect.fromLTRBR(
              _width * 0.25,
              0,
              _width,
              _thick,
              const Radius.circular(_half),
            ),
          ),
      );
      // A sliver left still shows.
      await tester.pumpApp(_bar(from: 0.99, value: 1), disableAnimations: true);
      expect(
        barOf(tester),
        paints
          ..rrect()
          ..rrect(
            rrect: RRect.fromLTRBR(
              _width * 0.99,
              0,
              _width * 0.99 + _thick,
              _thick,
              const Radius.circular(_half),
            ),
          ),
      );
    });

    testWidgets('ticks the target across the bar', (tester) async {
      await tester.pumpApp(
        _bar(target: 150, value: 120, maximum: 200),
        disableAnimations: true,
      );
      expect(sizeOf(tester), const Size(_width, _thick + 2 * _gap));
      const middle = _half + _gap;
      expect(
        barOf(tester),
        paints
          ..rrect()
          ..rrect()
          ..line(
            p1: const Offset(_width * 0.75, 0),
            p2: const Offset(_width * 0.75, 2 * middle),
            color: AppTheme.light.colorScheme.onSurface,
            strokeWidth: AppChartMark.tickWidth,
          ),
      );

      await tester.pumpApp(_bar(target: 0), disableAnimations: true);
      expect(barOf(tester), paintsExactlyCountTimes(#drawLine, 0));
    });

    testWidgets('keeps room for the caret, and draws it when over', (
      tester,
    ) async {
      const reach = _width - _gap - _caret;
      const middle = _half + _gap;
      await tester.pumpApp(
        _bar(value: 1, target: 0.5, over: true),
        disableAnimations: true,
      );
      expect(
        barOf(tester),
        paints
          ..rrect(
            rrect: RRect.fromLTRBR(
              0,
              _gap,
              reach,
              _gap + _thick,
              const Radius.circular(_half),
            ),
          )
          ..rrect()
          ..line(p1: const Offset(reach / 2, 0))
          ..path(
            includes: const [
              Offset(reach + _gap, middle - _caret),
              Offset(reach + _gap + _caret, middle),
            ],
          ),
      );

      await tester.pumpApp(
        _bar(value: 1, target: 0.5, over: false),
        disableAnimations: true,
      );
      expect(
        barOf(tester),
        paints..rrect(
          rrect: RRect.fromLTRBR(
            0,
            _gap,
            reach,
            _gap + _thick,
            const Radius.circular(_half),
          ),
        ),
      );
      expect(barOf(tester), paintsExactlyCountTimes(#drawPath, 0));
    });

    testWidgets('runs up from the foot when vertical', (tester) async {
      await tester.pumpApp(
        _bar(direction: Axis.vertical, width: 40, height: 120, target: 0.5),
        disableAnimations: true,
      );
      expect(sizeOf(tester), const Size(_thick + 2 * _gap, 120));
      expect(
        barOf(tester),
        paints
          ..translate(x: 0, y: 120)
          ..rotate()
          ..rrect(
            rrect: RRect.fromLTRBR(
              0,
              _gap,
              120,
              _gap + _thick,
              const Radius.circular(_half),
            ),
          )
          ..rrect(
            rrect: RRect.fromLTRBR(
              0,
              _gap,
              120 * 0.6,
              _gap + _thick,
              const Radius.circular(_half),
            ),
          ),
      );
    });

    testWidgets('fills from the right in a right-to-left language', (
      tester,
    ) async {
      await tester.pumpApp(
        Directionality(textDirection: TextDirection.rtl, child: _bar()),
        disableAnimations: true,
      );
      expect(
        barOf(tester),
        paints
          ..translate(x: _width, y: 0)
          ..scale()
          ..rrect()
          ..rrect(),
      );
    });

    testWidgets('draws in, then moves to a new value and target', (
      tester,
    ) async {
      await tester.pumpApp(_bar());
      expect(barOf(tester), paintsExactlyCountTimes(#drawRRect, 1));
      await tester.pump(AppMotion.progress.duration ~/ 2);
      expect(
        barOf(tester),
        isNot(
          paints
            ..rrect()
            ..rrect(
              rrect: RRect.fromLTRBR(
                0,
                0,
                _width * 0.6,
                _thick,
                const Radius.circular(_half),
              ),
            ),
        ),
      );
      await tester.pumpAndSettle();
      expect(barOf(tester), paintsExactlyCountTimes(#drawRRect, 2));

      // A target arrives where it is; then it moves with the value.
      await tester.pumpApp(_bar(value: 0.8, target: 0.5));
      await tester.pump(AppMotion.progress.duration ~/ 2);
      expect(barOf(tester), paints..line(p1: const Offset(_width * 0.5, 0)));
      await tester.pumpAndSettle();
      await tester.pumpApp(_bar(value: 0.8, target: 1));
      await tester.pump(AppMotion.progress.duration ~/ 2);
      expect(
        barOf(tester),
        isNot(paints..line(p1: const Offset(_width * 0.5, 0))),
      );
      await tester.pumpAndSettle();
      expect(barOf(tester), paints..line(p1: const Offset(_width, 0)));

      // And it goes at once.
      await tester.pumpApp(_bar(value: 0.8));
      await tester.pump(AppMotion.progress.duration ~/ 2);
      expect(barOf(tester), paintsExactlyCountTimes(#drawLine, 0));
      await tester.pumpAndSettle();
    });

    testWidgets('repaints for a new theme', (tester) async {
      await tester.pumpApp(_bar(target: 0.5), disableAnimations: true);
      await tester.pumpApp(
        _bar(target: 0.5),
        theme: AppTheme.dark,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      expect(
        barOf(tester),
        paints
          ..rrect(color: AppTheme.dark.colorScheme.outlineVariant)
          ..rrect()
          ..line(color: AppTheme.dark.colorScheme.onSurface),
      );
    });

    testWidgets('grows with the text, up to the room across', (tester) async {
      await tester.pumpApp(_bar(target: 0.5), textScale: 2);
      expect(sizeOf(tester), const Size(_width, 2 * (_thick + 2 * _gap)));
      expect(
        barOf(tester),
        paints..line(strokeWidth: 2 * AppChartMark.tickWidth),
      );

      await tester.pumpApp(_bar(target: 0.5, height: 10), textScale: 2);
      expect(sizeOf(tester), const Size(_width, 10));
    });

    testWidgets('sits in the middle of the room it is given', (tester) async {
      await tester.pumpApp(_bar(height: 60));
      expect(
        tester.getCenter(
          find.descendant(
            of: find.byType(BulletBar),
            matching: find.byType(CustomPaint),
          ),
        ),
        tester.getCenter(find.byType(BulletBar)),
      );
      expect(tester.getSize(find.byType(BulletBar)), const Size(_width, 60));
    });

    testWidgets('reads its label and the share filled', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(_bar(from: 0.2));
      expect(
        tester.getSemantics(find.byType(BulletBar)),
        matchesSemantics(label: 'Protein', value: '40%'),
      );
      await tester.pumpApp(
        const SizedBox(
          width: _width,
          child: BulletBar(
            value: 120,
            maximum: 200,
            color: _orange,
            semanticValue: '120 of 150 g',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(BulletBar)),
        matchesSemantics(value: '120 of 150 g'),
      );
      semantics.dispose();
    });
  });

  group('goldens', () {
    Widget bars(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.m,
      children: children,
    );
    Widget day(double value, {bool? over}) => SizedBox(
      width: AppSpacing.xxl,
      height: AppChartHeight.compact / 2,
      child: BulletBar(
        value: value,
        maximum: 3000,
        target: 2200,
        over: over,
        direction: Axis.vertical,
        color: _orange,
      ),
    );

    goldenStates('bullet_bar', [
      (
        'horizontal at 0, 3%, 60% and full',
        bars([
          for (final value in [0.0, 0.03, 0.6, 1.0])
            BulletBar(value: value, color: _orange),
        ]),
      ),
      (
        'with a target, under it, past it, and over with the caret',
        bars([
          const BulletBar(value: 120, maximum: 200, target: 150, color: _green),
          const BulletBar(value: 180, maximum: 200, target: 150, color: _green),
          const BulletBar(
            value: 200,
            maximum: 200,
            target: 150,
            over: true,
            color: _green,
          ),
        ]),
      ),
      (
        'thin, what is eaten and what is left, on a tinted track',
        bars([
          const BulletBar(
            value: 0.65,
            thickness: AppChartMark.bulletWidthSmall,
            color: _orange,
          ),
          BulletBar(
            from: 0.65,
            value: 1,
            thickness: AppChartMark.bulletWidthSmall,
            trackColor: AppColors.tintedSurface(_orange),
            color: _orange,
          ),
        ]),
      ),
      (
        'vertical days against a tick: none, under, over with the caret',
        Row(
          spacing: AppSpacing.s,
          children: [
            day(0, over: false),
            day(1500, over: false),
            day(2100, over: false),
            day(3000, over: true),
            day(1500),
          ],
        ),
      ),
    ]);
  });
}
