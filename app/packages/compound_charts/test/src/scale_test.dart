import 'package:app_ui/app_ui.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every label's width, as if each character were 7 wide.
double _measure(String text) => text.length * 7.0;

void _expectApart(List<ChartAxisLabel> labels, double width) {
  for (final (i, label) in labels.indexed) {
    expect(label.left, greaterThanOrEqualTo(0));
    expect(label.left + _measure(label.text), lessThanOrEqualTo(width));
    if (i > 0) {
      final before = labels[i - 1];
      expect(
        label.left,
        greaterThanOrEqualTo(
          before.left + _measure(before.text) + AppSpacing.s,
        ),
      );
    }
  }
}

void main() {
  group('niceTicks', () {
    test('steps 1, 2 or 5 times a power of ten around the values', () {
      expect(niceTicks(70.1, 74.6, 5), [70, 72, 74, 76]);
      expect(niceTicks(0, 2173, 5), [0, 1000, 2000, 3000]);
      expect(niceTicks(0, 4, 5), [0, 1, 2, 3, 4]);
      // A ratio steps in hundredths.
      expect(niceTicks(0.44, 0.5, 5), [0.44, 0.46, 0.48, 0.5]);
    });

    test('keeps to the count asked for', () {
      expect(niceTicks(0, 97, 2), [0, 100]);
      expect(niceTicks(0, 97, 3), [0, 50, 100]);
    });

    test('widens a flat series so it sits mid-axis', () {
      expect(niceTicks(70.3, 70.3, 5), [69.5, 70, 70.5, 71, 71.5]);
      expect(niceTicks(0, 0, 3), [-1, 0, 1]);
    });

    test('rounds away floating point', () {
      expect(niceTicks(0.1, 0.7, 5), [0, 0.2, 0.4, 0.6, 0.8]);
    });
  });

  group('fractionDigits', () {
    test('counts the decimals a step needs', () {
      expect(fractionDigits(1000), 0);
      expect(fractionDigits(1), 0);
      expect(fractionDigits(0.5), 1);
      expect(fractionDigits(0.02), 2);
    });
  });

  group('dateTicks', () {
    List<ChartAxisLabel> ticks(DateTime start, int days, double width) =>
        dateTicks(
          start: start,
          end: DateTime(start.year, start.month, start.day + days),
          width: width,
          measure: _measure,
          locale: 'en',
        );

    test('names each day of a week by its weekday', () {
      final labels = ticks(DateTime(2026, 10, 12), 7, 300);
      expect(labels.map((l) => l.text), [
        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
      ]);
      // Centred under each day.
      expect(labels.first.left, closeTo(300 / 14 - _measure('Mon') / 2, 1e-9));
      _expectApart(labels, 300);
    });

    test('thins the days evenly when they do not fit', () {
      final labels = ticks(DateTime(2026, 10, 12), 7, 120);
      expect(labels.map((l) => l.text), ['Mon', 'Wed', 'Fri', 'Sun']);
      _expectApart(labels, 120);
      expect(ticks(DateTime(2026, 10, 12), 7, 80).map((l) => l.text), [
        'Mon',
        'Thu',
        'Sun',
      ]);
    });

    test('dates the Mondays of a month, every week or fortnight', () {
      final wide = ticks(DateTime(2026, 9, 16), 30, 400);
      expect(wide.map((l) => l.text), ['Sep 21', 'Sep 28', 'Oct 5', 'Oct 12']);
      final narrow = ticks(DateTime(2026, 9, 16), 30, 200);
      expect(narrow.map((l) => l.text), ['Sep 21', 'Oct 5']);
      _expectApart(narrow, 200);
    });

    test('names the months of six months or a year', () {
      expect(ticks(DateTime(2026, 4, 17), 182, 300).map((l) => l.text), [
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
      ]);
      final year = ticks(DateTime(2025, 10), 365, 200);
      expect(year.first.text, 'Oct');
      expect(year.length, lessThan(12));
      _expectApart(year, 200);
    });

    test('keeps a label inside the plot', () {
      final labels = ticks(DateTime(2026, 10, 12), 2, 20);
      expect(labels, hasLength(1));
      expect(labels.single.left, 0);
    });

    test('thins the finest unit when no unit fits whole', () {
      // One Monday and no new month: the week's single label.
      final labels = ticks(DateTime(2026, 10, 13), 9, 50);
      expect(labels.map((l) => l.text), ['Oct 19']);
    });

    test('labels an empty window with nothing', () {
      expect(ticks(DateTime(2026, 10, 13), 0, 100), isEmpty);
    });
  });
}
