import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppShake, () {
    const key = Key('field');

    Widget shake(int trigger) => Center(
      child: AppShake(
        trigger: trigger,
        child: const SizedBox(key: key, width: 100, height: 44),
      ),
    );

    double x(WidgetTester tester) => tester.getTopLeft(find.byKey(key)).dx;

    testWidgets('shakes when the trigger changes and comes to rest', (
      tester,
    ) async {
      await tester.pumpApp(shake(0), disableAnimations: false);
      final rest = x(tester);
      await tester.pumpApp(shake(1), disableAnimations: false);
      await tester.pump();
      // The first leg, to the left.
      await tester.pump(AppShake.duration ~/ 12);
      expect(x(tester), lessThan(rest));
      // The second, to the right.
      await tester.pump(AppShake.duration ~/ 6);
      expect(x(tester), greaterThan(rest));
      await tester.pumpAndSettle();
      expect(x(tester), rest);
    });

    testWidgets('stays still when the trigger is unchanged', (tester) async {
      await tester.pumpApp(shake(1), disableAnimations: false);
      await tester.pumpApp(shake(1), disableAnimations: false);
      await tester.pump(AppShake.duration ~/ 4);
      expect(tester.getCenter(find.byKey(key)).dx, 400);
    });

    testWidgets('stays still under reduced motion', (tester) async {
      await tester.pumpApp(shake(0));
      await tester.pumpApp(shake(1));
      await tester.pump(AppShake.duration ~/ 4);
      expect(tester.getCenter(find.byKey(key)).dx, 400);
    });
  });
}
