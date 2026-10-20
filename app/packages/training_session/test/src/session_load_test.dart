import 'package:compound_models/compound_models.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_session/training_session.dart';

import '../helpers/fixtures.dart';

final m.EquipmentRef _bar = ref(m.EquipmentKind.loadableBar, 'barbell');
final m.EquipmentRef _cable = ref(m.EquipmentKind.cableMachine, 'cable');
final m.EquipmentRef _bench = ref(
  m.EquipmentKind.supportEquipment,
  'flat_bench',
);

final m.GymProfileModel _gym = gym(
  freeWeights: [
    plates([2.5, 5, 20], unit: m.ExerciseWeightUnit.pounds),
  ],
  loadableBars: const [
    m.LoadableBars(
      id: 'barbell',
      typeId: 'barbell',
      name: 'Barbell',
      collarWeight: 0,
      isActive: true,
      baseWeights: [
        m.BarBaseWeight(
          id: 'b',
          baseWeight: 45,
          unit: m.ExerciseWeightUnit.pounds,
          isActive: true,
        ),
      ],
    ),
  ],
  supportEquipment: const [
    m.PlainEquipment(
      id: 'flat_bench',
      typeId: 'flat_bench',
      name: 'Bench',
      isActive: false,
    ),
  ],
  plateLoadedMachines: const [
    m.PlateLoadedMachine(
      id: 'sled-off',
      typeId: 'sled',
      name: 'Sled',
      baseWeight: 90,
      unit: m.ExerciseWeightUnit.pounds,
      sleeves: 2,
      excludesBaseFromLoad: true,
      isActive: false,
    ),
    m.PlateLoadedMachine(
      id: 'sled-on',
      typeId: 'sled',
      name: 'Sled',
      baseWeight: 90,
      unit: m.ExerciseWeightUnit.pounds,
      sleeves: 2,
      excludesBaseFromLoad: true,
      isActive: true,
    ),
    m.PlateLoadedMachine(
      id: 'press',
      typeId: 'press',
      name: 'Press',
      baseWeight: 30,
      unit: m.ExerciseWeightUnit.kilograms,
      sleeves: 2,
      excludesBaseFromLoad: false,
      isActive: true,
    ),
  ],
);

void main() {
  group('SessionLoadChoice.variationId', () {
    final variations = [
      variation('benched', [_bar], support: [_bench]),
      variation('bar', [_bar]),
      variation('cable', [_cable]),
    ];

    test("last time's variation, in the same gym it can still be done", () {
      expect(
        SessionLoadChoice.variationId(
          variations: variations,
          previous: exercise(
            'p',
            variations: variations,
            chosenVariationId: 'bar',
          ),
          previousGymId: 'gym-1',
          gym: _gym,
        ),
        'bar',
      );
    });

    test('else the first the gym can do', () {
      for (final previous in [
        null,
        exercise('p', variations: variations, chosenVariationId: 'benched'),
        exercise('p', variations: variations, chosenVariationId: 'gone'),
        exercise('p'),
      ]) {
        expect(
          SessionLoadChoice.variationId(
            variations: variations,
            previous: previous,
            previousGymId: 'gym-1',
            gym: _gym,
          ),
          'bar',
        );
      }
      expect(
        SessionLoadChoice.variationId(
          variations: variations,
          previous: exercise(
            'p',
            variations: variations,
            chosenVariationId: 'cable',
          ),
          previousGymId: 'another-gym',
          gym: _gym,
        ),
        'bar',
      );
    });

    test('else the first; without a gym, anything goes', () {
      expect(
        SessionLoadChoice.variationId(
          variations: [
            variation('cable', [_cable]),
          ],
          previous: null,
          previousGymId: null,
          gym: _gym,
        ),
        'cable',
      );
      expect(
        SessionLoadChoice.variationId(
          variations: variations,
          previous: null,
          previousGymId: null,
          gym: null,
        ),
        'benched',
      );
      expect(
        SessionLoadChoice.variationId(
          variations: const [],
          previous: null,
          previousGymId: null,
          gym: null,
        ),
        isNull,
      );
    });
  });

  test('weightUnit: the chosen unit, else the label, else the app-wide', () {
    const chosen = UnitPreference(weightUnitIsChosen: true);
    const appWide = UnitPreference();
    expect(
      SessionLoadChoice.weightUnit(preference: chosen, refs: [_bar], gym: _gym),
      m.ExerciseWeightUnit.kilograms,
    );
    expect(
      SessionLoadChoice.weightUnit(
        preference: appWide,
        refs: [_bar],
        gym: _gym,
      ),
      m.ExerciseWeightUnit.pounds,
    );
    expect(
      SessionLoadChoice.weightUnit(
        preference: appWide,
        refs: [_cable],
        gym: _gym,
      ),
      m.ExerciseWeightUnit.kilograms,
    );
    expect(
      SessionLoadChoice.weightUnit(preference: null, refs: [_cable], gym: _gym),
      isNull,
    );
  });

  test('loadsPerSet: 2 for a weight in each hand', () {
    expect(
      SessionLoadChoice.loadsPerSet(
        library('db', metrics: const [m.TrackableExerciseMetric.weightPerSide]),
      ),
      2,
    );
    expect(
      SessionLoadChoice.loadsPerSet(
        library(
          'lunge',
          metrics: const [
            m.TrackableExerciseMetric.weightPerSide,
            m.TrackableExerciseMetric.repsPerSide,
          ],
        ),
      ),
      isNull,
    );
    expect(SessionLoadChoice.loadsPerSet(library('bench')), isNull);
  });

  test('machineBaseKg: a plates-only machine switched on', () {
    expect(
      SessionLoadChoice.machineBaseKg(
        refs: [_bar, ref(m.EquipmentKind.plateLoadedMachine, 'sled')],
        gym: _gym,
      ),
      closeTo(40.823, 0.001),
    );
    for (final refs in [
      [ref(m.EquipmentKind.plateLoadedMachine, 'press')],
      [ref(m.EquipmentKind.plateLoadedMachine, 'missing')],
      [_bar],
      null,
    ]) {
      expect(SessionLoadChoice.machineBaseKg(refs: refs, gym: _gym), isNull);
    }
    expect(
      SessionLoadChoice.machineBaseKg(
        refs: [ref(m.EquipmentKind.plateLoadedMachine, 'sled')],
        gym: null,
      ),
      isNull,
    );
  });

  test('takingLoad puts an exercise on the equipment the session chooses', () {
    final squat = library(
      'squat',
      metrics: const [m.TrackableExerciseMetric.weightPerSide],
      variations: [
        variation('sled', [ref(m.EquipmentKind.plateLoadedMachine, 'sled')]),
      ],
    );

    final loaded = takingLoad(
      exercise('e'),
      exercise: squat,
      gym: _gym,
      preference: null,
    );

    expect(loaded.chosenVariationId, 'sled');
    expect(loaded.equipmentVariations, hasLength(1));
    expect(loaded.weightUnit, m.ExerciseWeightUnit.pounds);
    expect(loaded.loadsPerSet, 2);
    expect(loaded.machineBaseKg, closeTo(40.823, 0.001));
  });

  test('refittingLoad rounds the open sets on the new equipment', () {
    final bench = library(
      'bench',
      variations: [
        variation('bar', [_bar]),
      ],
    );
    final open = exercise(
      'e',
      variations: [
        variation('bar', [_bar]),
      ],
      sets: [
        set('done', weightKg: 61, done: true),
        set('open', weightKg: 61),
        set('empty', weightKg: null),
      ],
    );

    final refitted = refittingLoad(
      open,
      library: bench,
      gym: _gym,
      preference: null,
    );

    expect(refitted.weightUnit, m.ExerciseWeightUnit.pounds);
    expect(refitted.sets.map((s) => s.weightKg), [
      61,
      closeTo(61.235, 0.001),
      null,
    ]);
    expect(refitted.machineBaseKg, isNull);
  });

  test('sameLoad: one kind of load, or either unknown', () {
    expect(sameLoad([_bar], [_bar]), isTrue);
    expect(sameLoad([_bar], [_cable]), isFalse);
    expect(sameLoad(null, [_cable]), isTrue);
  });

  group('LibraryExercise', () {
    test('tracking mode: weight, then distance, then time, else reps', () {
      m.TrackingMode mode(List<m.TrackableExerciseMetric> metrics) =>
          library('x', metrics: metrics).trackingMode;
      expect(
        mode(const [
          m.TrackableExerciseMetric.weightPerSideAssistance,
          m.TrackableExerciseMetric.distanceLong,
        ]),
        m.TrackingMode.weightReps,
      );
      expect(
        mode(const [
          m.TrackableExerciseMetric.distanceShortPerSide,
          m.TrackableExerciseMetric.duration,
        ]),
        m.TrackingMode.distanceTime,
      );
      expect(
        mode(const [m.TrackableExerciseMetric.durationPerSide]),
        m.TrackingMode.timeOnly,
      );
      expect(
        mode(const [m.TrackableExerciseMetric.repsPerSide]),
        m.TrackingMode.repsOnly,
      );
    });

    test('per side only for reps, duration or short distance per side', () {
      expect(
        library(
          'x',
          metrics: const [m.TrackableExerciseMetric.repsPerSide],
        ).isPerSide,
        isTrue,
      );
      expect(
        library(
          'x',
          metrics: const [m.TrackableExerciseMetric.weightPerSide],
        ).isPerSide,
        isFalse,
      );
    });

    test('assisted, and the picture', () {
      expect(
        library(
          'x',
          metrics: const [m.TrackableExerciseMetric.weightPerSideAssistance],
        ).isAssisted,
        isTrue,
      );
      expect(
        library('x', name: ' Barbell Bench Press ').sessionImageName,
        'BarbellBenchPress',
      );
      expect(
        library(
          'x',
          name: 'Barbell Bench Press',
          imageUrl: 'https://example.com/b.png',
        ).sessionImageName,
        'https://example.com/b.png',
      );
      expect(
        library(
          'x',
          name: 'Barbell Bench Press',
          imageUrl: '',
        ).sessionImageName,
        'BarbellBenchPress',
      );
      expect(library('x', name: 'Unknown Lift').sessionImageName, isNull);
    });
  });
}
