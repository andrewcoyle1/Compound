//
//  WorkoutTemplateExercise+PlanSummary.swift
//  Compound
//
//  The one-line readings of a template exercise's plan that the template detail and a prebuilt
//  mesocycle's detail show: a week's targets ("Week 3 · 3 sets · 8–10 · RIR 1") and how they
//  change through the block ("Week 1: 2 sets · From week 2: 3 sets").
//

import Foundation

extension WorkoutTemplateExercise {

    /// "3 sets · 8–10 · RIR 1": the working sets, their rep range and effort. A part with no
    /// target is left out.
    static func targetSummary(_ targets: [SetTarget], separator: String = " · ") -> String {
        var parts = [Format.sets(Double(targets.count))]
        let lowest = targets.compactMap(\.minReps).min()
        let highest = targets.compactMap(\.maxReps).max()
        switch (lowest, highest) {
        case let (low?, high?): parts.append(range(low, high))
        case let (nil, high?): parts.append(range(1, high))
        case let (low?, nil): parts.append("\(low.formatted())+")
        case (nil, nil): break
        }
        let rirs = targets.compactMap(\.rirTarget)
        if let low = rirs.min(), let high = rirs.max() {
            parts.append(String(localized: "RIR \(range(low, high))"))
        }
        return parts.joined(separator: separator)
    }

    /// The targets for the 1-based `microcycle`, led by the week when there is one:
    /// "Week 3 · 3 sets · 8–10 · RIR 1". Without one, the base targets alone.
    func weekSummary(microcycle: Int?) -> String {
        let summary = Self.targetSummary(setTargets(forMicrocycle: microcycle))
        guard let microcycle, microcycle >= 1 else { return summary }
        return "\(String(localized: "Week \(microcycle)")) · \(summary)"
    }

    /// "Week 1: 2 sets, 8–10 · Weeks 2–8: 3 sets, 8–10 · From week 9: 4 sets, 8–10", one part
    /// per stretch of weeks with the same targets. Nil when the targets never change.
    var variationSummary: String? {
        let starts = [1] + Set(setTargetsByMicrocycle.map(\.fromMicrocycle).filter { $0 > 1 }).sorted()
        guard starts.count > 1 else { return nil }
        return starts.enumerated().map { index, start in
            let end = index + 1 < starts.count ? starts[index + 1] - 1 : nil
            let weeks: String
            switch end {
            case nil: weeks = String(localized: "From week \(start)")
            case start?: weeks = String(localized: "Week \(start)")
            case let end?: weeks = String(localized: "Weeks \(Self.range(start, end))")
            }
            return "\(weeks): \(Self.targetSummary(setTargets(forMicrocycle: start), separator: ", "))"
        }
        .joined(separator: " · ")
    }

    /// The link as something Safari can open: http or https only.
    var planLink: URL? {
        guard let linkURL, let url = URL(string: linkURL.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    /// Each superset's letter, by group id, in the order the groups first appear. A group of one
    /// is not a superset and gets none.
    static func supersetLetters(in exercises: [WorkoutTemplateExercise]) -> [String: String] {
        let groups = exercises.compactMap(\.supersetGroupId)
        var order: [String] = []
        for group in groups where !order.contains(group) && groups.filter({ $0 == group }).count > 1 {
            order.append(group)
        }
        return Dictionary(uniqueKeysWithValues: order.enumerated().compactMap { index, group in
            ActiveWorkout.letter(index).map { (group, $0) }
        })
    }

    /// The names of the alternatives the plan offers, in its order. Ids not in `library` are skipped.
    func alternativeNames(in library: [ExerciseModel]) -> [String] {
        substituteExerciseIds.compactMap { id in library.first { $0.id == id }?.name }
    }

    private static func range(_ low: Int, _ high: Int) -> String {
        low == high ? low.formatted() : Format.repRange(low, high)
    }
}
