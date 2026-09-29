//
//  WorkoutSessionHighlights.swift
//  DialedIn
//

import Foundation

/// What made a finished session worth a reaction, read off the author's own history: the lifts
/// that beat everything they had done before, and where the session falls in its week.
///
/// Pure functions of the session and the sessions it is compared with, so the feed card can be
/// tested without any manager behind it.
enum WorkoutSessionHighlights {

    struct PersonalRecord: Equatable {
        let exerciseName: String
        /// The record itself, e.g. "100 kg × 5", "20 reps", "1:30", "5.2 km".
        let detail: String
    }

    /// The exercises in `session` whose best working set beat the author's best for that exercise
    /// across every finished session dated before it.
    ///
    /// A first-ever lift is not a record: with nothing earlier to beat, nothing is flagged —
    /// otherwise someone's first logged workout would be a wall of "PR" badges.
    static func personalRecords(
        in session: WorkoutSessionModel,
        priorSessions: [WorkoutSessionModel],
        limit: Int = 3
    ) -> [PersonalRecord] {
        let earlier = priorSessions.filter {
            counts($0, author: session.authorId) && $0.id != session.id && $0.dateCreated < session.dateCreated
        }
        var seen = Set<String>()
        var records: [PersonalRecord] = []

        for exercise in session.exercises where seen.insert(exercise.templateId).inserted {
            guard records.count < limit,
                  let now = best(exercise.templateId, mode: exercise.trackingMode, in: [session]),
                  let before = best(exercise.templateId, mode: exercise.trackingMode, in: earlier),
                  now > before
            else { continue }
            records.append(PersonalRecord(exerciseName: exercise.name, detail: describe(now, mode: exercise.trackingMode)))
        }
        return records
    }

    /// Where `session` falls among the author's finished, non-rest sessions in its calendar week:
    /// 1 for the first, 3 for the third. Later sessions that week do not change it.
    static func weeklyWorkoutNumber(
        of session: WorkoutSessionModel,
        history: [WorkoutSessionModel],
        calendar: Calendar = .current
    ) -> Int {
        let earlierThisWeek = sessions(of: session.authorId, inWeekOf: session.dateCreated, history: history, calendar: calendar)
            .filter { $0.id != session.id && $0.dateCreated <= session.dateCreated }
        return earlierThisWeek.count + 1
    }

    /// "3rd workout of the week", from the second one on — a first is not news. "Of the week"
    /// rather than "this week", because the card can be read long after the week is over.
    static func weeklyWorkoutText(_ number: Int) -> String? {
        guard number >= 2 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        let ordinal = formatter.string(from: NSNumber(value: number)) ?? "\(number)"
        return String(localized: "\(String(describing: ordinal)) workout of the week")
    }

    /// "12-day streak", stamped on the session when the author finished it. Only from two days
    /// on, like the weekly count, and absent on sessions finished before streaks were stamped.
    static func streakText(_ streakCount: Int?) -> String? {
        guard let streakCount, streakCount > 1 else { return nil }
        return String(localized: "\(streakCount)-day streak")
    }

    /// `author`'s finished, non-rest sessions dated in the calendar week containing `date`. The one
    /// weekly bucketing rule: the feed's "3rd workout this week" and the circle's weekly goal both
    /// count through here, so they cannot disagree.
    static func sessions(
        of author: String,
        inWeekOf date: Date,
        history: [WorkoutSessionModel],
        calendar: Calendar = .current
    ) -> [WorkoutSessionModel] {
        history.filter {
            counts($0, author: author) && calendar.isDate($0.dateCreated, equalTo: date, toGranularity: .weekOfYear)
        }
    }

    // MARK: - Helpers

    private static func counts(_ session: WorkoutSessionModel, author: String) -> Bool {
        session.authorId == author && session.endedAt != nil && !session.isRestDay && session.deletedAt == nil
    }

    /// The best completed working set of one exercise across `sessions`, as a pair compared
    /// value first, then reps. Weighted lifts reuse the exercise detail screen's heaviest-set rule
    /// (weight, then reps at that weight); every other mode takes the largest reps, time or distance.
    private static func best(_ templateId: String, mode: TrackingMode, in sessions: [WorkoutSessionModel]) -> (value: Double, reps: Int)? {
        if mode == .weightReps {
            let stats = ExerciseModelDetailStats.make(from: sessions, templateId: templateId)
            return stats.heaviestSetKg > 0 ? (stats.heaviestSetKg, stats.repsAtHeaviestSet) : nil
        }
        let values = sessions
            .filter { $0.endedAt != nil }
            .flatMap(\.exercises)
            .filter { $0.templateId == templateId }
            .flatMap(\.workingSets)
            .filter { $0.completedAt != nil }
            .compactMap { set -> Double? in
                switch mode {
                case .repsOnly: set.reps.map(Double.init)
                case .timeOnly: set.durationSec.map(Double.init)
                case .distanceTime: set.distanceMeters
                case .weightReps: nil
                }
            }
        guard let top = values.max(), top > 0 else { return nil }
        return (top, 0)
    }

    private static func describe(_ mark: (value: Double, reps: Int), mode: TrackingMode) -> String {
        switch mode {
        case .weightReps:
            return "\(mark.value.formatted(.number.precision(.fractionLength(0...1)))) kg × \(mark.reps)"
        case .repsOnly:
            return "\(Int(mark.value)) reps"
        case .timeOnly:
            return Duration.seconds(mark.value).formatted(.time(pattern: .minuteSecond))
        case .distanceTime:
            return mark.value >= 1000
                ? "\((mark.value / 1000).formatted(.number.precision(.fractionLength(0...1)))) km"
                : "\(Int(mark.value)) m"
        }
    }
}
