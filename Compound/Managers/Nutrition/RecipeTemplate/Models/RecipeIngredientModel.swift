//
//  RecipeIngredientModel.swift
//  Compound
//
//  Wrapper for an ingredient within a recipe, including amount and unit.
//

import Foundation

enum IngredientAmountUnit: String, Codable, CaseIterable, Sendable {
    case grams
    case milliliters
    case units
}

struct RecipeIngredientModel: DataSyncModelProtocol {
    var id: String { ingredient.ingredientId }
    var name: String { ingredient.name }
    var description: String? { ingredient.description }
    var imageURL: String? { ingredient.imageURL }
    let ingredient: FoodModel
    var amount: Double
    var unit: IngredientAmountUnit
    
    init(ingredient: FoodModel, amount: Double, unit: IngredientAmountUnit? = nil) {
        self.ingredient = ingredient
        self.amount = amount
        if let unit = unit {
            self.unit = unit
        } else {
            switch ingredient.measurementMethod {
            case .weight:
                self.unit = .grams
            case .volume:
                self.unit = .milliliters
            }
        }
    }
    enum CodingKeys: String, CodingKey {
        case ingredient
        case amount
        case unit
    }

    /// The stored amount is read back defensively for the same reason a stored nutrient is: both
    /// `RecipeDetailView` and `RecipeStartView` print it through `Int(_:)` from a view body, which
    /// traps on a value that is not finite or that overflows `Int` rather than printing something
    /// odd. Recipes written before the entry fields were sanitised can carry one. See
    /// `Double+EXT.swift`.
    ///
    /// An unusable amount reads as zero rather than being dropped, since unlike a nutrient the
    /// ingredient has to have some amount, and zero is what an emptied field already means.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ingredient = try container.decode(FoodModel.self, forKey: .ingredient)
        amount = try container.decode(Double.self, forKey: .amount).clamped(to: 0...Self.maximumAmount, whenNotFinite: 0)
        unit = try container.decode(IngredientAmountUnit.self, forKey: .unit)
    }

    /// One tonne of one ingredient, matching the ceiling the entry fields already impose.
    private static let maximumAmount: Double = 1_000_000

    static var mock: RecipeIngredientModel {
        mocks[0]
    }
    static let mocks: [RecipeIngredientModel] = Array(FoodModel.mocks.prefix(10)).map { RecipeIngredientModel(ingredient: $0, amount: 1) }
}
