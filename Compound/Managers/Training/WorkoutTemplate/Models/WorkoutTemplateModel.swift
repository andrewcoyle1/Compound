//
//  WorkoutTemplate.swift
//  Compound
//
//  Created by Andrew Coyle on 24/09/2025.
//

import Foundation

struct WorkoutTemplateModel: DataSyncModelProtocol, Hashable {
    
    var id: String { self.workoutId }
    
    let workoutId: String
    let authorId: String
    var name: String
    let description: String?
    let gymProfileId: String?
    private(set) var imageURL: String?
    let dateCreated: Date
    var dateModified: Date
    var exercises: [WorkoutTemplateExercise]
    
    init(
        id: String = UUID().uuidString,
        authorId: String,
        name: String,
        description: String? = nil,
        gymProfileId: String? = nil,
        imageURL: String? = nil,
        dateCreated: Date = .now,
        dateModified: Date = .now,
        exercises: [WorkoutTemplateExercise] = [],
    ) {
        self.workoutId = id
        self.authorId = authorId
        self.name = name
        self.description = description
        self.gymProfileId = gymProfileId
        self.imageURL = imageURL
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.exercises = exercises
    }
            
    enum CodingKeys: String, CodingKey {
        case workoutId = "workout_id"
        case authorId = "author_id"
        case name = "name"
        case description = "description"
        case gymProfileId = "gym_profile_id"
        case imageURL = "image_url"
        case dateCreated = "date_created"
        case dateModified = "date_modified"
        case exercises = "exercises"
    }
    
    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "workout_\(CodingKeys.workoutId.rawValue)": workoutId,
            "workout_\(CodingKeys.authorId.rawValue)": authorId,
            "workout_\(CodingKeys.name.rawValue)": name,
            "workout_\(CodingKeys.description.rawValue)": description,
            "workout_\(CodingKeys.gymProfileId.rawValue)": gymProfileId,
            "workout_\(CodingKeys.imageURL.rawValue)": imageURL,
            "workout_\(CodingKeys.dateCreated.rawValue)": dateCreated,
            "workout_\(CodingKeys.dateModified.rawValue)": dateModified,
            "workout_\(CodingKeys.exercises.rawValue)": exercises.map { $0.id }
        ]
        return dict.compactMapValues { $0 }
    }
    
    mutating func updateImageURL(imageUrl: String) {
        self.imageURL = imageUrl
    }
}

extension WorkoutTemplateModel {
    
    static func newWorkoutTemplate(
        name: String,
        authorId: String,
        description: String? = nil,
        imageURL: String? = nil,
        exercises: [WorkoutTemplateExercise] = []
    ) -> Self {
        WorkoutTemplateModel(
            id: UUID().uuidString,
            authorId: authorId,
            name: name,
            description: description,
            imageURL: imageURL,
            dateCreated: .now,
            dateModified: .now,
            exercises: exercises
        )
    }
    
    static var mock: WorkoutTemplateModel {
        mocks.first ?? WorkoutTemplateModel(
            id: "workout-empty",
            authorId: "mock_user_123",
            name: "Full Body",
            description: nil,
            imageURL: nil,
            dateCreated: .now,
            dateModified: .now,
            exercises: []
        )
    }
    
    /// The seeded system workout templates. Built from the same `PrebuiltWorkouts.json` the app
    /// seeds at login and resolved against the seeded exercises, so a mock workout holds real
    /// exercises — with their artwork — rather than hand-written ones with no image.
    static var mocks: [WorkoutTemplateModel] {
        PrebuiltSeedData.workoutTemplates
    }

    /// Workouts the mock user built themselves, for the "my workouts" side of the library.
    /// Their exercises still come from the seeded library, which is what a real custom workout
    /// would contain.
    static var userMocks: [WorkoutTemplateModel] {
        let seeded = PrebuiltSeedData.exercises
        guard !seeded.isEmpty else { return [] }

        func exercises(_ ids: [String]) -> [WorkoutTemplateExercise] {
            ids.compactMap { id in
                guard let exercise = PrebuiltSeedData.exercise(id: id) else { return nil }
                return WorkoutTemplateExercise(exercise: exercise, setRestTimers: false)
            }
        }

        return [
            WorkoutTemplateModel(
                id: "user-workout-upper",
                authorId: "mock_user_123",
                name: "My Upper Body",
                description: "Chest and back, alternating.",
                imageURL: nil,
                dateCreated: Date(timeIntervalSinceNow: -86400 * 14),
                dateModified: Date(timeIntervalSinceNow: -86400 * 2),
                exercises: exercises([
                    "system-barbell-bench-press",
                    "system-cable-neutral-grip-lat-pulldown",
                    "system-dumbbell-seated-shoulder-press",
                    "system-single-arm-row",
                    "system-cable-bicep-curl-straight-bar"
                ])
            ),
            WorkoutTemplateModel(
                id: "user-workout-legs",
                authorId: "mock_user_123",
                name: "My Leg Day",
                description: "Squat focused, with posterior chain accessories.",
                imageURL: nil,
                dateCreated: Date(timeIntervalSinceNow: -86400 * 7),
                dateModified: Date(timeIntervalSinceNow: -86400),
                exercises: exercises([
                    "system-barbell-squat",
                    "system-barbell-romanian-deadlift",
                    "system-lying-leg-curl",
                    "system-seated-leg-extension",
                    "system-calf-press-leg-press"
                ])
            )
        ]
    }
}
