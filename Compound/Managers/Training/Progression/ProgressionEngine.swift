//
//  ProgressionEngine.swift
//  Compound
//
//  Double progression: work up the rep range at a weight, then add weight and drop back to the
//  bottom of the range. Weight goes up by a share of the working weight (`LoadIncrement`), and a
//  reset after repeated misses is re-derived from the estimated one-rep max. Sources and
//  Compound's own choices: `MethodInfo.smartProgression`.
//
//  The engine is pure — no managers, no `@MainActor`, no `Date()` — so the whole of it can be
//  tested in milliseconds. Rounding to what the gym can actually load arrives
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
        rounding: ProgressionRounding,
        exerciseType: ExerciseType? = nil
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
            let heavier = increasedWeight(weight, fraction: LoadIncrement.targetFraction(for: exerciseType), rounding: rounding)
            // A step too big for the weight waits for next session's suggestion.
            guard jumpIsAffordable(from: weight, reps: reps, to: heavier, minReps: range.min) else { return unchanged }
            adjusted = SuggestedSet(weightKg: heavier, reps: range.min)
        } else {
            return unchanged
        }

        return remaining.map { _ in adjusted }
    }

    // MARK: - Weight/reps and reps-only

    private func suggestRepBased(_ input: ProgressionInput, reference: ProgressionHistorySession) -> ProgressionSuggestion {
        let classified = classify(input, reference: reference)
        let tracksWeight = input.trackingMode == .weightReps
        let fraction = LoadIncrement.targetFraction(for: input.exerciseType)
        // Sets whose weight went up, and sets that took a rep instead because the step was too big.
        var heavierSets = 0
        var repsInsteadSets = 0

        let sets = (0..<setCount(input, reference: reference)).map { index -> SuggestedSet in
            let setTarget = target(input, at: index)
            let previousSet = referenceSet(reference, at: index)
            let referenceWeight = tracksWeight ? previousSet?.weightKg : nil
            let referenceReps = previousSet?.reps
            let range = repRange(target: setTarget, referenceReps: referenceReps)

            // An AMRAP set with a planned target follows its own rule (set plan only).
            if let amrap = input.amrap, let setTarget, let previousSet,
               SetKind(setTarget.setType) == .amrap, let templateTarget = setTarget.amrapTargetReps {
                let earlier = input.history.count > 1 ? referenceSet(input.history[1], at: index) : nil
                return amrap.next(templateTarget: templateTarget, last: previousSet, previous: earlier) { weight in
                    increasedWeight(weight, fraction: fraction, rounding: input.rounding)
                }
            }

            // A drop, myo, partials, stretch or hold set is an intensity technique the template
            // author designed. Prefill it with what was done last time, but never progress it.
            guard isProgressable(setTarget) else {
                return SuggestedSet(weightKg: referenceWeight, reps: referenceReps)
            }

            switch classified {
            case .progressWeight where !tracksWeight:
                // Bodyweight work cannot add weight, so it raises the range instead.
                return SuggestedSet(reps: range.max + 1)
            case .progressWeight:
                let progressed = progressedSet(weight: referenceWeight, reps: referenceReps, range: range, fraction: fraction, rounding: input.rounding)
                if referenceWeight != nil, progressed.weightKg == referenceWeight { repsInsteadSets += 1 } else { heavierSets += 1 }
                return progressed
            case .addReps:
                let reps = referenceReps.map { min($0 + 1, range.max) } ?? range.min
                return SuggestedSet(weightKg: referenceWeight, reps: reps)
            case .hold:
                return SuggestedSet(weightKg: referenceWeight, reps: referenceReps)
            case .deload:
                let lighter = previousSet.flatMap { resetWeight(from: $0, target: setTarget, minReps: range.min, input: input) }
                return SuggestedSet(weightKg: tracksWeight ? lighter : nil, reps: range.min)
            case .noHistory:
                return .none
            }
        }

        // Every set that would have added weight took a rep instead, so that is what the header says.
        let rationale: ProgressionSuggestion.Rationale = classified == .progressWeight && tracksWeight
            && heavierSets == 0 && repsInsteadSets > 0 ? .addReps : classified
        return ProgressionSuggestion(rationale: rationale, sets: sets)
    }

    /// `missed > 0` twice running at the same weight or heavier is a pattern; once is a bad day.
    private func classify(_ input: ProgressionInput, reference: ProgressionHistorySession) -> ProgressionSuggestion.Rationale {
        let referenceTally = tally(input, session: reference)
        let previous = input.history.count > 1 ? input.history[1] : nil

        if referenceTally.missed > 0 {
            if let previous,
               heaviestWeight(previous) >= heaviestWeight(reference),
               failedMisses(input, session: reference) > 0,
               failedMisses(input, session: previous) > 0 {
                return .deload
            }
            return .hold
        }

        guard rpeWithinTarget(input, session: reference), reachedTop(input, session: reference) else { return .addReps }

        // Reps alone do not say how hard the top of the range was. Without an RPE, the top has
        // to be reached on two sessions running at this weight before weight goes on (ACSM 2009).
        if !hasLoggedEffort(reference) {
            guard let previous,
                  heaviestWeight(previous) >= heaviestWeight(reference),
                  reachedTop(input, session: previous) else { return .addReps }
        }
        return .progressWeight
    }

    /// Weight-first takes a majority of sets at the top: one good set followed by a fade is a
    /// weight that is not ready. Reps-first wants every set there.
    private func reachedTop(_ input: ProgressionInput, session: ProgressionHistorySession) -> Bool {
        let top = tally(input, session: session).top
        switch input.adjustmentMode {
        case .weightFirst: return top * 2 > session.workingSets.count
        case .repsFirst:   return top == session.workingSets.count
        }
    }

    private func hasLoggedEffort(_ session: ProgressionHistorySession) -> Bool {
        session.workingSets.contains { $0.rpe != nil }
    }

    /// Sets below the bottom of their range that were not stopped short on purpose: an RPE logged
    /// under `LoadIncrement.resetMinimumRPE` left reps in reserve. With no RPE the miss counts.
    private func failedMisses(_ input: ProgressionInput, session: ProgressionHistorySession) -> Int {
        session.workingSets.enumerated().filter { index, set in
            guard let reps = set.reps else { return false }
            let range = repRange(target: target(input, at: index), referenceReps: reps)
            return reps < range.min && (set.rpe.map { $0 >= LoadIncrement.resetMinimumRPE } ?? true)
        }.count
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
    /// `EffortScale`'s, so a target of 2 reps in reserve is an RPE of 8. A compound lift whose
    /// template sets no target is held to `LoadIncrement.defaultReserve`.
    private func rpeWithinTarget(_ input: ProgressionInput, session: ProgressionHistorySession) -> Bool {
        for (index, set) in session.workingSets.enumerated() {
            guard let rpe = set.rpe,
                  let rir = target(input, at: index)?.rirTarget ?? LoadIncrement.defaultReserve(for: input.exerciseType) else { continue }
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
        case .standard, .failure, .amrap:  return true
        case .drop, .myo, .restPause, .cluster, .partials, .stretch, .hold: return false
        }
    }

    /// Adds `fraction` of the weight, at least one increment, and rounds. Where the rounding
    /// swallows the step whole — 2.5 kg on a machine that only moves in fives — it adds twice the
    /// step rather than suggesting the weight that was just lifted. Assistance (a negative weight)
    /// has no share to take, so it steps by the increment alone.
    private func increasedWeight(_ weight: Double, fraction: Double, rounding: ProgressionRounding) -> Double {
        let step = max(weight > 0 ? weight * fraction : 0, rounding.minimumIncrementKg)
        let once = rounding.round(weight + step)
        guard once <= weight else { return once }
        return rounding.round(weight + step * 2)
    }

    /// One weighted set under `.progressWeight`: heavier, at the bottom of the range. Where the
    /// smallest step the equipment allows is too big a jump for this weight, a rep more at the
    /// same weight instead, until the reps carry the heavier weight (load and rep progression
    /// grow muscle alike, Plotkin 2022).
    private func progressedSet(
        weight: Double?,
        reps: Int?,
        range: (min: Int, max: Int),
        fraction: Double,
        rounding: ProgressionRounding
    ) -> SuggestedSet {
        guard let weight else { return SuggestedSet(weightKg: nil, reps: range.min) }
        let heavier = increasedWeight(weight, fraction: fraction, rounding: rounding)
        if let reps, !jumpIsAffordable(from: weight, reps: reps, to: heavier, minReps: range.min) {
            return SuggestedSet(weightKg: weight, reps: reps + 1)
        }
        return SuggestedSet(weightKg: heavier, reps: range.min)
    }

    /// Whether going from `weight` to `heavier` is a step the lifter can take now. Within
    /// `LoadIncrement.maximumFraction` it always is. A bigger one waits until the reps done at
    /// `weight` carry `heavier` for `minReps` by Epley's equation: 12 kg for 15 reps carries
    /// 14 kg for 8.
    private func jumpIsAffordable(from weight: Double, reps: Int, to heavier: Double, minReps: Int) -> Bool {
        guard weight > 0, heavier > weight else { return true }
        guard (heavier - weight) / weight > LoadIncrement.maximumFraction else { return true }
        return weight * (1 + Double(reps) / 30) >= heavier * (1 + Double(minReps) / 30)
    }

    /// After two sessions of misses: the weight for the bottom of the range with reps in reserve
    /// (the template's target, else `LoadIncrement.resetReserve`), worked back from this set's
    /// estimated one-rep max and kept 5–15 % under the weight missed. Without an estimate, ten
    /// per cent off. Rounded down where the rounding is ambiguous: a reset that rounds up to
    /// heavier than intended is not a reset. Assistance gets more assistance, not less.
    private func resetWeight(from set: WorkoutSetModel, target: SetTarget?, minReps: Int, input: ProgressionInput) -> Double? {
        guard let weight = set.weightKg else { return nil }
        let intended: Double
        if weight > 0, let oneRepMax = ExerciseOneRMAggregator.estimated1RM(of: set) {
            let reserve = Double(target?.rirTarget ?? LoadIncrement.resetReserve)
            let derived = ExerciseOneRMAggregator.load(forOneRepMax: oneRepMax, reps: minReps, reserve: reserve)
            intended = min(max(derived, weight * LoadIncrement.resetFloorFraction), weight * LoadIncrement.resetCeilingFraction)
        } else if weight < 0 {
            intended = weight * (2 - LoadIncrement.resetFallbackFraction)
        } else {
            intended = weight * LoadIncrement.resetFallbackFraction
        }
        // A gram of tolerance, so floating-point noise in an exact weight is not read as rounding up.
        let rounded = input.roundWeight(intended)
        guard rounded > intended + 0.001 else { return rounded }
        let lower = input.roundWeight(intended - input.minimumIncrementKg)
        return lower <= intended && (lower > 0 || weight <= 0) ? lower : rounded
    }

    private func round(_ value: Double, toNearest step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }
}
