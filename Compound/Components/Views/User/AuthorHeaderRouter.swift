//
//  AuthorHeaderRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 08/03/2026.
//

@MainActor
protocol AuthorHeaderRouter {
    func showSocialProfileView(delegate: SocialProfileDelegate)
}

extension CoreRouter: AuthorHeaderRouter { }
