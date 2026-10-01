//
//  WorkoutExerciseModel.swift
//  Compound
//
//  Created by Andrew Coyle on 23/09/2025.
//

import Foundation

struct WorkoutExerciseModel: Identifiable, DataSyncModelProtocol, Equatable {
    let id: String
    let authorId: String
    var templateId: String
    var name: String
    var trackingMode: TrackingMode
    var index: Int
    var notes: String?
    var imageName: String?
    var sets: [WorkoutSetModel]
    var setTargets: [SetTarget]
    var chosenVariationId: String?
    var equipmentVariations: [EquipmentVariation]
    var supersetGroupId: String?

    init(
        id: String,
        authorId: String,
        templateId: String,
        name: String,
        trackingMode: TrackingMode,
        index: Int,
        notes: String? = nil,
        imageName: String? = nil,
        sets: [WorkoutSetModel],
        setTargets: [SetTarget] = [],
        chosenVariationId: String? = nil,
        equipmentVariations: [EquipmentVariation] = [],
        supersetGroupId: String? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.templateId = templateId
        self.name = name
        self.trackingMode = trackingMode
        self.index = index
        self.notes = notes
        self.imageName = imageName
        self.sets = sets
        self.setTargets = setTargets
        self.chosenVariationId = chosenVariationId
        self.equipmentVariations = equipmentVariations
        self.supersetGroupId = supersetGroupId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case templateId = "template_id"
        case name
        case trackingMode = "tracking_mode"
        case index
        case notes
        case imageName = "image_name"
        case sets
        case setTargets = "set_targets"
        case chosenVariationId = "chosen_variation_id"
        case equipmentVariations = "equipment_variations"
        case supersetGroupId = "superset_group_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        templateId = try container.decode(String.self, forKey: .templateId)
        name = try container.decode(String.self, forKey: .name)
        trackingMode = try container.decode(TrackingMode.self, forKey: .trackingMode)
        index = try container.decode(Int.self, forKey: .index)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        sets = try container.decode([WorkoutSetModel].self, forKey: .sets)
        setTargets = try container.decodeIfPresent([SetTarget].self, forKey: .setTargets) ?? []
        chosenVariationId = try container.decodeIfPresent(String.self, forKey: .chosenVariationId)
        equipmentVariations = try container.decodeIfPresent([EquipmentVariation].self, forKey: .equipmentVariations) ?? []
        supersetGroupId = try container.decodeIfPresent(String.self, forKey: .supersetGroupId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(templateId, forKey: .templateId)
        try container.encode(name, forKey: .name)
        try container.encode(trackingMode, forKey: .trackingMode)
        try container.encode(index, forKey: .index)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(imageName, forKey: .imageName)
        try container.encode(sets, forKey: .sets)
        try container.encode(setTargets, forKey: .setTargets)
        try container.encodeIfPresent(chosenVariationId, forKey: .chosenVariationId)
        try container.encode(equipmentVariations, forKey: .equipmentVariations)
        try container.encodeIfPresent(supersetGroupId, forKey: .supersetGroupId)
    }

    /// How many working sets are logged, with a left/right pair counted as the one set it is.
    /// See `WorkoutSetPairing`.
    var completedSetsCount: Int {
        loggedSetCount
    }

    static var mock: WorkoutExerciseModel {
        mocks.first ?? userMocks[0]
    }

    /// Session exercises built from the seeded library, the same way `WorkoutSessionModel`
    /// builds them from a template: the seeded exercise's id as `templateId`, its real name,
    /// the tracking mode derived from its metrics, and the image resolved through `Constants`.
    /// Hand-written names like "Bench Press" matched nothing in the image map, so every mock
    /// session exercise rendered without artwork.
    static var mocks: [WorkoutExerciseModel] {
        ExerciseModel.mocks.prefix(10).enumerated().map { index, exercise in
            mock(exercise: exercise, index: index)
        }
    }

    /// The same, for the mock user's own exercises — these cover the duration-tracked and
    /// reps-only modes the seeded library does not.
    static var userMocks: [WorkoutExerciseModel] {
        ExerciseModel.userMocks.enumerated().map { index, exercise in
            mock(exercise: exercise, index: index)
        }
    }

    static func mock(exercise: ExerciseModel, index: Int) -> WorkoutExerciseModel {
        let trackingMode = WorkoutSessionModel.trackingMode(for: exercise)
        return WorkoutExerciseModel(
            id: "workout-exercise-\(exercise.id)",
            authorId: "mock_user_123",
            templateId: exercise.id,
            name: exercise.name,
            trackingMode: trackingMode,
            index: index + 1,
            notes: nil,
            imageName: Constants.exerciseImageName(for: exercise.name),
            sets: mockSets(exerciseId: exercise.id, trackingMode: trackingMode, index: index),
            setTargets: [],
            equipmentVariations: exercise.equipmentVariations
        )
    }

    /// Three completed working sets, filled in for whichever metrics the exercise tracks —
    /// a duration-tracked exercise carrying a weight and no time reads as broken data.
    private static func mockSets(exerciseId: String, trackingMode: TrackingMode, index: Int) -> [WorkoutSetModel] {
        let baseWeight: Double = 40 + Double(index % 5) * 12.5
        let tracksReps = trackingMode == .weightReps || trackingMode == .repsOnly
        let tracksWeight = trackingMode == .weightReps
        let tracksDuration = trackingMode == .timeOnly || trackingMode == .distanceTime
        let tracksDistance = trackingMode == .distanceTime

        return (0..<3).map { setIndex -> WorkoutSetModel in
            let reps: Int? = tracksReps ? 10 - setIndex : nil
            let weightKg: Double? = tracksWeight ? baseWeight + Double(setIndex) * 2.5 : nil
            let durationSec: Int? = tracksDuration ? 45 + setIndex * 15 : nil
            let distanceMeters: Double? = tracksDistance ? Double(setIndex + 1) * 400 : nil
            let completedAt = Date().addingTimeInterval(Double(setIndex - 3) * 300)
            let dateCreated = Date().addingTimeInterval(Double(setIndex - 4) * 300)

            return WorkoutSetModel(
                id: "\(exerciseId)-set-\(setIndex + 1)",
                authorId: "mock_user_123",
                index: setIndex + 1,
                reps: reps,
                weightKg: weightKg,
                durationSec: durationSec,
                distanceMeters: distanceMeters,
                rpe: 7 + Double(setIndex) * 0.5,
                isWarmup: false,
                completedAt: completedAt,
                dateCreated: dateCreated
            )
        }
    }
}
