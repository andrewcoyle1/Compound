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

    init(
        id: String = UUID().uuidString,
        setNumber: Int,
        minReps: Int? = nil,
        maxReps: Int? = nil,
        rirTarget: Int? = nil,
        setType: SetTargetSetType = .standard
    ) {
        self.id = id
        self.setNumber = setNumber
        self.minReps = minReps
        self.maxReps = maxReps
        self.rirTarget = rirTarget
        self.setType = setType
    }

    enum CodingKeys: String, CodingKey {
        case id
        case setNumber = "set_number"
        case minReps = "min_reps"
        case maxReps = "max_reps"
        case rirTarget = "rir_target"
        case setType = "set_type"
    }
}
