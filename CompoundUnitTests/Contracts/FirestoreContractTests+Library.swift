//
//  FirestoreContractTests+Library.swift
//  CompoundUnitTests
//
//  The training library under the Firestore contract: exercises (`exercise_templates`, queried by
//  `author_id`), exercise and workout settings, workout templates, and gym profiles with each kind
//  of equipment in a folder of its own, so every lenient path in their decoders has a case. See
//  FirestoreContractTests.swift.
//

import Foundation
import Testing
import FirebaseFirestore
@testable import Compound

extension FirestoreContractTests {

    /// Nothing here is written field by field: each manager saves whole documents, which merge.
    /// The exercise's three are the `author_id` listener in `ExerciseModelManager` and the reads in
    /// `functions/coach.js` (`id`, `muscle_groups`).
    static func libraryContracts() throws -> [Contract] {
        [
            try contract(
                ExerciseModel.self, directory: "exercise_model",
                full: Samples.fullExerciseModel, minimal: Samples.minimalExerciseModel,
                namedFields: ([.id, .authorId, .muscleGroups] as [ExerciseModel.CodingKeys]).map(\.rawValue)
            ),
            try contract(
                ExerciseSettingsModel.self, directory: "exercise_settings",
                full: Samples.fullExerciseSettings, minimal: Samples.minimalExerciseSettings, namedFields: []
            ),
            try contract(
                WorkoutTemplateModel.self, directory: "workout_template",
                full: Samples.fullWorkoutTemplate, minimal: Samples.minimalWorkoutTemplate, namedFields: []
            ),
            try contract(
                WorkoutTemplateExercise.self, directory: "workout_template_exercise",
                full: Samples.fullTemplateExercise, minimal: Samples.minimalTemplateExercise, namedFields: []
            ),
            try contract(
                WorkoutSettings.self, directory: "workout_settings",
                full: Samples.fullWorkoutSettings, minimal: Samples.minimalWorkoutSettings, namedFields: []
            )
        ]
    }

    static func gymContracts() throws -> [Contract] {
        [
            try contract(
                GymProfileModel.self, directory: "gym_profile",
                full: try Samples.fullGymProfile(), minimal: try Samples.minimalGymProfile(), namedFields: []
            ),
            try contract(
                FreeWeights.self, directory: "gym_free_weights",
                full: Samples.fullFreeWeights, minimal: Samples.minimalFreeWeights, namedFields: []
            ),
            try contract(
                LoadableBars.self, directory: "gym_loadable_bars",
                full: Samples.fullLoadableBars, minimal: Samples.minimalLoadableBars, namedFields: []
            ),
            try contract(
                FixedWeightBars.self, directory: "gym_fixed_weight_bars",
                full: Samples.fullFixedWeightBars, minimal: Samples.minimalFixedWeightBars, namedFields: []
            ),
            try contract(
                Bands.self, directory: "gym_bands",
                full: Samples.fullBands, minimal: Samples.minimalBands, namedFields: []
            ),
            try contract(
                BodyWeights.self, directory: "gym_body_weights",
                full: Samples.fullBodyWeights, minimal: Samples.minimalBodyWeights, namedFields: []
            )
        ] + (try gymAccessoryAndMachineContracts())
    }

    private static func gymAccessoryAndMachineContracts() throws -> [Contract] {
        [
            try contract(
                SupportEquipment.self, directory: "gym_support_equipment",
                full: Samples.fullSupportEquipment, minimal: Samples.minimalSupportEquipment, namedFields: []
            ),
            try contract(
                AccessoryEquipment.self, directory: "gym_accessory_equipment",
                full: Samples.fullAccessoryEquipment, minimal: Samples.minimalAccessoryEquipment, namedFields: []
            ),
            try contract(
                LoadableAccessoryEquipment.self, directory: "gym_loadable_accessory_equipment",
                full: Samples.fullLoadableAccessoryEquipment, minimal: Samples.minimalLoadableAccessoryEquipment,
                namedFields: []
            ),
            try contract(
                CableMachine.self, directory: "gym_cable_machine",
                full: Samples.fullCableMachine, minimal: Samples.minimalCableMachine, namedFields: []
            ),
            try contract(
                PlateLoadedMachine.self, directory: "gym_plate_loaded_machine",
                full: Samples.fullPlateLoadedMachine, minimal: Samples.minimalPlateLoadedMachine, namedFields: []
            ),
            try contract(
                PinLoadedMachine.self, directory: "gym_pin_loaded_machine",
                full: Samples.fullPinLoadedMachine, minimal: Samples.minimalPinLoadedMachine, namedFields: []
            )
        ]
    }

    /// The library's enums, exhaustive as in `enumRawValuesMatch`.
    static func libraryEnums() -> [String: [String]] {
        // Neither is CaseIterable.
        let targets: [MuscleTargetType] = [.primary, .secondary]
        for target in targets {
            switch target {
            case .primary, .secondary: break
            }
        }
        let metrics: [TrackableExerciseMetric] = [
            .reps, .repsPerSide, .weight, .weightPerSide, .weightPerSidePersistent, .weightPerSideAssistance,
            .duration, .durationPerSide, .distanceShort, .distanceShortPerSide, .distanceLong
        ]
        for metric in metrics {
            switch metric {
            case .reps, .repsPerSide, .weight, .weightPerSide, .weightPerSidePersistent, .weightPerSideAssistance,
                 .duration, .durationPerSide, .distanceShort, .distanceShortPerSide, .distanceLong: break
            }
        }
        return [
            "Muscles": Muscles.allCases.map(\.rawValue),
            "MuscleTargetType": targets.map(\.rawValue),
            "TrackableExerciseMetric": metrics.map(\.rawValue),
            "ExerciseType": ExerciseType.allCases.map(\.rawValue),
            "Laterality": Laterality.allCases.map(\.rawValue),
            // `anyWorkout` and `workoutsInProgram` are the stored values of `.sameWorkout` and
            // `.workoutsInMesocycle`.
            "PreviousWorkoutReferenceOption": PreviousWorkoutReferenceOption.allCases.map(\.rawValue),
            "InitialLogFillOption": InitialLogFillOption.allCases.map(\.rawValue),
            "ProgressionAdjustmentMode": ProgressionAdjustmentMode.allCases.map(\.rawValue)
        ]
    }

    @Test("The gym equipment catalogue matches contracts/firestore/gym_equipment_catalogue.json")
    func gymCatalogueMatches() throws {
        let text = try Self.jsonText(try GymCatalogueContract.catalogue())
        let url = Self.root.appendingPathComponent("gym_equipment_catalogue.json")
        if ProcessInfo.processInfo.environment["RECORD_CONTRACTS"] == "1" { try Self.write(try GymCatalogueContract.catalogue(), to: url) }
        #expect(
            text == (try String(contentsOf: url, encoding: .utf8)),
            "The catalogue changed: re-record with RECORD_CONTRACTS=1, then regenerate the Dart copy"
        )
    }
}
