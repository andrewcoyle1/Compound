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
        // Band and plate colours are iOS system colours turned into hex when the profile is made, so
        // their values follow the appearance, the OS and the SDK the tests were built with (Xcode 26.6
        // on CI, 27 here). Each must be a hex colour; everything else must match exactly.
        let stored = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let made = try JSONSerialization.jsonObject(with: Data(text.utf8))
        var colours: [String] = []
        #expect(
            try Self.jsonText(Self.withoutSystemColours(made, collecting: &colours))
                == (try Self.jsonText(Self.withoutSystemColours(stored, collecting: &colours))),
            "The catalogue changed: re-record with RECORD_CONTRACTS=1, then regenerate the Dart copy"
        )
        let hex = /^#[0-9A-F]{6}$/
        #expect(!colours.isEmpty && colours.allSatisfy { $0.wholeMatch(of: hex) != nil }, "System colours: \(colours)")
    }

    /// `object` with every `bandColour` and `plateColour` value replaced by a placeholder, the values
    /// collected.
    private static func withoutSystemColours(_ object: Any, collecting colours: inout [String]) -> Any {
        if let dictionary = object as? [String: Any] {
            var copy: [String: Any] = [:]
            for (key, value) in dictionary {
                if ["bandColour", "plateColour"].contains(key), let colour = value as? String {
                    colours.append(colour)
                    copy[key] = "#SYSTEM"
                } else {
                    copy[key] = withoutSystemColours(value, collecting: &colours)
                }
            }
            return copy
        }
        if let array = object as? [Any] { return array.map { withoutSystemColours($0, collecting: &colours) } }
        return object
    }
}
