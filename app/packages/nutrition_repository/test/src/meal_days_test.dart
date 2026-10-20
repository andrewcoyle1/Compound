import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

MealLogModel _meal(String id, String dayKey, int hour) => MealLogModel(
  mealId: id,
  authorId: 'me',
  dayKey: dayKey,
  date: DateTime.utc(2026, 10, int.parse(dayKey.substring(8)), hour),
  items: const [],
);

MealLogModel _healthImport(String dayKey) =>
    _meal(MealLogModel.healthKitMealId(dayKey), dayKey, 12);

void main() {
  group('withoutDuplicateHealthImports', () {
    test("drops a day's Apple Health import when meals were logged", () {
      final kept = withoutDuplicateHealthImports([
        _healthImport('2026-10-12'),
        _meal('breakfast', '2026-10-12', 8),
      ]);
      expect(kept.map((m) => m.mealId), ['breakfast']);
    });

    test('keeps the import on a day with nothing else logged', () {
      final kept = withoutDuplicateHealthImports([
        _healthImport('2026-10-11'),
        _meal('breakfast', '2026-10-12', 8),
      ]);
      expect(kept.map((m) => m.mealId), [
        'healthkit-nutrition-2026-10-11',
        'breakfast',
      ]);
    });

    test('treats a meal whose id names another day as logged', () {
      final stray = _meal('healthkit-nutrition-2026-10-11', '2026-10-12', 9);
      final kept = withoutDuplicateHealthImports([
        _healthImport('2026-10-12'),
        stray,
      ]);
      expect(kept, [stray]);
    });

    test('keeps everything when nothing came from Apple Health', () {
      final meals = [_meal('a', '2026-10-12', 8), _meal('b', '2026-10-13', 8)];
      expect(withoutDuplicateHealthImports(meals), meals);
    });
  });

  group('mealsByDay', () {
    test('groups by day key, days ascending and meals in time order', () {
      final dinner = _meal('dinner', '2026-10-12', 19);
      final breakfast = _meal('breakfast', '2026-10-12', 8);
      final earlier = _meal('earlier', '2026-10-11', 21);

      final days = mealsByDay([dinner, breakfast, earlier]);

      expect(days.keys, ['2026-10-11', '2026-10-12']);
      expect(days['2026-10-11'], [earlier]);
      expect(days['2026-10-12'], [breakfast, dinner]);
    });

    test('orders by day key even when a date says otherwise', () {
      // Logged while travelling: the later day key was eaten earlier in UTC.
      final travelling = MealLogModel(
        mealId: 'travelling',
        authorId: 'me',
        dayKey: '2026-10-13',
        date: DateTime.utc(2026, 10, 12, 23),
        items: const [],
      );
      final home = _meal('home', '2026-10-12', 23);
      expect(mealsByDay([travelling, home]).keys, ['2026-10-12', '2026-10-13']);
    });

    test('is empty for no meals', () {
      expect(mealsByDay(const []), isEmpty);
    });
  });
}
