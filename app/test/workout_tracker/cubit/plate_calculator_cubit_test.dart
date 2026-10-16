import 'package:bloc_test/bloc_test.dart';
import 'package:compound/workout_tracker/cubit/plate_calculator_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_rules/training_rules.dart' as r;

import '../../onboarding/cubit/helpers.dart';

/// Swift `PlateCalculatorPresenterTests`, case for case.
void main() {
  const kg = ExerciseWeightUnit.kilograms;
  final date = DateTime.utc(2026, 10, 16);

  GymProfileModel gym() => GymProfileModel(
    id: 'gym',
    authorId: 'u',
    name: 'Gym',
    icon: 'dumbbell',
    dateCreated: date,
    dateModified: date,
    freeWeights: [
      FreeWeights(
        id: 'weight_plates',
        typeId: 'weight_plates',
        name: 'Plates',
        needsColour: true,
        isPlates: true,
        isActive: true,
        range: [
          for (final weight in [2.5, 5.0, 10.0, 25.0])
            FreeWeightsAvailable(
              id: 'p$weight',
              availableWeights: weight,
              unit: kg,
              isActive: true,
            ),
        ],
      ),
    ],
    loadableBars: const [
      LoadableBars(
        id: 'barbell',
        typeId: 'barbell',
        name: 'Barbell',
        collarWeight: 0,
        isActive: true,
        baseWeights: [
          BarBaseWeight(id: 'b7', baseWeight: 7, unit: kg, isActive: true),
          BarBaseWeight(id: 'b20', baseWeight: 20, unit: kg, isActive: true),
        ],
      ),
    ],
    fixedWeightBars: const [],
    bands: const [],
    bodyWeights: const [],
    supportEquipment: const [],
    accessoryEquipment: const [],
    loadableAccessoryEquipment: const [],
    cableMachines: const [],
    plateLoadedMachines: const [],
    pinLoadedMachines: const [],
  );

  const barbell = EquipmentRef(
    kind: EquipmentKind.loadableBar,
    equipmentId: 'barbell',
  );

  late RecordingAnalytics analytics;

  setUp(() => analytics = RecordingAnalytics());

  PlateCalculatorCubit build({double? total, double machineBase = 0}) =>
      PlateCalculatorCubit(
        PlateCalculatorSetup(
          gym: gym(),
          equipment: barbell,
          unit: kg,
          total: total,
          machineBase: machineBase,
        ),
        analytics: analytics.repository,
      );

  test("it loads the set's weight on the heaviest bar", () {
    final state = build(total: 70).state;
    expect(state.load, 70);
    expect(state.chosenBarId, 'b20');
    expect([for (final bar in state.barChoices) bar.id], ['b7', 'b20']);
    expect(state.loading, const r.PlateLoading(perSide: [25], base: 20));
    expect(analytics.names, ['PlateCalculatorView_Appear']);
  });

  test('the title is the load', () {
    expect(build(total: 17, machineBase: 7).state.load, 10);
    expect(build().state.load, isNull);
  });

  blocTest<PlateCalculatorCubit, PlateCalculatorState>(
    'choosing a bar reloads the weight',
    build: () => build(total: 57),
    act: (cubit) => cubit.barChosen('b7'),
    verify: (cubit) {
      expect(cubit.state.chosenBarId, 'b7');
      expect(cubit.state.loading, const r.PlateLoading(perSide: [25], base: 7));
      expect(analytics.names, contains('PlateCalculatorView_Bar_Chosen'));
    },
  );

  test('a weight the plates cannot make says the nearest', () {
    final state = build(total: 21).state;
    expect(state.loading, isNull);
    expect(state.notLoadable, const r.NotLoadable(below: 20, above: 25));
    expect(build(total: 70).state.notLoadable, isNull);
    expect(build().state.notLoadable, isNull);
  });

  blocTest<PlateCalculatorCubit, PlateCalculatorState>(
    'done hands back the edited gym',
    build: () => build(total: 70),
    act: (cubit) => cubit
      ..barChosen('b7')
      ..plateToggled(cubit.state.plateChoices.first)
      ..done(),
    verify: (cubit) {
      final edited = cubit.state.gym;
      expect(
        edited.loadableBars
            .firstWhere((b) => b.id == 'barbell')
            .chosenBaseWeightId,
        'b7',
      );
      expect(cubit.state.plateChoices.first, (weight: 25.0, isOn: false));
      expect(
        analytics.names,
        containsAllInOrder([
          'PlateCalculatorView_Plate_Toggled',
          'PlateCalculatorView_Done',
        ]),
      );
    },
  );

  test('a plate-loaded machine has its base and no bars to choose', () {
    final machine = PlateCalculatorCubit(
      PlateCalculatorSetup(
        gym: GymProfileModel.fromFirestore({
          ...gym().toFirestore(),
          'plate_loaded_machines': [
            {
              'id': 'sled',
              'typeId': 'sled',
              'name': 'Sled',
              'baseWeight': 40.0,
              'unit': 'kilograms',
              'sleeves': 2,
              'isActive': true,
            },
          ],
        }),
        equipment: const EquipmentRef(
          kind: EquipmentKind.plateLoadedMachine,
          equipmentId: 'sled',
        ),
        unit: kg,
        total: 90,
      ),
      analytics: analytics.repository,
    ).state;
    expect(machine.barChoices, isEmpty);
    expect(machine.chosenBarId, isNull);
    expect(machine.step.baseWeight, 40);
    expect(machine.loading, const r.PlateLoading(perSide: [25], base: 40));
  });

  test('a bar chosen but switched off loads the heaviest', () {
    final stored = gym().toFirestore();
    final bars = (stored['loadable_bars']! as List)
        .cast<Map<String, Object?>>();
    final bar = {...bars.first, 'chosenBaseWeightId': 'b7'};
    bar['baseWeights'] = [
      for (final weight
          in (bar['baseWeights']! as List).cast<Map<String, Object?>>())
        if (weight['id'] == 'b7') {...weight, 'isActive': false} else weight,
    ];
    final state = PlateCalculatorState(
      PlateCalculatorSetup(
        gym: gym(),
        equipment: barbell,
        unit: kg,
        total: null,
      ),
      GymProfileModel.fromFirestore({
        ...stored,
        'loadable_bars': [bar, ...bars.skip(1)],
      }),
    );
    expect(state.chosenBarId, 'b20');
  });
}
