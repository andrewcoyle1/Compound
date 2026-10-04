//
//  IngredientAmountView.swift
//  Compound
//
//  Created by Andrew Coyle on 27/10/2025.
//

import SwiftUI

struct IngredientAmountDelegate {
    var ingredient: FoodModel
    let onPick: (MealItemModel) -> Void
    /// Prefills the amount, e.g. with an AI estimate's amount or last time's, so it can be
    /// corrected rather than starting over. Nil opens on the food's own portion.
    var initialAmountText: String?
    /// The serving unit `initialAmountText` is counted in; nil for grams or millilitres.
    var initialUnit: ServingUnit?
}

struct IngredientAmountView: View {

    @State var presenter: IngredientAmountPresenter

    var delegate: IngredientAmountDelegate

    @FocusState private var isAmountFocused: Bool

    var body: some View {
        Form {
            Section("Amount") {
                HStack {
                    TextField("Amount", text: $presenter.amountText)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
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
        .onAppear {
            presenter.onViewAppear(
                ingredient: delegate.ingredient,
                initialAmountText: delegate.initialAmountText,
                initialUnit: delegate.initialUnit
            )
        }
        // The amount is the one thing this screen asks for.
        .onFirstAppear {
            isAmountFocused = true
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add", role: .confirm) {
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
