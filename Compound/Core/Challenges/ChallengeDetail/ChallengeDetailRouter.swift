//
//  ChallengeDetailRouter.swift
//  Compound
//

@MainActor
protocol ChallengeDetailRouter: GlobalRouter {
    func showSocialProfileView(delegate: SocialProfileDelegate)
}

extension CoreRouter: ChallengeDetailRouter { }
