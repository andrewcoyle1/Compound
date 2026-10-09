//
//  VolumeRecommendation.swift
//  Compound
//
//  "Adjusts based on your progress": a suggestion, per muscle, for the next two to three weeks'
//  hard sets, from the user's own recent volume and how their lifts for that muscle are moving.
//  It is shown on the muscle's detail screen and changes nothing on its own: the user's templates
//  stay as they are.
//
//  The direction is from the literature: a step of 10–20% above a person's own habitual volume
//  (Scarpelli 2022, 1.2× habitual beat a fixed 22 sets; Camargo 2026, +120% was no better than
//  +20%), and a floor from the minimal dose that maintains (Spiering 2021). No closed-loop volume
//  rule has been trialled, so every threshold below is Compound's own and is named as such in
//  `MethodInfo.volumeRecommendation`.
//

import Foundation

enum VolumeRecommendation {

    // MARK: - Compound's own constants

    /// Weeks of history the baseline and the trend are read from.
    static let windowWeeks = 4
    /// A strength trend within this many percent a week either way is read as flat. A placeholder
    /// until it can be tuned on replayed training logs.
    static let flatTrendPercentPerWeek = 0.5
    /// Below this share of planned sets done, consistency comes before any change in volume.
    static let minimumAdherence = 0.8
    /// A rise in RPE at the same load of at least this much reads as accumulating fatigue.
    static let rpeDriftThreshold = 1.0
    /// The step up, as a fraction of the baseline: 10–20%.
    static let increase: ClosedRange<Double> = 0.10...0.20
    /// The step down, as a fraction of the baseline: 20–33%.
    static let decrease: ClosedRange<Double> = 0.20...0.33
    /// The floor a suggestion never goes under, and the floor from 60 years old.
    static let floorSets = 4.0
    static let olderAdultFloorSets = 6.0
    static let olderAdultAge = 60
    /// A trend needs at least this many sessions of an exercise, spread over at least this many
    /// days, to count.
    static let minimumTrendPoints = 3
    static let minimumTrendSpanDays = 7.0

    // MARK: - Result

    enum Action: Equatable {
        /// Progressing, or flat on too little evidence to change: keep the current volume.
        case keep
        /// Flat strength with steady effort: add 10–20%.
        case add
        /// Strength falling or effort rising at the same load: take 20–33% off.
        case reduce
        /// Fewer than 80% of the planned sets were done: fix consistency first.
        case beConsistent
        /// Not enough logged to judge.
        case needsMoreData
    }

    struct Result: Equatable {
        let action: Action
        /// Median weekly hard sets over the window.
        let baselineSets: Double
        /// The suggested weekly hard sets, rounded to whole sets; `nil` with nothing to suggest.
        let suggestedSets: ClosedRange<Double>?
        /// Strength change on the exercises that train the muscle directly, % a week.
        let trendPercentPerWeek: Double?
        let adherence: Double?
        let rpeDrift: Double?
        /// The baseline is above 20 sets a week: worth a word, not a block.
        var isHighVolume: Bool { baselineSets > MuscleVolume.productiveWeeklySets.upperBound }
    }

    /// One logged set's effort at its load, for `rpeDrift`.
    struct EffortSample: Equatable {
        let date: Date
        let weightKg: Double
        let rpe: Double
    }

    struct Inputs: Equatable {
        /// Weekly hard sets for the muscle, oldest first; the last `windowWeeks` are read.
        let weeklySets: [Double]
        let trendPercentPerWeek: Double?
        let adherence: Double?
        let rpeDrift: Double?
        let age: Int?
    }

    // MARK: - The rule

    static func recommend(_ inputs: Inputs) -> Result {
        let window = Array(inputs.weeklySets.suffix(windowWeeks))
        let trainedWeeks = window.filter { $0 > 0 }.count
        let baseline = median(window) ?? 0
        let minimum = (inputs.age ?? 0) >= olderAdultAge ? olderAdultFloorSets : floorSets

        func result(_ action: Action, _ suggested: ClosedRange<Double>?) -> Result {
            Result(
                action: action, baselineSets: baseline, suggestedSets: suggested,
                trendPercentPerWeek: inputs.trendPercentPerWeek, adherence: inputs.adherence, rpeDrift: inputs.rpeDrift
            )
        }

        guard trainedWeeks >= 2 else { return result(.needsMoreData, nil) }
        // A new user, without a full window behind them, starts from the productive band.
        let base = trainedWeeks < windowWeeks
            ? min(max(baseline, MuscleVolume.productiveWeeklySets.lowerBound), MuscleVolume.productiveWeeklySets.upperBound)
            : baseline

        if let adherence = inputs.adherence, adherence < minimumAdherence {
            return result(.beConsistent, range(base, base, floor: minimum))
        }
        guard let trend = inputs.trendPercentPerWeek else { return result(.needsMoreData, nil) }
        let effortRising = (inputs.rpeDrift ?? 0) >= rpeDriftThreshold

        if trend < -flatTrendPercentPerWeek || effortRising {
            return result(.reduce, range(base * (1 - decrease.upperBound), base * (1 - decrease.lowerBound), floor: minimum))
        }
        if trend > flatTrendPercentPerWeek {
            return result(.keep, range(base, base, floor: minimum))
        }
        let low = max(base * (1 + increase.lowerBound), base + 1)
        let high = max(base * (1 + increase.upperBound), low)
        return result(.add, range(low, high, floor: minimum))
    }

    /// Whole sets, never under the floor.
    private static func range(_ low: Double, _ high: Double, floor: Double) -> ClosedRange<Double> {
        let lower = max(low.rounded(), floor)
        let upper = max(high.rounded(), lower)
        return lower...upper
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    // MARK: - Strength trend

    /// The least-squares slope of the points, as a percentage of their mean per week. `nil` with
    /// fewer than `minimumTrendPoints` or a span under `minimumTrendSpanDays`.
    static func trendPercentPerWeek(_ points: [(date: Date, value: Double)]) -> Double? {
        let valid = points.filter { $0.value > 0 }
        guard valid.count >= minimumTrendPoints,
              let first = valid.map(\.date).min(), let last = valid.map(\.date).max() else { return nil }
        let days = valid.map { $0.date.timeIntervalSince(first) / 86_400 }
        guard last.timeIntervalSince(first) / 86_400 >= minimumTrendSpanDays else { return nil }
        let values = valid.map(\.value)
        let meanX = days.reduce(0, +) / Double(days.count)
        let meanY = values.reduce(0, +) / Double(values.count)
        let covariance = zip(days, values).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let variance = days.reduce(0) { $0 + ($1 - meanX) * ($1 - meanX) }
        guard variance > 0, meanY > 0 else { return nil }
        return covariance / variance * 7 / meanY * 100
    }

    // MARK: - From logged sessions

    /// The inputs for one muscle from finished sessions. The trend is the median of the
    /// per-exercise e1RM trends (`ExerciseOneRMAggregator`) over the window, for exercises that
    /// train the muscle directly; adherence is the share of those exercises' planned sets that were
    /// done; RPE drift is the median change in RPE at an unchanged load, second half of the window
    /// against the first.
    static func inputs(
        muscle: Muscles,
        sessions: [WorkoutSessionModel],
        templates: [String: ExerciseModel],
        age: Int?,
        calendar: Calendar,
        endDate: Date = Date()
    ) -> Inputs {
        let weekly = MuscleVolume.weeklySets(
            sessions: sessions, templates: templates, calendar: calendar, endDate: endDate, weeks: windowWeeks
        )[muscle] ?? []
        let windowStart = calendar.date(byAdding: .day, value: -windowWeeks * 7, to: calendar.startOfDay(for: endDate)) ?? endDate
        let recent = sessions.filter { ($0.endedAt ?? $0.dateCreated) >= windowStart && ($0.endedAt ?? $0.dateCreated) <= endDate }
        let primaryIds = Set(templates.filter { $0.value.muscleGroups[muscle] == .primary }.map(\.key))

        let aggregates = ExerciseOneRMAggregator.aggregate(sessions: recent)
        let trends = aggregates
            .filter { primaryIds.contains($0.key) }
            .compactMap { _, aggregate in
                trendPercentPerWeek(aggregate.last7Workouts.map { point in (date: point.date, value: point.value) })
            }

        var planned = 0
        var done = 0
        var effort: [String: [EffortSample]] = [:]
        for session in recent {
            let date = session.endedAt ?? session.dateCreated
            for exercise in session.exercises where primaryIds.contains(exercise.templateId) {
                if !exercise.setTargets.isEmpty {
                    planned += exercise.setTargets.count
                    done += min(MuscleVolume.completedWorkingSets(exercise), exercise.setTargets.count)
                }
                for set in exercise.sets where !set.isWarmup && !set.isSubSet && set.completedAt != nil {
                    guard let rpe = set.rpe, let weight = set.weightKg, weight > 0 else { continue }
                    effort[exercise.templateId, default: []].append(EffortSample(date: date, weightKg: weight, rpe: rpe))
                }
            }
        }
        let midpoint = windowStart.addingTimeInterval(endDate.timeIntervalSince(windowStart) / 2)
        let drifts = effort.values.compactMap { rpeDrift($0, midpoint: midpoint) }

        return Inputs(
            weeklySets: weekly,
            trendPercentPerWeek: median(trends),
            adherence: planned > 0 ? Double(done) / Double(planned) : nil,
            rpeDrift: median(drifts),
            age: age
        )
    }

    /// The change in mean RPE at the load used most often on both sides of `midpoint`, later
    /// minus earlier. `nil` when no load was logged with RPE on both sides.
    static func rpeDrift(_ sets: [EffortSample], midpoint: Date) -> Double? {
        let byLoad = Dictionary(grouping: sets) { ($0.weightKg * 100).rounded() }
        let candidates = byLoad.values.compactMap { group -> (count: Int, drift: Double)? in
            let before = group.filter { $0.date < midpoint }.map(\.rpe)
            let after = group.filter { $0.date >= midpoint }.map(\.rpe)
            guard !before.isEmpty, !after.isEmpty else { return nil }
            let drift = after.reduce(0, +) / Double(after.count) - before.reduce(0, +) / Double(before.count)
            return (count: group.count, drift: drift)
        }
        return candidates.max { $0.count != $1.count ? $0.count < $1.count : $0.drift < $1.drift }?.drift
    }
}
