//
//  SetTarget.swift
//  Compound
//
//  Created by Andrew Coyle on 28/02/2026.
//

import Foundation

struct SetTarget: DataSyncModelProtocol, Equatable, Hashable {
    var id: String = UUID().uuidString
    var setNumber: Int
    var minReps: Int?
    var maxReps: Int?
    var rirTarget: Int?
    var setType: SetTargetSetType

    // MARK: - Set plan (Workout Settings › Set Plan)
    //
    // What a session started from this target is created with, read only when the set plan is on.
    // All Optional, so every template saved before the plan existed decodes unchanged.

    /// A drop set's drops after its first piece.
    var dropCount: Int?
    /// How much lighter each drop is than the piece before it, in per cent. Read through `dropStep`.
    var dropStepPercent: Int?
    var dropStep: Int { dropStepPercent ?? 20 }
    /// The reps each drop asks for; nil means to failure.
    var dropReps: Int?
    /// A myo-rep, rest-pause or cluster set's mini-sets after its first piece.
    var miniSetCount: Int?
    /// The reps an AMRAP set sets out to beat.
    var amrapTargetReps: Int?

    init(
        id: String = UUID().uuidString,
        setNumber: Int,
        minReps: Int? = nil,
        maxReps: Int? = nil,
        rirTarget: Int? = nil,
        setType: SetTargetSetType = .standard,
        dropCount: Int? = nil,
        dropStepPercent: Int? = nil,
        dropReps: Int? = nil,
        miniSetCount: Int? = nil,
        amrapTargetReps: Int? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.minReps = minReps
        self.maxReps = maxReps
        self.rirTarget = rirTarget
        self.setType = setType
        self.dropCount = dropCount
        self.dropStepPercent = dropStepPercent
        self.dropReps = dropReps
        self.miniSetCount = miniSetCount
        self.amrapTargetReps = amrapTargetReps
    }

    enum CodingKeys: String, CodingKey {
        case id
        case setNumber = "set_number"
        case minReps = "min_reps"
        case maxReps = "max_reps"
        case rirTarget = "rir_target"
        case setType = "set_type"
        case dropCount = "drop_count"
        case dropStepPercent = "drop_step_percent"
        case dropReps = "drop_reps"
        case miniSetCount = "mini_set_count"
        case amrapTargetReps = "amrap_target_reps"
    }
}
