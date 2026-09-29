//
//  ChallengeModel.swift
//  DialedIn
//

import Foundation

/// `challenges/{id}`: a circle challenge — "train N times between these dates". The owner creates
/// it with a set of mutuals and may later edit the title and members; any member may leave. The
/// running counts live in `challenges/{id}/progress/{uid}`, written only by the
/// `onWorkoutSessionEndedForChallenges` Cloud Function.
struct ChallengeModel: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let ownerId: String
    var title: String
    let targetSessions: Int
    let startsAt: Date
    let endsAt: Date
    var memberIds: [String]
    let dateCreated: Date

    /// The lengths the create screen offers.
    static let durations: [Int] = [7, 14, 30]
    static let titleMaxLength = 60
    static let targetRange = 1...100

    init(
        id: String = UUID().uuidString,
        ownerId: String,
        title: String,
        targetSessions: Int,
        startsAt: Date,
        endsAt: Date,
        memberIds: [String],
        dateCreated: Date = .now
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.targetSessions = targetSessions
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.memberIds = memberIds
        self.dateCreated = dateCreated
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case targetSessions = "target_sessions"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case memberIds = "member_ids"
        case dateCreated = "date_created"
    }

    func isActive(at date: Date) -> Bool {
        startsAt <= date && date < endsAt
    }

    /// Whole days left, counting today; zero once it has ended.
    func daysLeft(from date: Date, calendar: Calendar = .current) -> Int {
        guard date < endsAt else { return 0 }
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: endsAt)
        return max((calendar.dateComponents([.day], from: start, to: end).day ?? 0), 1)
    }
}

/// `challenges/{id}/progress/{uid}`. The document id is the member; a member with no document has
/// not trained since the challenge began.
struct ChallengeProgressModel: Codable, Sendable, Equatable {
    let sessions: Int
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case sessions
        case updatedAt = "updated_at"
    }
}

extension ChallengeModel {
    /// Two challenges for the mock signed-in user (`mock_user_123`) and their mutuals.
    static var mocks: [ChallengeModel] {
        let now = Date()
        let day: TimeInterval = 86_400
        return [
            ChallengeModel(
                id: "mock_challenge_1",
                ownerId: "mock_user_123",
                title: "October Grind",
                targetSessions: 12,
                startsAt: now.addingTimeInterval(-10 * day),
                endsAt: now.addingTimeInterval(20 * day),
                memberIds: ["mock_user_123", "user1", "user3", "user4", "user5"],
                dateCreated: now.addingTimeInterval(-10 * day)
            ),
            ChallengeModel(
                id: "mock_challenge_2",
                ownerId: "user1",
                title: "Two-Week Kickstart",
                targetSessions: 6,
                startsAt: now.addingTimeInterval(-4 * day),
                endsAt: now.addingTimeInterval(10 * day),
                memberIds: ["user1", "mock_user_123", "user3"],
                dateCreated: now.addingTimeInterval(-4 * day)
            )
        ]
    }

    static var mock: ChallengeModel { mocks[0] }

    /// Sessions per member, keyed by challenge id, for the mocks above.
    static var mockProgress: [String: [String: Int]] {
        [
            "mock_challenge_1": ["mock_user_123": 5, "user1": 7, "user3": 4, "user4": 2],
            "mock_challenge_2": ["user1": 3, "mock_user_123": 6, "user3": 1]
        ]
    }
}
