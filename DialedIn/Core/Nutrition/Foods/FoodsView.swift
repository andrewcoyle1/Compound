//
//  FoodsView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/10/2025.
//

import SwiftUI

struct FoodsView<IngredientList: View>: View {
    
    @State var presenter: FoodsPresenter

    @ViewBuilder var ingredientListViewBuilder: (IngredientListBuilderDelegate) -> IngredientList

    var body: some View {
        let delegate = IngredientListBuilderDelegate(onIngredientSelectionChanged: presenter.onIngredientPressed)
        ingredientListViewBuilder(delegate)
            .navigationTitle("Foods")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Foods View") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    
    RouterView { router in
        builder.foodsView(router: router)
    }
}

extension CoreBuilder {
    func foodsView(router: AnyRouter) -> some View {
        FoodsView(
            presenter: FoodsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            ingredientListViewBuilder: { delegate in
                self.ingredientListBuilderView(router: router, delegate: delegate)
            }
        )
    }
}

extension CoreRouter {
    func showFoodsView() {
        router.showScreen(.push) { router in
            builder.foodsView(router: router)
        }
    }
}
