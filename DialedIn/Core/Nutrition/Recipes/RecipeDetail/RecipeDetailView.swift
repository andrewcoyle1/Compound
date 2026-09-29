//
//  RecipeDetailView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/09/2025.
//

import SwiftUI

struct RecipeDetailView: View {

    @State var presenter: RecipeDetailPresenter

    let delegate: RecipeDetailDelegate

    var body: some View {
        List {
            if let url = delegate.recipeTemplate.imageURL {
                imageSection(url: url)
            }

            servingsSection

            Section(header: Text("Ingredients")) {
                ForEach(delegate.recipeTemplate.ingredients) { wrapper in
                    ingredientSection(wrapper: wrapper)
                }
            }
        }
        .navigationTitle(delegate.recipeTemplate.name)
        .navigationSubtitle(delegate.recipeTemplate.description ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .bottomCTA {
            CallToActionButton {
                presenter.onStartRecipePressed(recipe: delegate.recipeTemplate)
            } label: {
                Label("Start", systemImage: "play.fill")
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
    }
    
    private func imageSection(url: String) -> some View {
        Section {
            // Decorative: the recipe's name is the title right above it.
            ImageLoaderView(urlString: url, resizingMode: .fill)
                .frame(maxWidth: .infinity, minHeight: 180)
                .accessibilityHidden(true)
        }
        .removeListRowFormatting()
    }
    
    private var servingsSection: some View {
        let recipe = delegate.recipeTemplate
        let servings = presenter.servings(recipe: recipe)
        let nutrients = presenter.scaledNutrients(recipe: recipe)
        return Section {
            Stepper(
                value: Binding(get: { servings }, set: { presenter.onServingsChanged($0) }),
                in: RecipeDetailPresenter.servingsRange,
                step: RecipeDetailPresenter.servingsStep
            ) {
                Text("\(servings.formatted()) \(servings == 1 ? String(localized: "serving") : String(localized: "servings"))")
            }
            nutrientRow("Calories", nutrients[.calories], unit: "kcal")
            nutrientRow("Protein", nutrients[.protein], unit: "g")
            nutrientRow("Carbs", nutrients[.carbs], unit: "g")
            nutrientRow("Fat", nutrients[.fatTotal], unit: "g")
        } header: {
            Text("Servings")
        }
    }

    private func nutrientRow(_ title: LocalizedStringKey, _ value: Double?, unit: String) -> some View {
        LabeledContent(title, value: value.map { NutrientAmount.format($0, unit: unit) } ?? Format.placeholder)
            .monospacedDigit()
    }

    private func ingredientSection(wrapper: RecipeIngredientModel) -> some View {
        ListRow(
            title: wrapper.ingredient.name,
            subtitle: wrapper.ingredient.description.flatMap { $0.isEmpty ? nil : $0 },
            accessory: .value("\(presenter.scaledAmount(wrapper, recipe: delegate.recipeTemplate).formatted()) \(presenter.displayUnit(wrapper.unit))")
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }

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
            .accessibilityLabel(presenter.isFavourited ? String(localized: "Remove from favorites") : String(localized: "Add to favorites"))
        }

        if presenter.canDelete(recipe: delegate.recipeTemplate) {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        presenter.showDeleteConfirmation(recipe: delegate.recipeTemplate)
                    } label: {
                        Label("Delete Recipe", systemImage: Symbol.delete)
                    }
                } label: {
                    Image(systemName: Symbol.more)
                }
                .disabled(presenter.isDeleting)
                .accessibilityLabel("Recipe options")
            }
        }
    }
}

extension CoreBuilder {
    func recipeDetailView(router: AnyRouter, delegate: RecipeDetailDelegate) -> some View {
        RecipeDetailView(
            presenter: RecipeDetailPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showRecipeDetailView(delegate: RecipeDetailDelegate) {
        router.showScreen(.sheet) { router in
            builder.recipeDetailView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.recipeDetailView(router: router, delegate: RecipeDetailDelegate(recipeTemplate: .mock))
    }
    
}
