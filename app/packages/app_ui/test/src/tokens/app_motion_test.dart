import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppMotion', () {
    test('timings get longer from press to progress', () {
      expect(
        AppMotion.values.map((motion) => motion.duration.inMilliseconds),
        orderedEquals([120, 200, 300, 350, 500, 1000]),
      );
      expect(AppMotion.emphasis.curve, Curves.easeOutBack);
      expect(AppMotion.progress.curve, Curves.easeOut);
    });

    test('responses ease out, in-place changes ease in and out', () {
      const easeOut = Cubic(0.32, 0.72, 0, 1);
      expect(AppMotion.press.curve, easeOut);
      expect(AppMotion.quick.curve, easeOut);
      expect(AppMotion.move.curve, easeOut);
      expect(AppMotion.standard.curve, const Cubic(0.77, 0, 0.175, 1));
      expect(AppMotion.exitCurve, const Cubic(0.55, 0, 1, 0.45));
    });

    Future<Duration> durationIn(
      WidgetTester tester, {
      required bool disableAnimations,
      bool exit = false,
    }) async {
      late Duration duration;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            duration = exit
                ? AppMotion.standard.exitDurationOf(context)
                : AppMotion.standard.durationOf(context);
            return const SizedBox();
          },
        ),
        disableAnimations: disableAnimations,
      );
      return duration;
    }

    testWidgets('durationOf keeps the duration normally', (tester) async {
      expect(
        await durationIn(tester, disableAnimations: false),
        const Duration(milliseconds: 300),
      );
    });

    testWidgets('durationOf is zero under reduced motion', (tester) async {
      expect(await durationIn(tester, disableAnimations: true), Duration.zero);
    });

    testWidgets('an exit takes three quarters of the entrance', (tester) async {
      expect(
        await durationIn(tester, disableAnimations: false, exit: true),
        const Duration(milliseconds: 225),
      );
    });

    testWidgets('an exit is zero under reduced motion', (tester) async {
      expect(
        await durationIn(tester, disableAnimations: true, exit: true),
        Duration.zero,
      );
    });
  });
}
