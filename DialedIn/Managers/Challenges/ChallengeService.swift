//
//  ChallengeService.swift
//  DialedIn
//

import Foundation

@MainActor
protocol ChallengeService: AnyObject {
    /// Every challenge `userId` is a member of.
    func fetchChallenges(userId: String) async throws -> [ChallengeModel]
    func fetchChallenge(id: String) async throws -> ChallengeModel
    /// Sessions per member id.
    func fetchProgress(challengeId: String) async throws -> [String: Int]
    func createChallenge(_ challenge: ChallengeModel) async throws
    func leaveChallenge(id: String, userId: String) async throws
}

/// Holds the signed-in user's challenges and their standings for the Dashboard and the detail
/// screen to read.
///
/// ponytail: fetched on appear rather than held by a sync engine, like `ShareManager` — the query
/// is by membership, not a per-user path. Move to a listener if standings need to tick live.
@Observable
@MainActor
final class ChallengeManager {
    private let service: ChallengeService

    /// Whose challenges these are, so a previous account's never show after a sign-in switch.
    private(set) var userId: String?
    private(set) var challenges: [ChallengeModel] = []
    /// Sessions per member id, keyed by challenge id.
    private(set) var progress: [String: [String: Int]] = [:]

    init(service: ChallengeService) {
        self.service = service
    }

    func refresh(userId: String) async throws {
        let fetched = try await service.fetchChallenges(userId: userId)
        var fetchedProgress: [String: [String: Int]] = [:]
        for challenge in fetched {
            fetchedProgress[challenge.id] = try await service.fetchProgress(challengeId: challenge.id)
        }
        self.userId = userId
        challenges = fetched.sorted { $0.endsAt < $1.endsAt }
        progress = fetchedProgress
    }

    func refreshProgress(challengeId: String) async throws {
        progress[challengeId] = try await service.fetchProgress(challengeId: challengeId)
    }

    func fetchChallenge(id: String) async throws -> ChallengeModel {
        try await service.fetchChallenge(id: id)
    }

    func createChallenge(_ challenge: ChallengeModel) async throws {
        try await service.createChallenge(challenge)
        challenges.append(challenge)
        challenges.sort { $0.endsAt < $1.endsAt }
        progress[challenge.id] = [:]
    }

    func leaveChallenge(id: String, userId: String) async throws {
        try await service.leaveChallenge(id: id, userId: userId)
        challenges.removeAll { $0.id == id }
        progress[id] = nil
    }
}

@MainActor
final class MockChallengeService: ChallengeService {
    private(set) var challenges: [ChallengeModel]
    private(set) var progress: [String: [String: Int]]

    init(challenges: [ChallengeModel] = ChallengeModel.mocks, progress: [String: [String: Int]] = ChallengeModel.mockProgress) {
        self.challenges = challenges
        self.progress = progress
    }

    func fetchChallenges(userId: String) async throws -> [ChallengeModel] {
        challenges.filter { $0.memberIds.contains(userId) }
    }

    func fetchChallenge(id: String) async throws -> ChallengeModel {
        guard let challenge = challenges.first(where: { $0.id == id }) else { throw URLError(.fileDoesNotExist) }
        return challenge
    }

    func fetchProgress(challengeId: String) async throws -> [String: Int] {
        progress[challengeId] ?? [:]
    }

    func createChallenge(_ challenge: ChallengeModel) async throws {
        challenges.append(challenge)
    }

    func leaveChallenge(id: String, userId: String) async throws {
        guard let index = challenges.firstIndex(where: { $0.id == id }) else { throw URLError(.fileDoesNotExist) }
        challenges[index].memberIds.removeAll { $0 == userId }
    }
}
