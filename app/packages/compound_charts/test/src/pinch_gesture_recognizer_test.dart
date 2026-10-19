import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/src/pinch_gesture_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  group(PinchGestureRecognizer, () {
    late List<String> events;
    late ScrollController scroll;

    Future<Rect> pumpPinchable(WidgetTester tester) async {
      events = [];
      scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpApp(
        ListView(
          controller: scroll,
          children: [
            RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                PinchGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      PinchGestureRecognizer
                    >(PinchGestureRecognizer.new, (recognizer) {
                      recognizer
                        ..onStart = ((_) => events.add('start'))
                        ..onUpdate = ((d) => events.add('scale ${d.scale > 1}'))
                        ..onEnd = ((_) => events.add('end'));
                    }),
              },
              child: const SizedBox(key: Key('pinchable'), height: 300),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      );
      return tester.getRect(find.byKey(const Key('pinchable')));
    }

    testWidgets('wins as soon as a second finger lands', (tester) async {
      final area = await pumpPinchable(tester);
      final a = await tester.startGesture(area.center - const Offset(20, 0));
      final b = await tester.startGesture(area.center + const Offset(20, 0));
      expect(events, ['start']);
      await b.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(events.last, 'scale true');
      await a.up();
      await b.up();
      expect(events.last, 'end');
      expect(scroll.offset, 0);
    });

    testWidgets('lets a one-finger drag scroll the page', (tester) async {
      final area = await pumpPinchable(tester);
      final a = await tester.startGesture(area.center);
      // The first move only takes it past the slop.
      await a.moveBy(const Offset(0, -30));
      await a.moveBy(const Offset(0, -100));
      await tester.pump();
      // A finger landing once the first has moved is no pinch either.
      final b = await tester.startGesture(area.center + const Offset(40, 0));
      await b.moveBy(const Offset(40, 0));
      await a.up();
      await b.up();
      await tester.pump();
      expect(events, isEmpty);
      expect(scroll.offset, greaterThan(0));
    });
  });
}
