//
//  MuscleVolume.swift
//  Compound
//
//  The one place a set is credited to a muscle. The template screens, the Muscle Groups cards, the
//  muscle detail chart and Muscle Balance each carried their own copy of this arithmetic, and one
//  of them had already drifted: it counted a left/right pair as two sets where the rest counted one.
//
//  What is counted is hard sets (`hardSets`), credited fractionally: 1 to a muscle an exercise
//  trains directly, 0.5 to one it assists (Pelland 2026). Every muscle is read against the same
//  tiers (`tier(sets:)`), 10–20 sets a week being the productive band: no meta-analysis supports a
//  lower band for small muscles (Baz-Valle 2022 found triceps did better above 20). The method and
//  its sources are `MethodInfo.weeklyHardSets` and `.weeklyVolumeTiers`.
//

import Foundation

struct TargetMuscleSummary: Identifiable, Hashable {
    var id: Muscles { muscle }
    let muscle: Muscles
    let weightedTargetSets: Double
    let exerciseCount: Int
}

enum MuscleVolume {

    /// A muscle the exercise trains directly gets the whole set; one it only assists gets half.
    static func factor(_ target: MuscleTargetType) -> Double {
        target == .secondary ? 0.5 : 1.0
    }

    /// Finished working sets, a left/right pair counting once, so a unilateral exercise does not
    /// double a muscle's volume. Every finished set, however easy: for set counts on screen. Weekly
    /// volume per muscle counts `hardSets` instead.
    static func completedWorkingSets(_ exercise: WorkoutExerciseModel) -> Int {
        exercise.sets
            .filter { !$0.isWarmup && $0.completedAt != nil }
            .pairedSetCount
    }

    // MARK: - Hard sets

    /// A set logged below this RPE (more than four reps in reserve) is too far from failure to
    /// count as a hard set. Compound's own cut-off; the direction is from Robinson 2024 and Refalo
    /// 2023. A set with no RPE counts, so not logging RPE costs nothing.
    static let minimumHardSetRPE = 6.0
    /// What each drop, myo-rep or rest-pause mini-set adds to the set it belongs to.
    static let miniSetCredit = 0.5
    /// The most one set and its drops or mini-sets can count for.
    static let maximumCreditPerSet = 2.0

    /// A finished working set taken close enough to failure to count.
    static func isHardSet(_ set: WorkoutSetModel) -> Bool {
        guard !set.isWarmup, set.completedAt != nil else { return false }
        guard let rpe = set.rpe else { return true }
        return rpe >= minimumHardSetRPE
    }

    /// What one set counts for: 1, plus `miniSetCredit` for each finished drop (a sub-set of kind
    /// `.drop`) or mini-set of a myo-rep or rest-pause set, capped at `maximumCreditPerSet`. A
    /// cluster's pieces, partials, stretches and holds add nothing: they are one set split up or
    /// finished off, not extra sets.
    static func credit(_ set: WorkoutSetModel, in sets: [WorkoutSetModel]) -> Double {
        let extras = sets.filter { piece in
            piece.parentSetId == set.id && !piece.isWarmup && piece.completedAt != nil
                && (piece.kind == .drop || set.kind == .myo || set.kind == .restPause)
        }.count
        return min(maximumCreditPerSet, 1 + miniSetCredit * Double(extras))
    }

    /// The hard sets in one logged exercise: finished, not warm-ups, not logged below
    /// `minimumHardSetRPE`, each with its drops and mini-sets (`credit`). A left/right pair is one
    /// set, as `pairedSetCount` counts it, worth its better half.
    static func hardSets(_ exercise: WorkoutExerciseModel) -> Double {
        var total = 0.0
        var previous: (side: SetSide?, credit: Double)?
        for set in exercise.sets where isHardSet(set) && !set.isSubSet {
            let value = credit(set, in: exercise.sets)
            if set.side == .right, let previous, previous.side == .left {
                total += max(0, value - previous.credit)
            } else {
                total += value
            }
            previous = (set.side, value)
        }
        return total
    }

    /// The weighted hard sets each muscle got from one logged exercise.
    static func weightedSets(_ exercise: WorkoutExerciseModel, template: ExerciseModel) -> [Muscles: Double] {
        let sets = hardSets(exercise)
        guard sets > 0 else { return [:] }
        return template.muscleGroups.mapValues { sets * factor($0) }
    }

    /// Planned sets per muscle for a template's exercises, ordered by muscle name.
    static func targetSummaries(exercises: [WorkoutTemplateExercise]) -> [TargetMuscleSummary] {
        var weightedSetCounts: [Muscles: Double] = [:]
        var exerciseCounts: [Muscles: Int] = [:]

        for workoutExercise in exercises {
            let setCount = Double(workoutExercise.setTargets.count)
            guard setCount > 0 else { continue }
            for (muscle, target) in workoutExercise.exercise.muscleGroups {
                weightedSetCounts[muscle, default: 0] += setCount * factor(target)
                exerciseCounts[muscle, default: 0] += 1
            }
        }

        return weightedSetCounts.keys
            .map { muscle in
                TargetMuscleSummary(
                    muscle: muscle,
                    weightedTargetSets: weightedSetCounts[muscle, default: 0],
                    exerciseCount: exerciseCounts[muscle, default: 0]
                )
            }
            .sorted { $0.muscle.name < $1.muscle.name }
    }

    /// Weighted working sets per muscle in `weeks` rolling seven-day windows, oldest first. The
    /// last window is the seven days ending on `endDate`'s day, the same "Last 7 Days" the Muscle
    /// Groups cards show. Every muscle is present, zero-filled.
    static func weeklySets(
        sessions: [WorkoutSessionModel],
        templates: [String: ExerciseModel],
        calendar: Calendar,
        endDate: Date = Date(),
        weeks: Int = 12
    ) -> [Muscles: [Double]] {
        var result = Dictionary(uniqueKeysWithValues: Muscles.allCases.map { ($0, Array(repeating: 0.0, count: weeks)) })
        let endDay = calendar.startOfDay(for: endDate)

        for session in sessions {
            let day = calendar.startOfDay(for: session.endedAt ?? session.dateCreated)
            guard let daysAgo = calendar.dateComponents([.day], from: day, to: endDay).day,
                  daysAgo >= 0, daysAgo < weeks * 7 else { continue }
            let bucket = weeks - 1 - daysAgo / 7

            for exercise in session.exercises {
                guard let template = templates[exercise.templateId] else { continue }
                for (muscle, sets) in weightedSets(exercise, template: template) {
                    result[muscle]?[bucket] += sets
                }
            }
        }
        return result
    }

    // MARK: - Recommended weekly range

    /// The productive band, the same for every muscle: hypertrophy keeps rising with weekly hard
    /// sets up to about 20 (Pelland 2026; Schoenfeld 2017), and 12–20 "may be an optimum" with
    /// triceps doing better above 20 (Baz-Valle 2022). The 0.5 credit for assisting already gives
    /// arms and delts sets from the compound lifts.
    static let productiveWeeklySets: ClosedRange<Double> = 10...20
    /// Below this, a week is unlikely to keep what has been built. Compound's own cut-point,
    /// anchored loosely on Spiering 2021's minimal maintenance dose.
    static let maintenanceWeeklySets = 4.0

    /// Weekly hard sets to aim for. One band for every muscle: there is no evidence for a lower
    /// one for small muscles.
    static func recommendedWeeklySets(for muscle: Muscles) -> ClosedRange<Double> {
        productiveWeeklySets
    }

    /// Where a week's sets fall: below 4, 4 to under 10, 10–20, over 20.
    static func tier(sets: Double) -> MuscleBalanceStatus {
        if sets < maintenanceWeeklySets { return .belowMaintenance }
        if sets < productiveWeeklySets.lowerBound { return .maintaining }
        if sets > productiveWeeklySets.upperBound { return .high }
        return .productive
    }

    static func classify(sets: Double, for muscle: Muscles) -> MuscleBalanceStatus {
        tier(sets: sets)
    }
}

/// A week's hard sets for one muscle against the tiers. The labels and the 4 and 10 cut-points
/// are Compound's own; only the 10–20 band rests on the meta-analyses.
enum MuscleBalanceStatus: Equatable, CaseIterable {
    case belowMaintenance, maintaining, productive, high

    var label: String {
        switch self {
        case .belowMaintenance: return String(localized: "Below maintenance")
        case .maintaining:      return String(localized: "Maintaining")
        case .productive:       return String(localized: "Productive")
        case .high:             return String(localized: "High")
        }
    }

    /// What the tier means, for the line under a muscle's trend.
    var explanation: String {
        switch self {
        case .belowMaintenance: return String(localized: "Fewer than 4 sets a week may not keep what you have built.")
        case .maintaining:      return String(localized: "Enough to keep muscle; 10–20 sets a week builds more.")
        case .productive:       return String(localized: "In the 10–20 sets a week band where most growth happens.")
        case .high:             return String(localized: "Over 20 sets a week: fine while you keep progressing and recovering.")
        }
    }

    var systemImage: String {
        switch self {
        case .belowMaintenance: return "arrow.down.circle.fill"
        case .maintaining:      return "minus.circle.fill"
        case .productive:       return "checkmark.circle.fill"
        case .high:             return "arrow.up.circle.fill"
        }
    }
}
