//
//  IngredientAmountView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/10/2025.
//

import SwiftUI

struct IngredientAmountDelegate {
    var ingredient: FoodModel
    let onPick: (MealItemModel) -> Void
}

struct IngredientAmountView: View {

    @State var presenter: IngredientAmountPresenter

    var delegate: IngredientAmountDelegate

    var body: some View {
        List {
            Section("Amount") {
                HStack {
                    TextField("Amount", text: $presenter.amountText)
                        .keyboardType(.decimalPad)
                    if delegate.ingredient.servingUnits.isEmpty {
                        Text(presenter.unitLabel(ingredient: delegate.ingredient))
                            .foregroundStyle(.secondary)
                    } else {
                        ServingUnitPicker(
                            baseLabel: delegate.ingredient.loggedUnitLabel,
                            units: delegate.ingredient.servingUnits,
                            selection: $presenter.selectedUnit
                        )
                    }
                }
            }

            EstimatedMacrosSection(
                title: "Estimated Macros",
                calories: presenter.calories(ingredient: delegate.ingredient),
                protein: presenter.protein(ingredient: delegate.ingredient),
                carbs: presenter.carbs(ingredient: delegate.ingredient),
                fat: presenter.fat(ingredient: delegate.ingredient)
            )
        }
        .navigationTitle(delegate.ingredient.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Log", role: .confirm) {
                    presenter.add(ingredient: delegate.ingredient, onConfirm: delegate.onPick)
                }
                .disabled(presenter.amountValue <= 0)
            }
        }
    }
}

extension CoreBuilder {
    func ingredientAmountView(router: AnyRouter, delegate: IngredientAmountDelegate) -> some View {
        IngredientAmountView(
            presenter: IngredientAmountPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showIngredientAmountView(delegate: IngredientAmountDelegate) {
        router.showScreen(.push) { router in
            builder.ingredientAmountView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.ingredientAmountView(
            router: router, 
            delegate: IngredientAmountDelegate(
                ingredient: FoodModel.mock,
                onPick: {ingredient in
                    print(ingredient.displayName)
                }
            )
        )
    }
}
