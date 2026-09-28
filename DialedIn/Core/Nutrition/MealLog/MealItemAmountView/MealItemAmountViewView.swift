import SwiftUI

enum MealItemAmountViewMode {
    case addFood(FoodModel)
    case editItem(MealItemModel)
}

struct MealItemAmountViewDelegate {
    let mode: MealItemAmountViewMode
    let onConfirm: (MealItemModel) -> Void

    var eventParameters: [String: Any]? { nil }

    var displayName: String {
        switch mode {
        case .addFood(let food): return food.name
        case .editItem(let item): return item.displayName
        }
    }

    var initialAmountText: String {
        switch mode {
        case .addFood(let food):
            let base = food.portionGramsCalculated ?? food.portionMillilitersCalculated ?? 100
            return base.formatted(.number.grouping(.never))
        case .editItem(let item):
            return item.amount.formatted(.number.grouping(.never))
        }
    }

    var unit: String {
        switch mode {
        case .addFood(let food):
            return food.measurementMethod == .volume ? String(localized: "ml") : String(localized: "g")
        case .editItem(let item):
            return item.unit
        }
    }

    /// Logging a new food and correcting a logged one are different jobs, so they get different
    /// verbs.
    var confirmTitle: String {
        switch mode {
        case .addFood: return String(localized: "Log")
        case .editItem: return String(localized: "Save")
        }
    }

    var unitNutrients: NutrientMap {
        switch mode {
        case .addFood(let food):
            return food.nutrients
        case .editItem(let item):
            guard item.amount > 0 else { return NutrientMap() }
            return item.nutrients.mapValues { $0 / item.amount }
        }
    }
}

struct MealItemAmountViewView: View {

    @State var presenter: MealItemAmountViewPresenter
    let delegate: MealItemAmountViewDelegate

    var body: some View {
        List {
            headerSection
            amountSection
            ForEach(Macros.allCases, id: \.self) { macro in
                breakdownSection(macro: macro)
            }
        }
        .navigationTitle(delegate.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(delegate.confirmTitle, role: .confirm) {
                    presenter.onConfirmPressed(delegate: delegate)
                }
                .disabled(presenter.amountValue <= 0)
            }
        }
    }

    private var headerSection: some View {
        Section {
            HStack(alignment: .top) {
                Stat(value: Format.kcal(presenter.calories), label: String(localized: "Calories"), alignment: .center)
                    .frame(maxWidth: .infinity)
                Stat(value: Format.grams(presenter.protein), label: String(localized: "Protein"), alignment: .center)
                    .frame(maxWidth: .infinity)
                Stat(value: Format.grams(presenter.fat), label: String(localized: "Fat"), alignment: .center)
                    .frame(maxWidth: .infinity)
                Stat(value: Format.grams(presenter.carbs), label: String(localized: "Carbs"), alignment: .center)
                    .frame(maxWidth: .infinity)
            }
        }
        .listRowSeparator(.hidden)
        .listSectionMargins(.top, 0)
    }

    private var amountSection: some View {
        Section("Amount") {
            HStack {
                TextField("0", text: $presenter.amountText)
                    .keyboardType(.decimalPad)
                if case .addFood(let food) = delegate.mode, !food.servingUnits.isEmpty {
                    ServingUnitPicker(baseLabel: delegate.unit, units: food.servingUnits, selection: $presenter.selectedUnit)
                } else {
                    Text(presenter.unitLabel(delegate: delegate))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func breakdownSection(macro: Macros) -> some View {
        let keys = macro.details.filter { presenter.scaledValue(for: $0) > 0 }
        if !keys.isEmpty {
            Section {
                ForEach(keys, id: \.rawValue) { key in
                    LabeledContent(key.name, value: NutrientAmount.format(presenter.scaledValue(for: key), unit: key.unit))
                }
            } header: {
                Text("\(macro.name) Breakdown")
            }
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = MealItemAmountViewDelegate(
        mode: .addFood(FoodModel.mock),
        onConfirm: { _ in }
    )

    return RouterView { router in
        builder.mealItemAmountViewView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func mealItemAmountViewView(router: AnyRouter, delegate: MealItemAmountViewDelegate) -> some View {
        MealItemAmountViewView(
            presenter: MealItemAmountViewPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showMealItemAmountViewView(delegate: MealItemAmountViewDelegate) {
        router.showScreen(.push) { router in
            builder.mealItemAmountViewView(router: router, delegate: delegate)
        }
    }

}
