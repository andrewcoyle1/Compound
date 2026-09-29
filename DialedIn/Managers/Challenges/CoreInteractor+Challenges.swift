//
//  CoreInteractor+Challenges.swift
//  DialedIn
//

import Foundation

extension CoreInteractor {

    /// The signed-in user's challenges; empty until the first refresh for this account.
    var challenges: [ChallengeModel] {
        guard let userId, challengeManager.userId == userId else { return [] }
        return challengeManager.challenges
    }

    /// Sessions per member id for one challenge.
    func challengeProgress(challengeId: String) -> [String: Int] {
        challengeManager.progress[challengeId] ?? [:]
    }

    func refreshChallenges() async throws {
        guard let userId else { return }
        try await challengeManager.refresh(userId: userId)
    }

    func refreshChallengeProgress(challengeId: String) async throws {
        try await challengeManager.refreshProgress(challengeId: challengeId)
    }

    func fetchChallenge(id: String) async throws -> ChallengeModel {
        try await challengeManager.fetchChallenge(id: id)
    }

    /// Starts now and runs `durationDays` whole days. The owner is always a member.
    @discardableResult
    func createChallenge(title: String, targetSessions: Int, durationDays: Int, memberIds: [String]) async throws -> ChallengeModel {
        guard let owner = userManager.currentUser else { throw AppError("Not signed in.") }
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: durationDays, to: start) ?? start
        let challenge = ChallengeModel(
            ownerId: owner.userId,
            title: title,
            targetSessions: targetSessions,
            startsAt: start,
            endsAt: end,
            memberIds: [owner.userId] + memberIds.filter { $0 != owner.userId }
        )
        try await challengeManager.createChallenge(challenge)
        return challenge
    }

    func leaveChallenge(id: String) async throws {
        guard let userId else { throw AppError("Not signed in.") }
        try await challengeManager.leaveChallenge(id: id, userId: userId)
    }
}
