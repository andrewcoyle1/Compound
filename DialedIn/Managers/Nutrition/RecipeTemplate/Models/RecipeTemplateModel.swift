//
//  RecipeTemplate.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2025.
//

import Foundation

struct RecipeTemplateModel: DataSyncModelProtocol, SearchListItem {
    var id: String {
        recipeId
    }

    let recipeId: String
    let authorId: String?
    let name: String
    let description: String?
    private(set) var imageURL: String?
    let dateCreated: Date
    let dateModified: Date
    var ingredients: [RecipeIngredientModel]
    let clickCount: Int?
    let bookmarkCount: Int?
    let favouriteCount: Int?
    let servingQuantity: Double
    let totalWeight: Double?
    let preparationSteps: [String]
    let prepTimeMins: Double?
    let cookTimeMins: Double?
    let sourceURL: String?

    init(
        id: String,
        authorId: String,
        name: String,
        description: String? = nil,
        imageURL: String? = nil,
        dateCreated: Date,
        dateModified: Date,
        ingredients: [RecipeIngredientModel] = [],
        clickCount: Int? = 0,
        bookmarkCount: Int? = 0,
        favouriteCount: Int? = 0,
        servingQuantity: Double = 1,
        totalWeight: Double? = nil,
        preparationSteps: [String] = [],
        prepTimeMins: Double? = nil,
        cookTimeMins: Double? = nil,
        sourceURL: String? = nil
    ) {
        self.recipeId = id
        self.authorId = authorId
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.ingredients = ingredients
        self.clickCount = clickCount
        self.bookmarkCount = bookmarkCount
        self.favouriteCount = favouriteCount
        self.servingQuantity = servingQuantity
        self.totalWeight = totalWeight
        self.preparationSteps = preparationSteps
        self.prepTimeMins = prepTimeMins
        self.cookTimeMins = cookTimeMins
        self.sourceURL = sourceURL
    }
    
    mutating func updateImageURL(imageUrl: String) {
        self.imageURL = imageUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case authorId = "author_id"
        case name = "name"
        case description = "description"
        case imageURL = "image_url"
        case dateCreated = "date_created"
        case dateModified = "date_modified"
        case ingredients = "ingredients"
        case clickCount = "click_count"
        case bookmarkCount = "bookmark_count"
        case favouriteCount = "favourite_count"
        case servingQuantity = "serving_quantity"
        case totalWeight = "total_weight"
        case preparationSteps = "preparation_steps"
        case prepTimeMins = "prep_time_mins"
        case cookTimeMins = "cook_time_mins"
        case sourceURL = "source_url"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipeId = try container.decode(String.self, forKey: .recipeId)
        authorId = try container.decodeIfPresent(String.self, forKey: .authorId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        dateModified = try container.decode(Date.self, forKey: .dateModified)
        ingredients = try container.decodeIfPresent([RecipeIngredientModel].self, forKey: .ingredients) ?? []
        clickCount = try container.decodeIfPresent(Int.self, forKey: .clickCount)
        bookmarkCount = try container.decodeIfPresent(Int.self, forKey: .bookmarkCount)
        favouriteCount = try container.decodeIfPresent(Int.self, forKey: .favouriteCount)
        servingQuantity = try container.decodeIfPresent(Double.self, forKey: .servingQuantity) ?? 1
        totalWeight = try container.decodeIfPresent(Double.self, forKey: .totalWeight)
        preparationSteps = try container.decodeIfPresent([String].self, forKey: .preparationSteps) ?? []
        prepTimeMins = try container.decodeIfPresent(Double.self, forKey: .prepTimeMins)
        cookTimeMins = try container.decodeIfPresent(Double.self, forKey: .cookTimeMins)
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "recipe_\(CodingKeys.recipeId.rawValue)": recipeId,
            "recipe_\(CodingKeys.authorId.rawValue)": authorId,
            "recipe_\(CodingKeys.name.rawValue)": name,
            "recipe_\(CodingKeys.description.rawValue)": description,
            "recipe_\(CodingKeys.imageURL.rawValue)": imageURL,
            "recipe_\(CodingKeys.dateCreated.rawValue)": dateCreated,
            "recipe_\(CodingKeys.dateModified.rawValue)": dateModified,
            "recipe_\(CodingKeys.ingredients.rawValue)": ingredients.map { $0.ingredient.ingredientId },
            "recipe_\(CodingKeys.clickCount.rawValue)": clickCount,
            "recipe_\(CodingKeys.bookmarkCount.rawValue)": bookmarkCount,
            "recipe_\(CodingKeys.favouriteCount.rawValue)": favouriteCount
        ]
        return dict.compactMapValues { $0 }
    }
    
    static func newRecipeTemplate(
        name: String,
        authorId: String,
        description: String? = nil,
        imageURL: String? = nil,
        ingredients: [RecipeIngredientModel] = [],
        clickCount: Int? = 0,
        bookmarkCount: Int? = 0,
        favouriteCount: Int? = 0,
        servingQuantity: Double = 1,
        totalWeight: Double? = nil,
        preparationSteps: [String] = [],
        prepTimeMins: Double? = nil,
        cookTimeMins: Double? = nil,
        sourceURL: String? = nil
    ) -> Self {
        RecipeTemplateModel(
            id: UUID().uuidString,
            authorId: authorId,
            name: name,
            description: description,
            imageURL: imageURL,
            dateCreated: .now,
            dateModified: .now,
            ingredients: ingredients,
            clickCount: clickCount,
            bookmarkCount: bookmarkCount,
            favouriteCount: favouriteCount,
            servingQuantity: servingQuantity,
            totalWeight: totalWeight,
            preparationSteps: preparationSteps,
            prepTimeMins: prepTimeMins,
            cookTimeMins: cookTimeMins,
            sourceURL: sourceURL
        )
    }
    
    static var mock: RecipeTemplateModel {
        mocks[0]
    }

    static var mocks: [RecipeTemplateModel] {
        [mockMargheritaPizza, mockProteinPancakes, mockVeganBuddhaBowl]
    }

    static var mockMargheritaPizza: RecipeTemplateModel {
        let pizzaDough = FoodModel(
            ingredientId: "ing1", authorId: "user1", name: "Pizza Dough",
            description: "Homemade classic pizza dough.", measurementMethod: .weight,
            nutrients: [
                .calories: 250, .protein: 7, .carbs: 50, .fatTotal: 2, .fiber: 2, .sugar: 1,
                .sodiumMg: 400, .potassiumMg: 80, .calciumMg: 20, .ironMg: 1.5,
                .vitaminCMg: 0, .vitaminDMcg: 0, .magnesiumMg: 10, .zincMg: 0.5
            ],
            portionWeight: 200, weightPortionSize: 1, weightPortionName: "base",
            dateCreated: Date(timeIntervalSinceNow: -86400 * 10),
            dateModified: Date(timeIntervalSinceNow: -86400 * 5), clickCount: 5
        )
        let mozzarella = FoodModel(
            ingredientId: "ing2", authorId: "user1", name: "Fresh Mozzarella",
            description: "Creamy mozzarella cheese.", measurementMethod: .weight,
            nutrients: [
                .calories: 80, .protein: 6, .carbs: 1, .fatTotal: 6, .fiber: 0, .sugar: 1,
                .sodiumMg: 150, .potassiumMg: 30, .calciumMg: 120, .ironMg: 0.1,
                .vitaminCMg: 0, .vitaminDMcg: 0.2, .magnesiumMg: 8, .zincMg: 0.4
            ],
            portionWeight: 125, weightPortionSize: 1, weightPortionName: "ball",
            dateCreated: Date(timeIntervalSinceNow: -86400 * 10),
            dateModified: Date(timeIntervalSinceNow: -86400 * 5), clickCount: 3
        )
        let tomatoSauce = FoodModel(
            ingredientId: "ing3", authorId: "user1", name: "Tomato Sauce",
            description: "Rich tomato sauce with herbs.", measurementMethod: .volume,
            nutrients: [
                .calories: 30, .protein: 1, .carbs: 6, .fatTotal: 0, .fiber: 1, .sugar: 4,
                .sodiumMg: 200, .potassiumMg: 180, .calciumMg: 15, .ironMg: 0.3,
                .vitaminCMg: 8, .vitaminDMcg: 0, .magnesiumMg: 6, .zincMg: 0.1
            ],
            portionVolume: 150, volumePortionSize: 150, volumePortionName: "ml",
            dateCreated: Date(timeIntervalSinceNow: -86400 * 10),
            dateModified: Date(timeIntervalSinceNow: -86400 * 5), clickCount: 2
        )
        return RecipeTemplateModel(
            id: "recipe1", authorId: "user1", name: "Classic Margherita Pizza",
            description: "A simple and delicious pizza with fresh mozzarella, tomatoes, and basil.",
            imageURL: Constants.randomImage,
            dateCreated: Date(timeIntervalSinceNow: -86400 * 10),
            dateModified: Date(timeIntervalSinceNow: -86400 * 5),
            ingredients: [
                RecipeIngredientModel(ingredient: pizzaDough, amount: 200, unit: .grams),
                RecipeIngredientModel(ingredient: mozzarella, amount: 100, unit: .grams),
                RecipeIngredientModel(ingredient: tomatoSauce, amount: 150, unit: .milliliters)
            ],
            bookmarkCount: 22, favouriteCount: 8
        )
    }

    static var mockProteinPancakes: RecipeTemplateModel {
        let oatFlour = FoodModel(
            ingredientId: "ing4", authorId: "user2", name: "Oat Flour",
            description: "Ground oats for a healthy base.", measurementMethod: .weight,
            nutrients: [
                .calories: 150, .protein: 5, .carbs: 27, .fatTotal: 3, .fiber: 4, .sugar: 1,
                .sodiumMg: 2, .potassiumMg: 120, .calciumMg: 20, .ironMg: 1.2,
                .vitaminCMg: 0, .vitaminDMcg: 0, .magnesiumMg: 40, .zincMg: 1
            ],
            portionWeight: 80, weightPortionSize: 0.75, weightPortionName: "cup",
            dateCreated: Date(timeIntervalSinceNow: -86400 * 20),
            dateModified: Date(timeIntervalSinceNow: -86400 * 15), clickCount: 4
        )
        let wheyProtein = FoodModel(
            ingredientId: "ing5", authorId: "user2", name: "Whey Protein",
            description: "Vanilla flavored whey protein powder.", measurementMethod: .weight,
            nutrients: [
                .calories: 120, .protein: 24, .carbs: 3, .fatTotal: 1, .fiber: 0, .sugar: 2,
                .sodiumMg: 50, .potassiumMg: 100, .calciumMg: 130, .ironMg: 0.2,
                .vitaminCMg: 0, .vitaminDMcg: 0, .magnesiumMg: 10, .zincMg: 0.2
            ],
            portionWeight: 30, weightPortionSize: 1, weightPortionName: "scoop",
            dateCreated: Date(timeIntervalSinceNow: -86400 * 20),
            dateModified: Date(timeIntervalSinceNow: -86400 * 15), clickCount: 6
        )
        return RecipeTemplateModel(
            id: "recipe2", authorId: "user2", name: "Protein Pancakes",
            description: "Fluffy pancakes packed with protein for a healthy breakfast.",
            dateCreated: Date(timeIntervalSinceNow: -86400 * 20),
            dateModified: Date(timeIntervalSinceNow: -86400 * 15),
            ingredients: [
                RecipeIngredientModel(ingredient: oatFlour, amount: 80, unit: .grams),
                RecipeIngredientModel(ingredient: wheyProtein, amount: 30, unit: .grams)
            ],
            bookmarkCount: 15, favouriteCount: 4
        )
    }

    static var mockVeganBuddhaBowl: RecipeTemplateModel {
        let quinoa = FoodModel(
            ingredientId: "ing6", authorId: "user3", name: "Quinoa",
            description: "Fluffy cooked quinoa.", measurementMethod: .weight,
            nutrients: [
                .calories: 120, .protein: 4, .carbs: 21, .fatTotal: 2, .fiber: 3, .sugar: 0,
                .sodiumMg: 7, .potassiumMg: 120, .calciumMg: 15, .ironMg: 1.5,
                .vitaminCMg: 0, .vitaminDMcg: 0, .magnesiumMg: 30, .zincMg: 1
            ],
            portionWeight: 150, weightPortionSize: 0.75, weightPortionName: "cup",
            dateCreated: Date(timeIntervalSinceNow: -86400 * 5),
            dateModified: Date(timeIntervalSinceNow: -86400 * 2), clickCount: 7
        )
        let chickpeas = FoodModel(
            ingredientId: "ing7", authorId: "user3", name: "Chickpeas",
            description: "Roasted chickpeas for protein.", measurementMethod: .weight,
            nutrients: [
                .calories: 140, .protein: 7, .carbs: 23, .fatTotal: 2, .fiber: 6, .sugar: 2,
                .sodiumMg: 120, .potassiumMg: 180, .calciumMg: 40, .ironMg: 2,
                .vitaminCMg: 1, .vitaminDMcg: 0, .magnesiumMg: 25, .zincMg: 1.3
            ],
            portionWeight: 100, weightPortionSize: 0.5, weightPortionName: "cup",
            dateCreated: Date(timeIntervalSinceNow: -86400 * 5),
            dateModified: Date(timeIntervalSinceNow: -86400 * 2), clickCount: 5
        )
        let spinach = FoodModel(
            ingredientId: "ing8", authorId: "user3", name: "Spinach",
            description: "Fresh baby spinach leaves.", measurementMethod: .weight,
            nutrients: [
                .calories: 20, .protein: 2, .carbs: 3, .fatTotal: 0, .fiber: 2, .sugar: 0,
                .sodiumMg: 65, .potassiumMg: 167, .calciumMg: 30, .ironMg: 0.8,
                .vitaminCMg: 14, .vitaminDMcg: 0, .magnesiumMg: 24, .zincMg: 0.2
            ],
            portionWeight: 50, weightPortionSize: 1, weightPortionName: "handful",
            dateCreated: Date(timeIntervalSinceNow: -86400 * 5),
            dateModified: Date(timeIntervalSinceNow: -86400 * 2), clickCount: 2
        )
        return RecipeTemplateModel(
            id: "recipe3", authorId: "user3", name: "Vegan Buddha Bowl",
            description: "A nourishing bowl with grains, greens, and plant protein.",
            imageURL: Constants.randomImage,
            dateCreated: Date(timeIntervalSinceNow: -86400 * 5),
            dateModified: Date(timeIntervalSinceNow: -86400 * 2),
            ingredients: [
                RecipeIngredientModel(ingredient: quinoa, amount: 150, unit: .grams),
                RecipeIngredientModel(ingredient: chickpeas, amount: 100, unit: .grams),
                RecipeIngredientModel(ingredient: spinach, amount: 50, unit: .grams)
            ],
            bookmarkCount: 30, favouriteCount: 10
        )
    }
}

extension RecipeTemplateModel: Hashable {

    static func == (lhs: RecipeTemplateModel, rhs: RecipeTemplateModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension RecipeTemplateModel: FoodItem {

    var calories: Double? { NutritionScaling.perServing(self)[.calories] }
    var protein: Double? { NutritionScaling.perServing(self)[.protein] }
    var carbs: Double? { NutritionScaling.perServing(self)[.carbs] }
    var fats: Double? { NutritionScaling.perServing(self)[.fatTotal] }
    var portionQuantityCalculated: Double? { 1 }
    var portionNameCalculated: String? { "serving" }
}
