//
//  FollowersListRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/03/2026.
//

@MainActor
protocol FollowersListRouter: GlobalRouter {
    func showSocialProfileView(delegate: SocialProfileDelegate)
}

extension CoreRouter: FollowersListRouter { }
