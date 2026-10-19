import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

const _orange = Color(0xFFFF9500);

Widget _arc({
  double value = 0.6,
  double from = 0,
  ArcSweep sweep = ArcSweep.ring,
  Widget? child,
}) => Center(
  child: ProgressArc(
    value: value,
    from: from,
    sweep: sweep,
    color: _orange,
    diameter: 120,
    semanticLabel: 'Calories',
    child: child,
  ),
);

void main() {
  group(ProgressArc, () {
    RenderObject arcOf(WidgetTester tester) => tester.renderObject(
      find.descendant(
        of: find.byType(ProgressArc),
        matching: find.byType(CustomPaint),
      ),
    );

    testWidgets('fills clockwise from the top over a full track', (
      tester,
    ) async {
      await tester.pumpApp(_arc(), disableAnimations: true);
      expect(
        arcOf(tester),
        paints
          ..arc(
            startAngle: -math.pi / 2,
            sweepAngle: 2 * math.pi,
            color: AppTheme.light.colorScheme.outlineVariant,
          )
          ..arc(
            startAngle: -math.pi / 2,
            sweepAngle: 2 * math.pi * 0.6,
            color: _orange,
            strokeWidth: AppChartMark.arcWidth,
            strokeCap: StrokeCap.round,
          ),
      );
    });

    testWidgets('draws only the track when empty', (tester) async {
      await tester.pumpApp(_arc(value: 0), disableAnimations: true);
      expect(arcOf(tester), paintsExactlyCountTimes(#drawArc, 1));
    });

    testWidgets('a ring laps itself past full, its tip shadowed', (
      tester,
    ) async {
      await tester.pumpApp(_arc(value: 1.4), disableAnimations: true);
      expect(
        arcOf(tester),
        paints
          ..arc(color: AppTheme.light.colorScheme.outlineVariant)
          ..arc(sweepAngle: 2 * math.pi, color: _orange)
          ..clipPath()
          ..circle(radius: AppChartMark.arcWidth / 2, hasMaskFilter: true)
          ..arc(
            startAngle: -math.pi / 2 + 2 * math.pi * (1.4 - 0.5),
            sweepAngle: math.pi,
          ),
      );
    });

    testWidgets('a gauge stops at full', (tester) async {
      await tester.pumpApp(
        _arc(value: 1.4, sweep: ArcSweep.gauge),
        disableAnimations: true,
      );
      expect(
        arcOf(tester),
        paints
          ..arc(startAngle: 0.75 * math.pi, sweepAngle: 1.5 * math.pi)
          ..arc(
            startAngle: 0.75 * math.pi,
            sweepAngle: 1.5 * math.pi,
            color: _orange,
          ),
      );
      expect(arcOf(tester), paintsExactlyCountTimes(#drawArc, 2));
    });

    testWidgets('fills from part way round to show what is left', (
      tester,
    ) async {
      await tester.pumpApp(
        _arc(value: 1, from: 0.25, sweep: ArcSweep.gauge),
        disableAnimations: true,
      );
      expect(
        arcOf(tester),
        paints
          ..arc()
          ..arc(
            startAngle: 0.75 * math.pi + 1.5 * math.pi * 0.25,
            sweepAngle: 1.5 * math.pi * 0.75,
          ),
      );
    });

    testWidgets('draws in, then moves to a new value', (tester) async {
      await tester.pumpApp(_arc());
      expect(arcOf(tester), paintsExactlyCountTimes(#drawArc, 1));
      await tester.pump(AppMotion.progress.duration ~/ 2);
      expect(
        arcOf(tester),
        isNot(
          paints
            ..arc()
            ..arc(sweepAngle: 2 * math.pi * 0.6),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        arcOf(tester),
        paints
          ..arc()
          ..arc(sweepAngle: 2 * math.pi * 0.6),
      );

      await tester.pumpApp(_arc(value: 0.9));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(
        arcOf(tester),
        paints
          ..arc()
          ..arc(sweepAngle: 2 * math.pi * 0.9),
      );
    });

    testWidgets('shows the value at once with reduced motion', (tester) async {
      await tester.pumpApp(_arc(), disableAnimations: true);
      expect(
        arcOf(tester),
        paints
          ..arc()
          ..arc(sweepAngle: 2 * math.pi * 0.6),
      );
    });

    testWidgets('fits its child inside the ring', (tester) async {
      await tester.pumpApp(
        _arc(child: const Text('A long figure that would not fit at all')),
        textScale: 2,
      );
      const inner = (120 - 2 * AppChartMark.arcWidth) / math.sqrt2;
      final text = tester.getRect(find.byType(Text));
      expect(text.width, lessThanOrEqualTo(inner + 0.01));
      expect(
        tester.getCenter(find.byType(Text)),
        within(
          distance: 0.01,
          from: tester.getCenter(find.byType(ProgressArc)),
        ),
      );
    });

    testWidgets('reads its label and the share filled, not its child', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(_arc(child: const Text('600')));
      expect(
        tester.getSemantics(find.byType(ProgressArc)),
        matchesSemantics(label: 'Calories', value: '60%'),
      );
      await tester.pumpApp(
        const ProgressArc(
          value: 0.5,
          color: _orange,
          diameter: 80,
          semanticValue: '3 of 6',
        ),
      );
      expect(
        tester.getSemantics(find.byType(ProgressArc)),
        matchesSemantics(value: '3 of 6'),
      );
      semantics.dispose();
    });
  });

  group('goldens', () {
    Widget figure(String value, String label) => Builder(
      builder: (context) => Column(
        children: [
          Text(value, style: AppTextStyles.display),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    Widget row(List<Widget> arcs) => Row(spacing: AppSpacing.l, children: arcs);
    ProgressArc ring(double value, {double diameter = 64}) => ProgressArc(
      value: value,
      color: _orange,
      diameter: diameter,
      strokeWidth: AppChartMark.arcWidthSmall,
    );

    goldenStates('progress_arc', [
      (
        'rings at 0, 60%, 100% and 140%',
        row([ring(0), ring(0.6), ring(1), ring(1.4)]),
      ),
      (
        'a gauge, used and left',
        row([
          ProgressArc(
            value: 0.7,
            sweep: ArcSweep.gauge,
            color: _orange,
            diameter: 140,
            child: figure('1,450', 'Consumed'),
          ),
          ProgressArc(
            value: 1,
            from: 0.7,
            sweep: ArcSweep.gauge,
            color: _orange,
            diameter: 140,
            child: figure('620', 'Remaining'),
          ),
        ]),
      ),
      (
        'rings with a figure and a tinted track, at 60% and past full',
        row([
          for (final (value, text) in [(0.6, '3/5'), (1.4, '7/5')])
            ProgressArc(
              value: value,
              color: const Color(0xFF34C759),
              trackColor: AppColors.tintedSurface(const Color(0xFF34C759)),
              diameter: 120,
              child: figure(text, 'sessions'),
            ),
        ]),
      ),
    ]);
  });
}
