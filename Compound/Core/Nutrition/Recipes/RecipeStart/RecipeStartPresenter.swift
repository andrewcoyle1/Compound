//
//  RecipeStartPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 20/11/2025.
//

import Foundation

@Observable
@MainActor
class RecipeStartPresenter {
    private let interactor: RecipeStartInteractor
    private let router: RecipeStartRouter

    init(
        interactor: RecipeStartInteractor,
        router: RecipeStartRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

}
