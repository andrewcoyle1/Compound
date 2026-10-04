//
//  MealDetailView.swift
//  Compound
//
//  Created by Andrew Coyle on 17/10/2025.
//

import SwiftUI

struct MealDetailDelegate {
    let meal: MealLogModel
}

/// A read-only summary of a meal that has already been logged.
///
/// Deliberately not `AddMealView`: that screen is the in-progress plate editor, and every mutation
/// to its `mealLog` autosaves to the *draft* meal. Editing a historical entry through it would
/// overwrite whatever plate the user is currently assembling.
struct MealDetailView: View {

    @State var presenter: MealDetailPresenter

    let delegate: MealDetailDelegate

    var body: some View {
        List {
            summarySection
            itemsSection
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .bottomCTA {
            CallToActionButton {
                presenter.onLogAgainPressed(meal: delegate.meal)
            } label: {
                Text("Log Again")
            }
            .disabled(delegate.meal.items.isEmpty)
        }
    }

    private var summarySection: some View {
        Section {
            HStack(alignment: .top) {
                ForEach(presenter.macroSummary(for: delegate.meal)) { macro in
                    Stat(value: macro.value, label: macro.label, alignment: .center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, Spacing.s)
        } header: {
            Text(delegate.meal.date.formatted(date: .abbreviated, time: .shortened))
        }
    }

    @ViewBuilder
    private var itemsSection: some View {
        if delegate.meal.items.isEmpty {
            Section {
                ContentUnavailableView {
                    Label("No Items", systemImage: Symbol.meal)
                } description: {
                    Text("This meal has no items.")
                }
            }
        } else {
            Section {
                // Read-only here, so the rows carry no edit button.
                ForEach(delegate.meal.items) { item in
                    MealItemRowView(
                        item: item,
                        style: .mealDetail
                    )
                }
            } header: {
                Text("Items")
            }
            .listRowSeparator(.hidden)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(role: .destructive) {
                presenter.onDeletePressed(meal: delegate.meal)
            } label: {
                Image(systemName: Symbol.delete)
            }
            .accessibilityLabel("Delete meal")
        }
    }
}

extension CoreBuilder {
    func mealDetailView(router: AnyRouter, delegate: MealDetailDelegate) -> some View {
        MealDetailView(
            presenter: MealDetailPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showMealDetailView(delegate: MealDetailDelegate) {
        router.showScreen(.push) { router in
            builder.mealDetailView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.mealDetailView(router: router, delegate: MealDetailDelegate(meal: .mock))
    }
}
