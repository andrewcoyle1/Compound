//
//  FoodDetailView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct FoodDetailDelegate {
    let food: FoodModel
}

struct FoodDetailView: View {

    @State var presenter: FoodDetailPresenter

    let delegate: FoodDetailDelegate

    var body: some View {
        List {
            if let url = delegate.food.imageURL {
                imageSection(url: url)
            }
            macroNutrientSection
            essentialMacroMineralsSection
            essentialTraceMineralsSection
            fatSolubleVitaminsSection
            waterSolubleVitaminsSection
            bioactiveCompoundsSection
            dateCreatedSection
            if let authorId =  delegate.food.authorId {
                authorSection(id: authorId)
            }
        }
        .navigationTitle(delegate.food.name)
        .navigationSubtitle(delegate.food.description ?? "")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .toolbar {
            toolbarContent
        }
    }

    private func imageSection(url: String) -> some View {
        Section {
            ImageLoaderView(urlString: url, resizingMode: .fill)
                .frame(maxWidth: .infinity, minHeight: 180)
        }
        .removeListRowFormatting()
    }

    private func descriptionSection(description: String) -> some View {
        Section(header: Text("Description")) {
            Text(description)
                .font(.body)
        }
    }

    private var macroNutrientSection: some View {
        Section {
            // Primary macronutrients
            rowItem(label: "Calories", value: delegate.food.calories, unit: "kcal")

            // Macronutrient composition
            rowItem(label: "Protein", value: delegate.food.protein, unit: "g")
            rowItem(label: "Carbohydrates", value: delegate.food.carbs, unit: "g")
            rowItem(label: "Total Fat", value: delegate.food.fatTotal, unit: "g")

            // Fat breakdown
            if delegate.food.fatSaturated != nil || delegate.food.fatMonounsaturated != nil || delegate.food.fatPolyunsaturated != nil {
                rowItem(label: "Saturated Fat", value: delegate.food.fatSaturated, unit: "g")
                rowItem(label: "Monounsaturated Fat", value: delegate.food.fatMonounsaturated, unit: "g")
                rowItem(label: "Polyunsaturated Fat", value: delegate.food.fatPolyunsaturated, unit: "g")
            }

            // Carbohydrate breakdown
            if delegate.food.fiber != nil || delegate.food.sugar != nil {
                rowItem(label: "Dietary Fiber", value: delegate.food.fiber, unit: "g")
                rowItem(label: "Total Sugars", value: delegate.food.sugar, unit: "g")
            }
        } header: {
            Text("Nutrition Information (per 100g)")
        }
    }

    private var essentialMacroMineralsSection: some View {
        Section {
            // Essential Macrominerals - Required in larger amounts
            rowItem(label: "Calcium", value: delegate.food.calciumMg, unit: "mg")
            rowItem(label: "Phosphorus", value: delegate.food.phosphorusMg, unit: "mg")
            rowItem(label: "Magnesium", value: delegate.food.magnesiumMg, unit: "mg")
            rowItem(label: "Sodium", value: delegate.food.sodiumMg, unit: "mg")
            rowItem(label: "Potassium", value: delegate.food.potassiumMg, unit: "mg")
            rowItem(label: "Chloride", value: delegate.food.chlorideMg, unit: "mg")
        } header: {
            Text("Essential Macrominerals (per 100g)")
        }
    }

    private var essentialTraceMineralsSection: some View {
        Section {
            // Essential Trace Minerals - Required in smaller amounts
            rowItem(label: "Iron", value: delegate.food.ironMg, unit: "mg")
            rowItem(label: "Zinc", value: delegate.food.zincMg, unit: "mg")
            rowItem(label: "Copper", value: delegate.food.copperMg, unit: "mg")
            rowItem(label: "Manganese", value: delegate.food.manganeseMg, unit: "mg")
            rowItem(label: "Iodine", value: delegate.food.iodineMcg, unit: "μg")
            rowItem(label: "Selenium", value: delegate.food.seleniumMcg, unit: "μg")
            rowItem(label: "Molybdenum", value: delegate.food.molybdenumMcg, unit: "μg")
            rowItem(label: "Chromium", value: delegate.food.chromiumMcg, unit: "μg")
        } header: {
            Text("Essential Trace Minerals (per 100g)")
        }
    }

    private var fatSolubleVitaminsSection: some View {
        Section {
            // Fat-Soluble Vitamins - A, D, E, K
            rowItem(label: "Vitamin A", value: delegate.food.vitaminAMcg, unit: " mcg RAE")
            rowItem(label: "Vitamin D", value: delegate.food.vitaminDMcg, unit: " mcg")
            rowItem(label: "Vitamin E", value: delegate.food.vitaminEMg, unit: " mg α-tocopherol")
            rowItem(label: "Vitamin K", value: delegate.food.vitaminKMcg, unit: " mcg")
        } header: {
            Text("Fat-Soluble Vitamins (per 100g)")
        }
    }

    private var waterSolubleVitaminsSection: some View {
        Section {
            // Water-Soluble Vitamins - B-Complex & C
            rowItem(label: "Thiamin - B1", value: delegate.food.thiaminMg, unit: " mg")
            rowItem(label: "Riboflavin - B2", value: delegate.food.riboflavinMg, unit: " mg")
            rowItem(label: "Niacin - B3", value: delegate.food.niacinMg, unit: " mg NE")
            rowItem(label: "Pantothenic Acid - B5", value: delegate.food.pantothenicAcidMg, unit: " mg")
            rowItem(label: "Vitamin B6", value: delegate.food.vitaminB6Mg, unit: " mg")
            rowItem(label: "Folate - B9", value: delegate.food.folateMcg, unit: " mcg DFE")
            rowItem(label: "Vitamin B12", value: delegate.food.vitaminB12Mcg, unit: " mcg")
            rowItem(label: "Biotin - B7", value: delegate.food.biotinMcg, unit: " mcg")
            rowItem(label: "Vitamin C", value: delegate.food.vitaminCMg, unit: " mg")
        } header: {
            Text("Water-Soluble Vitamins (per 100g)")
        }
    }

    private var bioactiveCompoundsSection: some View {
        Section {
            // Bioactive Compounds
            rowItem(label: "Cholesterol", value: delegate.food.cholesterolMg, unit: " mg")
            rowItem(label: "Caffeine", value: delegate.food.caffeineMg, unit: " mg")
        } header: {
            Text("Bioactive Compounds (per 100g)")
        }
    }

    private func rowItem(label: String, value: Double?, unit: String? = nil) -> some View {
        HStack {
            Text(label)
            Spacer()
            if let value = value {
                Text(value.formatted() + " " + (unit ?? ""))
            } else {
                Text("-")
            }
        }
    }

    private var dateCreatedSection: some View {
        Section(header: Text("Date Created")) {
            Text(delegate.food.dateCreated.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private func authorSection(id: String) -> some View {
        Section(header: Text("Author ID")) {
            Text(id)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if DEBUG || MOCK
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
            }
            .accessibilityLabel("Developer settings")
        }
        #endif

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onFavouritePressed(delegate: delegate)
            } label: {
                Image(systemName: presenter.isFavourited ? "heart.fill" : "heart")
            }
            .accessibilityLabel(presenter.isFavourited ? String(localized: "Remove from favourites") : String(localized: "Add to favourites"))
        }

        if presenter.canDelete(food: delegate.food) {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        presenter.showDeleteConfirmation(food: delegate.food)
                    } label: {
                        Label("Delete Food", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(presenter.isDeleting)
                .accessibilityLabel("Food options")
            }
        }
    }
}

extension CoreBuilder {
    func foodDetailView(router: AnyRouter, delegate: FoodDetailDelegate) -> some View {
        FoodDetailView(
            presenter: FoodDetailPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showFoodDetailView(delegate: FoodDetailDelegate) {
        router.showScreen(.sheet) { router in
            builder.foodDetailView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.foodDetailView(
            router: router,
            delegate: FoodDetailDelegate(
                food: FoodModel.mocks[0]
            )
        )
    }
    
}
