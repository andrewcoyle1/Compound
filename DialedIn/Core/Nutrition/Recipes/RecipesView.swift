//
//  RecipesView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/10/2025.
//

import SwiftUI

struct RecipesView<RecipeList: View>: View {

    @State var presenter: RecipesPresenter
    
    @ViewBuilder var recipeListViewBuilder: (RecipeListBuilderDelegate) -> RecipeList
    
    var body: some View {
        let delegate = RecipeListBuilderDelegate(onRecipeSelectionChanged: presenter.onRecipePressed)
        recipeListViewBuilder(delegate)
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                presenter.onViewAppear()
            }
            .onDisappear {
                presenter.onViewDisappear()
            }
    }
}

extension CoreBuilder {
    func recipesView(router: AnyRouter) -> some View {
        RecipesView(
            presenter: RecipesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            recipeListViewBuilder: { delegate in
                self.recipeListBuilderView(router: router, delegate: delegate)
            }
        )
    }
}

extension CoreRouter {
    func showRecipesView() {
        router.showScreen(.push) { router in
            builder.recipesView(router: router)
        }
    }
}

#Preview("Recipes View") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    List {
        RouterView { router in
            builder.recipesView(router: router)
        }
    }
    
}
