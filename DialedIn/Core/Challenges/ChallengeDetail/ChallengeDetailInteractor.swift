//
//  ChallengeDetailInteractor.swift
//  DialedIn
//

@MainActor
protocol ChallengeDetailInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var followingUsers: [UserModel] { get }
    var challenges: [ChallengeModel] { get }
    func challengeProgress(challengeId: String) -> [String: Int]
    func refreshChallengeProgress(challengeId: String) async throws
    func getUser(userId: String) async throws -> UserModel
    func leaveChallenge(id: String) async throws
}

extension CoreInteractor: ChallengeDetailInteractor { }
