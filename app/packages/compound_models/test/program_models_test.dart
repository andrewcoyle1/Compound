import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

final _date = DateTime.utc(2026);

(String, double) _pair(ServingUnit unit) => (unit.name, unit.grams);

FoodModel _food({
  MeasurementMethod method = MeasurementMethod.weight,
  String? portionName,
  double? servingWeight,
  double? portionSize,
  String? weightPortionName,
  double? portionWeight,
  double? weightPortionSize,
  String? volumePortionName,
  double? portionVolume,
  double? volumePortionSize,
}) => FoodModel(
  ingredientId: 'food',
  name: 'Food',
  dateCreated: _date,
  dateModified: _date,
  measurementMethod: method,
  portionName: portionName,
  servingWeight: servingWeight,
  portionSize: portionSize,
  weightPortionName: weightPortionName,
  portionWeight: portionWeight,
  weightPortionSize: weightPortionSize,
  volumePortionName: volumePortionName,
  portionVolume: portionVolume,
  volumePortionSize: volumePortionSize,
);

void main() {
  group('FoodModel.servingUnits', () {
    test("reads a weighed food's two portions, as Swift does", () {
      // Swift's mockRolledOats: 40 g for half a cup.
      expect(
        _food(
          weightPortionName: 'cup',
          portionWeight: 40,
          weightPortionSize: 0.5,
        ).servingUnits.map(_pair).toList(),
        [('cup', 80)],
      );
      expect(
        _food(
          portionName: ' slice ',
          servingWeight: 30,
          weightPortionName: 'pack',
          portionWeight: 120,
          weightPortionSize: 4,
        ).servingUnits.map(_pair).toList(),
        [('slice', 30), ('pack', 30)],
      );
    });

    test("offers only a volume food's volume portion", () {
      // Swift's mockOliveOil: 14 ml for one tablespoon.
      expect(
        _food(
          method: MeasurementMethod.volume,
          portionName: 'slice',
          servingWeight: 30,
          volumePortionName: 'tbsp',
          portionVolume: 14,
          volumePortionSize: 1,
        ).servingUnits.map(_pair).toList(),
        [('tbsp', 14)],
      );
    });

    test('skips unusable portions and keeps the first of a name', () {
      expect(
        _food(
          portionName: 'G',
          servingWeight: 100,
        ).servingUnits.map(_pair).toList(),
        isEmpty,
      );
      expect(
        _food(
          portionName: '  ',
          servingWeight: 100,
        ).servingUnits.map(_pair).toList(),
        isEmpty,
      );
      expect(
        _food(portionName: 'cup').servingUnits.map(_pair).toList(),
        isEmpty,
      );
      expect(
        _food(
          portionName: 'cup',
          servingWeight: double.infinity,
        ).servingUnits.map(_pair).toList(),
        isEmpty,
      );
      expect(
        _food(
          portionName: 'cup',
          servingWeight: 0,
        ).servingUnits.map(_pair).toList(),
        isEmpty,
      );
      expect(
        _food(
          portionName: 'cup',
          servingWeight: 50,
          portionSize: 0,
          weightPortionName: 'cup',
          portionWeight: 80,
        ).servingUnits.map(_pair).toList(),
        [('cup', 50)],
      );
      expect(
        _food(
          portionName: 'cup',
          servingWeight: 50,
          portionSize: double.nan,
        ).servingUnits.map(_pair).toList(),
        [('cup', 50)],
      );
    });

    test('trims spaces and tabs but not line breaks, as Swift does', () {
      expect(
        _food(
          portionName: '\tcup ',
          servingWeight: 50,
        ).servingUnits.map(_pair).toList().single,
        ('cup', 50),
      );
      expect(
        _food(portionName: '\n', servingWeight: 50).servingUnits.single.name,
        '\n',
      );
    });
  });

  group('strict decoding', () {
    test('refuses an unknown deload, status or measurement method', () {
      final mesocycle = Mesocycle(
        id: 'm',
        authorId: 'u',
        name: 'M',
        icon: 'flag',
        colour: '#FFFFFF',
        workoutTemplates: const [],
        dateCreated: _date,
        dateModified: _date,
      ).toFirestore();
      expect(
        () => Mesocycle.fromFirestore({...mesocycle, 'deload': 'middle'}),
        throwsFormatException,
      );
      final macrocycle = Macrocycle(
        id: 'mc',
        authorId: 'u',
        name: 'MC',
        mesocycleIds: const ['m'],
        mesocycleStartedAt: _date,
        dateCreated: _date,
        dateModified: _date,
      ).toFirestore();
      expect(
        () => Macrocycle.fromFirestore({...macrocycle, 'status': 'paused'}),
        throwsFormatException,
      );
      expect(
        () => FoodModel.fromFirestore({
          ..._food().toFirestore(),
          'measurement_method': 'count',
        }),
        throwsFormatException,
      );
    });
  });
}
