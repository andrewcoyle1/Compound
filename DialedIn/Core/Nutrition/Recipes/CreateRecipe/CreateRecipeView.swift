//
//  CreateRecipeView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/09/2025.
//

import SwiftUI
import PhotosUI

struct CreateRecipeView: View {
    
    @State var presenter: CreateRecipePresenter

    @ScaledMetric(relativeTo: .body) private var amountFieldWidth: CGFloat = 70
    
    var body: some View {
        List {
            nameSection
            servingQuantitySection
            totalWeightSection
            foodsSection
        }
        .navigationTitle("Create Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .bottomCTA {
            CallToActionButton {
                presenter.onNextPressed()
            } label: {
                Text("Next")
            }
        }
    }
    
    private var nameSection: some View {
        Section {
            TextField("Enter recipe name", text: $presenter.recipeName)
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Recipe name")
                Spacer()
                Text("Required")
                    .font(.label)
            }
        }
    }
    
    private var servingQuantitySection: some View {
        Section {
            AutoSelectNumberField(
                prompt: String(localized: "Enter serving quantity"),
                value: $presenter.servingQuantity,
                alignment: .leading,
                keyboardType: .decimalPad
            )
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Serving Quantity")
                Spacer()
                Text("Required")
                    .font(.label)
            }
        }
    }
    
    private var totalWeightSection: some View {
        Section {
            NumberField(String(localized: "Enter weight after preparation"), value: $presenter.recipeTotalWeight, unit: NutritionWeightUnit.grams.acronym)
        } header: {
            Text("Total Weight")
        }

    }
    
    private var foodsSection: some View {
        Section {
            ForEach($presenter.ingredients) { $wrapper in
                HStack(spacing: Spacing.s) {
                    ListRow(title: wrapper.ingredient.name, subtitle: wrapper.ingredient.description, imageName: wrapper.ingredient.imageURL)
                    TextField("Amount", value: $wrapper.amount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: amountFieldWidth)
                    Picker("Unit", selection: $wrapper.unit) {
                        Text("g").tag(IngredientAmountUnit.grams)
                        Text("ml").tag(IngredientAmountUnit.milliliters)
                        Text("units").tag(IngredientAmountUnit.units)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
            }
        } header: {
            HStack {
                VStack(alignment: .leading) {
                    Text("Ingredients")
                    if let weight = presenter.ingredientsWeightText {
                        Text(weight)
                            .font(.label)
                    }
                }
                Spacer()
                Button {
                    presenter.onAddIngredientPressed()
                } label: {
                    Image(systemName: Symbol.add)
                        .iconSize(.medium)
                }
                .accessibilityLabel("Add ingredient")
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }
#if DEBUG || MOCK
        ToolbarSpacer(.fixed, placement: .topBarLeading)
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
            }
            .accessibilityLabel("Developer settings")
        }
#endif
    }
}

extension CoreBuilder {
    func createRecipeView(router: AnyRouter) -> some View {
        CreateRecipeView(
            presenter: CreateRecipePresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            )
        )
    }
}

extension CoreRouter {
    func showCreateRecipeView() {
        router.showScreen(.fullScreenCover) { router in
            builder.createRecipeView(router: router)
        }
    }
}

#Preview("With Ingredients") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)

    RouterView { router in
        builder.createRecipeView(router: router)
    }
    
}

#Preview("Without Ingredients") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)

    RouterView { router in
        builder.createRecipeView(router: router)
    }
    
}
