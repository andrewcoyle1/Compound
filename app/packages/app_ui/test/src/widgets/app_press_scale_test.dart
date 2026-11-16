import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppPressScale, () {
    const key = Key('face');

    Widget control({double width = 100, bool enabled = true}) => Center(
      child: AppPressScale(
        enabled: enabled,
        builder: (context, states) => InkWell(
          statesController: states,
          onTap: () {},
          child: SizedBox(key: key, width: width, height: 44),
        ),
      ),
    );

    double drawnWidth(WidgetTester tester) =>
        tester.getRect(find.byKey(key)).width;

    testWidgets('shrinks while pressed and glides back on release', (
      tester,
    ) async {
      await tester.pumpApp(control(), disableAnimations: false);
      final press = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pump();
      await tester.pump(AppMotion.press.duration ~/ 2);
      expect(drawnWidth(tester), allOf(lessThan(100), greaterThan(96)));
      await tester.pumpAndSettle();
      expect(drawnWidth(tester), moreOrLessEquals(96));

      await press.up();
      await tester.pump();
      await tester.pump(AppMotion.press.duration ~/ 2);
      expect(drawnWidth(tester), allOf(lessThan(100), greaterThan(96)));
      await tester.pumpAndSettle();
      expect(drawnWidth(tester), 100);
    });

    testWidgets('lets go when the press turns into a drag', (tester) async {
      await tester.pumpApp(
        ListView(children: [control(), const SizedBox(height: 2000)]),
        disableAnimations: false,
      );
      final press = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pumpAndSettle();
      expect(drawnWidth(tester), moreOrLessEquals(96));
      await press.moveBy(const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(drawnWidth(tester), 100);
      await press.up();
    });

    testWidgets('a control wider than maxWidth keeps its size', (tester) async {
      await tester.pumpApp(
        control(width: AppPressScale.maxWidth + 1),
        disableAnimations: false,
      );
      final press = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pumpAndSettle();
      expect(drawnWidth(tester), AppPressScale.maxWidth + 1);
      await press.up();
    });

    testWidgets('does not scale under reduced motion', (tester) async {
      await tester.pumpApp(control());
      final press = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pumpAndSettle();
      expect(drawnWidth(tester), 100);
      await press.up();
    });

    testWidgets('does not scale when turned off', (tester) async {
      await tester.pumpApp(control(enabled: false), disableAnimations: false);
      final press = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pumpAndSettle();
      expect(drawnWidth(tester), 100);
      await press.up();
    });

    testWidgets('settles back at once when reduced motion is turned on', (
      tester,
    ) async {
      final reduced = ValueNotifier(false);
      addTearDown(reduced.dispose);
      await tester.pumpApp(
        ValueListenableBuilder(
          valueListenable: reduced,
          builder: (context, still, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: child!,
          ),
          child: control(),
        ),
        disableAnimations: false,
      );
      final press = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pumpAndSettle();
      expect(drawnWidth(tester), moreOrLessEquals(96));
      reduced.value = true;
      await tester.pump();
      expect(drawnWidth(tester), 100);
      await press.up();
    });

    testWidgets('AppPressable scales unless told not to', (tester) async {
      Future<double> pressedWidth({required bool pressScale}) async {
        await tester.pumpApp(
          Center(
            child: AppPressable(
              onTap: () {},
              pressScale: pressScale,
              child: const SizedBox(key: key, width: 100, height: 44),
            ),
          ),
          disableAnimations: false,
        );
        final press = await tester.startGesture(
          tester.getCenter(find.byKey(key)),
        );
        await tester.pumpAndSettle();
        final width = drawnWidth(tester);
        await press.up();
        await tester.pumpAndSettle();
        return width;
      }

      expect(await pressedWidth(pressScale: true), moreOrLessEquals(96));
      expect(await pressedWidth(pressScale: false), 100);
    });
  });
}
