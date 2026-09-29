//
//  AddFoodView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI

struct AddFoodView: View {

    @State var presenter: AddFoodPresenter

    var delegate: AddFoodDelegate

    var body: some View {
        List {
            ForEach(presenter.filteredFoods) { ingredient in
                Button {
                    presenter.onIngredientPressed(ingredient: ingredient, selectedIngredients: &delegate.selectedIngredients.wrappedValue)
                } label: {
                    ListRow(
                        title: ingredient.name,
                        subtitle: ingredient.description,
                        imageName: ingredient.imageURL,
                        accessory: .checkmark(delegate.selectedIngredients.contains(where: { $0.id == ingredient.id }))
                    )
                    .contentShape(.rect)
                }
            }
        }
        .scrollIndicators(.hidden)
        .searchable(text: $presenter.searchText, placement: .toolbar, prompt: Text("Search foods"))
        .navigationTitle("Add Ingredients")
        .navigationSubtitle("Select one or more ingredients to add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
        }
    }
}

extension CoreBuilder {
    func addFoodView(router: AnyRouter, delegate: AddFoodDelegate) -> some View {
        AddFoodView(
            presenter: AddFoodPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showAddIngredientView(delegate: AddFoodDelegate) {
        router.showScreen(.sheet) { router in
            builder.addFoodView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    @Previewable @State var selectedIngredients: [FoodModel] = [FoodModel.mock]
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.addFoodView(router: router, delegate: AddFoodDelegate(selectedIngredients: $selectedIngredients))
    }
    
}
