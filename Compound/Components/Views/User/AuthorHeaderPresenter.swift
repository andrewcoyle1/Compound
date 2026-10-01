//
//  AuthorHeaderPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 08/03/2026.
//

import Foundation

@Observable
@MainActor
class AuthorHeaderPresenter {
    private let interactor: AuthorHeaderInteractor
    private let router: AuthorHeaderRouter
    
    init(interactor: AuthorHeaderInteractor, router: AuthorHeaderRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onUserPressed(author: UserModel) {
        router.showSocialProfileView(delegate: SocialProfileDelegate(user: author))
    }
}
