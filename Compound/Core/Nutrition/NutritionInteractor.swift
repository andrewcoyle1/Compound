//
//  NutritionInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import Foundation

@MainActor
protocol NutritionInteractor: ReminderOfferInteractor {
    var currentUser: UserModel? { get }
    var userMeals: [MealLogModel] { get }
    var draftMeal: MealLogModel? { get }
    var currentDietPlan: DietPlan? { get }
    var userImageUrl: String? { get }
    var foodLogSettings: FoodLogSettings { get }
    var foods: [FoodModel] { get }
    var userRecipeTemplates: [RecipeTemplateModel] { get }
    func getMeals(for dayKey: String) throws -> [MealLogModel]
    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget
    func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget?
    func addMeal(_ meal: MealLogModel) async throws
    func deleteDraftMeal() throws
    func deleteMealAndSync(id: String, dayKey: String, authorId: String) async throws
    func canRequestHealthDataAuthorisation() -> Bool
    func requestHealthKitAuthorisation(for scope: HealthDataScope) async throws
    func syncNutritionFromHealthKit() async
}

extension CoreInteractor: NutritionInteractor { }
