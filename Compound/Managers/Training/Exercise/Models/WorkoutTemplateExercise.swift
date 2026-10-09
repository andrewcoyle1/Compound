//
//  WorkoutTemplateExercise.swift
//  Compound
//
//  Created by Andrew Coyle on 28/02/2026.
//

import Foundation

struct WorkoutTemplateExercise: DataSyncModelProtocol, Equatable, Hashable {
    var id: String = UUID().uuidString
    var exercise: ExerciseModel
    var setTargets: [SetTarget] = [SetTarget(setNumber: 1, setType: SetTargetSetType.standard)]
    var setRestTimers: Bool

    // MARK: - The plan's per-exercise columns
    //
    // All optional or defaulted, and decoded with `decodeIfPresent`, so every template saved
    // before they existed decodes unchanged.

    /// The coach's notes for this exercise, shown on the tracker card.
    var notes: String?
    /// How many warm-up sets to generate; nil leaves it to the weight-based rule.
    var warmupSetCount: Int?
    /// The rest after this exercise's sets, ahead of the exercise and global settings.
    var restSeconds: Int?
    /// Exercise ids the plan offers in its place.
    var substituteExerciseIds: [String] = []
    /// Exercises sharing a group id run as a superset.
    var supersetGroupId: String?
    /// A demonstration video or other reference.
    var linkURL: String?
    /// Targets that replace `setTargets` from a later microcycle on. Unordered.
    var setTargetsByMicrocycle: [MicrocycleSetTargets] = []

    enum CodingKeys: String, CodingKey {
        case id
        case exercise
        case setTargets = "set_targets"
        case setRestTimers = "set_rest_timers"
        case notes
        case warmupSetCount = "warmup_set_count"
        case restSeconds = "rest_seconds"
        case substituteExerciseIds = "substitute_exercise_ids"
        case supersetGroupId = "superset_group_id"
        case linkURL = "link_url"
        case setTargetsByMicrocycle = "set_targets_by_microcycle"
    }

    /// The targets for the 1-based `microcycle`: the override with the greatest `fromMicrocycle`
    /// not past it, else the base targets. Nil, or below 1, is the base.
    func setTargets(forMicrocycle microcycle: Int?) -> [SetTarget] {
        guard let microcycle, microcycle >= 1 else { return setTargets }
        return setTargetsByMicrocycle
            .filter { $0.fromMicrocycle <= microcycle }
            .max { $0.fromMicrocycle < $1.fromMicrocycle }?
            .setTargets ?? setTargets
    }

    static var mock: WorkoutTemplateExercise {
        mocks[0]
    }

    /// Six exercises from the seeded library — the length of a real workout, and enough to
    /// exercise a list without rendering all thirty-two.
    static var mocks: [WorkoutTemplateExercise] {
        ExerciseModel.mocks.prefix(6).map { exercise in
            WorkoutTemplateExercise(exercise: exercise, setRestTimers: false)
        }
    }
}

// In an extension so the memberwise initializer survives.
extension WorkoutTemplateExercise {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        exercise = try container.decode(ExerciseModel.self, forKey: .exercise)
        setTargets = try container.decode([SetTarget].self, forKey: .setTargets)
        setRestTimers = try container.decode(Bool.self, forKey: .setRestTimers)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        warmupSetCount = try container.decodeIfPresent(Int.self, forKey: .warmupSetCount)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
        substituteExerciseIds = try container.decodeIfPresent([String].self, forKey: .substituteExerciseIds) ?? []
        supersetGroupId = try container.decodeIfPresent(String.self, forKey: .supersetGroupId)
        linkURL = try container.decodeIfPresent(String.self, forKey: .linkURL)
        setTargetsByMicrocycle = try container.decodeIfPresent([MicrocycleSetTargets].self, forKey: .setTargetsByMicrocycle) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(exercise, forKey: .exercise)
        try container.encode(setTargets, forKey: .setTargets)
        try container.encode(setRestTimers, forKey: .setRestTimers)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(warmupSetCount, forKey: .warmupSetCount)
        try container.encodeIfPresent(restSeconds, forKey: .restSeconds)
        if !substituteExerciseIds.isEmpty {
            try container.encode(substituteExerciseIds, forKey: .substituteExerciseIds)
        }
        try container.encodeIfPresent(supersetGroupId, forKey: .supersetGroupId)
        try container.encodeIfPresent(linkURL, forKey: .linkURL)
        if !setTargetsByMicrocycle.isEmpty {
            try container.encode(setTargetsByMicrocycle, forKey: .setTargetsByMicrocycle)
        }
    }
}
