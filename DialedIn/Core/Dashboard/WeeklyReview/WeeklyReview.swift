//
//  WeeklyReview.swift
//  DialedIn
//
//  One week of the user's own training, body weight and nutrition, as a pure function of their
//  data and a date, so every number on the Weekly Review screen is tested without a manager.
//

import Foundation

struct WeeklyReview: Equatable {

    struct MuscleSets: Equatable {
        let muscle: Muscles
        /// Primary muscles count a set in full, secondary ones half, as on the Muscle Groups screen.
        let sets: Double
    }

    struct NutritionAdherence: Equatable {
        /// Days with meals logged whose calories landed within `tolerance` of that day's target.
        let daysOnTarget: Int
        let daysLogged: Int

        static let tolerance = 0.1
    }

    let week: DateInterval
    let sessionCount: Int
    let goal: Int
    let volumeKg: Double
    let previousVolumeKg: Double
    let setsPerMuscle: [MuscleSets]
    let personalRecords: [WorkoutSessionHighlights.PersonalRecord]
    let averageRPE: Double?
    let latestWeightKg: Double?
    let weightChangeKg: Double?
    let nutrition: NutritionAdherence?

    /// Fraction of last week's volume, e.g. 0.12 for 12% more; nil when last week had none.
    var volumeChange: Double? {
        previousVolumeKg > 0 ? (volumeKg - previousVolumeKg) / previousVolumeKg : nil
    }

    // MARK: - Build

    /// `week` is any date inside the week under review. `dailyTargets` is the diet plan's days,
    /// Monday first; empty when the user has no plan, and then there is no adherence to report.
    static func build(
        sessions: [WorkoutSessionModel],
        measurements: [BodyMeasurementEntry],
        meals: [MealLogModel],
        week: Date,
        userId: String,
        goal: Int = CircleWeek.defaultGoal,
        templates: [String: ExerciseModel] = [:],
        dailyTargets: [DailyMacroTarget] = [],
        calendar: Calendar = .current
    ) -> WeeklyReview {
        let interval = calendar.dateInterval(of: .weekOfYear, for: week) ?? DateInterval(start: week, duration: 7 * 86_400)
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: week) ?? week
        let weekSessions = WorkoutSessionHighlights.sessions(of: userId, inWeekOf: week, history: sessions, calendar: calendar)
        let weight = weights(measurements, in: interval)

        return WeeklyReview(
            week: interval,
            sessionCount: weekSessions.count,
            goal: goal,
            volumeKg: CircleWeek.volumeKg(of: userId, inWeekOf: week, sessions: sessions, calendar: calendar),
            previousVolumeKg: CircleWeek.volumeKg(of: userId, inWeekOf: lastWeek, sessions: sessions, calendar: calendar),
            setsPerMuscle: setsPerMuscle(weekSessions, templates: templates, calendar: calendar),
            personalRecords: personalRecords(weekSessions, history: sessions),
            averageRPE: averageRPE(weekSessions),
            latestWeightKg: weight.latest,
            weightChangeKg: weight.change,
            nutrition: adherence(meals, in: interval, dailyTargets: dailyTargets, calendar: calendar)
        )
    }

    private static func setsPerMuscle(
        _ sessions: [WorkoutSessionModel],
        templates: [String: ExerciseModel],
        calendar: Calendar
    ) -> [MuscleSets] {
        MuscleGroupSetsAggregator.aggregate(sessions: sessions, templates: templates, calendar: calendar)
            .filter { $0.value.total > 0 }
            .map { MuscleSets(muscle: $0.key, sets: $0.value.total) }
            .sorted { $0.sets != $1.sets ? $0.sets > $1.sets : $0.muscle.name < $1.muscle.name }
    }

    /// Every record set that week, one per exercise: a lift beaten twice keeps its later mark.
    private static func personalRecords(
        _ weekSessions: [WorkoutSessionModel],
        history: [WorkoutSessionModel]
    ) -> [WorkoutSessionHighlights.PersonalRecord] {
        let all = weekSessions
            .sorted { $0.dateCreated < $1.dateCreated }
            .flatMap { WorkoutSessionHighlights.personalRecords(in: $0, priorSessions: history, limit: .max) }
        var seen = Set<String>()
        return all.reversed().filter { seen.insert($0.exerciseName).inserted }.reversed()
    }

    /// Mean RPE of completed working sets that recorded one; nil when none did.
    private static func averageRPE(_ sessions: [WorkoutSessionModel]) -> Double? {
        let values = sessions
            .flatMap(\.exercises)
            .flatMap(\.workingSets)
            .filter { $0.completedAt != nil }
            .compactMap(\.rpe)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// The week's last weigh-in, and its change from the last one before the week (or, with none
    /// before, from the week's first).
    private static func weights(
        _ measurements: [BodyMeasurementEntry],
        in interval: DateInterval
    ) -> (latest: Double?, change: Double?) {
        let weighIns = measurements
            .filter { $0.deletedAt == nil && $0.weightKg != nil }
            .sorted { $0.date < $1.date }
        let inWeek = weighIns.filter { $0.date >= interval.start && $0.date < interval.end }
        guard let latest = inWeek.last?.weightKg else { return (nil, nil) }
        let baselineEntry = weighIns.last { $0.date < interval.start } ?? (inWeek.count > 1 ? inWeek.first : nil)
        return (latest, baselineEntry?.weightKg.map { latest - $0 })
    }

    private static func adherence(
        _ meals: [MealLogModel],
        in interval: DateInterval,
        dailyTargets: [DailyMacroTarget],
        calendar: Calendar
    ) -> NutritionAdherence? {
        guard !dailyTargets.isEmpty else { return nil }
        let days = Dictionary(grouping: meals.filter { $0.date >= interval.start && $0.date < interval.end }) {
            calendar.startOfDay(for: $0.date)
        }
        let onTarget = days.filter { day, meals in
            // The plan stores one target per weekday, Monday first, as `NutritionPresenter` reads it.
            let index = (calendar.component(.weekday, from: day) + 5) % 7
            guard index < dailyTargets.count, dailyTargets[index].calories > 0 else { return false }
            let target = dailyTargets[index].calories
            let eaten = meals.reduce(0) { $0 + $1.totalCalories }
            return abs(eaten - target) <= target * NutritionAdherence.tolerance
        }
        return NutritionAdherence(daysOnTarget: onTarget.count, daysLogged: days.count)
    }

    // MARK: - Wording

    /// The one line at the top of the review, first match wins.
    var takeaway: String {
        let prCount = personalRecords.count
        if sessionCount == 0 {
            return String(localized: "No sessions logged this week.")
        }
        if sessionCount >= goal, prCount > 0 {
            return String(localized: "Goal hit and \(String(describing: prCount)) \(prCount == 1 ? String(localized: "PR") : String(localized: "PRs")) set. Great week.")
        }
        if sessionCount >= goal {
            return String(localized: "Goal hit: \(String(describing: sessionCount)) of \(String(describing: goal)) sessions.")
        }
        if let change = volumeChange, change >= 0.1 {
            return String(localized: "Volume up \(Self.percent(change)) on last week.")
        }
        let toGo = CircleWeek.remaining(sessions: sessionCount, goal: goal)
        return String(localized: "\(String(describing: toGo)) more \(toGo == 1 ? String(localized: "session") : String(localized: "sessions")) would have hit your goal.")
    }

    var dateRangeText: String {
        // The interval's end is the next Monday; show the Sunday.
        let end = week.end.addingTimeInterval(-1)
        return (week.start..<end).formatted(.interval.day().month(.abbreviated))
    }

    var sessionsText: String { "\(sessionCount) of \(goal)" }

    var volumeText: String {
        ShareCardContent.volumeText(volumeKg) ?? "0 kg"
    }

    /// "+12% vs last week"; nil when there is nothing to compare with.
    var volumeChangeText: String? {
        guard let change = volumeChange else { return nil }
        return String(localized: "\(change >= 0 ? "+" : "")\(Self.percent(change)) vs last week")
    }

    var averageRPEText: String? {
        averageRPE.map { $0.formatted(.number.precision(.fractionLength(1))) }
    }

    var weightText: String? {
        guard let latest = latestWeightKg else { return nil }
        let value = "\(latest.formatted(.number.precision(.fractionLength(0...1)))) kg"
        guard let change = weightChangeKg else { return value }
        let sign = change > 0 ? "+" : change < 0 ? "−" : "±"
        return String(localized: "\(String(describing: value)) (\(sign)\(abs(change).formatted(.number.precision(.fractionLength(0...1)))) kg)")
    }

    var nutritionText: String? {
        nutrition.map { "\($0.daysOnTarget) of \($0.daysLogged) logged days on target" }
    }

    private static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}
