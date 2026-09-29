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
            return String(format: "%g", base)
        case .editItem(let item):
            return String(format: "%g", item.amount)
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
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    TextField("0", text: $presenter.amountText)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                    if case .addFood(let food) = delegate.mode, !food.servingUnits.isEmpty {
                        ServingUnitPicker(baseLabel: delegate.unit, units: food.servingUnits, selection: $presenter.selectedUnit)
                            .padding(.trailing, 8)
                    } else {
                        Text(presenter.unitLabel(delegate: delegate))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    presenter.onConfirmPressed(delegate: delegate)
                } label: {
                    Text("Add")
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private var headerSection: some View {
        Section {
            HStack(alignment: .bottom) {
                MacroTotalHeader(value: presenter.calories, label: "Calories")
                MacroTotalHeader(value: presenter.protein, label: "Protein", colour: .proteinColor)
                MacroTotalHeader(value: presenter.fat, label: "Fat", colour: .fatColor)
                MacroTotalHeader(value: presenter.carbs, label: "Carbs", colour: .carbsColor)
            }
            .listRowInsets(.bottom, 0)
        }
        .listRowSeparator(.hidden)
        .listSectionMargins(.top, 0)
    }

    @ViewBuilder
    private func breakdownSection(macro: Macros) -> some View {
        let keys = macro.details.filter { presenter.scaledValue(for: $0) > 0 }
        if !keys.isEmpty {
            Section {
                ForEach(keys, id: \.rawValue) { key in
                    HStack {
                        Text(key.name)
                        Spacer()
                        Text(String(format: "%.1f %@", presenter.scaledValue(for: key), key.unit))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("\(macro.name) Breakdown")
            }
        }
    }
}

private struct MacroTotalHeader: View {

    var value: Double
    let label: String
    var colour: Color = .blue

    var body: some View {
        VStack {
            Text(String(format: "%g", value))
                .font(.title2)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
