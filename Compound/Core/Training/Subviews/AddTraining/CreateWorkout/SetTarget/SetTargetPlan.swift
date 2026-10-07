//
//  SetTargetPlan.swift
//  Compound
//
//  How a template's set plan (Workout Settings › Set Plan) reads in the set-target editor: the
//  name of each kind, the chip after the set number, and the one line under it. Pure, so the
//  strings are tested rather than eyeballed.
//

import Foundation

enum SetTargetPlan {

    /// The kinds the editor offers, in its picker's order. `failure` is not among them: a template
    /// saved before AMRAP existed shows its failure sets as AMRAP and writes `amrap` once edited.
    static let kinds: [SetTargetSetType] = [.standard, .amrap, .myo, .restPause, .cluster, .drop]

    /// How much lighter each drop can be than the piece before it, in per cent.
    static let dropSteps = [10, 20, 30]
    static let dropCountRange = 1...5
    static let miniSetCountRange = 1...6

    /// The kind as it reads in the picker and on the chip.
    static func title(for type: SetTargetSetType) -> String {
        switch type {
        case .standard: return String(localized: "Standard")
        case .failure, .amrap: return String(localized: "AMRAP")
        case .myo: return String(localized: "Myo-reps")
        case .restPause: return String(localized: "Rest-pause")
        case .cluster: return String(localized: "Cluster")
        case .drop: return String(localized: "Drop set")
        }
    }

    /// The chip after the set number: the kind, and an AMRAP's target as "AMRAP 8+". A standard set
    /// has none.
    static func chip(for target: SetTarget) -> String? {
        switch target.setType {
        case .standard: return nil
        case .failure, .amrap:
            return target.amrapTargetReps.map { String(localized: "AMRAP \($0)+") } ?? title(for: target.setType)
        case .myo, .restPause, .cluster, .drop: return title(for: target.setType)
        }
    }

    /// `"−20%"`, a drop's step.
    static func dropStepTitle(_ percent: Int) -> String {
        "−" + Format.percent(Double(percent) / 100)
    }

    /// The line under a planned set: "8 reps, then −20% ×2 to failure", "As many as possible,
    /// target 8", "3 mini-sets, 15 s breath". Nil for a standard set, which shows nothing extra.
    static func summary(for target: SetTarget, settings: WorkoutSettings) -> String? {
        switch target.setType {
        case .standard:
            return nil
        case .failure, .amrap:
            return target.amrapTargetReps.map { String(localized: "As many as possible, target \($0)") }
                ?? String(localized: "As many as possible")
        case .drop:
            let reps = repsTitle(target)
            let count = target.dropCount ?? 0
            guard count > 0 else { return reps }
            let steps = "\(dropStepTitle(target.dropStep)) ×\(count)"
            let drops = target.dropReps.map { "\(steps), \(String(localized: "\(Format.reps($0)) each"))" }
                ?? "\(steps) \(String(localized: "to failure"))"
            return reps.map { String(localized: "\($0), then \(drops)") } ?? drops
        case .myo, .restPause, .cluster:
            let count = target.miniSetCount ?? 0
            guard count > 0 else { return repsTitle(target) }
            let rest = settings.intraSetRest(for: SetKind(target.setType)) ?? settings.intraSetRest
            return String(localized: "\(String(localized: "\(count) mini-sets")), \(String(localized: "\(rest) s")) breath")
        }
    }

    /// "8 reps", "8–12 reps", or nil when the set has no reps planned.
    private static func repsTitle(_ target: SetTarget) -> String? {
        switch (target.minReps, target.maxReps) {
        case let (min?, max?) where min != max:
            return String(localized: "\(Format.repRange(Swift.min(min, max), Swift.max(min, max))) reps")
        case let (reps?, _), let (nil, reps?):
            return Format.reps(reps)
        case (nil, nil):
            return nil
        }
    }
}
