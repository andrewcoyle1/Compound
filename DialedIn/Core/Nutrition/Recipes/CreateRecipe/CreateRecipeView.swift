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
        .safeAreaInset(edge: .bottom) {
            CallToActionButton {
                presenter.onNextPressed()
            } label: {
                Text("Next")
            }
            .padding(.bottom)
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
                    .font(.caption)
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
                    .font(.caption)
            }
        }
    }
    
    private var totalWeightSection: some View {
        Section {
            TextFieldwUnit<NutritionWeightUnit>(prompt: String(localized: "Enter weight after preparation"), value: $presenter.recipeTotalWeight, unit: .grams)

        } header: {
            Text("Total Weight")
        }

    }
    
    private var foodsSection: some View {
        Section {
            ForEach($presenter.ingredients) { $wrapper in
                HStack(alignment: .center, spacing: 12) {
                    CustomListCellView(imageName: wrapper.ingredient.imageURL, title: wrapper.ingredient.name, subtitle: wrapper.ingredient.description)
                    Spacer()
                    HStack(spacing: 6) {
                        TextField("Amount", value: $wrapper.amount, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 70)
                        
                        Picker("", selection: $wrapper.unit) {
                            Text("g").tag(IngredientAmountUnit.grams)
                            Text("ml").tag(IngredientAmountUnit.milliliters)
                            Text("units").tag(IngredientAmountUnit.units)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 15)
                    }
                }
                .removeListRowFormatting()
            }
        } header: {
            HStack {
                VStack(alignment: .leading) {
                    Text("Ingredients")
                    Text("Weight of ingredients is 0 \(NutritionWeightUnit.grams.acronym)")
                        .font(.caption)
                }
                Spacer()
                Button {
                    presenter.onAddIngredientPressed()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24))
                }
                .accessibilityLabel("Add ingredient")
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onDismissPressed()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
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
