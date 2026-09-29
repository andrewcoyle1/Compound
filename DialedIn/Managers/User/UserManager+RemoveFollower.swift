//
//  UserManager+RemoveFollower.swift
//  DialedIn
//
//  Removing someone who follows the reader. The follow lives in the follower's own document, so the
//  `removeFollower` Cloud Function does the write.
//

import Foundation

extension UserManager {

    func removeFollower(userId: String) async throws {
        try await queryService.removeFollower(followerId: userId)
    }
}

extension CoreInteractor {

    func removeFollower(userId: String) async throws {
        try await userManager.removeFollower(userId: userId)
    }
}
