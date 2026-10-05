import SwiftUI

@Observable
@MainActor
class MealItemAmountViewPresenter {

    private let interactor: MealItemAmountViewInteractor
    private let router: MealItemAmountViewRouter
    private let onConfirm: (MealItemModel) -> Void
    private let unitNutrients: NutrientMap

    var amountText: String

    init(interactor: MealItemAmountViewInteractor, router: MealItemAmountViewRouter, delegate: MealItemAmountViewDelegate) {
        self.interactor = interactor
        self.router = router
        self.amountText = delegate.item.amount.formatted(.number.grouping(.never))
        self.unitNutrients = delegate.unitNutrients
        self.onConfirm = delegate.onConfirm
    }

    /// The corrected amount. Sanitised for the reason given on
    /// `IngredientAmountPresenter.amountValue` — this one is the worse of the pair, because the
    /// amount and the nutrients scaled from it are written straight onto the meal item.
    var amountValue: Double { .enteredAmount(amountText) }

    /// The stored figures are already divided back to one unit, so the amount is the scale itself.
    func scaledValue(for key: NutrientKey) -> Double {
        (unitNutrients[key] ?? 0) * amountValue
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
        let existing = delegate.item
        let ratio = existing.amount > 0 ? amountValue / existing.amount : 0
        let item = MealItemModel(
            itemId: existing.itemId,
            sourceType: existing.sourceType,
            sourceId: existing.sourceId,
            displayName: existing.displayName,
            amount: amountValue,
            unit: existing.unit,
            resolvedGrams: existing.resolvedGrams.map { $0 * ratio },
            resolvedMilliliters: existing.resolvedMilliliters.map { $0 * ratio },
            nutrients: unitNutrients.mapValues { $0 * amountValue }
        )
        interactor.playHaptic(option: .success)
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
