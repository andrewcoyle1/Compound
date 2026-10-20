import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

void main() {
  group('LoggingBreak.isOpenAt', () {
    final start = DateTime.utc(2026, 10, 10, 9);
    LoggingBreak at({DateTime? end}) =>
        LoggingBreak(authorId: 'u', startDate: start, endDate: end);

    test('is open from its start while it has no end', () {
      expect(at().isOpenAt(start), isTrue);
      expect(at().isOpenAt(start.add(const Duration(days: 3))), isTrue);
    });

    test('is not open before it starts, or once ended', () {
      expect(
        at().isOpenAt(start.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(at(end: start).isOpenAt(start), isFalse);
    });
  });

  group('NutritionDayAnnotation.isEmpty', () {
    NutritionDayAnnotation annotation({
      bool partial = false,
      bool fast = false,
    }) => NutritionDayAnnotation(
      dayKey: '2026-10-12',
      authorId: 'u',
      dateModified: DateTime.utc(2026, 10, 13),
      isPartiallyLogged: partial,
      isFastingDay: fast,
    );

    test('says nothing only with both flags off', () {
      expect(annotation().isEmpty, isTrue);
      expect(annotation(partial: true).isEmpty, isFalse);
      expect(annotation(fast: true).isEmpty, isFalse);
    });
  });

  test('Cunningham is stored as katchMcArdle', () {
    expect(BmrEquation.cunningham.value, 'katchMcArdle');
  });
}
