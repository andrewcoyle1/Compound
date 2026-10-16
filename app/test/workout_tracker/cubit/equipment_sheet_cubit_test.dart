import 'package:compound/workout_tracker/cubit/equipment_sheet_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show GymEditorRules, GymEquipmentList, sampleGymProfiles;

import '../../helpers/library_fixtures.dart';
import '../../onboarding/cubit/helpers.dart';

/// Swift `WorkoutEquipmentSheetPresenterTests`: what the sheet lists. The
/// taps that hand a choice back are the sheet's widget tests.
void main() {
  late RecordingAnalytics analytics;

  setUp(() => analytics = RecordingAnalytics());

  EquipmentVariation variation(String id) => EquipmentVariation(
    id: id,
    resistanceEquipment: const [
      EquipmentRef(kind: EquipmentKind.freeWeight, equipmentId: 'dumbbells'),
    ],
    supportEquipment: const [
      EquipmentRef(
        kind: EquipmentKind.supportEquipment,
        equipmentId: 'flat_bench',
      ),
    ],
  );

  WorkoutExerciseModel exercise({
    String templateId = 'template-1',
    String? chosenVariationId,
    List<EquipmentVariation> variations = const [],
  }) => WorkoutExerciseModel(
    id: 'exercise-1',
    authorId: 'user-1',
    templateId: templateId,
    name: 'Bench Press',
    trackingMode: TrackingMode.weightReps,
    index: 1,
    sets: const [],
    chosenVariationId: chosenVariationId,
    equipmentVariations: variations,
  );

  EquipmentSheetCubit build(
    WorkoutExerciseModel exercise, {
    List<ExerciseModel> library = const [],
    List<GymProfileModel> gyms = const [],
    GymProfileModel? gym,
  }) => EquipmentSheetCubit(
    EquipmentSheetSetup(
      exercise: exercise,
      library: library,
      gyms: gyms,
      gym: gym,
    ),
    analytics: analytics.repository,
  );

  test("the session's own variations are listed", () {
    final state = build(
      exercise(variations: [variation('v1'), variation('v2')]),
    ).state;
    expect([for (final item in state.items) item.id], ['v1', 'v2']);
    expect([for (final item in state.items) item.number], [1, 2]);
    expect(state.hasNoVariations, isFalse);
    expect(state.exerciseId, 'exercise-1');
    expect(state.exerciseName, 'Bench Press');
    expect(analytics.names, [
      'WorkoutExerciseEquipmentSheetView_Appear',
      'WorkoutExerciseEquipmentSheetView_LoadVariations_Start',
      'WorkoutExerciseEquipmentSheetView_LoadVariations_Success',
    ]);
  });

  test('equipment is shown by name, not by reference', () {
    final item = build(exercise(variations: [variation('v1')]))
        .state
        .items
        .single;
    expect(item.resistance, ['Dumbbells']);
    expect(item.support, ['Flat Bench']);
    expect(item.equipment, {
      (EquipmentKind.freeWeight, 'dumbbells'),
      (EquipmentKind.supportEquipment, 'flat_bench'),
    });
  });

  test('equipment no catalogue lists is named for what happened to it', () {
    const removed = 'B5E4C0A2-1C2D-4E5F-8A9B-0C1D2E3F4A5B';
    final item = build(
      exercise(
        variations: [
          const EquipmentVariation(
            id: 'v1',
            resistanceEquipment: [
              EquipmentRef(
                kind: EquipmentKind.cableMachine,
                equipmentId: removed,
              ),
              EquipmentRef(
                kind: EquipmentKind.freeWeight,
                equipmentId: 'mystery_weight',
              ),
            ],
          ),
        ],
      ),
    ).state.items.single;
    expect(item.resistance, [null, 'mystery_weight']);
  });

  test('a variation with no equipment lists none', () {
    final item = build(
      exercise(variations: [const EquipmentVariation(id: 'v1')]),
    ).state.items.single;
    expect(item.resistance, isEmpty);
    expect(item.support, isEmpty);
  });

  test('the first variation is chosen when none was', () {
    expect(
      build(exercise(variations: [variation('v1'), variation('v2')]))
          .state
          .chosenId,
      'v1',
    );
  });

  test('an existing choice is kept', () {
    expect(
      build(
        exercise(
          chosenVariationId: 'v2',
          variations: [variation('v1'), variation('v2')],
        ),
      ).state.chosenId,
      'v2',
    );
  });

  test('an old session falls back to the exercise library', () {
    final state = build(
      exercise(),
      library: [
        fixtureLibraryExercise(
          'template-1',
          name: 'Bench Press',
          variations: [variation('lib-1')],
        ),
      ],
    ).state;
    expect([for (final item in state.items) item.id], ['lib-1']);
  });

  test('a stale template id is matched by name', () {
    final state = build(
      exercise(templateId: 'gone'),
      library: [
        fixtureLibraryExercise(
          'system-bench-v2',
          name: 'bench press',
          variations: [variation('lib-1')],
        ),
      ],
    ).state;
    expect([for (final item in state.items) item.id], ['lib-1']);
  });

  test('an exercise with no variations explains itself', () {
    final state = build(
      exercise(),
      library: [fixtureLibraryExercise('template-1', name: 'Bench Press')],
    ).state;
    expect(state.hasNoVariations, isTrue);
    expect(state.items, isEmpty);
    expect(
      analytics.names,
      contains('WorkoutExerciseEquipmentSheetView_LoadVariations_Fail'),
    );
  });

  test('a choice is held, and closing is tracked', () async {
    final cubit = build(
      exercise(
        chosenVariationId: 'v1',
        variations: [variation('v1'), variation('v2')],
      ),
    )..selected('v2');
    expect(cubit.state.chosenId, 'v2');
    await cubit.close();
    expect(analytics.names.last, 'WorkoutExerciseEquipmentSheetView_Disappear');
  });

  test("a variation the gym lacks says so, and follows the gym's saves", () {
    final gym = sampleGymProfiles.single;
    final cubit = build(
      exercise(variations: [variation('v1')]),
      gym: gym,
      gyms: [gym],
    );
    expect(cubit.state.items.single.isAvailable, isTrue);
    expect(cubit.state.gym, gym);

    cubit.editPressed();
    expect(
      analytics.names.last,
      'WorkoutExerciseEquipmentSheetView_EditVariation_Pressed',
    );

    final withoutBench = GymEditorRules.settingActive(
      gym,
      GymEquipmentList.supportEquipment,
      gym.supportEquipment.firstWhere((item) => item.typeId == 'flat_bench').id,
      isActive: false,
    );
    cubit.gymSaved(withoutBench);
    expect(cubit.state.items.single.isAvailable, isFalse);
    expect(cubit.state.gym, withoutBench);
  });

  test('without a gym every variation reads as available', () {
    expect(
      build(exercise(variations: [variation('v1')]))
          .state
          .items
          .single
          .isAvailable,
      isTrue,
    );
  });
}
