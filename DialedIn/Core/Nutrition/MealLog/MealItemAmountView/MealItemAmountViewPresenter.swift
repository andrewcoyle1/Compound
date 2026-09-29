import SwiftUI

@Observable
@MainActor
class MealItemAmountViewPresenter {

    private let interactor: MealItemAmountViewInteractor
    private let router: MealItemAmountViewRouter
    private let onConfirm: (MealItemModel) -> Void
    private let isAddFoodMode: Bool
    private let unitNutrients: NutrientMap

    var amountText: String

    init(interactor: MealItemAmountViewInteractor, router: MealItemAmountViewRouter, delegate: MealItemAmountViewDelegate) {
        self.interactor = interactor
        self.router = router
        self.amountText = delegate.initialAmountText
        self.unitNutrients = delegate.unitNutrients
        self.onConfirm = delegate.onConfirm
        if case .addFood = delegate.mode {
            self.isAddFoodMode = true
        } else {
            self.isAddFoodMode = false
        }
    }

    /// How much is being added or corrected. Sanitised for the reason given on
    /// `IngredientAmountPresenter.amountValue` — this one is the worse of the pair, because the
    /// amount and the nutrients scaled from it are written straight onto the meal item.
    var amountValue: Double { .enteredAmount(amountText) }

    /// What a new food's amount is counted in: a serving unit such as a slice, or nil for the
    /// food's grams/ml. Only offered when adding a food — an edit keeps the unit it was logged in.
    /// Changing it rewrites the amount the way `IngredientAmountPresenter.selectedUnit` does.
    var selectedUnit: ServingUnit? {
        didSet {
            guard selectedUnit != oldValue else { return }
            let previous = NutritionScaling.baseAmount(amountValue, in: oldValue)
            amountText = selectedUnit == nil ? String(format: "%g", NutritionScaling.rounded(previous)) : "1"
        }
    }

    func unitLabel(delegate: MealItemAmountViewDelegate) -> String {
        selectedUnit?.name ?? delegate.unit
    }

    private var scale: Double {
        isAddFoodMode ? NutritionScaling.baseAmount(amountValue, in: selectedUnit) / 100 : amountValue
    }

    func scaledValue(for key: NutrientKey) -> Double {
        (unitNutrients[key] ?? 0) * scale
    }

    var calories: Double { scaledValue(for: .calories) }
    var protein: Double { scaledValue(for: .protein) }
    var fat: Double { scaledValue(for: .fatTotal) }
    var carbs: Double { scaledValue(for: .carbs) }

    func onViewAppear(delegate: MealItemAmountViewDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: MealItemAmountViewDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onConfirmPressed(delegate: MealItemAmountViewDelegate) {
        let item: MealItemModel
        switch delegate.mode {
        case .addFood(let food):
            item = food.mealItem(amount: amountValue, unit: selectedUnit)
        case .editItem(let existing):
            let ratio = existing.amount > 0 ? amountValue / existing.amount : 0
            item = MealItemModel(
                itemId: existing.itemId,
                sourceType: existing.sourceType,
                sourceId: existing.sourceId,
                displayName: existing.displayName,
                amount: amountValue,
                unit: existing.unit,
                resolvedGrams: existing.resolvedGrams.map { $0 * ratio },
                resolvedMilliliters: existing.resolvedMilliliters.map { $0 * ratio },
                nutrients: unitNutrients.mapValues { $0 * scale }
            )
        }
        onConfirm(item)
        router.dismissScreen()
    }
}

extension MealItemAmountViewPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: MealItemAmountViewDelegate)
        case onDisappear(delegate: MealItemAmountViewDelegate)

        var eventName: String {
            switch self {
            case .onAppear:     return "MealItemAmountViewView_Appear"
            case .onDisappear:  return "MealItemAmountViewView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let delegate), .onDisappear(let delegate):
                return delegate.eventParameters
            }
        }

        var type: LogType {
            return .analytic
        }
    }
}
