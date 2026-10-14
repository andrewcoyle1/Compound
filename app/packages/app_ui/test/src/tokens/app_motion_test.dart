import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppMotion', () {
    test('curves get longer from quick to progress', () {
      expect(
        AppMotion.values.map((motion) => motion.duration.inMilliseconds),
        orderedEquals([200, 350, 500, 1000]),
      );
      expect(AppMotion.emphasis.curve, Curves.easeOutBack);
    });

    Future<Duration> durationIn(
      WidgetTester tester, {
      required bool disableAnimations,
    }) async {
      late Duration duration;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            duration = AppMotion.standard.durationOf(context);
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
        const Duration(milliseconds: 350),
      );
    });

    testWidgets('durationOf is zero under reduced motion', (tester) async {
      expect(await durationIn(tester, disableAnimations: true), Duration.zero);
    });
  });
}
