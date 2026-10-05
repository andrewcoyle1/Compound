import SwiftUI

/// Corrects the amount of a food already on a plate or in a logged meal. Adding a food goes
/// through `IngredientAmountView`; this screen's add mode was last used by the Library tab and
/// went when that moved to the same amount screen as search.
struct MealItemAmountViewDelegate {
    let item: MealItemModel
    let onConfirm: (MealItemModel) -> Void

    var eventParameters: [String: Any]? { nil }

    /// The item's figures for one of its units, which the amount typed multiplies back up.
    var unitNutrients: NutrientMap {
        guard item.amount > 0 else { return NutrientMap() }
        return item.nutrients.mapValues { $0 / item.amount }
    }
}

struct MealItemAmountViewView: View {

    @State var presenter: MealItemAmountViewPresenter
    let delegate: MealItemAmountViewDelegate

    var body: some View {
        Form {
            headerSection
            amountSection
            ForEach(Macros.allCases, id: \.self) { macro in
                breakdownSection(macro: macro)
            }
        }
        .navigationTitle(delegate.item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", role: .confirm) {
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
                Text(delegate.item.unit)
                    .foregroundStyle(.secondary)
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
        item: MealItemModel.mocks[0],
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
