//
//  MicrocycleSetTargets.swift
//  Compound
//
//  A template exercise's targets from one microcycle of a mesocycle on, replacing the base
//  targets (microcycle 1) until a later override takes over.
//

import Foundation

struct MicrocycleSetTargets: Codable, Equatable, Hashable, Sendable {
    /// The first microcycle these targets apply to, 1-based.
    var fromMicrocycle: Int
    var setTargets: [SetTarget]

    enum CodingKeys: String, CodingKey {
        case fromMicrocycle = "from_microcycle"
        case setTargets = "set_targets"
    }
}
