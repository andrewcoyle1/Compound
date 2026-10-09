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
    /// The reps an AMRAP set sets out to beat, from the template's set plan; nil for every other
    /// set and for every set created without the plan.
    var targetReps: Int?
    /// The resistance bands used, by name, in the order they were chosen: "Red", "Blue". `nil` for
    /// every set without bands and every set logged before bands were recorded. Names, not ids, so
    /// the set still reads right after the gym's bands are renamed or removed. Bands carry no kg,
    /// so they add nothing to `volumeKg`.
    var bands: [String]?

    var isWarmup: Bool
    var completedAt: Date?
    var dateCreated: Date

    /// Weight × reps, `nil` without both. A `both` row is two limbs' work logged once, so it
    /// counts twice — the same as the left and right rows it stands for.
    ///
    /// `nil` for a negative weight too: that is assistance (`ExerciseModel.isAssisted`), and
    /// without the lifter's bodyweight there is no load to multiply.
    var volumeKg: Double? {
        guard let weightKg, weightKg >= 0, let reps else { return nil }
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
        targetReps: Int? = nil,
        bands: [String]? = nil,
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
        self.targetReps = targetReps
        self.bands = bands
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
        case targetReps = "target_reps"
        case bands
        case isWarmup
        case completedAt = "completed_at"
        case dateCreated = "date_created"
    }

    /// Written by hand for `bands` alone: an unreadable value (written by a later build, or
    /// corrupted) reads as no bands rather than throwing, for the reason `sideRawValue` is stored
    /// raw. Every other field decodes exactly as the synthesized decoder did.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        index = try container.decode(Int.self, forKey: .index)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        durationSec = try container.decodeIfPresent(Int.self, forKey: .durationSec)
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters)
        rpe = try container.decodeIfPresent(Double.self, forKey: .rpe)
        sideRawValue = try container.decodeIfPresent(String.self, forKey: .sideRawValue)
        kindRawValue = try container.decodeIfPresent(String.self, forKey: .kindRawValue)
        parentSetId = try container.decodeIfPresent(String.self, forKey: .parentSetId)
        targetReps = try container.decodeIfPresent(Int.self, forKey: .targetReps)
        bands = (try? container.decodeIfPresent([String].self, forKey: .bands)) ?? nil
        isWarmup = try container.decode(Bool.self, forKey: .isWarmup)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        dateCreated = try container.decode(Date.self, forKey: .dateCreated)
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
