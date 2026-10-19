import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ChartData, () {
    final data = ChartData(
      start: DateTime(2026, 10, 12),
      end: DateTime(2026, 10, 19),
      series: [
        ChartSeries(
          label: 'a',
          color: const Color(0xFF000000),
          points: [
            (x: DateTime(2026, 10, 14), y: 1),
            (x: DateTime(2026, 10, 12), y: 2),
          ],
        ),
        ChartSeries(
          label: 'b',
          color: const Color(0xFF000000),
          mark: ChartMark.bar,
          points: [(x: DateTime(2026, 10, 14), y: 3)],
        ),
      ],
    );

    test('draws a point in the middle of its bucket', () {
      expect(data.fraction(DateTime(2026, 10, 12)), closeTo(1 / 14, 1e-9));
      expect(data.fraction(DateTime(2026, 10, 18)), closeTo(13 / 14, 1e-9));
      // Kept inside the window.
      expect(data.fraction(DateTime(2026, 10, 30)), 1);
    });

    test('lists each bucket once, oldest first', () {
      expect(data.buckets, [DateTime(2026, 10, 12), DateTime(2026, 10, 14)]);
    });

    test('defaults to a line on a tight axis, a day a point', () {
      expect(data.series.first.mark, ChartMark.line);
      expect(data.yFit, ChartYFit.tight);
      expect(data.bucketDays, 1);
    });
  });
}
