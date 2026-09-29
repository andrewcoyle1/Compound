//
//  MuscleVolume.swift
//  DialedIn
//
//  The one place a set is credited to a muscle. The template screens, the Muscle Groups cards, the
//  muscle detail chart and Muscle Balance each carried their own copy of this arithmetic, and one
//  of them had already drifted: it counted a left/right pair as two sets where the rest counted one.
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
    /// double a muscle's volume.
    static func completedWorkingSets(_ exercise: WorkoutExerciseModel) -> Int {
        exercise.sets
            .filter { !$0.isWarmup && $0.completedAt != nil }
            .pairedSetCount
    }

    /// The weighted sets each muscle got from one logged exercise.
    static func weightedSets(_ exercise: WorkoutExerciseModel, template: ExerciseModel) -> [Muscles: Double] {
        let sets = Double(completedWorkingSets(exercise))
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

    /// Working sets a week to aim for. Large muscles tolerate and need more volume than small ones,
    /// which also get indirect work from the compound lifts.
    static func recommendedWeeklySets(for muscle: Muscles) -> ClosedRange<Double> {
        switch muscle {
        case .chest, .lats, .upperBack, .quads, .hamstrings, .glutes:
            return 10...20
        case .triceps, .upperTraps, .obliques, .neck, .forearms, .sideDelts, .rearDelts, .frontDelts,
             .biceps, .lowerBack, .abs, .serratus, .calves, .abductors, .adductors, .tibialis:
            return 6...12
        }
    }

    static func classify(sets: Double, for muscle: Muscles) -> MuscleBalanceStatus {
        let range = recommendedWeeklySets(for: muscle)
        if sets < range.lowerBound { return .below }
        if sets > range.upperBound { return .above }
        return .within
    }
}

enum MuscleBalanceStatus: Equatable {
    case below, within, above

    var label: String {
        switch self {
        case .below:  return String(localized: "Under")
        case .within: return String(localized: "On target")
        case .above:  return String(localized: "Over")
        }
    }

    var systemImage: String {
        switch self {
        case .below:  return "arrow.down.circle.fill"
        case .within: return "checkmark.circle.fill"
        case .above:  return "arrow.up.circle.fill"
        }
    }
}
