//
//  ProgressionEngine.swift
//  DialedIn
//
//  Double progression: work up the rep range at a weight, then add weight and drop back to the
//  bottom of the range. The engine is pure — no managers, no `@MainActor`, no `Date()` — so the
//  whole of it can be tested in milliseconds. Rounding to what the gym can actually load arrives
//  as a closure, because the equipment lives on the other side of a manager and the rule does not.
//

import Foundation

struct ProgressionEngine {

    // MARK: - Session start

    /// What to suggest for every working set of one exercise at the start of a session.
    func suggest(_ input: ProgressionInput) -> ProgressionSuggestion {
        guard let reference = input.history.first, !reference.workingSets.isEmpty else {
            return .noHistory(setCount: input.setTargets.count)
        }

        switch input.trackingMode {
        case .weightReps, .repsOnly:
            return suggestRepBased(input, reference: reference)
        case .timeOnly, .distanceTime:
            return suggestMeasured(input, reference: reference)
        }
    }

    // MARK: - Live adjustment

    /// Re-suggests the sets of an exercise that are still to come, from the set just logged.
    ///
    /// A `nil` entry means "leave that set exactly as it is": the engine only speaks up when the
    /// set that was just done was far enough from its target to be worth acting on.
    func adjustRemaining(
        completed: WorkoutSetModel,
        target: SetTarget?,
        remaining: [WorkoutSetModel],
        mode: TrackingMode,
        rounding: ProgressionRounding
    ) -> [SuggestedSet?] {
        let unchanged = [SuggestedSet?](repeating: nil, count: remaining.count)
        guard mode == .weightReps, let reps = completed.reps, let weight = completed.weightKg else {
            return unchanged
        }

        let range = repRange(target: target, referenceReps: reps)
        let adjusted: SuggestedSet

        if reps < range.min - 1 {
            adjusted = SuggestedSet(weightKg: rounding.round(weight * 0.95), reps: range.min)
        } else if reps == range.min - 1 {
            adjusted = SuggestedSet(weightKg: weight, reps: range.min)
        } else if reps >= range.max + 2, (completed.rpe ?? 0) <= 8 {
            let heavier = increasedWeight(weight, rounding: rounding)
            adjusted = SuggestedSet(weightKg: heavier, reps: range.min)
        } else {
            return unchanged
        }

        return remaining.map { _ in adjusted }
    }

    // MARK: - Weight/reps and reps-only

    private func suggestRepBased(_ input: ProgressionInput, reference: ProgressionHistorySession) -> ProgressionSuggestion {
        let rationale = classify(input, reference: reference)
        let tracksWeight = input.trackingMode == .weightReps

        let sets = (0..<setCount(input, reference: reference)).map { index -> SuggestedSet in
            let setTarget = target(input, at: index)
            let previousSet = referenceSet(reference, at: index)
            let referenceWeight = tracksWeight ? previousSet?.weightKg : nil
            let referenceReps = previousSet?.reps
            let range = repRange(target: setTarget, referenceReps: referenceReps)

            // A drop or myo set is an intensity technique the template author designed. Prefill it
            // with what was done last time, but never progress it.
            guard isProgressable(setTarget) else {
                return SuggestedSet(weightKg: referenceWeight, reps: referenceReps)
            }

            switch rationale {
            case .progressWeight where !tracksWeight:
                // Bodyweight work cannot add weight, so it raises the range instead.
                return SuggestedSet(reps: range.max + 1)
            case .progressWeight:
                let heavier = referenceWeight.map { increasedWeight($0, rounding: input.rounding) }
                return SuggestedSet(weightKg: heavier, reps: range.min)
            case .addReps:
                let reps = referenceReps.map { min($0 + 1, range.max) } ?? range.min
                return SuggestedSet(weightKg: referenceWeight, reps: reps)
            case .hold:
                return SuggestedSet(weightKg: referenceWeight, reps: referenceReps)
            case .deload:
                let lighter = referenceWeight.map { deloadedWeight($0, input: input) }
                return SuggestedSet(weightKg: lighter, reps: range.min)
            case .noHistory:
                return .none
            }
        }

        return ProgressionSuggestion(rationale: rationale, sets: sets)
    }

    /// `missed > 0` twice running at the same weight or heavier is a pattern; once is a bad day.
    private func classify(_ input: ProgressionInput, reference: ProgressionHistorySession) -> ProgressionSuggestion.Rationale {
        let referenceTally = tally(input, session: reference)

        if referenceTally.missed > 0 {
            let previous = input.history.count > 1 ? input.history[1] : nil
            if let previous,
               tally(input, session: previous).missed > 0,
               heaviestWeight(previous) >= heaviestWeight(reference) {
                return .deload
            }
            return .hold
        }

        guard rpeWithinTarget(input, session: reference) else { return .addReps }

        switch input.adjustmentMode {
        case .weightFirst:
            // More than half the sets at the top. One good set followed by a fade is a weight
            // that is not ready; every set at the top is reps-first's bar, not this one's.
            return referenceTally.top * 2 > reference.workingSets.count ? .progressWeight : .addReps
        case .repsFirst:
            return referenceTally.top == reference.workingSets.count ? .progressWeight : .addReps
        }
    }

    /// How many of a session's working sets reached the top of their range, and how many fell
    /// below the bottom of it.
    private func tally(_ input: ProgressionInput, session: ProgressionHistorySession) -> (top: Int, missed: Int) {
        var top = 0
        var missed = 0
        for (index, set) in session.workingSets.enumerated() {
            guard let reps = set.reps else { continue }
            let range = repRange(target: target(input, at: index), referenceReps: reps)
            if reps >= range.max { top += 1 }
            if reps < range.min { missed += 1 }
        }
        return (top, missed)
    }

    /// False when any set was logged harder than it was prescribed. The RPE/RIR mapping is
    /// `EffortScale`'s, so a target of 2 reps in reserve is an RPE of 8.
    private func rpeWithinTarget(_ input: ProgressionInput, session: ProgressionHistorySession) -> Bool {
        for (index, set) in session.workingSets.enumerated() {
            guard let rpe = set.rpe, let rir = target(input, at: index)?.rirTarget else { continue }
            if rpe > EffortScale.rpe(fromRIR: rir) + 0.5 { return false }
        }
        return true
    }

    private func heaviestWeight(_ session: ProgressionHistorySession) -> Double {
        session.workingSets.compactMap(\.weightKg).max() ?? 0
    }

    // MARK: - Timed and distance work

    /// No rep range to work up, so the only question is whether every set was finished.
    private func suggestMeasured(_ input: ProgressionInput, reference: ProgressionHistorySession) -> ProgressionSuggestion {
        let allCompleted = reference.workingSets.allSatisfy { $0.completedAt != nil }
        let rationale: ProgressionSuggestion.Rationale = allCompleted ? .progressWeight : .hold

        let sets = (0..<setCount(input, reference: reference)).map { index -> SuggestedSet in
            let previousSet = referenceSet(reference, at: index)
            let duration = previousSet?.durationSec
            let distance = previousSet?.distanceMeters

            guard allCompleted, isProgressable(target(input, at: index)) else {
                return SuggestedSet(durationSec: duration, distanceMeters: distance)
            }

            switch input.trackingMode {
            case .timeOnly:
                let longer = duration.map { Int(round(Double($0) * 1.10, toNearest: 5)) }
                return SuggestedSet(durationSec: longer, distanceMeters: distance)
            default:
                // Distance grows; however long it took is carried over untouched.
                let further = distance.map { round($0 * 1.05, toNearest: 50) }
                return SuggestedSet(durationSec: duration, distanceMeters: further)
            }
        }

        return ProgressionSuggestion(rationale: rationale, sets: sets)
    }

    // MARK: - Shared helpers

    /// One suggestion per set the user will be asked to do: the template's targets, or the sets
    /// that were actually logged last time when there are more of those.
    private func setCount(_ input: ProgressionInput, reference: ProgressionHistorySession) -> Int {
        max(reference.workingSets.count, input.setTargets.count)
    }

    /// The last target applies to every set past the end of the list.
    private func target(_ input: ProgressionInput, at index: Int) -> SetTarget? {
        index < input.setTargets.count ? input.setTargets[index] : input.setTargets.last
    }

    /// Set `i` progresses from its own reference set, so a session logged with descending weights
    /// stays descending.
    private func referenceSet(_ reference: ProgressionHistorySession, at index: Int) -> WorkoutSetModel? {
        index < reference.workingSets.count ? reference.workingSets[index] : reference.workingSets.last
    }

    /// The template's range, or one derived from what was done last time when it is silent.
    private func repRange(target: SetTarget?, referenceReps: Int?) -> (min: Int, max: Int) {
        let previous = referenceReps ?? 0
        let minReps = target?.minReps ?? previous
        let maxReps = target?.maxReps ?? (previous + 2)
        return (min: minReps, max: max(maxReps, minReps))
    }

    private func isProgressable(_ target: SetTarget?) -> Bool {
        switch target?.setType ?? .standard {
        case .standard, .failure: return true
        case .drop, .myo:         return false
        }
    }

    /// Adds at least one increment and rounds. Where the rounding swallows the increment whole —
    /// a 2.5 kg step on a machine that only moves in fives — it adds a second one rather than
    /// suggesting the weight that was just lifted.
    private func increasedWeight(_ weight: Double, rounding: ProgressionRounding) -> Double {
        let once = rounding.round(weight + rounding.minimumIncrementKg)
        guard once <= weight else { return once }
        return rounding.round(weight + rounding.minimumIncrementKg * 2)
    }

    /// Ten per cent off, rounded down where the rounding is ambiguous: a deload that rounds up to
    /// heavier than intended is not a deload.
    private func deloadedWeight(_ weight: Double, input: ProgressionInput) -> Double {
        let intended = weight * 0.90
        let rounded = input.roundWeight(intended)
        guard rounded > intended else { return rounded }
        let lower = input.roundWeight(intended - input.minimumIncrementKg)
        return lower > 0 && lower <= intended ? lower : rounded
    }

    private func round(_ value: Double, toNearest step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }
}
