//
//  CreateChallengeInteractor.swift
//  DialedIn
//

@MainActor
protocol CreateChallengeInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var followingUsers: [UserModel] { get }
    @discardableResult
    func createChallenge(title: String, targetSessions: Int, durationDays: Int, memberIds: [String]) async throws -> ChallengeModel
}

extension CoreInteractor: CreateChallengeInteractor { }
