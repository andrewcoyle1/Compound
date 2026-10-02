//
//  AddMealInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol AddMealInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var draftMeal: MealLogModel? { get }
    var currentDietPlan: DietPlan? { get }
    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget
    /// Needed for the nutrient breakdown at day scope: `getDailyTotals` carries only the four
    /// macros, so micronutrients have to come from the day's meals themselves.
    func getMeals(for dayKey: String) throws -> [MealLogModel]
    func updateDraftMeal(_ draftMeal: MealLogModel) throws
    func deleteDraftMeal() throws
    func saveMeal(_ meal: MealLogModel) async throws
}

extension CoreInteractor: AddMealInteractor { }
