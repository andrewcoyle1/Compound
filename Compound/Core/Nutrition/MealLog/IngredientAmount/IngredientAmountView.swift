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
    /// Prefills the amount, e.g. with an AI estimate's amount, so it can be corrected rather than
    /// starting the field over at 100.
    /// Nil opens on the food's own portion.
    var initialAmountText: String?
    /// The plate's Log. When set, the screen offers Log beside Add to Plate, so a single food can be
    /// logged from here without going back through the picker and the plate.
    var onLog: (() -> Void)?
}

struct IngredientAmountView: View {

    @State var presenter: IngredientAmountPresenter

    var delegate: IngredientAmountDelegate

    /// The amount opens focused and selected, so typing replaces it rather than appending to it.
    @FocusState private var isAmountFocused: Bool
    @State private var amountSelection: TextSelection?

    var body: some View {
        Form {
            Section("Amount") {
                HStack {
                    TextField("Amount", text: $presenter.amountText, selection: $amountSelection)
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
            presenter.onViewAppear(ingredient: delegate.ingredient, initialAmountText: delegate.initialAmountText)
            isAmountFocused = true
        }
        .onDisappear { presenter.onViewDisappear() }
        // Selected once the field has focus: taking focus puts the caret at the end, which
        // replaced a selection made any earlier, and typing then appended to the amount.
        .onChange(of: isAmountFocused) { _, focused in
            guard focused else { return }
            let text = presenter.amountText
            amountSelection = TextSelection(range: text.startIndex..<text.endIndex)
        }
        .navigationBarTitleDisplayMode(.inline)
        .bottomCTA {
            if let onLog = delegate.onLog {
                CallToActionButton {
                    presenter.log(ingredient: delegate.ingredient, onConfirm: delegate.onPick, onLog: onLog)
                } label: {
                    Text("Log")
                }
                .disabled(presenter.amountValue <= 0)
            }
            CallToActionButton(isPrimaryAction: delegate.onLog == nil) {
                presenter.add(ingredient: delegate.ingredient, onConfirm: delegate.onPick)
            } label: {
                Text("Add to Plate")
            }
            .disabled(presenter.amountValue <= 0)
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
