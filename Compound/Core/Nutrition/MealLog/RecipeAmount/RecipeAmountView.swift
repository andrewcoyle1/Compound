//
//  RecipeAmountView.swift
//  Compound
//
//  Created by Andrew Coyle on 27/10/2025.
//

import SwiftUI

struct RecipeAmountDelegate {
    let recipe: RecipeTemplateModel
    let onPick: (MealItemModel) -> Void
    /// The plate's Log. When set, the screen offers Log beside Add to Plate.
    var onLog: (() -> Void)?
}

struct RecipeAmountView: View {
    @State var presenter: RecipeAmountPresenter

    let delegate: RecipeAmountDelegate

    /// The servings open focused and selected, so typing replaces them.
    @FocusState private var isServingsFocused: Bool
    @State private var servingsSelection: TextSelection?

    var body: some View {
        Form {
            Section("Servings") {
                TextField("Servings", text: $presenter.servingsText, selection: $servingsSelection)
                    .keyboardType(.decimalPad)
                    .focused($isServingsFocused)
            }
            // For the servings entered, as the food amount screen shows: per serving left the
            // figures unchanged whatever was typed, so they could not confirm the amount.
            EstimatedMacrosSection(
                title: "Estimated Macros",
                calories: presenter.forServings(presenter.baseCalories(recipe: delegate.recipe)),
                protein: presenter.forServings(presenter.baseProtein(recipe: delegate.recipe)),
                carbs: presenter.forServings(presenter.baseCarbs(recipe: delegate.recipe)),
                fat: presenter.forServings(presenter.baseFat(recipe: delegate.recipe))
            )
        }
        .navigationTitle(delegate.recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
            isServingsFocused = true
        }
        .onDisappear { presenter.onViewDisappear() }
        .onChange(of: isServingsFocused) { _, focused in
            guard focused else { return }
            let text = presenter.servingsText
            servingsSelection = TextSelection(range: text.startIndex..<text.endIndex)
        }
        .bottomCTA {
            if let onLog = delegate.onLog {
                CallToActionButton {
                    presenter.log(recipe: delegate.recipe, onConfirm: delegate.onPick, onLog: onLog)
                } label: {
                    Text("Log")
                }
                .disabled(presenter.servings <= 0)
            }
            CallToActionButton(isPrimaryAction: delegate.onLog == nil) {
                presenter.add(recipe: delegate.recipe, onConfirm: delegate.onPick)
            } label: {
                Text("Add to Plate")
            }
            .disabled(presenter.servings <= 0)
        }
    }
}

extension CoreBuilder {
    func recipeAmountView(router: AnyRouter, delegate: RecipeAmountDelegate) -> some View {
        RecipeAmountView(
            presenter: RecipeAmountPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showRecipeAmountView(delegate: RecipeAmountDelegate) {
        router.showScreen(.push) { router in
            builder.recipeAmountView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.recipeAmountView(
            router: router, 
            delegate: RecipeAmountDelegate(
                recipe: RecipeTemplateModel.mock,
                onPick: { meal in
                    print(meal.id)
                }
            )
        )
    }
}
