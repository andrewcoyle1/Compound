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
        Form {
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
            
            Section("Estimated Macros") {
                HStack {
                    Text("Calories")
                    Spacer()
                    Text(presenter.calories(ingredient: delegate.ingredient).map { String(Int(round($0))) } ?? "-")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Protein")
                    Spacer()
                    Text(presenter.protein(ingredient: delegate.ingredient).map { String(format: "%.1f g", $0) } ?? "-")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Carbs")
                    Spacer()
                    Text(presenter.carbs(ingredient: delegate.ingredient).map { String(format: "%.1f g", $0) } ?? "-")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Fat")
                    Spacer()
                    Text(presenter.fat(ingredient: delegate.ingredient).map { String(format: "%.1f g", $0) } ?? "-")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(delegate.ingredient.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { presenter.add(ingredient: delegate.ingredient, onConfirm: delegate.onPick) }
                    .disabled((Double(presenter.amountText) ?? 0) <= 0)
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
