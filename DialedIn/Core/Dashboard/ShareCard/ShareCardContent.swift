//
//  ShareCardContent.swift
//  DialedIn
//

import Foundation

/// Everything the share card prints, as strings, so the card's wording is tested without
/// rendering it.
///
/// Privacy: the only person on the card is the session's author, and only by first name and
/// avatar. No username, no last name, no comments, no likers.
struct ShareCardContent: Equatable {
    let firstName: String?
    let avatarURL: String?
    let sessionName: String
    let dateText: String
    let durationText: String?
    let volumeText: String?
    let setCount: Int
    let personalRecordLines: [String]
    let weeklyText: String?
    let streakText: String?

    /// The card for `session`, with its records and weekly count read off the author's `history`.
    static func make(
        session: WorkoutSessionModel,
        author: UserModel?,
        history: [WorkoutSessionModel],
        locale: Locale = .current
    ) -> ShareCardContent {
        make(
            session: session,
            author: author,
            personalRecords: WorkoutSessionHighlights.personalRecords(in: session, priorSessions: history),
            weeklyWorkoutNumber: WorkoutSessionHighlights.weeklyWorkoutNumber(of: session, history: history),
            locale: locale
        )
    }

    static func make(
        session: WorkoutSessionModel,
        author: UserModel?,
        personalRecords: [WorkoutSessionHighlights.PersonalRecord],
        weeklyWorkoutNumber: Int,
        locale: Locale = .current
    ) -> ShareCardContent {
        let workingSets = session.exercises.flatMap(\.workingSets)
        let volume = workingSets.reduce(0.0) { $0 + (($1.weightKg ?? 0) * Double($1.reps ?? 0)) }
        // A left and a right are one set, as on the feed card.
        let setCount = session.exercises.reduce(0) { $0 + $1.workingSetCount }

        return ShareCardContent(
            firstName: author?.firstNameCalculated,
            avatarURL: author?.profileImageNameCalculated,
            sessionName: session.name,
            dateText: session.dateCreated.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale)),
            durationText: durationText(from: session.dateCreated, to: session.endedAt),
            volumeText: volumeText(volume, locale: locale),
            setCount: setCount,
            personalRecordLines: personalRecords.map { "\($0.exerciseName) \($0.detail)" },
            weeklyText: WorkoutSessionHighlights.weeklyWorkoutText(weeklyWorkoutNumber),
            streakText: WorkoutSessionHighlights.streakText(session.streakCount)
        )
    }

    /// "1h 5m", or "45m" under an hour; nil for a session still running.
    static func durationText(from start: Date, to end: Date?) -> String? {
        guard let end else { return nil }
        let total = max(0, Int(end.timeIntervalSince(start)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? String(localized: "\(String(describing: hours))h \(String(describing: minutes))m") : String(localized: "\(String(describing: minutes))m")
    }

    /// "12,340 kg" with the reader's grouping; nil when nothing was lifted, so a run or a
    /// bodyweight session does not boast "0 kg".
    static func volumeText(_ kilograms: Double, locale: Locale = .current) -> String? {
        guard kilograms > 0 else { return nil }
        return String(localized: "\(Int(kilograms.rounded()).formatted(.number.locale(locale))) kg")
    }
}
