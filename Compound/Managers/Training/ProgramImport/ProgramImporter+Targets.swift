//
//  ProgramImporter+Targets.swift
//  Compound
//
//  One sheet row as set targets and plan fields. Ranges import as single values: rest is the
//  midpoint rounded to 15 s, warm-ups the upper bound, RIR = 10 − the upper RPE. The technique
//  becomes the set type of the last working set.
//

import Foundation

extension ProgramImporter {

    /// The row's working sets: reps, effort and, on the last set, the technique.
    static func setTargets(for row: ProgramSheet.Row) -> [SetTarget] {
        let count = max(row.workingSets, 1)
        let hasRIRColumns = row.rirPerSet.contains { $0 != nil }
        return (1...count).map { number in
            var target = SetTarget(
                setNumber: number,
                minReps: row.reps.map { Int($0.low.rounded()) },
                maxReps: row.reps.map { Int($0.high.rounded()) }
            )
            if hasRIRColumns {
                target.rirTarget = row.rirPerSet.indices.contains(number - 1) ? row.rirPerSet[number - 1] : nil
            } else {
                target.rirTarget = (number == count ? row.lastRPE : row.earlyRPE).map(rir(fromRPE:))
            }
            if number == count { applyTechnique(row.technique, to: &target) }
            return target
        }
    }

    /// RIR = 10 − the upper RPE, rounded down and kept to 0…5.
    static func rir(fromRPE rpe: ValueRange) -> Int {
        min(max(Int((10 - rpe.high).rounded(.down)), 0), 5)
    }

    /// The midpoint in seconds, rounded to 15 s and at least 15 s.
    static func restSeconds(for row: ProgramSheet.Row) -> Int? {
        guard let rest = row.rest else { return nil }
        let seconds = (rest.low + rest.high) / 2 * (row.restUnit == .minutes ? 60 : 1)
        return max(Int((seconds / 15).rounded()) * 15, 15)
    }

    /// The upper bound: "0-1" warm-ups is 1.
    static func warmupSetCount(for row: ProgramSheet.Row) -> Int? {
        row.warmupSets.map { Int($0.high.rounded()) }
    }

    /// "Failure" is an AMRAP at RIR 0; "LLP", "Lengthened" and "Extend" are partials; "Myo" is
    /// three mini-sets; "Two Drop Sets (~25%)" is two 25 % drops; "Static Stretch (30s)" and
    /// "Static Hold (20 sec)" are timed pieces. Anything else leaves a standard set. The specific
    /// techniques are checked before "failure", which several of them mention.
    static func applyTechnique(_ technique: String?, to target: inout SetTarget) {
        guard let text = technique?.lowercased() else { return }
        let seconds = text.firstMatch(of: #/(\d+)\s*(?:s\b|sec)/#).flatMap { Int($0.1) }
        if text.contains("drop") {
            target.setType = .drop
            target.dropCount = dropCount(in: text)
            target.dropStepPercent = text.firstMatch(of: #/(\d+)\s*%/#).flatMap { Int($0.1) }
        } else if text.contains("myo") {
            target.setType = .myo
            target.miniSetCount = 3
        } else if ["llp", "lengthened", "extend"].contains(where: text.contains) {
            target.setType = .partials
        } else if text.contains("stretch") {
            target.setType = .stretch
            target.holdSeconds = seconds
        } else if text.contains("hold") {
            target.setType = .hold
            target.holdSeconds = seconds
        } else if text.contains("failure") {
            target.setType = .amrap
            target.rirTarget = 0
        }
    }

    private static func dropCount(in text: String) -> Int? {
        let words = ["one": 1, "two": 2, "three": 3, "four": 4]
        if let word = text.firstMatch(of: #/\b(one|two|three|four)\b/#) { return words[String(word.1)] }
        return text.firstMatch(of: #/(\d+)\s*(?:x\s*)?drop/#).flatMap { Int($0.1) }
    }
}
