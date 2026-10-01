import SwiftUI

struct RecipeIngredientAmountDelegate {
    let food: FoodModel
    let onConfirm: (RecipeIngredientModel) -> Void
}

struct RecipeIngredientAmountView: View {
    @State var presenter: RecipeIngredientAmountPresenter
    let delegate: RecipeIngredientAmountDelegate

    var body: some View {
        List {
            Section("Amount") {
                HStack {
                    TextField("Amount", text: $presenter.amountText)
                        .keyboardType(.decimalPad)
                    Text(presenter.unitLabel(food: delegate.food))
                        .foregroundStyle(.secondary)
                }
            }
            EstimatedMacrosSection(
                title: "Estimated Macros",
                calories: presenter.calories(food: delegate.food),
                protein: presenter.protein(food: delegate.food),
                carbs: presenter.carbs(food: delegate.food),
                fat: presenter.fat(food: delegate.food)
            )
        }
        .navigationTitle(delegate.food.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Adding to a recipe is not logging, so this keeps its own verb.
            ToolbarItem(placement: .confirmationAction) {
                Button("Add", role: .confirm) {
                    presenter.confirm(delegate: delegate)
                }
                .disabled(presenter.amountValue <= 0)
            }
        }
    }
}

extension CoreBuilder {
    func recipeIngredientAmountView(router: AnyRouter, delegate: RecipeIngredientAmountDelegate) -> some View {
        RecipeIngredientAmountView(
            presenter: RecipeIngredientAmountPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showRecipeIngredientAmountView(delegate: RecipeIngredientAmountDelegate) {
        router.showScreen(.push) { router in
            builder.recipeIngredientAmountView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.recipeIngredientAmountView(
            router: router,
            delegate: RecipeIngredientAmountDelegate(
                food: FoodModel.mock,
                onConfirm: { _ in }
            )
        )
    }
}
