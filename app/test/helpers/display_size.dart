import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// An iPhone 17's window, in points.
const phoneSize = Size(402, 874);

/// An 11-inch iPad Air's window, in points.
const tabletSize = Size(820, 1180);

extension DisplaySize on WidgetTester {
  /// Sizes the window, in points, until the test ends. The test default
  /// (800 × 600) is wide enough for the tablet layouts.
  void useSize(Size size) {
    view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
  }
}
