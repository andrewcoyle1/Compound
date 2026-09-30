//
//  FollowersListInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/03/2026.
//

@MainActor
protocol FollowersListInteractor: FollowInteractor {
    func removeFollower(userId: String) async throws
}

extension CoreInteractor: FollowersListInteractor { }
