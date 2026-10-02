//
//  RecipesPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

@Observable
@MainActor
class RecipesPresenter {
    private let interactor: RecipesInteractor
    private let router: RecipesRouter
    
    init(interactor: RecipesInteractor,
         router: RecipesRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onRecipePressed(recipe: RecipeTemplateModel) {
        router.showRecipeDetailView(delegate: RecipeDetailDelegate(recipeTemplate: recipe))
    }
}

extension RecipesPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "RecipesView_Appear"
            case .onDisappear: return "RecipesView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
