import 'dart:ui' as ui;

import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('renderWidgetPng', () {
    testWidgets('draws the widget at its size times the pixel ratio', (
      tester,
    ) async {
      final pixels = await tester.runAsync(() async {
        final png = await renderWidgetPng(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 10,
                height: 10,
                child: ColoredBox(color: Color(0xFFFF0000)),
              ),
            ),
          ),
          size: const Size(40, 20),
          pixelRatio: 3,
        );
        final codec = await ui.instantiateImageCodec(png);
        final image = (await codec.getNextFrame()).image;
        return (image.width, image.height, (await image.toByteData())!);
      });
      final (width, height, bytes) = pixels!;
      expect((width, height), (120, 60));
      // Red inside the box, transparent outside it.
      expect(bytes.getUint32(0), 0xFF0000FF);
      expect(bytes.getUint32((59 * width + 119) * 4), 0);
    });
  });
}
