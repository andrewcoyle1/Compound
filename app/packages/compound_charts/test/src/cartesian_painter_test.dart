import 'dart:math' as math;

import 'package:compound_charts/src/cartesian_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monotoneCubics', () {
    void expectNoOvershoot(List<Offset> points) {
      final segments = monotoneCubics(points);
      expect(segments, hasLength(points.length - 1));
      for (final (i, (c1, c2, end)) in segments.indexed) {
        final from = points[i];
        expect(end, points[i + 1]);
        final low = math.min(from.dy, end.dy) - 1e-9;
        final high = math.max(from.dy, end.dy) + 1e-9;
        // A Bézier stays inside its control points' hull, so controls
        // between the ends mean the curve is too.
        for (final control in [c1, c2]) {
          expect(control.dy, inInclusiveRange(low, high), reason: '$i');
          expect(control.dx, inInclusiveRange(from.dx, end.dx), reason: '$i');
        }
      }
    }

    test('never overshoots a peak, a trough or a step', () {
      expectNoOvershoot(const [
        Offset(0, 50),
        Offset(10, 10),
        Offset(20, 90),
        Offset(30, 89),
        Offset(40, 89),
        Offset(45, 0),
        Offset(90, 1),
        Offset(100, 100),
      ]);
    });

    test('never overshoots a steep run', () {
      expectNoOvershoot(const [
        Offset.zero,
        Offset(1, 100),
        Offset(2, 101),
        Offset(50, 102),
        Offset(51, 200),
      ]);
    });

    test('keeps a straight line straight', () {
      final segments = monotoneCubics(const [
        Offset.zero,
        Offset(30, 30),
        Offset(60, 60),
      ]);
      expect(segments.first.$1, const Offset(10, 10));
      expect(segments.last.$2, const Offset(50, 50));
    });

    test('has no segment for fewer than two points', () {
      expect(monotoneCubics(const []), isEmpty);
      expect(monotoneCubics(const [Offset(1, 1)]), isEmpty);
    });

    test('takes two points at one x as flat', () {
      expectNoOvershoot(const [Offset.zero, Offset(0, 10), Offset(10, 20)]);
    });
  });
}
