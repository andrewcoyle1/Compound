import SwiftUI

@Observable
@MainActor
class FoodDefinitionPresenter {
    
    private let interactor: FoodDefinitionInteractor
    private let router: FoodDefinitionRouter
    
    var foodDefinitionOption: FoodDefinitionOption = .foodDetail
    
    var nutritionWeightUnit: NutritionWeightUnit = .grams
    var energyUnit: EnergyUnit = .kcal

    var isShowingMacros: Bool = true
    
    var energy: Double?
    var protein: Double?
    var carbs: Double?
    var fats: Double?
    var fiber: Double?
    var starch: Double?
    var sugars: Double?
    var addedSugars: Double?
    var monounsaturatedFats: Double?
    var polyunsaturatedFats: Double?
    var omega3: Double?
    var omega3Ala: Double?
    var omega3Dha: Double?
    var omega3Epa: Double?
    var omega6: Double?
    var saturatedFats: Double?
    var transFats: Double?

    var cysteine: Double?
    var histidine: Double?
    var isoleucine: Double?
    var leucine: Double?
    var lysine: Double?
    var methionine: Double?
    var phenylalinine: Double?
    var threonine: Double?
    var tryptophan: Double?
    var tyrosine: Double?
    var valine: Double?

    var b1Thiamine: Double?
    var b2Riboflavin: Double?
    var b3Niacin: Double?
    var b5PantothenicAcid: Double?
    var b6Pyridoxine: Double?
    var b12Cobalamin: Double?
    var folate: Double?
    var vitaminA: Double?
    var vitaminC: Double?
    var vitaminD: Double?
    var vitaminE: Double?
    var vitaminK: Double?

    var calcium: Double?
    var copper: Double?
    var iron: Double?
    var magnesium: Double?
    var manganese: Double?
    var phosphorus: Double?
    var potassium: Double?
    var selenium: Double?
    var sodium: Double?
    var zinc: Double?

    var alcohol: Double?
    var caffeine: Double?
    var cholesterol: Double?
    var choline: Double?
    var water: Double?
    
    init(interactor: FoodDefinitionInteractor, router: FoodDefinitionRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: FoodDefinitionDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: FoodDefinitionDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onCreatePressed(delegate: FoodDefinitionDelegate) {
        guard let userId = interactor.currentUser?.userId else { return }
        Task {
            interactor.trackEvent(event: Event.createFoodStart)
            do {
                _ = try await self.createFood(userId: userId, delegate: delegate)
                interactor.trackEvent(event: Event.createFoodSuccess)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.createFoodFail(error: error))
                // Creating is what closes this form. Silence leaves a filled-in form and a button
                // that appears to do nothing.
                router.showSimpleAlert(
                    title: String(localized: "Unable to Create Food"),
                    subtitle: "Please check your internet connection and try again."
                )
            }
        }
    }
    
    func onCreateAndAddPressed(delegate: FoodDefinitionDelegate) {
        guard let userId = interactor.currentUser?.userId else { return }
        Task {
            interactor.trackEvent(event: Event.createFoodStart)
            do {
                let food = try await self.createFood(userId: userId, delegate: delegate)
                let mealLogItem = MealItemModel(
                    itemId: UUID().uuidString,
                    sourceType: .ingredient,
                    sourceId: food.id,
                    displayName: food.name,
                    amount: 100,
                    unit: "grams"
                )
                delegate.mealItems?.wrappedValue.append(mealLogItem)
                interactor.trackEvent(event: Event.createFoodSuccess)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.createFoodFail(error: error))
                // Creating is what closes this form. Silence leaves a filled-in form and a button
                // that appears to do nothing.
                router.showSimpleAlert(
                    title: String(localized: "Unable to Create Food"),
                    subtitle: "Please check your internet connection and try again."
                )
            }
        }
    }
    
    private func createFood(userId: String, delegate: FoodDefinitionDelegate) async throws -> FoodModel {
        var nutrients = enteredNutrients()

        // Normalize to per-100g so all downstream callers work correctly
        if case .serving = delegate.nutritionDefinitionOption,
           let weight = delegate.servingWeight, weight > 0 {
            nutrients = nutrients.mapValues { $0 * (100.0 / weight) }
        }

        let ingredient = FoodModel(
            authorId: userId,
            name: delegate.name,
            brandName: delegate.brandName,
            description: nil,
            measurementMethod: .weight,
            nutrients: nutrients,
            barcode: delegate.barcode,
            servingWeight: delegate.servingWeight,
            portionSize: delegate.portionSize,
            portionName: delegate.portionName,
            portionWeight: delegate.portionWeight,
            weightPortionSize: delegate.weightPortionSize,
            weightPortionName: delegate.weightPortionName,
            portionVolume: delegate.portionVolume,
            volumePortionSize: delegate.volumePortionSize,
            volumePortionName: delegate.volumePortionName
        )
        try await interactor.saveFood(ingredient, image: delegate.image)
        return ingredient
    }
    /// Every nutrient field the user filled in, keyed for `NutrientMap`. Extracted from
    /// `createFood` so that function stays inside the body-length limit.
    private func enteredNutrients() -> NutrientMap {
        var nutrients = NutrientMap()
        func set(_ key: NutrientKey, _ value: Double?) {
            if let value { nutrients[key] = value }
        }
        set(.calories, energy)
        set(.protein, protein)
        set(.carbs, carbs)
        set(.fatTotal, fats)
        set(.fatSaturated, saturatedFats)
        set(.fatMonounsaturated, monounsaturatedFats)
        set(.fatPolyunsaturated, polyunsaturatedFats)
        set(.fiber, fiber)
        set(.sugar, sugars)
        set(.sodiumMg, sodium)
        set(.potassiumMg, potassium)
        set(.calciumMg, calcium)
        set(.ironMg, iron)
        set(.vitaminAMcg, vitaminA)
        set(.vitaminB6Mg, b6Pyridoxine)
        set(.vitaminB12Mcg, b12Cobalamin)
        set(.vitaminCMg, vitaminC)
        set(.vitaminDMcg, vitaminD)
        set(.vitaminEMg, vitaminE)
        set(.vitaminKMcg, vitaminK)
        set(.magnesiumMg, magnesium)
        set(.zincMg, zinc)
        set(.copperMg, copper)
        set(.folateMcg, folate)
        set(.niacinMg, b3Niacin)
        set(.thiaminMg, b1Thiamine)
        set(.caffeineMg, caffeine)
        set(.seleniumMcg, selenium)
        set(.manganeseMg, manganese)
        set(.phosphorusMg, phosphorus)
        set(.riboflavinMg, b2Riboflavin)
        set(.cholesterolMg, cholesterol)
        set(.pantothenicAcidMg, b5PantothenicAcid)
        set(.fatTrans, transFats)
        set(.omega3, omega3)
        set(.omega3Ala, omega3Ala)
        set(.omega3Dha, omega3Dha)
        set(.omega3Epa, omega3Epa)
        set(.omega6, omega6)
        set(.addedSugars, addedSugars)
        set(.starch, starch)
        set(.alcohol, alcohol)
        set(.water, water)
        setAminoAcids(into: &nutrients)
        return nutrients
    }

    /// The eleven amino acids, split out so `enteredNutrients` stays inside the body-length limit.
    private func setAminoAcids(into nutrients: inout NutrientMap) {
        func set(_ key: NutrientKey, _ value: Double?) {
            if let value { nutrients[key] = value }
        }
        set(.cysteine, cysteine)
        set(.histidine, histidine)
        set(.isoleucine, isoleucine)
        set(.leucine, leucine)
        set(.lysine, lysine)
        set(.methionine, methionine)
        set(.phenylalanine, phenylalinine)
        set(.threonine, threonine)
        set(.tryptophan, tryptophan)
        set(.tyrosine, tyrosine)
        set(.valine, valine)
    }
}

extension FoodDefinitionPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: FoodDefinitionDelegate)
        case onDisappear(delegate: FoodDefinitionDelegate)
        case createFoodStart
        case createFoodSuccess
        case createFoodFail(error: Error)
        
        var eventName: String {
            switch self {
            case .onAppear:             return "FoodDefinitionView_Appear"
            case .onDisappear:          return "FoodDefinitionView_Disappear"
            case .createFoodStart:      return "FoodDefinitionView_CreateFood_Start"
            case .createFoodSuccess:    return "FoodDefinitionView_CreateFood_Success"
            case .createFoodFail:       return "FoodDefinitionView_CreateFood_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .createFoodFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .createFoodFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
