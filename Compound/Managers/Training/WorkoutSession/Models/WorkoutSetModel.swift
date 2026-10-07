//
//  WorkoutSet.swift
//  Compound
//
//  Created by Andrew Coyle on 23/09/2025.
//

import Foundation

struct WorkoutSetModel: Identifiable, Codable, Hashable {
    let id: String
    let authorId: String
    var index: Int
    var reps: Int?
    var weightKg: Double?
    var durationSec: Int?
    var distanceMeters: Double?
    var rpe: Double?
    /// Stored as the raw string rather than the enum so an unrecognised side — written by a later
    /// build, or corrupted — decodes as `nil` instead of throwing and taking the whole
    /// `WorkoutSessionModel` down with it. One unreadable field must not cost a logged session.
    private var sideRawValue: String?

    /// Which limb this set was worked with, for exercises done one side at a time. `nil` for every
    /// two-sided exercise, and for every set logged before sides existed.
    var side: SetSide? {
        get { SetSide(storedValue: sideRawValue) }
        set { sideRawValue = newValue?.rawValue }
    }

    /// Stored raw for the same reason as `sideRawValue`; read it through `kind` (`SetKind.swift`).
    var kindRawValue: String?
    /// The set this row is a drop, mini-set or cluster of, or `nil` for a set of its own.
    var parentSetId: String?

    var isWarmup: Bool
    var completedAt: Date?
    var dateCreated: Date

    /// Weight × reps, `nil` without both. A `both` row is two limbs' work logged once, so it
    /// counts twice — the same as the left and right rows it stands for.
    var volumeKg: Double? {
        guard let weightKg, let reps else { return nil }
        return weightKg * Double(reps) * (side == .both ? 2 : 1)
    }

    init(
        id: String,
        authorId: String,
        index: Int,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSec: Int? = nil,
        distanceMeters: Double? = nil,
        rpe: Double? = nil,
        side: SetSide? = nil,
        kind: SetKind = .standard,
        parentSetId: String? = nil,
        isWarmup: Bool,
        completedAt: Date? = nil,
        dateCreated: Date
    ) {
        self.id = id
        self.authorId = authorId
        self.index = index
        self.reps = reps
        self.weightKg = weightKg
        self.durationSec = durationSec
        self.distanceMeters = distanceMeters
        self.rpe = rpe
        self.sideRawValue = side?.rawValue
        self.kindRawValue = kind == .standard ? nil : kind.rawValue
        self.parentSetId = parentSetId
        self.isWarmup = isWarmup
        self.completedAt = completedAt
        self.dateCreated = dateCreated
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case index
        case reps
        case weightKg = "weight_kg"
        case durationSec = "duration_sec"
        case distanceMeters = "distance_meters"
        case rpe
        case sideRawValue = "side"
        case kindRawValue = "kind"
        case parentSetId = "parent_set_id"
        case isWarmup
        case completedAt = "completed_at"
        case dateCreated = "date_created"
    }

    static var mock: WorkoutSetModel {
        mocks[0]
    }
    
    static var mocks: [WorkoutSetModel] {
        [
            WorkoutSetModel(
                id: "1",
                authorId: "1",
                index: 1,
                reps: 12,
                weightKg: 60,
                durationSec: nil,
                distanceMeters: nil,
                rpe: 7.5,
                isWarmup: true,
                completedAt: Date().addingTimeInterval(-3600),
                dateCreated: Date().addingTimeInterval(-7200)
            ),
            WorkoutSetModel(
                id: "2",
                authorId: "2",
                index: 2,
                reps: 8,
                weightKg: 80,
                durationSec: nil,
                distanceMeters: nil,
                rpe: 8.5,
                isWarmup: false,
                completedAt: Date().addingTimeInterval(-3500),
                dateCreated: Date().addingTimeInterval(-7100)
            ),
            WorkoutSetModel(
                id: "3",
                authorId: "3",
                index: 3,
                reps: nil,
                weightKg: nil,
                durationSec: 60,
                distanceMeters: nil,
                rpe: 6,
                isWarmup: false,
                completedAt: Date().addingTimeInterval(-3400),
                dateCreated: Date().addingTimeInterval(-7000)
            ),
            WorkoutSetModel(
                id: "4",
                authorId: "4",
                index: 4,
                reps: 15,
                weightKg: 40,
                durationSec: nil,
                distanceMeters: nil,
                rpe: 5,
                isWarmup: true,
                completedAt: Date().addingTimeInterval(-3300),
                dateCreated: Date().addingTimeInterval(-6900)
            ),
            WorkoutSetModel(
                id: "5",
                authorId: "5",
                index: 5,
                reps: 10,
                weightKg: 90,
                durationSec: nil,
                distanceMeters: nil,
                rpe: 9,
                isWarmup: false,
                completedAt: Date().addingTimeInterval(-3200),
                dateCreated: Date().addingTimeInterval(-6800)
            ),
            WorkoutSetModel(
                id: "6",
                authorId: "6",
                index: 6,
                reps: nil,
                weightKg: nil,
                durationSec: 120,
                distanceMeters: 400,
                rpe: 8,
                isWarmup: false,
                completedAt: Date().addingTimeInterval(-3100),
                dateCreated: Date().addingTimeInterval(-6700)
            ),
            WorkoutSetModel(
                id: "7",
                authorId: "7",
                index: 7,
                reps: 20,
                weightKg: 20,
                durationSec: nil,
                distanceMeters: nil,
                rpe: 4,
                isWarmup: true,
                completedAt: Date().addingTimeInterval(-3000),
                dateCreated: Date().addingTimeInterval(-6600)
            ),
            WorkoutSetModel(
                id: "8",
                authorId: "8",
                index: 8,
                reps: 6,
                weightKg: 110,
                durationSec: nil,
                distanceMeters: nil,
                rpe: 10,
                isWarmup: false,
                completedAt: Date().addingTimeInterval(-2900),
                dateCreated: Date().addingTimeInterval(-6500)
            ),
            WorkoutSetModel(
                id: "9",
                authorId: "9",
                index: 9,
                reps: nil,
                weightKg: nil,
                durationSec: 180,
                distanceMeters: 1000,
                rpe: 7,
                isWarmup: false,
                completedAt: Date().addingTimeInterval(-2800),
                dateCreated: Date().addingTimeInterval(-6400)
            ),
            WorkoutSetModel(
                id: "10",
                authorId: "10",
                index: 10,
                reps: 8,
                weightKg: 70,
                durationSec: nil,
                distanceMeters: nil,
                rpe: 8,
                isWarmup: false,
                completedAt: Date().addingTimeInterval(-2700),
                dateCreated: Date().addingTimeInterval(-6300)
            )
        ]
    }
}
