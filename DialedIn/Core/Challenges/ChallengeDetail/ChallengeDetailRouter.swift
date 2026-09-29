//
//  ChallengeDetailRouter.swift
//  DialedIn
//

@MainActor
protocol ChallengeDetailRouter: GlobalRouter {
    func showSocialProfileView(delegate: SocialProfileDelegate)
}

extension CoreRouter: ChallengeDetailRouter { }
