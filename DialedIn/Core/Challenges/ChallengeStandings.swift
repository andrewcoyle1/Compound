//
//  ChallengeStandings.swift
//  DialedIn
//
//  The pure part of a challenge's display: who is where, and how full the ring is. Shared by the
//  Dashboard card and the detail screen so the two never disagree.
//

import Foundation

enum ChallengeStandings {

    struct Entry: Identifiable, Equatable {
        let userId: String
        let name: String
        let imageUrl: String?
        let sessions: Int
        let isComplete: Bool

        var id: String { userId }
    }

    /// Every member, most sessions first; ties by name so the order is stable.
    static func entries(for challenge: ChallengeModel, progress: [String: Int], users: [String: UserModel]) -> [Entry] {
        challenge.memberIds
            .map { memberId in
                let user = users[memberId]
                let sessions = progress[memberId] ?? 0
                return Entry(
                    userId: memberId,
                    name: user.flatMap { $0.commonNameCalculated ?? $0.fullNameCalculated } ?? "Member",
                    imageUrl: user?.profileImageNameCalculated,
                    sessions: sessions,
                    isComplete: sessions >= challenge.targetSessions
                )
            }
            .sorted { lhs, rhs in
                if lhs.sessions != rhs.sessions { return lhs.sessions > rhs.sessions }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// How full a member's ring is, 0 to 1.
    static func ringProgress(sessions: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(max(Double(sessions) / Double(target), 0), 1)
    }
}
