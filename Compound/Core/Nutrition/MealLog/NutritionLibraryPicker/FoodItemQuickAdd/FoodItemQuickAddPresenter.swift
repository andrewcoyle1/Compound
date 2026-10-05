import SwiftUI

@Observable
@MainActor
class FoodItemQuickAddPresenter {
    
    private let interactor: FoodItemQuickAddInteractor
    private let router: FoodItemQuickAddRouter
    
    var quickAddName: String = ""
    var energyValue: Double?
    var unitOfEnergy: EnergyUnit = .kcal
    
    var proteinValue: Double?
    var carbsValue: Double?
    var fatsValue: Double?
    var weightUnit: NutritionWeightUnit = .grams
    
    var alcoholValue: Double?
    
    /// Atwater factors. The macro fields can be entered in ounces, so they are converted to grams
    /// first — otherwise the sum silently under-reports by a factor of 28.
    var computedTotalEnergy: Int {
        let protein: Double = gramsValue(self.proteinValue ?? 0.0)
        let carbs: Double = gramsValue(self.carbsValue ?? 0.0)
        let fats: Double = gramsValue(self.fatsValue ?? 0.0)
        let alcohol: Double = gramsValue(self.alcoholValue ?? 0.0)
        let totalEnergy: Double = (protein * 4.0) + (carbs * 4.0) + (fats * 9.0) + (alcohol * 7.0)

        return Int(totalEnergy.rounded())
    }
    
    init(interactor: FoodItemQuickAddInteractor, router: FoodItemQuickAddRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    /// The macro sum in the unit the energy field is showing, for the footer under it. It printed
    /// the kcal figure beside whichever unit was picked, so in kilojoules it was 4.2 times low.
    var macroEnergyInSelectedUnit: Int {
        unitOfEnergy == .kjoule
            ? Int((Double(computedTotalEnergy) * Self.kilojoulesPerKilocalorie).rounded())
            : computedTotalEnergy
    }

    /// Energy in kcal, which is what `NutrientKey.calories` stores. A typed-in figure wins over the
    /// macro sum, so a user who knows the label value is not overruled by rounding in the macros.
    var resolvedCalories: Double {
        guard let energyValue, energyValue > 0 else { return Double(computedTotalEnergy) }
        return unitOfEnergy == .kjoule ? energyValue / Self.kilojoulesPerKilocalorie : energyValue
    }

    /// Nothing is worth logging without a name and some energy behind it.
    var canSubmit: Bool {
        !quickAddName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && resolvedCalories > 0
    }

    private static let kilojoulesPerKilocalorie: Double = 4.184

    func onViewAppear(delegate: FoodItemQuickAddDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: FoodItemQuickAddDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    /// Adds the typed macros to the plate being built, leaving the user in the picker's parent to
    /// keep adding. This is the same hand-back every other picker mode performs.
    func onQuickAddPressed(delegate: FoodItemQuickAddDelegate) {
        guard canSubmit else { return }
        interactor.trackEvent(event: Event.onQuickAdd(name: trimmedName))
        interactor.playHaptic(option: .success)
        delegate.onPick(quickAddItem())
        router.dismissScreen()
    }

    /// Set once Log has put the item on the plate, so a second Log after a failed save does not
    /// add it twice.
    private var hasAddedForLog = false

    /// Adds the typed macros and logs the plate; logging closes the logger with the picker in it.
    func onLogPressed(delegate: FoodItemQuickAddDelegate, onLog: () -> Void) {
        guard canSubmit else { return }
        if !hasAddedForLog {
            hasAddedForLog = true
            interactor.trackEvent(event: Event.onQuickAdd(name: trimmedName))
            delegate.onPick(quickAddItem())
        }
        onLog()
    }

    private var trimmedName: String {
        quickAddName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Unlike every other mode there is no food behind this item, so the values are absolute
    /// rather than per 100g and go through unscaled.
    private func quickAddItem() -> MealItemModel {
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .quickAdd,
            sourceId: UUID().uuidString,
            displayName: trimmedName,
            amount: 1,
            unit: "serving",
            resolvedGrams: nil,
            resolvedMilliliters: nil,
            nutrients: quickAddNutrients
        )
    }

    /// Alcohol has no `NutrientKey`, so it is folded into the calorie figure by
    /// `computedTotalEnergy` rather than stored in its own right.
    private var quickAddNutrients: NutrientMap {
        var nutrients = NutrientMap([.calories: resolvedCalories])
        if let proteinValue, proteinValue > 0 { nutrients[.protein] = gramsValue(proteinValue) }
        if let carbsValue, carbsValue > 0 { nutrients[.carbs] = gramsValue(carbsValue) }
        if let fatsValue, fatsValue > 0 { nutrients[.fatTotal] = gramsValue(fatsValue) }
        return nutrients
    }

    private func gramsValue(_ value: Double) -> Double {
        weightUnit == .ounces ? value * Self.gramsPerOunce : value
    }

    private static let gramsPerOunce: Double = 28.349523125
}

extension FoodItemQuickAddPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: FoodItemQuickAddDelegate)
        case onDisappear(delegate: FoodItemQuickAddDelegate)
        case onQuickAdd(name: String)

        var eventName: String {
            switch self {
            case .onAppear:                 return "FoodItemQuickAddView_Appear"
            case .onDisappear:              return "FoodItemQuickAddView_Disappear"
            case .onQuickAdd:               return "FoodItemQuickAddView_QuickAdd"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onQuickAdd(name: let name):
                return ["food_name": name]
            }
        }

        var type: LogType {
            .analytic
        }
    }

}
