//
//  MealLogModel.swift
//  Compound
//
//  Created by Andrew Coyle on 13/10/2025.
//

import Foundation

struct MealLogModel: DataSyncModelProtocol, Hashable {
    var id: String { mealId }
    let mealId: String
    let authorId: String
    /// yyyy-MM-dd for efficient per-day queries
    let dayKey: String
    let date: Date
    var items: [MealItemModel]
    var notes: String?

    /// Every nutrient in the meal, summed across its items — micronutrients included, since each
    /// item carries a full snapshot taken when it was logged.
    var totalNutrients: NutrientMap {
        items.reduce(NutrientMap()) { $0 + $1.nutrients }
    }

    /// Derived from the day, so a run that cannot yet see the previous run's write, or another
    /// device importing the same day, overwrites rather than duplicates.
    static func healthKitMealId(dayKey: String) -> String {
        "healthkit-nutrition-\(dayKey)"
    }

    /// The day's totals imported from Apple Health, rather than a meal logged here.
    var isHealthKitImport: Bool { mealId == Self.healthKitMealId(dayKey: dayKey) }

    var totalCalories: Double { totalNutrients[.calories] ?? 0 }
    var totalProteinGrams: Double { totalNutrients[.protein] ?? 0 }
    var totalCarbGrams: Double { totalNutrients[.carbs] ?? 0 }
    var totalFatGrams: Double { totalNutrients[.fatTotal] ?? 0 }

    init(
        mealId: String = UUID().uuidString,
        authorId: String,
        dayKey: String,
        date: Date,
        items: [MealItemModel],
        notes: String? = nil
    ) {
        self.mealId = mealId
        self.authorId = authorId
        self.dayKey = dayKey
        self.date = date
        self.items = items
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case mealId = "meal_id"
        case authorId = "author_id"
        case dayKey = "day_key"
        case date
        case items
        case notes
    }
}
