// Ported from WeightStepperTests.swift (the chips' words are the app's, so
// those expectations are left out), with the resolution's other branches.
import 'package:compound_models/compound_models.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

import '../helpers/fixtures.dart';

const m.ExerciseWeightUnit kg = m.ExerciseWeightUnit.kilograms;
const m.ExerciseWeightUnit lb = m.ExerciseWeightUnit.pounds;

m.FreeWeightsAvailable _weight(
  String id,
  double weight, {
  bool active = true,
}) => m.FreeWeightsAvailable(
  id: id,
  availableWeights: weight,
  unit: kg,
  isActive: active,
);

m.LoadableBars _bar({
  double collar = 0,
  List<m.BarBaseWeight>? weights,
  String? chosen,
  String id = 'barbell',
}) => m.LoadableBars(
  id: id,
  typeId: id,
  name: 'Barbell',
  baseWeights:
      weights ??
      const [
        m.BarBaseWeight(id: 'b20', baseWeight: 20, unit: kg, isActive: true),
      ],
  collarWeight: collar,
  isActive: true,
  chosenBaseWeightId: chosen,
);

m.StackMachine _stack(
  String id,
  List<m.WeightStack> ranges, {
  String? defaultRangeId,
  bool active = true,
}) => m.StackMachine(
  id: id,
  typeId: id,
  name: id,
  ranges: ranges,
  isActive: active,
  defaultRangeId: defaultRangeId,
);

m.WeightStack _range(
  String id, {
  double min = 5,
  double max = 50,
  double increment = 5,
  m.ExerciseWeightUnit unit = kg,
  List<double> addOns = const [],
  List<double>? weights,
  bool active = true,
}) => m.WeightStack(
  id: id,
  name: id,
  minWeight: min,
  maxWeight: max,
  increment: increment,
  unit: unit,
  isActive: active,
  addOns: addOns,
  weights: weights,
);

m.PlateLoadedMachine _machine(
  String id, {
  double base = 40,
  int sleeves = 2,
  bool excludes = false,
  m.ExerciseWeightUnit unit = kg,
}) => m.PlateLoadedMachine(
  id: id,
  typeId: id,
  name: id,
  baseWeight: base,
  unit: unit,
  sleeves: sleeves,
  excludesBaseFromLoad: excludes,
  isActive: true,
);

final m.GymProfileModel _profile = gym(
  freeWeights: [
    plates([1.25, 2.5, 5, 10, 20]),
    m.FreeWeights(
      id: 'dumbbells',
      typeId: 'dumbbells',
      name: 'Dumbbells',
      needsColour: false,
      isPlates: false,
      isActive: true,
      range: [
        _weight('d1', 10),
        _weight('d2', 12.5),
        _weight('d3', 15),
        _weight('d4', 17.5, active: false),
        _weight('d5', 20),
      ],
    ),
  ],
  loadableBars: [_bar()],
  fixedWeightBars: const [
    m.FixedWeightBars(
      id: 'fixed',
      typeId: 'fixed',
      name: 'Fixed',
      isActive: true,
      baseWeights: [
        m.BarBaseWeight(id: 'f1', baseWeight: 10, unit: kg, isActive: true),
        m.BarBaseWeight(id: 'f2', baseWeight: 20, unit: kg, isActive: true),
        m.BarBaseWeight(id: 'f3', baseWeight: 30, unit: kg, isActive: true),
      ],
    ),
  ],
  bands: const [
    m.Bands(
      id: 'bands',
      typeId: 'bands',
      name: 'Bands',
      isActive: true,
      range: [
        m.BandsAvailable(
          id: 'h',
          name: 'Heavy',
          bandColour: '',
          availableResistance: 30,
          unit: kg,
          isActive: true,
        ),
        m.BandsAvailable(
          id: 'l',
          name: 'Light',
          bandColour: '',
          availableResistance: 8,
          unit: kg,
          isActive: true,
        ),
      ],
    ),
  ],
  cableMachines: [
    _stack('cable', [_range('c')]),
  ],
  plateLoadedMachines: [_machine('sled')],
  pinLoadedMachines: [
    _stack('pin', [_range('p', min: 10, max: 100, increment: 10, unit: lb)]),
  ],
);

r.WeightStep _step(
  m.EquipmentKind kind,
  String id, {
  r.WeightUnit unit = r.WeightUnit.kilograms,
  m.GymProfileModel? profile,
}) => WeightStepper.stepsForExercise(
  exercise(
    'e',
    variations: [
      variation('v', [ref(kind, id)]),
    ],
  ),
  profile ?? _profile,
  unit,
);

List<(double, int?)> _plates(List<r.Plate> plates) => [
  for (final plate in plates) (plate.weight, plate.perSleeve),
];

void main() {
  group('every kind', () {
    final cases = <(m.EquipmentKind, String, double?, double?, double?)>[
      // Bar: 2 × the smallest plate, from the bar's own weight.
      (m.EquipmentKind.loadableBar, 'barbell', 60, 62.5, 57.5),
      (m.EquipmentKind.loadableBar, 'barbell', null, 20, 20),
      (m.EquipmentKind.loadableBar, 'barbell', 21, 22.5, 20),
      (m.EquipmentKind.plateLoadedMachine, 'sled', 40, 42.5, 40),
      // Cable: its increment, clamped to the stack.
      (m.EquipmentKind.cableMachine, 'cable', 20, 25, 15),
      (m.EquipmentKind.cableMachine, 'cable', 50, 50, 45),
      (m.EquipmentKind.cableMachine, 'cable', 5, 10, 5),
      (m.EquipmentKind.cableMachine, 'cable', 22, 25, 20),
      // Dumbbells: the next on the rack, skipping inactive ones.
      (m.EquipmentKind.freeWeight, 'dumbbells', 15, 20, 12.5),
      (m.EquipmentKind.freeWeight, 'dumbbells', 20, 20, 15),
      (m.EquipmentKind.freeWeight, 'dumbbells', 10, 12.5, 10),
      (m.EquipmentKind.freeWeight, 'dumbbells', 11, 12.5, 10),
      // Fixed bars: the next bar.
      (m.EquipmentKind.fixedWeightBar, 'fixed', 20, 30, 10),
      // Body weight: external load in 1.25 kg, never below none.
      (m.EquipmentKind.bodyWeight, 'vest', 0, 1.25, 0),
      (m.EquipmentKind.bodyWeight, 'vest', null, 0, 0),
      // Equipment this gym does not have: the default 2.5 kg.
      (m.EquipmentKind.cableMachine, 'missing', 20, 22.5, 17.5),
      (m.EquipmentKind.supportEquipment, 'bench', 20, 22.5, 17.5),
    ];
    for (final (kind, id, from, up, down) in cases) {
      test('${kind.name} $id from $from', () {
        final step = _step(kind, id);
        expect(step.next(from), up);
        expect(step.previous(from), down);
      });
    }
  });

  test('an assisted machine steps below zero to its deepest', () {
    final step = _step(
      m.EquipmentKind.cableMachine,
      'cable',
    ).assisted(bodyweightOnly: true);
    expect(step.next(-30), -25);
    expect(step.previous(-30), -35);
    expect(step.previous(-50), -50);
    expect(step.next(-5), 0);
    expect(step.next(0), 0);
    expect(step.previous(null), -5);
  });

  test('nothing else steps below zero', () {
    for (final (kind, id) in [
      (m.EquipmentKind.cableMachine, 'cable'),
      (m.EquipmentKind.freeWeight, 'dumbbells'),
      (m.EquipmentKind.bodyWeight, 'vest'),
      (m.EquipmentKind.supportEquipment, 'bench'),
    ]) {
      final step = _step(kind, id);
      expect(step.previous(0) ?? 0, greaterThanOrEqualTo(0));
      expect(step.previous(null) ?? 0, greaterThanOrEqualTo(0));
    }
  });

  test('a bar carries its weight and plates', () {
    final step = _step(m.EquipmentKind.loadableBar, 'barbell');
    expect(step.baseWeight, 20);
    expect(step.plates.map((p) => p.weight), [1.25, 2.5, 5, 10, 20]);
    expect(step.isPlateLoaded, isTrue);
    expect(_step(m.EquipmentKind.bodyWeight, 'vest').isPlateLoaded, isFalse);
  });

  test('bands cycle by name, lightest first', () {
    final step = _step(m.EquipmentKind.bands, 'bands');
    expect(step.kind, const r.StepBands());
    expect(step.bands, ['Light', 'Heavy']);
    expect(step.band(null, forward: true), 0);
    expect(step.band(1, forward: true), 0);
    expect(step.band(0, forward: false), 1);
    expect(step.next(10), isNull);
  });

  test('a bar with bands offers the bar step and the bands', () {
    final bar = _step(m.EquipmentKind.loadableBar, 'barbell');
    for (final refs in [
      [
        ref(m.EquipmentKind.loadableBar, 'barbell'),
        ref(m.EquipmentKind.bands, 'bands'),
      ],
      [
        ref(m.EquipmentKind.bands, 'bands'),
        ref(m.EquipmentKind.loadableBar, 'barbell'),
      ],
    ]) {
      final step = WeightStepper.steps(refs, _profile, r.WeightUnit.kilograms);
      expect(step.kind, bar.kind);
      expect(step.baseWeight, 20);
      expect(step.constrainsWeight, isTrue);
      expect(step.bands, ['Light', 'Heavy']);
    }
    expect(bar.bands, isEmpty);
  });

  test('a band listed in both units is offered once', () {
    final profile = gym(
      bands: const [
        m.Bands(
          id: 'bands',
          typeId: 'bands',
          name: 'Bands',
          isActive: true,
          range: [
            m.BandsAvailable(
              id: 'lb',
              name: 'Light',
              bandColour: '',
              availableResistance: 18,
              unit: lb,
              isActive: true,
            ),
            m.BandsAvailable(
              id: 'kg',
              name: 'Light',
              bandColour: '',
              availableResistance: 8,
              unit: kg,
              isActive: true,
            ),
            m.BandsAvailable(
              id: 'h',
              name: 'Heavy',
              bandColour: '',
              availableResistance: 30,
              unit: kg,
              isActive: true,
            ),
          ],
        ),
      ],
    );
    final step = WeightStepper.steps(
      [ref(m.EquipmentKind.bands, 'bands')],
      profile,
      r.WeightUnit.kilograms,
    );
    expect(step.bands, ['Light', 'Heavy']);
    expect(step.constrainsWeight, isFalse);
  });

  test('only equipment the gym has constrains the weight', () {
    for (final (kind, id) in [
      (m.EquipmentKind.cableMachine, 'cable'),
      (m.EquipmentKind.freeWeight, 'dumbbells'),
      (m.EquipmentKind.fixedWeightBar, 'fixed'),
      (m.EquipmentKind.loadableBar, 'barbell'),
      (m.EquipmentKind.plateLoadedMachine, 'sled'),
    ]) {
      expect(_step(kind, id).constrainsWeight, isTrue, reason: id);
    }
    for (final (kind, id) in [
      (m.EquipmentKind.cableMachine, 'missing'),
      (m.EquipmentKind.bodyWeight, 'vest'),
      (m.EquipmentKind.bands, 'bands'),
    ]) {
      expect(_step(kind, id).constrainsWeight, isFalse, reason: id);
    }
  });

  test('the smallest step is the grid or the smallest gap', () {
    expect(_step(m.EquipmentKind.cableMachine, 'cable').smallestStep, 5);
    expect(_step(m.EquipmentKind.freeWeight, 'dumbbells').smallestStep, 2.5);
    expect(_step(m.EquipmentKind.fixedWeightBar, 'fixed').smallestStep, 10);
    expect(_step(m.EquipmentKind.loadableBar, 'barbell').smallestStep, 2.5);
    expect(_step(m.EquipmentKind.bands, 'bands').smallestStep, isNull);
  });

  test('nearest picks the lighter of two equally close weights', () {
    expect(_step(m.EquipmentKind.freeWeight, 'dumbbells').nearest(17.5), 15);
    expect(_step(m.EquipmentKind.freeWeight, 'dumbbells').nearest(100), 20);
    expect(_step(m.EquipmentKind.cableMachine, 'cable').nearest(1), 5);
    expect(_step(m.EquipmentKind.loadableBar, 'barbell').nearest(61), 60);
    expect(_step(m.EquipmentKind.bands, 'bands').nearest(7), 7);
  });

  group('fallbacks', () {
    test('no profile falls back to 2.5 kg or 5 lb', () {
      final kilograms = WeightStepper.steps(
        [ref(m.EquipmentKind.loadableBar, 'barbell')],
        null,
        r.WeightUnit.kilograms,
      );
      final pounds = WeightStepper.steps(
        [ref(m.EquipmentKind.loadableBar, 'barbell')],
        null,
        r.WeightUnit.pounds,
      );
      expect(kilograms.next(100), 102.5);
      expect(pounds.next(100), 105);
      expect(
        WeightStepper.fallback(r.WeightUnit.kilograms).constrainsWeight,
        isFalse,
      );
    });

    test('no variation falls back', () {
      final step = WeightStepper.stepsForExercise(
        exercise('e'),
        _profile,
        r.WeightUnit.kilograms,
      );
      expect(step.kind, const r.StepIncrement(2.5, min: 0));
      expect(step.constrainsWeight, isFalse);
    });

    test('the chosen variation wins over the first', () {
      final lift = exercise(
        'e',
        variations: [
          variation('v', [ref(m.EquipmentKind.loadableBar, 'barbell')]),
          variation('cable-v', [ref(m.EquipmentKind.cableMachine, 'cable')]),
        ],
        chosenVariationId: 'cable-v',
      );
      expect(
        WeightStepper.stepsForExercise(
          lift,
          _profile,
          r.WeightUnit.kilograms,
        ).next(20),
        25,
      );
    });

    test('equipment with nothing switched on is not a load', () {
      final profile = gym(
        loadableBars: [
          _bar(
            weights: const [
              m.BarBaseWeight(
                id: 'b',
                baseWeight: 20,
                unit: kg,
                isActive: false,
              ),
            ],
          ),
        ],
        freeWeights: [
          m.FreeWeights(
            id: 'dumbbells',
            typeId: 'dumbbells',
            name: 'D',
            needsColour: false,
            isPlates: false,
            isActive: true,
            range: [_weight('d', 10, active: false)],
          ),
        ],
        fixedWeightBars: const [
          m.FixedWeightBars(
            id: 'fixed',
            typeId: 'fixed',
            name: 'F',
            isActive: true,
            baseWeights: [],
          ),
        ],
        bands: const [
          m.Bands(
            id: 'bands',
            typeId: 'bands',
            name: 'B',
            isActive: true,
            range: [],
          ),
        ],
        cableMachines: [
          _stack('cable', [_range('c', increment: 0)]),
          _stack('empty', [_range('x', active: false)]),
          _stack('nothing', [
            _range('n', weights: [0]),
          ]),
        ],
      );
      for (final (kind, id) in [
        (m.EquipmentKind.loadableBar, 'barbell'),
        (m.EquipmentKind.freeWeight, 'dumbbells'),
        (m.EquipmentKind.fixedWeightBar, 'fixed'),
        (m.EquipmentKind.bands, 'bands'),
        (m.EquipmentKind.cableMachine, 'cable'),
        (m.EquipmentKind.cableMachine, 'empty'),
        (m.EquipmentKind.cableMachine, 'nothing'),
        (m.EquipmentKind.plateLoadedMachine, 'missing'),
        (m.EquipmentKind.pinLoadedMachine, 'missing'),
        (m.EquipmentKind.fixedWeightBar, 'missing'),
        (m.EquipmentKind.bands, 'missing'),
      ]) {
        expect(
          _step(kind, id, profile: profile).constrainsWeight,
          isFalse,
          reason: '$kind $id',
        );
      }
    });
  });

  group('units', () {
    test('a pound range converts to kilograms', () {
      final step = _step(m.EquipmentKind.pinLoadedMachine, 'pin');
      expect(step.next(null), 4.536);
      expect(step.next(4.536), 9.072);
    });

    test('a pound range stays in pounds', () {
      final step = _step(
        m.EquipmentKind.pinLoadedMachine,
        'pin',
        unit: r.WeightUnit.pounds,
      );
      expect(step.next(50), 60);
      expect(step.previous(10), 10);
      expect(step.next(100), 100);
    });

    test('kilogram plates convert for a pound user', () {
      final step = _step(
        m.EquipmentKind.loadableBar,
        'barbell',
        unit: r.WeightUnit.pounds,
      );
      expect(step.baseWeight, 44.092);
      expect(step.next(44.092), 49.604);
    });

    test("plates in the user's unit are used when there are any", () {
      final profile = gym(
        freeWeights: [
          plates([1.25, 20]),
          plates([2.5, 45], id: 'lb_plates', unit: lb),
        ],
      );
      expect(
        WeightStepper.availablePlates(
          profile,
          r.WeightUnit.pounds,
        ).map((p) => p.weight),
        [2.5, 45],
      );
      expect(
        WeightStepper.availablePlates(
          profile,
          r.WeightUnit.kilograms,
        ).map((p) => p.weight),
        [1.25, 20],
      );
    });
  });

  group('sleeves, counts and collars', () {
    test('a single-sleeve machine steps one plate', () {
      final profile = gym(
        freeWeights: [
          plates([1.25, 2.5, 5, 10, 20]),
        ],
        plateLoadedMachines: [_machine('t_bar', base: 18, sleeves: 1)],
      );
      final step = _step(
        m.EquipmentKind.plateLoadedMachine,
        't_bar',
        profile: profile,
      );
      expect(step.sleeves, 1);
      expect(step.smallestStep, 1.25);
      expect(step.next(18), 19.25);
      expect(step.nearest(20.5), 20.5);
      expect(
        r.PlateCalculator.load(
          total: 20.5,
          bar: 18,
          plates: step.plates,
          sleeves: 1,
        ),
        const r.Loadable([2.5]),
      );
    });

    test('a two-sleeve machine still steps a pair', () {
      final step = _step(m.EquipmentKind.plateLoadedMachine, 'sled');
      expect(step.sleeves, 2);
      expect(step.smallestStep, 2.5);
    });

    test('limited plates fall to the next one down', () {
      final profile = gym(
        freeWeights: [
          plates([5, 15, 20], counts: [null, null, 2]),
        ],
        loadableBars: [_bar()],
      );
      final step = _step(
        m.EquipmentKind.loadableBar,
        'barbell',
        profile: profile,
      );
      expect(_plates(step.plates), [(5, null), (15, null), (20, 1)]);
      expect(
        r.PlateCalculator.load(total: 100, bar: 20, plates: step.plates),
        const r.Loadable([20, 15, 5]),
      );
    });

    test('iron and bumper plates of one weight add up', () {
      final profile = gym(
        freeWeights: [
          plates([10, 20], counts: [1, 2]),
          plates([10, 20], id: 'bumper_plates', counts: [null, 2]),
        ],
      );
      expect(
        _plates(WeightStepper.availablePlates(profile, r.WeightUnit.kilograms)),
        [(10, null), (20, 2)],
      );
    });

    test('a plate too few for every sleeve is left out', () {
      final profile = gym(
        freeWeights: [
          plates([1.25, 2.5], counts: [1, null]),
        ],
        loadableBars: [_bar()],
      );
      expect(
        WeightStepper.availablePlates(
          profile,
          r.WeightUnit.kilograms,
        ).map((p) => p.weight),
        [2.5],
      );
      expect(
        _plates(
          WeightStepper.availablePlates(
            profile,
            r.WeightUnit.kilograms,
            sleeves: 1,
          ),
        ),
        [(1.25, 1), (2.5, null)],
      );
      expect(
        _step(
          m.EquipmentKind.loadableBar,
          'barbell',
          profile: profile,
        ).smallestStep,
        5,
      );
    });

    test('an item marked as plates is loaded, whatever its id', () {
      final profile = gym(
        freeWeights: [
          plates([0.5], id: 'change_discs'),
          plates([0.25], id: 'fractional_plates', isPlates: false),
        ],
      );
      expect(
        WeightStepper.availablePlates(
          profile,
          r.WeightUnit.kilograms,
        ).map((p) => p.weight),
        [0.5],
      );
    });

    test('collars are added to the bar', () {
      final profile = gym(
        freeWeights: [
          plates([1.25, 2.5, 5, 10, 20]),
        ],
        loadableBars: [_bar(collar: 2.5)],
      );
      final step = _step(
        m.EquipmentKind.loadableBar,
        'barbell',
        profile: profile,
      );
      expect(step.baseWeight, 25);
      expect(step.next(null), 25);
      expect(step.nearest(22), 25);
      expect(step.nearest(61), 60);
    });

    test('a bar with no plates steps by the fallback', () {
      final profile = gym(loadableBars: [_bar()]);
      final step = _step(
        m.EquipmentKind.loadableBar,
        'barbell',
        profile: profile,
      );
      expect(step.kind, const r.StepIncrement(2.5, min: 20));
      expect(
        _step(
          m.EquipmentKind.loadableBar,
          'barbell',
          profile: profile,
          unit: r.WeightUnit.pounds,
        ).smallestStep,
        5,
      );
    });

    test('a landmine bar loads one sleeve', () {
      final profile = gym(
        freeWeights: [
          plates([2.5]),
        ],
        loadableBars: [_bar()],
      );
      final step = WeightStepper.steps(
        [
          ref(m.EquipmentKind.loadableBar, 'barbell'),
          ref(m.EquipmentKind.supportEquipment, 'landmine'),
        ],
        profile,
        r.WeightUnit.kilograms,
      );
      expect(step.sleeves, 1);
      expect(step.smallestStep, 2.5);
    });

    test('the chosen bar wins, else the heaviest switched on', () {
      const weights = [
        m.BarBaseWeight(id: 'b15', baseWeight: 15, unit: kg, isActive: true),
        m.BarBaseWeight(id: 'b45', baseWeight: 45, unit: lb, isActive: true),
        m.BarBaseWeight(id: 'b20', baseWeight: 20, unit: kg, isActive: true),
      ];
      double base(String? chosen) => _step(
        m.EquipmentKind.loadableBar,
        'barbell',
        profile: gym(
          loadableBars: [_bar(weights: weights, chosen: chosen)],
        ),
      ).baseWeight!;
      expect(base('b15'), 15);
      expect(base(null), 20.412);
    });
  });

  group('stacks', () {
    test('the top pin, not the stored maximum, caps the grid', () {
      final profile = gym(
        cableMachines: [
          _stack('cable', [_range('c', max: 100, increment: 7)]),
        ],
      );
      final step = _step(
        m.EquipmentKind.cableMachine,
        'cable',
        profile: profile,
      );
      expect(step.kind, const r.StepIncrement(7, min: 5, max: 96));
    });

    test('a stack from zero starts at its first pin', () {
      final profile = gym(
        cableMachines: [
          _stack('cable', [_range('c', min: 0, max: 20)]),
        ],
      );
      expect(
        _step(m.EquipmentKind.cableMachine, 'cable', profile: profile).kind,
        const r.StepIncrement(5, min: 5, max: 20),
      );
    });

    test('a stack whose lightest pin is past its top has none', () {
      final profile = gym(
        cableMachines: [
          _stack('cable', [_range('c', min: 60)]),
        ],
      );
      expect(
        _step(m.EquipmentKind.cableMachine, 'cable', profile: profile).kind,
        const r.StepIncrement(5, min: 60, max: 50),
      );
    });

    test('add-ons give every load the pins and add-ons make', () {
      final profile = gym(
        cableMachines: [
          _stack('cable', [
            _range('c', min: 7, max: 21, increment: 7, addOns: [2, 2, 0]),
          ]),
        ],
      );
      expect(
        _step(m.EquipmentKind.cableMachine, 'cable', profile: profile).kind,
        const r.StepList([7, 9, 11, 14, 16, 18, 21, 23, 25]),
      );
    });

    test('an uneven stack lists its pins', () {
      final profile = gym(
        cableMachines: [
          _stack('cable', [
            _range('c', weights: [10, 0, 15, 25, 15]),
          ]),
        ],
      );
      expect(
        _step(m.EquipmentKind.cableMachine, 'cable', profile: profile).kind,
        const r.StepList([10, 15, 25]),
      );
    });

    test('the stack in the unit, else the default, else the first', () {
      m.GymProfileModel profileWith(String? defaultId) => gym(
        cableMachines: [
          _stack('cable', [
            _range('first'),
            _range('pounds', increment: 10, unit: lb),
            _range('default', increment: 2.5),
          ], defaultRangeId: defaultId),
        ],
      );
      r.WeightStep step(String? defaultId, r.WeightUnit unit) => _step(
        m.EquipmentKind.cableMachine,
        'cable',
        profile: profileWith(defaultId),
        unit: unit,
      );
      expect(step('default', r.WeightUnit.pounds).smallestStep, 10);
      expect(step('default', r.WeightUnit.kilograms).smallestStep, 5);
      final noKilograms = gym(
        cableMachines: [
          _stack('cable', [
            _range('pounds', increment: 10, unit: lb),
            _range('pounds-2', unit: lb),
          ], defaultRangeId: 'pounds-2'),
        ],
      );
      expect(
        _step(
          m.EquipmentKind.cableMachine,
          'cable',
          profile: noKilograms,
        ).smallestStep,
        2.268,
      );
      final noDefault = gym(
        cableMachines: [
          _stack('cable', [_range('pounds', increment: 10, unit: lb)]),
        ],
      );
      expect(
        _step(
          m.EquipmentKind.cableMachine,
          'cable',
          profile: noDefault,
        ).smallestStep,
        4.536,
      );
    });
  });

  group('equipmentUnit', () {
    m.ExerciseWeightUnit? unit(
      List<m.EquipmentRef>? refs, [
      m.GymProfileModel? profile,
    ]) => WeightStepper.equipmentUnit(refs, profile ?? _profile);

    test('is the plates on a bar or machine, a stack, a rack', () {
      expect(unit([ref(m.EquipmentKind.loadableBar, 'barbell')]), kg);
      expect(unit([ref(m.EquipmentKind.plateLoadedMachine, 'sled')]), kg);
      expect(unit([ref(m.EquipmentKind.cableMachine, 'cable')]), kg);
      expect(unit([ref(m.EquipmentKind.pinLoadedMachine, 'pin')]), lb);
      expect(unit([ref(m.EquipmentKind.freeWeight, 'dumbbells')]), kg);
      expect(unit([ref(m.EquipmentKind.fixedWeightBar, 'fixed')]), kg);
    });

    test('skips the plates beside a bar and equipment the gym lacks', () {
      expect(
        unit([
          ref(m.EquipmentKind.freeWeight, 'weight_plates'),
          ref(m.EquipmentKind.supportEquipment, 'bench'),
          ref(m.EquipmentKind.cableMachine, 'missing'),
          ref(m.EquipmentKind.loadableBar, 'barbell'),
        ]),
        kg,
      );
      expect(
        unit([
          ref(m.EquipmentKind.freeWeight, 'weight_plates'),
          ref(m.EquipmentKind.plateLoadedMachine, 'missing'),
        ]),
        isNull,
      );
    });

    test('is nothing for what carries no load of its own', () {
      expect(
        unit([
          ref(m.EquipmentKind.bands, 'bands'),
          ref(m.EquipmentKind.supportEquipment, 'bench'),
          ref(m.EquipmentKind.accessoryEquipment, 'straps'),
          ref(m.EquipmentKind.loadableAccessoryEquipment, 'belt'),
        ]),
        isNull,
      );
      for (final kind in [
        m.EquipmentKind.accessoryEquipment,
        m.EquipmentKind.loadableAccessoryEquipment,
      ]) {
        expect(_step(kind, 'x').constrainsWeight, isFalse);
      }
    });

    test('is nothing for body weight, both units, no gym or no refs', () {
      expect(unit([ref(m.EquipmentKind.bodyWeight, 'vest')]), isNull);
      expect(unit([ref(m.EquipmentKind.bands, 'bands')]), isNull);
      expect(WeightStepper.equipmentUnit(null, _profile), isNull);
      expect(
        WeightStepper.equipmentUnit([
          ref(m.EquipmentKind.loadableBar, 'barbell'),
        ], null),
        isNull,
      );
      final mixed = gym(
        freeWeights: [
          plates([20]),
          plates([45], id: 'lb_plates', unit: lb),
        ],
        loadableBars: [_bar()],
      );
      expect(
        unit([ref(m.EquipmentKind.loadableBar, 'barbell')], mixed),
        isNull,
      );
    });

    test('a plate held alone is its own load, its unit read off its rack', () {
      expect(unit([ref(m.EquipmentKind.freeWeight, 'weight_plates')]), kg);
      final step = WeightStepper.steps(
        [ref(m.EquipmentKind.freeWeight, 'weight_plates')],
        _profile,
        r.WeightUnit.kilograms,
      );
      expect(step.kind, const r.StepList([1.25, 2.5, 5, 10, 20]));
    });

    test('a plate the gym does not list is known by its id', () {
      final profile = gym(loadableBars: [_bar()]);
      expect(
        WeightStepper.steps(
          [
            ref(m.EquipmentKind.freeWeight, 'bumper_plates'),
            ref(m.EquipmentKind.loadableBar, 'barbell'),
          ],
          profile,
          r.WeightUnit.kilograms,
        ).baseWeight,
        20,
      );
    });
  });

  group('weightRoundingRule', () {
    test('rounds on the first variation without one chosen', () {
      final bench = library(
        'bench',
        variations: [
          variation('v', [ref(m.EquipmentKind.loadableBar, 'barbell')]),
        ],
      );
      final rule = weightRoundingRule(
        exercise: bench,
        gym: _profile,
        preferredUnit: null,
      );
      expect(rule.round(61), 60);
      expect(progressionRounding(rule).minimumIncrementKg, 2.5);
    });

    test('mirrors the equipment for an assisted exercise', () {
      final dip = library(
        'dip',
        metrics: const [m.TrackableExerciseMetric.weightPerSideAssistance],
        isBodyweight: true,
        variations: [
          variation('v', [ref(m.EquipmentKind.cableMachine, 'cable')]),
        ],
      );
      final rule = weightRoundingRule(
        exercise: dip,
        gym: _profile,
        preferredUnit: kg,
      );
      expect(rule.round(-31), -30);
      expect(rule.round(4), 0);
    });
  });
}
