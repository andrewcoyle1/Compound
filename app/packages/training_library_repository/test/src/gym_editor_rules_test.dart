import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

typedef _Rules = GymEditorRules;
typedef _List = GymEquipmentList;

const ExerciseWeightUnit _kg = ExerciseWeightUnit.kilograms;
const ExerciseWeightUnit _lb = ExerciseWeightUnit.pounds;

final _date = DateTime.utc(2026, 10, 16);

/// A gym holding only what is given (Swift's
/// `GymProfileModel(id:authorId:name:freeWeights:)` in the tests).
GymProfileModel _gym({
  List<FreeWeights> freeWeights = const [],
  List<LoadableBars> loadableBars = const [],
  List<FixedWeightBars> fixedWeightBars = const [],
  List<Bands> bands = const [],
  List<BodyWeights> bodyWeights = const [],
  List<StackMachine> cableMachines = const [],
  List<StackMachine> pinLoadedMachines = const [],
  List<PlateLoadedMachine> plateLoadedMachines = const [],
}) => GymProfileModel(
  id: 'gym-1',
  authorId: 'author-1',
  name: 'Home Gym',
  icon: 'dumbbell',
  dateCreated: _date,
  dateModified: _date,
  freeWeights: freeWeights,
  loadableBars: loadableBars,
  fixedWeightBars: fixedWeightBars,
  bands: bands,
  bodyWeights: bodyWeights,
  supportEquipment: const [],
  accessoryEquipment: const [],
  loadableAccessoryEquipment: const [],
  cableMachines: cableMachines,
  plateLoadedMachines: plateLoadedMachines,
  pinLoadedMachines: pinLoadedMachines,
);

/// The whole catalogue, as a new gym starts.
GymProfileModel _catalogueGym() {
  final catalogue = GymEquipmentCatalogue.instance;
  return GymProfileModel(
    id: 'gym-1',
    authorId: 'author-1',
    name: 'Home Gym',
    icon: 'dumbbell',
    dateCreated: _date,
    dateModified: _date,
    freeWeights: catalogue.freeWeights,
    loadableBars: catalogue.loadableBars,
    fixedWeightBars: catalogue.fixedWeightBars,
    bands: catalogue.bands,
    bodyWeights: catalogue.bodyWeights,
    supportEquipment: catalogue.supportEquipment,
    accessoryEquipment: catalogue.accessoryEquipment,
    loadableAccessoryEquipment: catalogue.loadableAccessoryEquipment,
    cableMachines: catalogue.cableMachines,
    plateLoadedMachines: catalogue.plateLoadedMachines,
    pinLoadedMachines: catalogue.pinLoadedMachines,
  );
}

FreeWeights _freeWeight(
  String name, {
  String? id,
  bool isActive = false,
  bool isPlates = false,
  bool needsColour = false,
  List<FreeWeightsAvailable> range = const [],
}) => FreeWeights(
  id: id ?? name.toLowerCase(),
  typeId: id ?? name.toLowerCase(),
  name: name,
  needsColour: needsColour,
  isPlates: isPlates,
  range: range,
  isActive: isActive,
);

FreeWeightsAvailable _plate(double weight, [ExerciseWeightUnit unit = _kg]) =>
    FreeWeightsAvailable(
      id: 'plate-$weight-${unit.value}',
      availableWeights: weight,
      unit: unit,
      isActive: true,
    );

BarBaseWeight _bar(double weight, [ExerciseWeightUnit unit = _kg]) =>
    BarBaseWeight(
      id: 'bar-$weight-${unit.value}',
      baseWeight: weight,
      unit: unit,
      isActive: true,
    );

LoadableBars _loadableBars(List<BarBaseWeight> weights, {String? defaultId}) =>
    LoadableBars(
      id: 'barbell-x',
      typeId: 'barbell-x',
      name: 'Barbell',
      baseWeights: weights,
      collarWeight: 0,
      isActive: true,
      defaultBaseWeightId: defaultId,
    );

FixedWeightBars _fixedBars(List<BarBaseWeight> weights, {String? defaultId}) =>
    FixedWeightBars(
      id: 'ez-x',
      typeId: 'ez-x',
      name: 'Fixed EZ Bar',
      baseWeights: weights,
      isActive: true,
      defaultBaseWeightId: defaultId,
    );

BandsAvailable _band(double resistance, {String name = 'Light'}) =>
    BandsAvailable(
      id: 'band-$resistance',
      name: name,
      bandColour: '#FF0000',
      availableResistance: resistance,
      unit: _kg,
      isActive: true,
    );

Bands _bands(List<BandsAvailable> range) => Bands(
  id: 'bands-x',
  typeId: 'bands-x',
  name: 'Long Bands',
  range: range,
  isActive: true,
);

BodyWeightsAvailable _bodyWeight(double weight) => BodyWeightsAvailable(
  id: 'body-$weight',
  availableWeights: weight,
  unit: _kg,
  isActive: true,
);

BodyWeights _bodyWeights(List<BodyWeightsAvailable> range) => BodyWeights(
  id: 'belt-x',
  typeId: 'belt-x',
  name: 'Dip Belt',
  range: range,
  isActive: true,
);

WeightStack _stack(
  String name, {
  double min = 0,
  double max = 100,
  double increment = 5,
  ExerciseWeightUnit unit = _kg,
  bool isActive = true,
  List<double> addOns = const [],
  List<double>? weights,
}) => WeightStack(
  id: 'cable-$name',
  name: name,
  minWeight: min,
  maxWeight: max,
  increment: increment,
  unit: unit,
  isActive: isActive,
  addOns: addOns,
  weights: weights,
);

StackMachine _cable(List<WeightStack> ranges, {String? defaultId}) =>
    StackMachine(
      id: 'lat-pulldown',
      typeId: 'lat-pulldown',
      name: 'Lat Pulldown',
      ranges: ranges,
      isActive: true,
      defaultRangeId: defaultId,
    );

List<String> _ids(Iterable<Object> items) => [
  for (final item in items)
    switch (item) {
      final GymEquipmentItem item => item.id,
      final WeightEntry entry => entry.id,
      final WeightStack stack => stack.id,
      _ => '$item',
    },
];

String Function() _counter() {
  var next = 0;
  return () => 'new-${next++}';
}

void main() {
  group(GymEquipmentList, () {
    test('reads, decodes and lists every list', () {
      final gym = _catalogueGym();
      for (final list in _List.values) {
        final items = list.of(gym);
        expect(items, isNotEmpty, reason: list.name);
        expect(_ids(list.catalogue), _ids(items), reason: list.name);
        final decoded = list.decode(items.first.toFirestore());
        expect(decoded.toFirestore(), items.first.toFirestore());
        expect(list.key, isNotEmpty);
      }
    });

    test('names the machines and the lists with weights', () {
      expect(
        [
          for (final list in _List.values)
            if (list.isMachine) list,
        ],
        [
          _List.cableMachines,
          _List.plateLoadedMachines,
          _List.pinLoadedMachines,
        ],
      );
      expect(_List.supportEquipment.entriesKey, isNull);
      expect(_List.cableMachines.valueKey, isNull);
      expect(_List.bands.valueKey, GymEquipmentKeys.availableResistance);
      expect(_List.fixedWeightBars.entriesKey, GymEquipmentKeys.baseWeights);
    });
  });

  group('the equipment list (GymProfilePresenter)', () {
    final dumbbells = _freeWeight('Dumbbells', isActive: true);
    final kettlebells = _freeWeight('Kettlebells');

    List<String> names(GymProfileModel gym, {String query = '', bool? sel}) => [
      for (final item in _Rules.visibleItems(
        gym,
        _List.freeWeights,
        query: query,
        selectedOnly: sel ?? false,
      ))
        _Rules.nameOf(item),
    ];

    test('every piece of equipment is listed by default', () {
      expect(names(_gym(freeWeights: [dumbbells, kettlebells])), hasLength(2));
    });

    test('equipment is listed in name order', () {
      final gym = _gym(
        freeWeights: [kettlebells, dumbbells, _freeWeight('Medicine Balls')],
      );
      expect(names(gym), ['Dumbbells', 'Kettlebells', 'Medicine Balls']);
    });

    test('case does not affect the order', () {
      final gym = _gym(
        freeWeights: [
          _freeWeight('kettlebells', id: 'k'),
          _freeWeight('Dumbbells', id: 'd'),
        ],
      );
      expect(_ids(_Rules.visibleItems(gym, _List.freeWeights)), ['d', 'k']);
    });

    test('equal names keep their original order', () {
      final gym = _gym(
        freeWeights: [
          _freeWeight('Dumbbells', id: 'first'),
          _freeWeight('Dumbbells', id: 'second'),
        ],
      );
      expect(_ids(_Rules.visibleItems(gym, _List.freeWeights)), [
        'first',
        'second',
      ]);
    });

    test('searching narrows the list, ignoring case', () {
      final gym = _gym(freeWeights: [dumbbells, kettlebells]);
      expect(names(gym, query: 'dumb'), ['Dumbbells']);
      expect(names(gym, query: 'DUMBBELLS'), ['Dumbbells']);
    });

    test('a whitespace query is no query at all', () {
      final gym = _gym(freeWeights: [dumbbells, kettlebells]);
      expect(names(gym, query: '   '), hasLength(2));
    });

    test('a query matching nothing empties the list', () {
      final gym = _gym(freeWeights: [dumbbells]);
      expect(names(gym, query: 'treadmill'), isEmpty);
    });

    test('no matching equipment needs a query that hides everything', () {
      final gym = _gym(freeWeights: [dumbbells]);
      bool hides(String query) =>
          _Rules.hidesEverything(gym, query: query, selectedOnly: false);
      expect(hides(''), isFalse);
      expect(hides('dumb'), isFalse);
      expect(hides('treadmill'), isTrue);
    });

    test('the selected filter shows only equipment the gym has', () {
      final gym = _gym(freeWeights: [dumbbells, kettlebells]);
      expect(names(gym, sel: true), ['Dumbbells']);
    });

    test('search and the selected filter apply together', () {
      final gym = _gym(
        freeWeights: [
          dumbbells,
          _freeWeight('Kettlebells', isActive: true),
          _freeWeight('Dumbbell Rack', id: 'rack'),
        ],
      );
      expect(names(gym, query: 'dumbbell', sel: true), ['Dumbbells']);
    });

    test("a row's switch writes back to the right item", () {
      final gym = _gym(
        freeWeights: [
          _freeWeight('Kettlebells', id: 'kettlebells'),
          _freeWeight('Dumbbells', id: 'dumbbells'),
        ],
      );
      final first = _Rules.visibleItems(gym, _List.freeWeights).first;
      final edited = _Rules.settingActive(
        gym,
        _List.freeWeights,
        first.id,
        isActive: true,
      );
      bool active(String id) =>
          _Rules.item(edited, _List.freeWeights, id)!.isActive;
      expect(active('dumbbells'), isTrue);
      expect(active('kettlebells'), isFalse);
    });

    test('an edit is visible on the next read; a gone item writes nothing', () {
      final gym = _gym(freeWeights: [dumbbells]);
      final renamed = _Rules.updatingItem(
        gym,
        _List.freeWeights,
        dumbbells.id,
        (data) => {...data, GymEquipmentKeys.name: 'Hex Dumbbells'},
      );
      expect(names(renamed, query: 'hex'), ['Hex Dumbbells']);
      final untouched = _Rules.updatingItem(
        gym,
        _List.freeWeights,
        'gone',
        (data) => {...data, GymEquipmentKeys.name: 'X'},
      );
      expect(_Rules.item(untouched, _List.freeWeights, 'gone'), isNull);
      expect(names(untouched, query: 'dumbbells'), ['Dumbbells']);
    });

    test('renaming a gym keeps everything else', () {
      final gym = _gym(freeWeights: [dumbbells]);
      final renamed = _Rules.renamed(gym, 'Garage Gym');
      expect(renamed.name, 'Garage Gym');
      expect(renamed.id, gym.id);
      expect(_Rules.item(renamed, _List.freeWeights, dumbbells.id), isNotNull);
    });
  });

  group('the weight editors', () {
    final mixedRack = [_plate(10), _plate(20, _lb), _plate(15)];
    final gym = _gym(
      freeWeights: [
        _freeWeight('Plates', id: 'plates-x', isPlates: true, range: mixedRack),
      ],
    );
    FreeWeights rack(GymProfileModel gym) =>
        _Rules.item(gym, _List.freeWeights, 'plates-x')! as FreeWeights;

    test("only the chosen unit's weights are listed, lightest first", () {
      final item = rack(gym);
      expect(_ids(_Rules.weights(_List.freeWeights, item, _kg)), [
        'plate-10.0-kilograms',
        'plate-15.0-kilograms',
      ]);
      expect(_ids(_Rules.weights(_List.freeWeights, item, _lb)), [
        'plate-20.0-pounds',
      ]);
    });

    test("a weight's figure is read back by its own identifier", () {
      final weight = _Rules.allWeights(
        _List.freeWeights,
        rack(gym),
      ).firstWhere((entry) => entry.id == 'plate-15.0-kilograms');
      expect(weight.value, 15);
      expect(weight.name, isNull);
    });

    test('editing one weight leaves the others alone', () {
      final edited = _Rules.updatingEntry(
        gym,
        _List.freeWeights,
        'plates-x',
        'plate-15.0-kilograms',
        (entry) => {...entry, GymEquipmentKeys.availableWeights: 17.5},
      );
      final range = rack(edited).range;
      expect([for (final w in range) w.availableWeights], [10, 20, 17.5]);
      expect([for (final w in range) w.unit], [_kg, _lb, _kg]);
    });

    test('editing a weight that is gone changes nothing', () {
      final edited = _Rules.updatingEntry(
        gym,
        _List.freeWeights,
        'plates-x',
        'missing',
        (entry) => {...entry, GymEquipmentKeys.availableWeights: 99},
      );
      expect(
        [for (final w in rack(edited).range) w.availableWeights],
        [10, 20, 15],
      );
    });

    test("deleting a row deletes that row's weight", () {
      final pounds = _Rules.weights(_List.freeWeights, rack(gym), _lb);
      final edited = _Rules.deletingEntries(
        gym,
        _List.freeWeights,
        'plates-x',
        {pounds.first.id},
      );
      expect(_ids(rack(edited).range.map((w) => w.id)), [
        'plate-10.0-kilograms',
        'plate-15.0-kilograms',
      ]);
    });

    test('deleting several rows leaves the rest intact', () {
      final edited = _Rules.deletingEntries(
        gym,
        _List.freeWeights,
        'plates-x',
        {'plate-10.0-kilograms', 'plate-15.0-kilograms'},
      );
      expect(rack(edited).range.single.id, 'plate-20.0-pounds');
    });

    test('deleting a row that is gone deletes nothing', () {
      final edited = _Rules.deletingEntries(
        gym,
        _List.freeWeights,
        'plates-x',
        {'missing'},
      );
      expect(rack(edited).range, hasLength(3));
    });

    test('a plate count is written to its own plate', () {
      expect(_Rules.plateCount(null), isNull);
      expect(_Rules.plateCount(4.7), 4);
      expect(_Rules.plateCount(-2), 0);
      final counted = _Rules.updatingEntry(
        gym,
        _List.freeWeights,
        'plates-x',
        'plate-15.0-kilograms',
        (entry) => {...entry, GymEquipmentKeys.count: _Rules.plateCount(4.7)},
      );
      expect([for (final w in rack(counted).range) w.count], [null, null, 4]);
      expect(_Rules.allWeights(_List.freeWeights, rack(counted)).last.count, 4);
    });

    test('free weights, bands and body weights open on kilograms', () {
      expect(_Rules.openingUnit(_List.freeWeights, rack(gym)), _kg);
    });

    test("a bar rack opens on its default bar's unit", () {
      final loadable = _loadableBars([
        _bar(45, _lb),
        _bar(20),
      ], defaultId: 'bar-45.0-pounds');
      final fixed = _fixedBars([
        _bar(45, _lb),
        _bar(20),
      ], defaultId: 'bar-45.0-pounds');
      expect(_Rules.openingUnit(_List.loadableBars, loadable), _lb);
      expect(_Rules.openingUnit(_List.fixedWeightBars, fixed), _lb);
    });

    test('an empty rack opens on kilograms', () {
      expect(_Rules.openingUnit(_List.loadableBars, _loadableBars([])), _kg);
    });

    test("a machine opens on its default stack's unit", () {
      final machine = _cable([
        _stack('a'),
        _stack('b', unit: _lb),
      ], defaultId: 'cable-b');
      expect(_Rules.openingUnit(_List.cableMachines, machine), _lb);
      expect(_Rules.openingUnit(_List.cableMachines, _cable([])), _kg);
    });

    test("only the chosen unit's bars are listed; editing and deleting one "
        'leaves the others alone', () {
      final bars = _gym(
        loadableBars: [
          _loadableBars([_bar(20), _bar(45, _lb), _bar(15)]),
        ],
        fixedWeightBars: [
          _fixedBars([_bar(20), _bar(45, _lb)]),
        ],
      );
      final loadable = _Rules.item(bars, _List.loadableBars, 'barbell-x')!;
      expect(_ids(_Rules.weights(_List.loadableBars, loadable, _lb)), [
        'bar-45.0-pounds',
      ]);
      final edited = _Rules.updatingEntry(
        bars,
        _List.loadableBars,
        'barbell-x',
        'bar-15.0-kilograms',
        (entry) => {...entry, GymEquipmentKeys.baseWeight: 12},
      );
      final weights = _Rules.allWeights(
        _List.loadableBars,
        _Rules.item(edited, _List.loadableBars, 'barbell-x')!,
      );
      expect([for (final w in weights) w.value], [20, 45, 12]);
      final deleted = _Rules.deletingEntries(
        bars,
        _List.fixedWeightBars,
        'ez-x',
        {'bar-45.0-pounds'},
      );
      final fixed = _Rules.item(deleted, _List.fixedWeightBars, 'ez-x')!;
      expect(_ids(_Rules.allWeights(_List.fixedWeightBars, fixed)), [
        'bar-20.0-kilograms',
      ]);
    });

    test("a band's resistance and label are read back by its own id", () {
      final bands = _gym(
        bands: [
          _bands([_band(10), _band(20, name: 'Heavy')]),
        ],
      );
      final item = _Rules.item(bands, _List.bands, 'bands-x')!;
      final heavy = _Rules.weights(_List.bands, item, _kg).last;
      expect(heavy.value, 20);
      expect(heavy.name, 'Heavy');
      expect(heavy.colour, '#FF0000');
      final renamed = _Rules.updatingEntry(
        bands,
        _List.bands,
        'bands-x',
        'band-10.0',
        (entry) => {...entry, GymEquipmentKeys.name: 'Light Blue'},
      );
      final names = [
        for (final entry in _Rules.allWeights(
          _List.bands,
          _Rules.item(renamed, _List.bands, 'bands-x')!,
        ))
          entry.name,
      ];
      expect(names, ['Light Blue', 'Heavy']);
    });

    test('a body weight is deleted by its own row', () {
      final belts = _gym(
        bodyWeights: [
          _bodyWeights([_bodyWeight(10), _bodyWeight(20)]),
        ],
      );
      final edited = _Rules.deletingEntries(
        belts,
        _List.bodyWeights,
        'belt-x',
        {'body-10.0'},
      );
      expect(
        _ids(
          _Rules.allWeights(
            _List.bodyWeights,
            _Rules.item(edited, _List.bodyWeights, 'belt-x')!,
          ),
        ),
        ['body-20.0'],
      );
    });

    test('a collar weight is stored in kilograms', () {
      final bar = _loadableBars([_bar(20)]);
      expect(_Rules.collarShown(bar, _kg), isNull);
      final stored = _Rules.collarStored(5.512, _lb);
      expect(stored, closeTo(2.5, 0.001));
      final collared = LoadableBars.fromFirestore({
        ...bar.toFirestore(),
        GymEquipmentKeys.collarWeight: stored,
      });
      expect(_Rules.collarShown(collared, _lb), 5.512);
      expect(_Rules.collarShown(collared, _kg), 2.5);
      expect(_Rules.collarStored(null, _kg), 0);
      expect(_Rules.collarStored(-3, _kg), 0);
    });
  });

  group('adding a weight', () {
    final plates = _freeWeight(
      'Plates',
      id: 'plates-x',
      isPlates: true,
      range: [_plate(20)],
    );

    AddWeightProblem? problem(
      GymEquipmentList list,
      GymEquipmentItem item, {
      double value = 0,
      ExerciseWeightUnit unit = _kg,
      int? count,
      String name = '',
    }) => _Rules.addWeightProblem(
      list,
      item,
      value: value,
      unit: unit,
      count: count,
      name: name,
    );

    test('a free weight is prepared in the unit the list was showing, with '
        'its colour and count', () {
      final entry = _Rules.newWeight(
        _List.freeWeights,
        id: 'w',
        value: 25,
        unit: _lb,
        colour: '#FF4245',
        count: 2,
      );
      final added = _Rules.addingEntry(
        _gym(freeWeights: [plates]),
        _List.freeWeights,
        'plates-x',
        entry,
      );
      final weight =
          (_Rules.item(added, _List.freeWeights, 'plates-x')! as FreeWeights)
              .range
              .last;
      expect(weight.availableWeights, 25);
      expect(weight.unit, _lb);
      expect(weight.plateColour, '#FF4245');
      expect(weight.count, 2);
      expect(weight.isActive, isTrue);
      expect(
        _Rules.newWeight(_List.freeWeights, id: 'w', value: 5, unit: _kg),
        isNot(contains(GymEquipmentKeys.plateColour)),
      );
    });

    test('a free weight needs a weight, and a count of at least one', () {
      expect(problem(_List.freeWeights, plates), AddWeightProblem.notAboveZero);
      expect(
        problem(_List.freeWeights, plates, value: 10, count: 0),
        AddWeightProblem.countBelowOne,
      );
      expect(problem(_List.freeWeights, plates, value: 10, count: 1), isNull);
      expect(problem(_List.freeWeights, plates, value: 10), isNull);
    });

    test('a free weight already held is not added again', () {
      expect(
        problem(_List.freeWeights, plates, value: 20),
        AddWeightProblem.duplicate,
      );
    });

    test('the same figure in the other unit is a different weight', () {
      expect(problem(_List.freeWeights, plates, value: 20, unit: _lb), isNull);
    });

    test('a body weight is added in its unit; one already held is not; the '
        'first can always be added', () {
      final belt = _bodyWeights([_bodyWeight(10)]);
      expect(
        problem(_List.bodyWeights, belt, value: 10),
        AddWeightProblem.duplicate,
      );
      expect(problem(_List.bodyWeights, _bodyWeights([]), value: 10), isNull);
      // Swift asks for no weight above zero here.
      expect(problem(_List.bodyWeights, _bodyWeights([])), isNull);
      final entry = _Rules.newWeight(
        _List.bodyWeights,
        id: 'b',
        value: 5,
        unit: _lb,
      );
      expect(BodyWeightsAvailable.fromFirestore(entry).unit, _lb);
    });

    test('a bar weight is added; one held is not; the other unit is its own '
        'bar; zero cannot be added', () {
      final bar = _loadableBars([_bar(20)]);
      expect(
        problem(_List.loadableBars, bar, value: 20),
        AddWeightProblem.duplicate,
      );
      expect(problem(_List.loadableBars, bar, value: 20, unit: _lb), isNull);
      expect(
        problem(_List.fixedWeightBars, _fixedBars([])),
        AddWeightProblem.notAboveZero,
      );
      expect(problem(_List.fixedWeightBars, _fixedBars([]), value: 8), isNull);
      final entry = _Rules.newWeight(
        _List.loadableBars,
        id: 'b',
        value: 15,
        unit: _kg,
      );
      expect(BarBaseWeight.fromFirestore(entry).baseWeight, 15);
    });

    test('a band needs a name, after a resistance not already held', () {
      final bands = _bands([_band(10)]);
      expect(
        problem(_List.bands, bands, value: 10),
        AddWeightProblem.duplicate,
      );
      expect(problem(_List.bands, bands, value: 15), AddWeightProblem.noName);
      expect(problem(_List.bands, bands, value: 15, name: 'Red'), isNull);
    });

    test('a chosen band colour travels with the band, in its unit', () {
      final band = BandsAvailable.fromFirestore(
        _Rules.newWeight(
          _List.bands,
          id: 'b',
          value: 15,
          unit: _lb,
          colour: '#0091FF',
          name: 'Blue',
        ),
      );
      expect(band.bandColour, '#0091FF');
      expect(band.name, 'Blue');
      expect(band.unit, _lb);
    });
  });

  group('stacks', () {
    final machine = _cable([
      _stack('Zeta'),
      _stack('alpha', unit: _lb),
      _stack('Beta'),
    ], defaultId: 'cable-Zeta');
    final gym = _gym(cableMachines: [machine]);
    StackMachine read(GymProfileModel gym) =>
        _Rules.item(gym, _List.cableMachines, 'lat-pulldown')! as StackMachine;

    test("stacks are listed by name, the chosen unit's only", () {
      expect(_ids(_Rules.stacks(machine, _kg)), ['cable-Beta', 'cable-Zeta']);
      expect(_ids(_Rules.stacks(machine, _lb)), ['cable-alpha']);
      final twins = _cable([
        _stack('Same'),
        WeightStack.fromFirestore({
          ..._stack('Same').toFirestore(),
          GymEquipmentKeys.id: 'a-first',
        }),
      ]);
      expect(_ids(_Rules.stacks(twins, _kg)), ['a-first', 'cable-Same']);
    });

    test('editing a stack changes only the stack tapped', () {
      final edited = _Rules.updatingEntry(
        gym,
        _List.cableMachines,
        'lat-pulldown',
        'cable-Beta',
        (_) => _stack('Beta', max: 150).toFirestore(),
      );
      expect(
        [for (final s in read(edited).ranges) s.maxWeight],
        [100, 100, 150],
      );
    });

    test('deleting the default stack points the default at what remains', () {
      final withInactive = _gym(
        cableMachines: [
          _cable([
            _stack('a'),
            _stack('b', isActive: false),
            _stack('c'),
          ], defaultId: 'cable-a'),
        ],
      );
      final edited = _Rules.deletingEntries(
        withInactive,
        _List.cableMachines,
        'lat-pulldown',
        {'cable-a'},
      );
      expect(read(edited).defaultRangeId, 'cable-c');
      final allInactive = _gym(
        cableMachines: [
          _cable([
            _stack('a'),
            _stack('b', isActive: false),
          ], defaultId: 'cable-a'),
        ],
      );
      expect(
        read(
          _Rules.deletingEntries(
            allInactive,
            _List.cableMachines,
            'lat-pulldown',
            {'cable-a'},
          ),
        ).defaultRangeId,
        'cable-b',
      );
      expect(
        read(
          _Rules.deletingEntries(
            allInactive,
            _List.cableMachines,
            'lat-pulldown',
            {'cable-a', 'cable-b'},
          ),
        ).defaultRangeId,
        isNull,
      );
    });

    test('deleting another stack keeps the default', () {
      final edited = _Rules.deletingEntries(
        gym,
        _List.cableMachines,
        'lat-pulldown',
        {'cable-Beta'},
      );
      expect(read(edited).defaultRangeId, 'cable-Zeta');
      expect(read(edited).ranges, hasLength(2));
    });

    test('the first stack becomes the default; a later one does not', () {
      final empty = _gym(cableMachines: [_cable([])]);
      final first = _Rules.addingEntry(
        empty,
        _List.cableMachines,
        'lat-pulldown',
        _stack('One').toFirestore(),
      );
      expect(read(first).defaultRangeId, 'cable-One');
      final second = _Rules.addingEntry(
        first,
        _List.cableMachines,
        'lat-pulldown',
        _stack('Two').toFirestore(),
      );
      expect(read(second).defaultRangeId, 'cable-One');
      expect(read(second).ranges, hasLength(2));
    });

    test('a new stack opens on the unit being viewed', () {
      final kilograms = _Rules.newStack(id: 's', unit: _kg);
      expect(
        [kilograms.minWeight, kilograms.maxWeight, kilograms.increment],
        [2.5, 150, 2.5],
      );
      final pounds = _Rules.newStack(id: 's', unit: _lb);
      expect([pounds.minWeight, pounds.increment, pounds.unit], [5, 5, _lb]);
      expect(pounds.name, isEmpty);
      expect(pounds.isActive, isTrue);
    });

    group('adding a stack (AddWeightStackPresenter)', () {
      final existing = [_stack('Main', min: 5)];
      WeightStack draft({
        String name = 'Second',
        double min = 5,
        double max = 150,
        double increment = 5,
        ExerciseWeightUnit unit = _kg,
      }) => WeightStack(
        id: 'draft',
        name: name,
        minWeight: min,
        maxWeight: max,
        increment: increment,
        unit: unit,
        isActive: true,
      );

      test('a stack must start below where it ends', () {
        expect(
          _Rules.addStackProblem(existing, draft(min: 150)),
          AddStackProblem.minNotBelowMax,
        );
        expect(
          _Rules.addStackProblem(existing, draft(min: 200)),
          AddStackProblem.minNotBelowMax,
        );
      });

      test('a stack must have an increment', () {
        expect(
          _Rules.addStackProblem(existing, draft(increment: 0)),
          AddStackProblem.noIncrement,
        );
        expect(
          _Rules.addStackProblem(existing, draft(increment: -5)),
          AddStackProblem.noIncrement,
        );
      });

      test("a stack's name cannot be reused, whatever its case or spaces", () {
        expect(
          _Rules.addStackProblem(existing, draft(name: ' main ')),
          AddStackProblem.nameTaken,
        );
      });

      test('an identical stack is not added twice', () {
        expect(
          _Rules.addStackProblem(existing, draft(max: 100)),
          AddStackProblem.duplicate,
        );
        expect(
          _Rules.addStackProblem(existing, draft(max: 100, unit: _lb)),
          isNull,
        );
        expect(_Rules.addStackProblem(existing, draft()), isNull);
      });
    });

    group('editing a stack (EditWeightRangePresenter)', () {
      test('a usable stack is left alone', () {
        final stack = _stack('a', min: 5, increment: 2.5);
        expect(_Rules.needsRepair(stack), isFalse);
        expect(_Rules.repaired(stack, 2.5).toFirestore(), stack.toFirestore());
      });

      test('an increment cleared to nothing, or negative, is restored', () {
        for (final increment in [0.0, -1.0]) {
          final stack = _stack('a', increment: increment);
          expect(_Rules.needsRepair(stack), isTrue);
          expect(_Rules.repaired(stack, 2.5).increment, 2.5);
        }
      });

      test(
        "a stack with no usable increment falls back to its unit's step",
        () {
          expect(_Rules.repaired(_stack('a', increment: 0), 0).increment, 2.5);
          expect(
            _Rules.repaired(_stack('a', increment: 0, unit: _lb), -1).increment,
            5,
          );
        },
      );

      test('a stack entered back to front is turned round', () {
        final repaired = _Rules.repaired(_stack('a', min: 100, max: 5), 5);
        expect([repaired.minWeight, repaired.maxWeight], [5, 100]);
      });

      test('add-ons are added, repeated and removed', () {
        var stack = _stack('a');
        stack = _Rules.addingAddOn(stack, 2);
        stack = _Rules.addingAddOn(stack, 2);
        stack = _Rules.addingAddOn(stack, 1.25);
        expect(stack.addOns, [2, 2, 1.25]);
        stack = _Rules.removingAddOns(stack, {0});
        expect(stack.addOns, [2, 1.25]);
      });

      test('an add-on must weigh something', () {
        for (final value in [0.0, -2.0]) {
          expect(
            _Rules.addOnProblem(_stack('a'), value),
            StackWeightProblem.notAboveZero,
          );
        }
        expect(_Rules.addOnProblem(_stack('a'), 2), isNull);
      });

      test('add-ons stop at the cap', () {
        final full = _stack('a', addOns: List.filled(_Rules.maxAddOns, 1));
        expect(_Rules.addOnProblem(full, 1), StackWeightProblem.tooManyAddOns);
      });

      test('an uneven stack lists its pins in order', () {
        var stack = _Rules.settingUneven(_stack('a'), isUneven: true);
        expect(stack.weights, isEmpty);
        stack = _Rules.addingPinWeight(stack, 20);
        stack = _Rules.addingPinWeight(stack, 7);
        stack = _Rules.addingPinWeight(stack, 12.5);
        expect(stack.weights, [7, 12.5, 20]);
        stack = _Rules.removingPinWeights(stack, {1});
        expect(stack.weights, [7, 20]);
        expect(_Rules.settingUneven(stack, isUneven: true).weights, [7, 20]);
      });

      test('a pin weight must be new and more than zero', () {
        final stack = _stack('a', weights: [7]);
        expect(
          _Rules.pinWeightProblem(stack, 0),
          StackWeightProblem.notAboveZero,
        );
        expect(_Rules.pinWeightProblem(stack, 7), StackWeightProblem.duplicate);
        expect(_Rules.pinWeightProblem(stack, 9), isNull);
        expect(_Rules.pinWeightProblem(_stack('b'), 9), isNull);
      });

      test('an empty or abandoned uneven stack goes back to its grid', () {
        final empty = _stack('a', weights: []);
        expect(_Rules.needsRepair(empty), isTrue);
        expect(_Rules.repaired(empty, 5).weights, isNull);
        final even = _Rules.settingUneven(
          _stack('a', weights: [7]),
          isUneven: false,
        );
        expect(even.weights, isNull);
        expect(_Rules.removingPinWeights(_stack('c'), {0}).weights, isEmpty);
      });
    });
  });

  group('machines (GymProfileModel+Machines)', () {
    const latPulldown = 'cable_lat_pulldown_machine';
    final gym = _catalogueGym();

    test('duplicate adds a copy beside the original, numbered', () {
      final (duplicated, id) = _Rules.duplicatingMachine(
        gym,
        _List.cableMachines,
        latPulldown,
        newId: _counter(),
      );
      final machines = duplicated.cableMachines;
      final index = machines.indexWhere((m) => m.id == latPulldown);
      expect(machines, hasLength(gym.cableMachines.length + 1));
      expect(machines[index + 1].id, id);
      expect(machines[index + 1].typeId, latPulldown);
      expect(machines[index + 1].name, 'Cable Lat Pulldown Machine 2');
      expect(_Rules.isCustom(_List.cableMachines, machines[index + 1]), isTrue);
      expect(_Rules.isCustom(_List.cableMachines, machines[index]), isFalse);
      final (again, _) = _Rules.duplicatingMachine(
        duplicated,
        _List.cableMachines,
        latPulldown,
        newId: _counter(),
        numbered: (name, number) => '$name ($number)',
      );
      expect(
        again.cableMachines.map((m) => m.name),
        contains('Cable Lat Pulldown Machine (2)'),
      );
    });

    test('a machine that is gone duplicates nothing', () {
      final (same, id) = _Rules.duplicatingMachine(
        gym,
        _List.cableMachines,
        'gone',
        newId: _counter(),
      );
      expect(id, isNull);
      expect(same, gym);
    });

    test('the next free name skips the numbers taken', () {
      expect(_Rules.nextFreeName('Row', {'Row', 'Row 2', 'Row 3'}), 'Row 4');
    });

    test('a machine added as a catalogue type takes its loading', () {
      final (added, id) = _Rules.addingMachine(
        gym,
        _List.cableMachines,
        name: 'Hammer Pulldown',
        worksAs: latPulldown,
        newId: () => 'mine',
      );
      final machine = added.cableMachines.last;
      final template = gym.cableMachines.firstWhere((m) => m.id == latPulldown);
      expect(id, 'mine');
      expect(machine.name, 'Hammer Pulldown');
      expect(machine.typeId, latPulldown);
      expect(machine.isActive, isTrue);
      expect(machine.ranges, hasLength(template.ranges.length));
    });

    test('a plate-loaded machine of its own is its own type, at 0 kg', () {
      final (added, id) = _Rules.addingMachine(
        gym,
        _List.plateLoadedMachines,
        name: 'Garage Sled',
        newId: () => 'sled',
      );
      final machine = added.plateLoadedMachines.last;
      expect(machine.id, id);
      expect(machine.typeId, machine.id);
      expect(machine.name, 'Garage Sled');
      expect([machine.baseWeight, machine.sleeves], [0, 2]);
    });

    test('a pin-loaded machine of its own takes the first catalogue '
        "machine's stacks", () {
      final (added, _) = _Rules.addingMachine(
        gym,
        _List.pinLoadedMachines,
        name: 'Hip Abductor 2',
        newId: () => 'hip',
      );
      final machine = added.pinLoadedMachines.last;
      expect(machine.typeId, 'hip');
      expect(
        machine.ranges.length,
        GymEquipmentCatalogue.instance.pinLoadedMachines.first.ranges.length,
      );
    });

    test(
      "only the user's own machine is deleted; a catalogue machine stays",
      () {
        final (duplicated, id) = _Rules.duplicatingMachine(
          gym,
          _List.cableMachines,
          latPulldown,
          newId: _counter(),
        );
        final deleted = _Rules.deletingMachine(
          duplicated,
          _List.cableMachines,
          id!,
        );
        expect(deleted.cableMachines.any((m) => m.id == id), isFalse);
        final kept = _Rules.deletingMachine(
          gym,
          _List.cableMachines,
          latPulldown,
        );
        expect(kept.cableMachines.any((m) => m.id == latPulldown), isTrue);
      },
    );

    test("a row's machine is still found by id after another is deleted", () {
      final (duplicated, id) = _Rules.duplicatingMachine(
        gym,
        _List.cableMachines,
        latPulldown,
        newId: _counter(),
      );
      final index = duplicated.cableMachines.indexWhere((m) => m.id == id);
      final next = duplicated.cableMachines[index + 1];
      final deleted = _Rules.deletingMachine(
        duplicated,
        _List.cableMachines,
        id!,
      );
      final toggled = _Rules.settingActive(
        deleted,
        _List.cableMachines,
        next.id,
        isActive: !next.isActive,
      );
      expect(
        _Rules.item(toggled, _List.cableMachines, next.id)!.isActive,
        !next.isActive,
      );
    });

    test('a name cleared to nothing is restored on leaving', () {
      final (duplicated, id) = _Rules.duplicatingMachine(
        gym,
        _List.cableMachines,
        latPulldown,
        newId: _counter(),
      );
      final blank = _Rules.updatingItem(
        duplicated,
        _List.cableMachines,
        id!,
        (data) => {...data, GymEquipmentKeys.name: '  '},
      );
      final restored = _Rules.restoringBlankName(
        blank,
        _List.cableMachines,
        id,
        'Pulldown 2',
      );
      expect(
        _Rules.nameOf(_Rules.item(restored, _List.cableMachines, id)!),
        'Pulldown 2',
      );
      expect(
        _Rules.restoringBlankName(duplicated, _List.cableMachines, id, 'X'),
        duplicated,
      );
      expect(
        _Rules.restoringBlankName(duplicated, _List.cableMachines, 'gone', 'X'),
        duplicated,
      );
    });
  });

  group('scoped to a variation (GymProfileDelegate.equipment)', () {
    test('lists only the equipment named, by kind and type', () {
      final gym = _gym(
        freeWeights: [
          _freeWeight('Dumbbells', isActive: true),
          _freeWeight('Kettlebells'),
        ],
        loadableBars: [
          _loadableBars([_bar(20)]),
        ],
      );
      final scope = {(EquipmentKind.freeWeight, 'dumbbells')};
      expect(_ids(_Rules.visibleItems(gym, _List.freeWeights, scope: scope)), [
        'dumbbells',
      ]);
      expect(
        _Rules.visibleItems(gym, _List.loadableBars, scope: scope),
        isEmpty,
      );
      // The type alone is not enough: a bar named like the dumbbells is not
      // the dumbbells.
      expect(
        _Rules.visibleItems(
          gym,
          _List.loadableBars,
          scope: {(EquipmentKind.freeWeight, 'barbell-x')},
        ),
        isEmpty,
      );
      expect(
        _Rules.hidesEverything(
          gym,
          query: 'kettle',
          selectedOnly: false,
          scope: scope,
        ),
        isTrue,
      );
    });

    test('every list names its kind', () {
      expect({
        for (final list in _List.values) list.kind,
      }, hasLength(_List.values.length));
      expect(_List.plateLoadedMachines.kind, EquipmentKind.plateLoadedMachine);
    });
  });

  group('loading (GymProfileModel+Loading)', () {
    FreeWeights plates(
      String id,
      List<(double, bool)> weights, {
      ExerciseWeightUnit unit = _kg,
    }) => _freeWeight(
      id,
      id: id,
      isActive: true,
      isPlates: true,
      range: [
        for (final (weight, isOn) in weights)
          FreeWeightsAvailable(
            id: '$id$weight',
            availableWeights: weight,
            unit: unit,
            isActive: isOn,
          ),
      ],
    );

    LoadableBars bars(List<BarBaseWeight> weights, {String? chosen}) =>
        LoadableBars(
          id: 'barbell',
          typeId: 'barbell',
          name: 'Barbell',
          baseWeights: weights,
          collarWeight: 0,
          isActive: true,
          chosenBaseWeightId: chosen,
        );

    BarBaseWeight bar(
      String id,
      double weight, {
      ExerciseWeightUnit unit = _kg,
      bool isOn = true,
    }) => BarBaseWeight(id: id, baseWeight: weight, unit: unit, isActive: isOn);

    test('bar choices are the active bars, lightest first', () {
      var gym = _gym(
        loadableBars: [
          bars([
            bar('20', 20),
            bar('45', 45, unit: _lb),
            bar('10', 10, isOn: false),
          ]),
        ],
      );
      expect(_ids(_Rules.barChoices(gym, 'barbell').map((b) => b.id)), [
        '20',
        '45',
      ]);
      expect(_Rules.barChoices(gym, 'trap-bar'), isEmpty);
      gym = _Rules.choosingBar(gym, '45', typeId: 'barbell');
      expect(_Rules.loadedBar(gym, 'barbell')!.chosenBaseWeightId, '45');
      expect(_Rules.choosingBar(gym, '20', typeId: 'trap-bar'), same(gym));
    });

    test('a bar switched off is not the loaded one', () {
      final gym = _gym(
        loadableBars: [
          LoadableBars(
            id: 'off',
            typeId: 'barbell',
            name: 'Barbell',
            baseWeights: [bar('7', 7)],
            collarWeight: 0,
            isActive: false,
          ),
          bars([bar('20', 20)]),
        ],
      );
      expect(_Rules.loadedBar(gym, 'barbell')!.id, 'barbell');
    });

    test('choosing a bar is stored on the gym', () {
      final gym = _Rules.choosingBar(
        _gym(
          loadableBars: [
            bars([bar('b7', 7), bar('b20', 20)]),
          ],
        ),
        'b7',
        typeId: 'barbell',
      );
      final decoded = GymProfileModel.fromFirestore(gym.toFirestore());
      expect(_Rules.loadedBar(decoded, 'barbell')!.chosenBaseWeightId, 'b7');
    });

    test('choices are every weight in the unit, heaviest first', () {
      final gym = _gym(
        freeWeights: [
          plates('iron', [(20, true), (10, false), (2.5, true)]),
          plates('bumper', [(20, false), (15, true)]),
          plates('pounds', [(45, true)], unit: _lb),
        ],
      );
      expect(_Rules.plateChoices(gym, _kg), [
        (weight: 20.0, isOn: true),
        (weight: 15.0, isOn: true),
        (weight: 10.0, isOn: false),
        (weight: 2.5, isOn: true),
      ]);
    });

    test('a unit with no plates of its own offers them all converted', () {
      final gym = _gym(
        freeWeights: [
          plates('iron', [(20, true)]),
        ],
      );
      expect(_Rules.plateChoices(gym, _lb), [(weight: 44.092, isOn: true)]);
    });

    test('switching a weight off reaches every plate of it', () {
      var gym = _gym(
        freeWeights: [
          plates('iron', [(20, true), (2.5, true)]),
          plates('bumper', [(20, true)]),
          _freeWeight('Dumbbells', isActive: true, range: [_plate(20)]),
          plates('pounds', [(44.092, true)], unit: _lb),
        ],
      );
      gym = _Rules.settingPlate(gym, 20, _kg, isOn: false);
      expect(_Rules.plateChoices(gym, _kg).first, (weight: 20.0, isOn: false));
      final byId = {for (final item in gym.freeWeights) item.id: item};
      expect(byId['iron']!.range.map((p) => p.isActive), [false, true]);
      expect(byId['bumper']!.range.single.isActive, isFalse);
      // Dumbbells are not plates, and pound plates are not in kilograms.
      expect(byId['dumbbells']!.range.single.isActive, isTrue);
      expect(byId['pounds']!.range.single.isActive, isTrue);

      gym = _Rules.settingPlate(gym, 20, _kg, isOn: true);
      final twenties = [
        for (final item in gym.freeWeights)
          if (item.isPlates)
            for (final plate in item.range)
              if (plate.availableWeights == 20) plate,
      ];
      expect(twenties.every((plate) => plate.isActive), isTrue);
    });

    test('the plate calculator only changes loading', () {
      GymProfileModel gym({String? chosen, bool firstPlateOn = true}) => _gym(
        freeWeights: [
          plates('iron', [(20, firstPlateOn), (10, true)]),
          _freeWeight('Dumbbells', isActive: true, range: [_plate(20)]),
        ],
        loadableBars: [
          bars([bar('a', 20), bar('b', 15)], chosen: chosen),
        ],
      );
      final current = _Rules.renamed(gym(chosen: 'a'), 'Renamed meanwhile');
      final edited = _Rules.renamed(
        gym(chosen: 'b', firstPlateOn: false),
        'Stale name',
      );
      final merged = _Rules.takingLoading(current, edited);
      expect(merged.name, 'Renamed meanwhile');
      expect(_Rules.loadedBar(merged, 'barbell')!.chosenBaseWeightId, 'b');
      final iron = merged.freeWeights.firstWhere((item) => item.id == 'iron');
      expect(iron.range.first.isActive, isFalse);

      // A choice cleared in the calculator is cleared on the gym.
      final cleared = _Rules.takingLoading(current, gym());
      expect(_Rules.loadedBar(cleared, 'barbell')!.chosenBaseWeightId, isNull);
    });
  });
}
