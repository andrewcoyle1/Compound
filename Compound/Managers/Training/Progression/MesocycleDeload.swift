//
//  MesocycleDeload.swift
//  Compound
//
//  What a mesocycle's deload week (`MesocycleSchedule.isDeload`) does to a planned session: about
//  half the working sets, at 90 % of the planned weight rounded to the equipment, reps as planned.
//  Lifters and coaches deload by cutting volume and effort while keeping frequency (Rogerson 2024,
//  Bell 2022), so the sets come down rather than the weight falling by a third.
//
//  Sources and Compound's own choices: `MethodInfo.mesocycleDeload`.
//

import Foundation

enum MesocycleDeload {

    /// The share of working sets a deload keeps, rounded up: 4 → 2, 3 → 2, 5 → 3. Inside the
    /// 0.5–0.6 practitioners describe; never below one set.
    static let setFraction = 0.5

    /// The share of the planned weight a deload lifts: the middle of 0.85–0.95.
    static let loadFraction = 0.90

    /// Working sets to keep out of `planned`.
    static func setCount(from planned: Int) -> Int {
        guard planned > 0 else { return 0 }
        return max(1, Int((Double(planned) * setFraction).rounded(.up)))
    }

    /// The lighter weight before rounding. Assistance (a negative weight) gets more assistance,
    /// not less.
    static func lighter(_ weightKg: Double) -> Double {
        weightKg >= 0 ? weightKg * loadFraction : weightKg * (2 - loadFraction)
    }

    /// `lighter`, rounded by `round` to something the equipment makes, and lighter than `weightKg`
    /// even where the nearest weight is the one being lifted (15 kg on a 5 kg stack is 15, not
    /// 13.5): one more step down is tried, and the weight is kept only where nothing is lighter.
    static func lighterWeight(_ weightKg: Double, round: (Double) -> Double) -> Double {
        let drop = weightKg - lighter(weightKg)
        for steps in 1...4 {
            let rounded = round(weightKg - drop * Double(steps))
            if rounded < weightKg - 0.001 { return rounded }
        }
        return weightKg
    }

    /// `sets` with only the first `setCount(from:)` working sets left, re-numbered from one. A set
    /// is counted as `pairedSetCount` counts it: its drops and mini-sets go with it, and the right
    /// half of a left/right pair goes with the left. Warm-ups are all kept.
    static func keptSets(_ sets: [WorkoutSetModel]) -> [WorkoutSetModel] {
        var groups: [Int] = []
        var group = -1
        var previousSide: SetSide?
        for set in sets {
            guard !set.isWarmup else {
                groups.append(-1)
                continue
            }
            if !set.isSubSet {
                if !(set.side == .right && previousSide == .left) { group += 1 }
                previousSide = set.side
            }
            groups.append(group)
        }

        let keep = setCount(from: group + 1)
        let kept = zip(sets, groups).filter { $0.1 < keep }.map { $0.0 }
        return kept.enumerated().map { offset, set in
            var set = set
            set.index = offset + 1
            return set
        }
    }
}
