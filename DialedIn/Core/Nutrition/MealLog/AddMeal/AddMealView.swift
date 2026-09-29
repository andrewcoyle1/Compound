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
            CustomToggleView(symbolName: "carrot", title: String(localized: "Show all nutrients"), subtitle: nil, bool: $presenter.showAllNutrients)
        }
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
        .toolbar {
            toolbarContent
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    presenter.saveMeal()
                } label: {
                    Text("Log Foods")
                        .padding(8)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glassProminent)
                .disabled(presenter.mealLog.items.isEmpty)
            }
            .padding(.horizontal)
        }
    }

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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presenter.isEditingMealTime = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var yourPlateSection: some View {
        Section {
            if presenter.mealLog.items.isEmpty {
                CustomLabelButtonView(symbolName: "info", title: String(localized: "Your plate is empty"), subtitle: String(localized: "Add foods using Search, Scan or AI.")) {
                    Button {
                        presenter.onShowPickerPressed()
                    } label: {
                        Text("Add")
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ForEach(presenter.mealLog.items) { mealItem in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mealItem.displayName)
                                .font(.subheadline)
                            HStack(spacing: 4) {
                                Text("\(Int(mealItem.calories ?? 0)) kcal")
                                Text("·")
                                Text(String(format: "%.1f P", mealItem.proteinGrams ?? 0))
                                Text("·")
                                Text(String(format: "%.1f F", mealItem.fatGrams ?? 0))
                                Text("·")
                                Text(String(format: "%.1f C", mealItem.carbGrams ?? 0))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "%g %@", mealItem.amount, mealItem.unit))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                presenter.onEditMealItem(mealItem)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .accessibilityLabel("Edit meal item")
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            guard let index = presenter.mealLog.items.firstIndex(of: mealItem) else { return }
                            presenter.mealLog.items.remove(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Your Plate")
        }
    }
    
    private var nutritionSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 100)), count: 2)) {
                AnalyticsCard(
                    title: String(localized: "Calories"),
                    subtitle: String(localized: "\(String(describing: Int(presenter.displayCalories))) kcal \(presenter.scopeLabel)"),
                    subsubtitle: "",
                    subsubsubtitle: "") {
                        MacroProgressChart(
                            current: presenter.displayCalories,
                            target: presenter.targetCalories,
                            maxValue: max(presenter.targetCalories * 1.2, presenter.displayCalories + 1),
                            color: .blue)
                    }
                AnalyticsCard(
                    title: String(localized: "Protein"),
                    subtitle: String(localized: "\(presenter.displayProtein.formatted(.number.precision(.fractionLength(1)))) g \(presenter.scopeLabel)"),
                    subsubtitle: "",
                    subsubsubtitle: "") {
                        MacroProgressChart(
                            current: presenter.displayProtein,
                            target: presenter.targetProtein,
                            maxValue: max(presenter.targetProtein * 1.2, presenter.displayProtein + 1),
                            color: .proteinColor)
                    }
                AnalyticsCard(
                    title: String(localized: "Fat"),
                    subtitle: String(localized: "\(presenter.displayFat.formatted(.number.precision(.fractionLength(1)))) g \(presenter.scopeLabel)"),
                    subsubtitle: "",
                    subsubsubtitle: "") {
                        MacroProgressChart(
                            current: presenter.displayFat,
                            target: presenter.targetFat,
                            maxValue: max(presenter.targetFat * 1.2, presenter.displayFat + 1),
                            color: .fatColor)
                    }
                AnalyticsCard(
                    title: String(localized: "Carbs"),
                    subtitle: String(localized: "\(presenter.displayCarbs.formatted(.number.precision(.fractionLength(1)))) g \(presenter.scopeLabel)"),
                    subsubtitle: "",
                    subsubsubtitle: "") {
                        MacroProgressChart(
                            current: presenter.displayCarbs,
                            target: presenter.targetCarbs,
                            maxValue: max(presenter.targetCarbs * 1.2, presenter.displayCarbs + 1),
                            color: .carbsColor)
                    }
            }
            .removeListRowFormatting()
        } header: {
            HStack {
                Text("Nutrition")
                Spacer()
                Picker("", selection: $presenter.nutritionScope) {
                    ForEach(NutritionScope.allCases) { scope in
                        Text(scope.rawValue.capitalized)
                            .tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
            }
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
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(nutrients) { nutrient in
                    MetricRow(label: nutrient.name, value: presenter.formatted(nutrient))
                }
            }
        } header: {
            Text(category.name)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.dismissScreen()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
        }

        ToolbarSpacer(.flexible, placement: .topBarLeading)
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.isEditingMealTime = true
            } label: {
                VStack {
                    Text(presenter.mealLog.date.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                    Text(presenter.mealLog.date.formatted(date: .numeric, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Change meal time")
        }
        ToolbarSpacer(.flexible, placement: .topBarLeading)

        // A readout, not an action — it was previously a Button that did nothing when tapped.
        ToolbarItem(placement: .topBarLeading) {
            Text(presenter.calorieLabel)
                .font(.subheadline)
                .accessibilityLabel("\(presenter.calorieLabel) calories \(presenter.scopeLabel)")
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack {
                cartView
                Button {
                    presenter.onShowPickerPressed()
                } label: {
                    Image(systemName: "chevron.up")

                }
                .accessibilityLabel("Show food picker")
            }
            .frame(maxWidth: .infinity)

        }
    }
    
    private var cartView: some View {
        HStack {
            Image(systemName: "fork.knife")
            mealItemImagesSection
            Spacer()
        }
        .padding(.leading, 8)
    }
    
    private var mealItemImagesSection: some View {
        HStack(spacing: -10) {
            ForEach(presenter.mealLog.items.prefix(5)) { mealItem in
                mealItemCircle(mealItem: mealItem)
            }
        }
    }

    @ViewBuilder
    private func mealItemCircle(mealItem: MealItemModel) -> some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .secondarySystemBackground))

            ImageLoaderView(
                urlString: "SplashScreen",
                resizingMode: .fit,
                clipShape: AnyShape(Circle())
            )
        }
        .frame(width: 38, height: 38)
        .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
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
