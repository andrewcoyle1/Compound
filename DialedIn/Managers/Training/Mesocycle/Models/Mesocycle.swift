//
//  Mesocycle.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/01/2026.
//

import SwiftUI

struct Mesocycle: DataSyncModelProtocol {
    var id: String
    var authorId: String
    var name: String
    var icon: String
    var colour: String
    var numMicrocycles: Int = 8
    var deload: DeloadType = .none
    var periodisation: Bool = false
    var workoutTemplates: [WorkoutTemplateModel]
    let dateCreated: Date
    let dateModified: Date
    
    init(
        id: String = UUID().uuidString,
        authorId: String,
        name: String,
        icon: String,
        colour: String,
        numMicrocycles: Int = 8,
        deload: DeloadType = .none,
        periodisation: Bool = false,
        workoutTemplates: [WorkoutTemplateModel] = [],
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.name = name
        self.icon = icon
        self.colour = colour
        self.numMicrocycles = numMicrocycles
        self.deload = deload
        self.periodisation = periodisation
        self.workoutTemplates = workoutTemplates.isEmpty ? Self.defaultWorkoutTemplateModels(authorId: authorId) : workoutTemplates
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case name
        case icon
        case colour
        case numMicrocycles = "num_microcycles"
        case deload
        case periodisation
        case workoutTemplates = "workout_templates"
        case dateCreated = "date_created"
        case dateModified = "date_modified"
    }
    
    var eventParameters: [String: Any] {
        [:]
    }
    
    static func defaultWorkoutTemplateModels(authorId: String) -> [WorkoutTemplateModel] {
        [
            WorkoutTemplateModel(
                id: UUID().uuidString,
                authorId: authorId,
                name: "Rest",
                dateCreated: Date(),
                exercises: []
            )
        ]
    }
    
    static var mock: Mesocycle {
        mocks[0]
    }
    
    static var mocks: [Mesocycle] {
        // Slices of the seeded templates rather than all thirteen, so a mock mesocycle reads as a
        // three-to-four day microcycle instead of a fortnight of unique sessions.
        let templates = WorkoutTemplateModel.mocks
        func days(_ range: Range<Int>) -> [WorkoutTemplateModel] {
            Array(templates.dropFirst(range.lowerBound).prefix(range.count))
        }

        return [
            Mesocycle(
                id: "training-program-1",
                authorId: "mock_user_123",
                name: "Block 1",
                icon: "dumbbell",
                colour: Color.red.asHex(),
                numMicrocycles: 8,
                deload: .none,
                periodisation: false,
                workoutTemplates: days(0..<3)
            ),
            Mesocycle(
                id: "training-program-2",
                authorId: "mock_user_123",
                name: "Block 2",
                icon: "pencil",
                colour: Color.blue.asHex(),
                numMicrocycles: 8,
                deload: .end,
                periodisation: false,
                workoutTemplates: days(3..<7)
            ),
            Mesocycle(
                id: "training-program-3",
                authorId: "mock_user_123",
                name: "Block 3",
                icon: "flag",
                colour: Color.green.asHex(),
                numMicrocycles: 8,
                deload: .none,
                periodisation: false,
                workoutTemplates: days(7..<10)
            )
        ]
    }

}

enum PeriodisationPhase {
    case hypertrophy
    case strength
    case power

    var repRange: ClosedRange<Int> {
        switch self {
        case .hypertrophy: return 8...15
        case .strength:    return 5...8
        case .power:       return 1...5
        }
    }

    var weightMultiplier: Double {
        switch self {
        case .hypertrophy: return 0.65
        case .strength:    return 0.80
        case .power:       return 0.90
        }
    }

    var label: String {
        switch self {
        case .hypertrophy: return "Hypertrophy Phase"
        case .strength:    return "Strength Phase"
        case .power:       return "Power Phase"
        }
    }
}

enum DeloadType: String, Hashable, Codable, CaseIterable {
    case none
    case start
    case end
    
    var title: String {
        switch self {
        case .none: return "None"
        case .start: return "First Cycle"
        case .end: return "Last Cycle"
        }
    }
    
    var description: String {
        switch self {
        case .none: return "Train continuously without scheduled reductions in intensity or volume."
        case .start: return "Start each training block with a lower-intensity cycle to ease into new workloads and reduce soreness."
        case .end: return "Finish each training block with a lighter cycle to promote recovery and readiness for the next phase."
        }
    }
}
