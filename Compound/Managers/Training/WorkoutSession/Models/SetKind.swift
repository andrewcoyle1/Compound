//
//  SetKind.swift
//  Compound
//
//  Created by Andrew Coyle on 07/10/2026.
//

import Foundation

/// How a set is performed, beyond its figures.
///
/// A drop, a myo-rep mini-set, a rest-pause, a cluster, partials, a stretch or a hold is logged as
/// its own row, because it has its own figures, but it is part of the set before it rather than a
/// set of its own: its `parentSetId` names that set. Such a sub-set is counted once with its parent
/// (`pairedSetCount`), rests only the short intra-set rest or none (`RestDurationRules`), and is
/// left out of progression, where the parent's figures stand.
enum SetKind: String, Codable, CaseIterable, Sendable {
    case standard
    case drop
    /// As many reps as possible: the reps are open-ended.
    case amrap
    case myo
    case restPause
    case cluster
    /// Lengthened partials after the set, at its weight.
    case partials
    /// A static stretch after the set, timed, with no weight.
    case stretch
    /// A static hold after the set, timed, at its weight.
    case hold

    /// The kind a template's set target asks for. A template's "failure" set is an AMRAP set.
    init(_ setType: SetTargetSetType) {
        switch setType {
        case .standard: self = .standard
        case .drop: self = .drop
        case .myo: self = .myo
        case .failure, .amrap: self = .amrap
        case .restPause: self = .restPause
        case .cluster: self = .cluster
        case .partials: self = .partials
        case .stretch: self = .stretch
        case .hold: self = .hold
        }
    }

    /// Whether the rows of this kind rest briefly between them rather than not at all: mini-sets
    /// and clusters take a breath, a drop is a change of weight, and partials, a stretch or a
    /// hold follow the set without a break.
    var restsWithinTheSet: Bool {
        switch self {
        case .myo, .restPause, .cluster: return true
        case .standard, .drop, .amrap, .partials, .stretch, .hold: return false
        }
    }

    /// A stretch or hold piece is logged as a time rather than reps.
    var isTimed: Bool { self == .stretch || self == .hold }
}

extension WorkoutSetModel {

    /// The set's kind. Every set logged before kinds existed, and any kind written by a later build
    /// that this one does not know, reads as `.standard`: a set whose kind cannot be read is still
    /// a set. `.standard` is stored as no value at all, so plain sets are saved as before.
    var kind: SetKind {
        get { kindRawValue.flatMap(SetKind.init(rawValue:)) ?? .standard }
        set { kindRawValue = newValue == .standard ? nil : newValue.rawValue }
    }

    /// A drop, mini-set or cluster belonging to the set named by `parentSetId`, rather than a set
    /// of its own.
    var isSubSet: Bool { parentSetId != nil }

    /// A stretch or hold after its set: logged as a time, whatever the exercise tracks. The set
    /// itself carries the same kind but is lifted as usual.
    var isTimedPiece: Bool { isSubSet && kind.isTimed }
}
