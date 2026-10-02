//
//  ExerciseModel.swift
//  Compound
//
//  Created by Andrew Coyle on 23/01/2026.
//

import Foundation

enum MuscleTargetType: String, Codable {
    case primary
    case secondary
}

struct ExerciseModel: DataSyncModelProtocol, SearchListItem, Hashable {
    var id: String
    var authorId: String
    var name: String
    var description: String?
    var imageURL: String?
    var trackableMetrics: [TrackableExerciseMetric]
    var type: ExerciseType?
    var laterality: Laterality?
    var muscleGroups: [Muscles: MuscleTargetType]
    var isBodyweight: Bool
    var equipmentVariations: [EquipmentVariation]
    var rangeOfMotion: Int
    var stability: Int
    var bodyWeightContribution: Int
    var alternateNames: [String]
    var isSystemExercise: Bool
    var dateCreated: Date
    var dateModified: Date
    var clickCount: Int?
    var bookmarkCount: Int?
    var favouriteCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case name
        case description
        case imageURL = "image_url"
        case trackableMetrics = "trackable_metrics"
        case type
        case laterality
        case muscleGroups = "muscle_groups"
        case isBodyweight = "is_bodyweight"
        case equipmentVariations = "equipment_variations"
        case rangeOfMotion = "range_of_motion"
        case stability = "stability"
        case bodyWeightContribution = "body_weight_contribution"
        case alternateNames = "alternate_names"
        case isSystemExercise = "is_system_exercise"
        case dateCreated = "date_created"
        case dateModified = "date_modified"
        case clickCount = "click_count"
        case bookmarkCount = "bookmark_count"
        case favouriteCount = "favourite_count"
    }

    init(
        id: String = UUID().uuidString,
        authorId: String,
        name: String,
        description: String? = nil,
        imageURL: String? = nil,
        trackableMetrics: [TrackableExerciseMetric],
        type: ExerciseType?,
        laterality: Laterality?,
        muscleGroups: [Muscles: MuscleTargetType],
        isBodyweight: Bool,
        equipmentVariations: [EquipmentVariation] = [],
        rangeOfMotion: Int,
        stability: Int,
        bodyWeightContribution: Int,
        alternateNames: [String],
        isSystemExercise: Bool = false,
        dateCreated: Date = .now,
        dateModified: Date = .now,
        clickCount: Int? = 0,
        bookmarkCount: Int? = 0,
        favouriteCount: Int? = 0
    ) {
        self.id = id
        self.authorId = authorId
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.trackableMetrics = trackableMetrics
        self.type = type
        self.laterality = laterality
        self.muscleGroups = muscleGroups
        self.isBodyweight = isBodyweight
        self.equipmentVariations = equipmentVariations
        self.rangeOfMotion = rangeOfMotion
        self.stability = stability
        self.bodyWeightContribution = bodyWeightContribution
        self.alternateNames = alternateNames
        self.isSystemExercise = isSystemExercise
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.clickCount = clickCount
        self.bookmarkCount = bookmarkCount
        self.favouriteCount = favouriteCount
    }

    mutating func updateImageURL(imageUrl: String) {
        imageURL = imageUrl
    }

    static var mock: ExerciseModel {
        // Falls back to a hand-written one, so a bundle that cannot supply the seeded JSON
        // degrades to a preview without artwork rather than trapping.
        mocks.first ?? userMocks[0]
    }

    /// The seeded system exercise library. Reading the same JSON the app seeds at login means
    /// mock exercises carry the real `system-*` ids and asset image names, so the Mock scheme
    /// and previews show the same artwork as a signed-in build.
    static var mocks: [ExerciseModel] {
        PrebuiltSeedData.exercises
    }

    /// Exercises the mock user created themselves, for the "my exercises" side of the library.
    /// Kept hand-written: a user-authored exercise has no bundled artwork, and these cover the
    /// duration-tracked and bodyweight cases the seeded library does not.
    static var userMocks: [ExerciseModel] {
        [
            ExerciseModel(
                id: "user-exercise-plank",
                authorId: "mock_user_123",
                name: "Plank",
                description: "An isometric core stability exercise emphasizing abdominal endurance.",
                trackableMetrics: [.duration],
                type: .core,
                laterality: .bilateral,
                muscleGroups: [
                    .abs: .primary,
                    .frontDelts: .secondary
                ],
                isBodyweight: true,
                equipmentVariations: [],
                rangeOfMotion: 1,
                stability: 5,
                bodyWeightContribution: 100,
                alternateNames: []
            ),
            ExerciseModel(
                id: "user-exercise-push-up",
                authorId: "mock_user_123",
                name: "Push Up",
                description: "A bodyweight pressing movement targeting the chest, triceps, and shoulders.",
                trackableMetrics: [.reps],
                type: .compoundUpper,
                laterality: .bilateral,
                muscleGroups: [
                    .chest: .primary,
                    .triceps: .secondary,
                    .frontDelts: .secondary
                ],
                isBodyweight: true,
                equipmentVariations: [],
                rangeOfMotion: 4,
                stability: 3,
                bodyWeightContribution: 100,
                alternateNames: ["Press Up"]
            )
        ]
    }
}

extension ExerciseModel: Sendable {}
