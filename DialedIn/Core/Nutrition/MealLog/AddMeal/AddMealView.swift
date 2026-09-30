//
//  AddMeal.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/10/2025.
//

import SwiftUI

struct AddMealDelegate {
    let mealLog: MealLogModel
}

struct AddMealView: View {

    @State var presenter: AddMealPresenter

    let delegate: AddMealDelegate

    var body: some View {
        List {
            yourPlateSection
            nutritionSection
            if presenter.showAllNutrients {
                ForEach(Macros.allCases, id: \.self) { category in
                    breakdownSection(for: category)
                }
            }
            ListRowToggle(title: String(localized: "Show all nutrients"), systemImage: Symbol.nutrition, isOn: $presenter.showAllNutrients)
        }
        .navigationTitle("Add Meal")
//        .navigationSubtitle("\(presenter.mealLog.date.formatted(date: .numeric, time: .shortened))")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presenter.isEditingMealTime) {
            mealTimeSheet
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .onChange(of: presenter.nutritionScope) {
            presenter.onNutritionScopeChanged()
        }
        .toolbar {
            toolbarContent
        }
        .bottomCTA {
            CallToActionButton(isLoading: presenter.isSaving) {
                presenter.saveMeal()
            } label: {
                Text("Log")
            }
            .disabled(presenter.mealLog.items.isEmpty)
        }
    }

    /// A native sheet, because the picker edits the presenter's meal through a binding.
    private var mealTimeSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Logged at",
                    selection: Binding(
                        get: { presenter.mealLog.date },
                        set: { presenter.updateMealTime($0) }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .navigationTitle("Meal Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { presenter.onMealTimeCancelled() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { presenter.isEditingMealTime = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var yourPlateSection: some View {
        Section {
            if presenter.mealLog.items.isEmpty {
                ContentUnavailableView {
                    Label("Your plate is empty", systemImage: Symbol.meal)
                } description: {
                    Text("Add foods using Search, Scan or AI.")
                } actions: {
                    Button("Add") {
                        presenter.onShowPickerPressed()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ForEach(presenter.mealLog.items) { mealItem in
                    plateRow(mealItem)
                }
                ListRowButton(title: String(localized: "Add Food"), systemImage: Symbol.add, accessory: .none) {
                    presenter.onShowPickerPressed()
                }
            }
        } header: {
            Text("Your Plate")
        }
    }

    private func plateRow(_ mealItem: MealItemModel) -> some View {
        ListRow(
            title: mealItem.displayName,
            subtitle: mealItem.macroSummary,
            accessory: .value(mealItem.formattedAmount)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                presenter.onDeleteMealItem(mealItem)
            } label: {
                Label("Delete", systemImage: Symbol.delete)
            }
            .accessibilityLabel("Delete \(mealItem.displayName)")
            Button {
                presenter.onEditMealItem(mealItem)
            } label: {
                Label("Edit", systemImage: Symbol.edit)
            }
            .accessibilityLabel("Edit \(mealItem.displayName)")

        }
        // The same action for anyone who cannot swipe.
        .contextMenu {
            Button {
                presenter.onEditMealItem(mealItem)
            } label: {
                Image(systemName: Symbol.edit)
            }
            .accessibilityLabel("Edit \(mealItem.displayName)")
            Button(role: .destructive) {
                presenter.onDeleteMealItem(mealItem)
            } label: {
                Label("Delete", systemImage: Symbol.delete)
            }
        }
    }

    /// Not tappable, so no chevrons.
    private var nutritionSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 100)), count: 2)) {
                macroCard(
                    title: String(localized: "Calories"),
                    value: presenter.displayCalories.formatted(.number.precision(.fractionLength(0))),
                    unit: "kcal",
                    symbol: Symbol.calories,
                    color: .calories,
                    current: presenter.displayCalories,
                    target: presenter.targetCalories
                )
                macroCard(
                    title: String(localized: "Protein"),
                    value: presenter.displayProtein.formatted(.number.precision(.fractionLength(1))),
                    unit: "g",
                    symbol: Symbol.protein,
                    color: .protein,
                    current: presenter.displayProtein,
                    target: presenter.targetProtein
                )
                macroCard(
                    title: String(localized: "Fat"),
                    value: presenter.displayFat.formatted(.number.precision(.fractionLength(1))),
                    unit: "g",
                    symbol: Symbol.fat,
                    color: .fat,
                    current: presenter.displayFat,
                    target: presenter.targetFat
                )
                macroCard(
                    title: String(localized: "Carbs"),
                    value: presenter.displayCarbs.formatted(.number.precision(.fractionLength(1))),
                    unit: "g",
                    symbol: Symbol.carbs,
                    color: .carbs,
                    current: presenter.displayCarbs,
                    target: presenter.targetCarbs
                )
            }
            .removeListRowFormatting()
        } header: {
            HStack {
                Text("Nutrition")
                Spacer()
                Picker("Scope", selection: $presenter.nutritionScope) {
                    ForEach(NutritionScope.allCases) { scope in
                        Text(scope.title)
                            .tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func macroCard(title: String, value: String, unit: String, symbol: String, color: Color, current: Double, target: Double) -> some View {
        AnalyticsCard(
            title: title,
            subtitle: presenter.scopeLabel,
            value: value,
            unit: unit,
            systemImage: symbol,
            themeColor: color,
            showsChevron: false
        ) {
            MacroProgressChart(
                current: current,
                target: target,
                maxValue: max(target * 1.2, current + 1),
                color: color
            )
        }
    }

    /// One section per nutrient category, driven by `Macros.details`.
    ///
    /// This replaces six hand-written sections that were byte-for-byte identical: every one of them
    /// showed the same four hardcoded cards ("791 kcal in plate", a half-filled bar), so "Carb
    /// Breakdown" did not show carbs and none of the numbers came from the plate.
    ///
    /// Values only, no progress bars. The diet plan sets targets for the four macros and nothing
    /// else, so a bar for saturated fat or selenium would have to invent the target it fills — which
    /// is the problem these sections already had.
    @ViewBuilder
    private func breakdownSection(for category: Macros) -> some View {
        Section {
            let nutrients = presenter.breakdown(for: category)
            if nutrients.isEmpty {
                Text("None of the foods on this plate record \(category.name.lowercased()) data.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(nutrients) { nutrient in
                    LabeledContent(nutrient.name, value: presenter.formatted(nutrient))
                }
            }
        } header: {
            Text(category.name)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(role: .close) {
                presenter.dismissScreen()
            }
        }

//        ToolbarSpacer(.flexible, placement: .topBarLeading)
        ToolbarItem(placement: .title) {
            Button {
                presenter.onEditMealTimePressed()
            } label: {
                    Text(presenter.mealLog.date.formatted(date: .numeric, time: .shortened))
                    .underline()
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Change meal time")
        }
    }
}

extension CoreBuilder {
    func addMealView(router: AnyRouter, delegate: AddMealDelegate) -> some View {
        AddMealView(
            presenter: AddMealPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                ),
                delegate: delegate
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showAddMealView(delegate: AddMealDelegate) {
        router.showScreen(.fullScreenCover) { router in
            builder.addMealView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = AddMealDelegate(mealLog: MealLogModel.mock)
    RouterView { router in
        builder.addMealView(router: router, delegate: delegate)
    }
    
}
