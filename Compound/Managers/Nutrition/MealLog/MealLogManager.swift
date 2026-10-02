//
//  MealLogManager.swift
//  Compound
//
//  Created by Andrew Coyle on 13/10/2025.
//

import SwiftUI

@Observable
@MainActor
class MealLogManager {

    private let draftMealLogPersistence: any LocalDocumentPersistence<MealLogModel>
    private let mealLogSyncEngine: CollectionSyncEngine<MealLogModel>

    #if canImport(HealthKit)
    private let healthKit: HealthKitNutritionService?
    private var healthKitTask: Task<Void, Never>?
    private var isHealthKitImportRunning = false
    private var isHealthKitImportRequested = false
    #endif

    // UI state for draft/edit flows
    var draftMeal: MealLogModel?

    /// Compound's own log wins: a day with a meal logged here leaves out the day's Apple Health
    /// total, so the same food is not counted twice. Decided here rather than when importing,
    /// because the import can run before the listener has delivered the day's meals.
    var userMeals: [MealLogModel] {
        let meals = mealLogSyncEngine.currentCollection
        let loggedDays = Set(meals.filter { !$0.isHealthKitImport }.map(\.dayKey))
        return meals.filter { !$0.isHealthKitImport || !loggedDays.contains($0.dayKey) }
    }

    init(
        draftMealLogPersistence: any LocalDocumentPersistence<MealLogModel>,
        mealLogSyncEngine: CollectionSyncEngine<MealLogModel>,
        healthKitService: (any HealthKitNutritionService)? = nil
    ) {
        self.draftMealLogPersistence = draftMealLogPersistence
        self.mealLogSyncEngine = mealLogSyncEngine
        #if canImport(HealthKit)
        self.healthKit = healthKitService
        #endif
        self.draftMeal = try? draftMealLogPersistence.getDocument(managerKey: Keys.draftMealLogManagerKey)

    }

    // MARK: - Lifecycle

    /// - Parameter importSince: food in Apple Health before this, usually the account's creation
    ///   date, is not imported. A year back when nil.
    func signIn(userId: String, importSince: Date? = nil) async {
        await mealLogSyncEngine.startListening { query in
            query.where("author_id", isEqualTo: userId)
        }
        #if canImport(HealthKit)
        startHealthKitImport(userId: userId, since: importSince)
        #endif
    }

    func signOut() {
        #if canImport(HealthKit)
        healthKitTask?.cancel()
        healthKitTask = nil
        #endif
        mealLogSyncEngine.stopListening()
    }

    // MARK: - High-level API

    func updateDraftMeal(_ draftMeal: MealLogModel) throws {
        try draftMealLogPersistence.saveDocument(managerKey: Keys.draftMealLogManagerKey, draftMeal)
        self.draftMeal = draftMeal
    }
    
    func deleteDraftMeal() throws {
        try self.clearDraftMeal()
    }

    private func clearDraftMeal() throws {
        try draftMealLogPersistence.saveDocument(managerKey: Keys.draftMealLogManagerKey, nil)
        self.draftMeal = nil

    }
    
    func saveMeal(_ meal: MealLogModel) async throws {
        try await mealLogSyncEngine.saveDocument(meal)
    }

    func deleteMeal(id: String) async throws {
        try await mealLogSyncEngine.deleteDocument(id: id)
    }

    func getMeals(for dayKey: String) -> [MealLogModel] {
        userMeals.filter { $0.dayKey == dayKey }
    }

    func getMeals(startDayKey: String, endDayKey: String) -> [MealLogModel] {
        userMeals.filter { $0.dayKey >= startDayKey && $0.dayKey <= endDayKey }
    }

    func getDailyTotals(dayKey: String) -> DailyMacroTarget {
        let meals = getMeals(for: dayKey)
        let totals = meals.reduce((cal: 0.0, protein: 0.0, carbs: 0.0, fats: 0.0)) { acc, meal in
            (acc.cal + meal.totalCalories,
             acc.protein + meal.totalProteinGrams,
             acc.carbs + meal.totalCarbGrams,
             acc.fats + meal.totalFatGrams)
        }
        return DailyMacroTarget(
            calories: totals.cal,
            proteinGrams: totals.protein,
            carbGrams: totals.carbs,
            fatGrams: totals.fats
        )
    }

    #if canImport(HealthKit)
    // MARK: - HealthKit Import

    /// Imports what changed in Apple Health now, then again whenever Health reports a change,
    /// until sign-out. Call again after access is granted: queries started without it see nothing.
    /// `fromScratch` drops the anchor and recounts every day; only days whose totals differ are
    /// written.
    func startHealthKitImport(userId: String, since: Date?, fromScratch: Bool = false) {
        guard let healthKit else { return }
        if fromScratch { UserDefaults.standard.removeObject(forKey: Self.anchorKey(userId)) }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: since ?? calendar.date(byAdding: .year, value: -1, to: .now) ?? .now)
        healthKitTask?.cancel()
        healthKitTask = Task { [weak self] in
            await self?.importHealthKitChanges(userId: userId, since: start)
            for await _ in healthKit.changeNotifications() {
                await self?.importHealthKitChanges(userId: userId, since: start)
            }
        }
    }

    /// One run at a time, each in a task of its own so a restart cannot cut it off before its
    /// anchor is stored. See `StepsManager.importHealthKitChanges`.
    func importHealthKitChanges(userId: String, since start: Date) async {
        guard !isHealthKitImportRunning else {
            isHealthKitImportRequested = true
            return
        }
        isHealthKitImportRunning = true
        defer { isHealthKitImportRunning = false }
        repeat {
            isHealthKitImportRequested = false
            await Task { try? await self.importChanges(userId: userId, since: start) }.value
        } while isHealthKitImportRequested
    }

    private static func anchorKey(_ userId: String) -> String {
        "healthkit.nutrition.anchor.\(userId)"
    }

    /// Fetches only what changed since the stored anchor, then rewrites the entry of each day it
    /// touched. The anchor is stored only once every write has succeeded, so a failure is retried.
    private func importChanges(userId: String, since start: Date) async throws {
        guard let healthKit else { return }
        let anchorKey = Self.anchorKey(userId)
        let storedAnchor = UserDefaults.standard.data(forKey: anchorKey)
        let changes = try await healthKit.changes(after: storedAnchor, since: start)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let first = changes.hasDeletions ? start : changes.changedDays.min()
        let last = changes.hasDeletions ? today : changes.changedDays.max()
        if let first, let last, let end = calendar.date(byAdding: .day, value: 1, to: last) {
            let totals = try await healthKit.dailyTotals(from: first, to: end)
            let days = changes.hasDeletions ? Set(totals.keys).union(healthKitDays(from: first)) : changes.changedDays
            // Every imported entry, including those `userMeals` hides behind a meal logged here:
            // the total is kept current so it is right again if those meals are deleted.
            let imported = Dictionary(
                mealLogSyncEngine.currentCollection.filter(\.isHealthKitImport).map { ($0.mealId, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            for day in days.sorted() {
                let id = MealLogModel.healthKitMealId(dayKey: day.dayKey)
                let existing = imported[id]
                let nutrients = totals[day] ?? NutrientMap()
                if nutrients == NutrientMap() {
                    if existing != nil { try await mealLogSyncEngine.deleteDocument(id: id) }
                } else if existing?.totalNutrients != nutrients {
                    try await mealLogSyncEngine.saveDocument(Self.healthKitMeal(id: id, userId: userId, day: day, nutrients: nutrients))
                }
            }
        }

        // Without read access HealthKit returns nothing rather than an error, and an anchor
        // stored then would skip the history once access is granted. So the first anchor is
        // kept only once Health has handed over something.
        if storedAnchor != nil || !changes.changedDays.isEmpty {
            UserDefaults.standard.set(changes.anchor, forKey: anchorKey)
        }
    }

    /// Days already holding an imported entry, which a deletion may have changed.
    private func healthKitDays(from start: Date) -> [Date] {
        mealLogSyncEngine.currentCollection
            .filter { $0.isHealthKitImport && $0.date >= start }
            .map { Calendar.current.startOfDay(for: $0.date) }
    }

    /// One quick-add item carrying the day's totals: it resolves to nothing in the food library,
    /// so the daily breakdown skips it while the totals, and the expenditure estimate, count it.
    private static func healthKitMeal(id: String, userId: String, day: Date, nutrients: NutrientMap) -> MealLogModel {
        MealLogModel(
            mealId: id,
            authorId: userId,
            dayKey: day.dayKey,
            date: day,
            items: [MealItemModel(
                itemId: id,
                sourceType: .quickAdd,
                sourceId: id,
                displayName: "Apple Health",
                amount: 1,
                unit: "serving",
                nutrients: nutrients
            )]
        )
    }
    #endif
}

extension CoreInteractor {
    // MARK: MealLogManager

    var userMeals: [MealLogModel] {
        mealLogManager.userMeals
    }

    var draftMeal: MealLogModel? {
        mealLogManager.draftMeal
    }
    
    func updateDraftMeal(_ draftMeal: MealLogModel) throws {
        try mealLogManager.updateDraftMeal(draftMeal)
    }
    
    func saveMeal(_ meal: MealLogModel) async throws {
        try await mealLogManager.saveMeal(meal)
    }
    
    func deleteDraftMeal() throws {
        try mealLogManager.deleteDraftMeal()
    }

    func addMeal(_ meal: MealLogModel) async throws {
        try await mealLogManager.saveMeal(meal)
        requestReviewIfEarned(.foodLogged(
            daysInARow: ReviewMoment.daysInARow(endingOn: .now, loggedDays: userMeals.map(\.date) + [meal.date])
        ))
    }

    func deleteMealAndSync(id: String, dayKey: String, authorId: String) async throws {
        try await mealLogManager.deleteMeal(id: id)
    }

    func getMeals(for dayKey: String) throws -> [MealLogModel] {
        mealLogManager.getMeals(for: dayKey)
    }

    func getMeals(startDayKey: String, endDayKey: String) throws -> [MealLogModel] {
        mealLogManager.getMeals(startDayKey: startDayKey, endDayKey: endDayKey)
    }

    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
        mealLogManager.getDailyTotals(dayKey: dayKey)
    }

    func getDailyTotals(startDayKey: String, endDayKey: String) throws -> [(dayKey: String, totals: DailyMacroTarget)] {
        guard let startDate = Date(dayKey: startDayKey), let endDate = Date(dayKey: endDayKey), startDate <= endDate else {
            return []
        }
        let keys = Date.dayKeys(from: startDate, to: endDate)
        return keys.map { key in
            (dayKey: key, totals: mealLogManager.getDailyTotals(dayKey: key))
        }
    }

    /// Restarts the import so it runs with whatever access the person has just granted.
    func syncNutritionFromHealthKit() async {
        #if canImport(HealthKit)
        guard let userId else { return }
        mealLogManager.startHealthKitImport(userId: userId, since: currentUser?.creationDate)
        #endif
    }

    func getDailyNutritionBreakdown(dayKey: String) throws -> DailyNutritionBreakdown {
        let meals = mealLogManager.getMeals(for: dayKey)
        var breakdown = DailyNutritionBreakdown()
        for meal in meals {
            for item in meal.items {
                if item.sourceType == .ingredient {
                    if let ingredient = foods.first(where: { $0.id == item.sourceId }) {
                        let scale = ((item.resolvedGrams ?? item.resolvedMilliliters) ?? 0) / 100.0
                        addIngredientToBreakdown(ingredient, scale: scale, into: &breakdown)
                    }
                } else if item.sourceType == .recipe {
                    if let recipe = userRecipeTemplates.first(where: { $0.id == item.sourceId }) {
                        let recipeTotals = aggregateRecipeNutrients(recipe: recipe)
                        let scale = item.amount
                        addRecipeTotalsToBreakdown(recipeTotals, scale: scale, into: &breakdown)
                    }
                }
            }
        }
        if let fiber = breakdown.fiberGrams {
            let carbs = mealLogManager.getDailyTotals(dayKey: dayKey).carbGrams
            breakdown.netCarbsGrams = max(0, carbs - fiber)
        }
        return breakdown
    }

    func getDailyNutritionBreakdown(startDayKey: String, endDayKey: String) throws -> [(dayKey: String, breakdown: DailyNutritionBreakdown)] {
        guard let startDate = Date(dayKey: startDayKey), let endDate = Date(dayKey: endDayKey), startDate <= endDate else {
            return []
        }
        let keys = Date.dayKeys(from: startDate, to: endDate)
        return keys.map { key in
            (dayKey: key, breakdown: (try? getDailyNutritionBreakdown(dayKey: key)) ?? DailyNutritionBreakdown.empty)
        }
    }

    private func addIngredientToBreakdown(_ ingredient: FoodModel, scale: Double, into breakdown: inout DailyNutritionBreakdown) {
        func add(_ value: Double?, to keyPath: inout Double?) {
            guard let value, value > 0 else { return }
            keyPath = (keyPath ?? 0) + value * scale
        }
        add(ingredient.fiber, to: &breakdown.fiberGrams)
        add(ingredient.sugar, to: &breakdown.sugarGrams)
        add(ingredient.fatSaturated, to: &breakdown.fatSaturatedGrams)
        add(ingredient.fatMonounsaturated, to: &breakdown.fatMonounsaturatedGrams)
        add(ingredient.fatPolyunsaturated, to: &breakdown.fatPolyunsaturatedGrams)
        add(ingredient.sodiumMg, to: &breakdown.sodiumMg)
        add(ingredient.potassiumMg, to: &breakdown.potassiumMg)
        add(ingredient.calciumMg, to: &breakdown.calciumMg)
        add(ingredient.ironMg, to: &breakdown.ironMg)
        add(ingredient.magnesiumMg, to: &breakdown.magnesiumMg)
        add(ingredient.zincMg, to: &breakdown.zincMg)
        add(ingredient.copperMg, to: &breakdown.copperMg)
        add(ingredient.manganeseMg, to: &breakdown.manganeseMg)
        add(ingredient.phosphorusMg, to: &breakdown.phosphorusMg)
        add(ingredient.seleniumMcg, to: &breakdown.seleniumMcg)
        add(ingredient.vitaminAMcg, to: &breakdown.vitaminAMcg)
        add(ingredient.vitaminB6Mg, to: &breakdown.vitaminB6Mg)
        add(ingredient.vitaminB12Mcg, to: &breakdown.vitaminB12Mcg)
        add(ingredient.vitaminCMg, to: &breakdown.vitaminCMg)
        add(ingredient.vitaminDMcg, to: &breakdown.vitaminDMcg)
        add(ingredient.vitaminEMg, to: &breakdown.vitaminEMg)
        add(ingredient.vitaminKMcg, to: &breakdown.vitaminKMcg)
        add(ingredient.thiaminMg, to: &breakdown.thiaminMg)
        add(ingredient.riboflavinMg, to: &breakdown.riboflavinMg)
        add(ingredient.niacinMg, to: &breakdown.niacinMg)
        add(ingredient.pantothenicAcidMg, to: &breakdown.pantothenicAcidMg)
        add(ingredient.folateMcg, to: &breakdown.folateMcg)
        add(ingredient.caffeineMg, to: &breakdown.caffeineMg)
        add(ingredient.cholesterolMg, to: &breakdown.cholesterolMg)
    }

    private struct RecipeNutrientTotals {
        var fiberGrams: Double = 0
        var sugarGrams: Double = 0
        var fatSaturatedGrams: Double = 0
        var fatMonounsaturatedGrams: Double = 0
        var fatPolyunsaturatedGrams: Double = 0
        var sodiumMg: Double = 0
        var potassiumMg: Double = 0
        var calciumMg: Double = 0
        var ironMg: Double = 0
        var magnesiumMg: Double = 0
        var zincMg: Double = 0
        var copperMg: Double = 0
        var manganeseMg: Double = 0
        var phosphorusMg: Double = 0
        var seleniumMcg: Double = 0
        var vitaminAMcg: Double = 0
        var vitaminB6Mg: Double = 0
        var vitaminB12Mcg: Double = 0
        var vitaminCMg: Double = 0
        var vitaminDMcg: Double = 0
        var vitaminEMg: Double = 0
        var vitaminKMcg: Double = 0
        var thiaminMg: Double = 0
        var riboflavinMg: Double = 0
        var niacinMg: Double = 0
        var pantothenicAcidMg: Double = 0
        var folateMcg: Double = 0
        var caffeineMg: Double = 0
        var cholesterolMg: Double = 0
    }

    private func aggregateRecipeNutrients(recipe: RecipeTemplateModel) -> RecipeNutrientTotals {
        var totals = RecipeNutrientTotals()
        for ringredient in recipe.ingredients {
            let grams: Double
            switch ringredient.unit {
            case .grams: grams = ringredient.amount
            case .milliliters: grams = ringredient.amount
            case .units: grams = ringredient.amount * 100
            }
            let scale = grams / 100.0
            addScaledIngredientNutrients(ringredient.ingredient, scale: scale, into: &totals)
        }
        return totals
    }

    private func addScaledIngredientNutrients(_ ingredient: FoodModel, scale: Double, into totals: inout RecipeNutrientTotals) {
        addScaled(ingredient.fiber, to: &totals.fiberGrams, scale: scale)
        addScaled(ingredient.sugar, to: &totals.sugarGrams, scale: scale)
        addScaled(ingredient.fatSaturated, to: &totals.fatSaturatedGrams, scale: scale)
        addScaled(ingredient.fatMonounsaturated, to: &totals.fatMonounsaturatedGrams, scale: scale)
        addScaled(ingredient.fatPolyunsaturated, to: &totals.fatPolyunsaturatedGrams, scale: scale)
        addScaled(ingredient.sodiumMg, to: &totals.sodiumMg, scale: scale)
        addScaled(ingredient.potassiumMg, to: &totals.potassiumMg, scale: scale)
        addScaled(ingredient.calciumMg, to: &totals.calciumMg, scale: scale)
        addScaled(ingredient.ironMg, to: &totals.ironMg, scale: scale)
        addScaled(ingredient.magnesiumMg, to: &totals.magnesiumMg, scale: scale)
        addScaled(ingredient.zincMg, to: &totals.zincMg, scale: scale)
        addScaled(ingredient.copperMg, to: &totals.copperMg, scale: scale)
        addScaled(ingredient.manganeseMg, to: &totals.manganeseMg, scale: scale)
        addScaled(ingredient.phosphorusMg, to: &totals.phosphorusMg, scale: scale)
        addScaled(ingredient.seleniumMcg, to: &totals.seleniumMcg, scale: scale)
        addScaled(ingredient.vitaminAMcg, to: &totals.vitaminAMcg, scale: scale)
        addScaled(ingredient.vitaminB6Mg, to: &totals.vitaminB6Mg, scale: scale)
        addScaled(ingredient.vitaminB12Mcg, to: &totals.vitaminB12Mcg, scale: scale)
        addScaled(ingredient.vitaminCMg, to: &totals.vitaminCMg, scale: scale)
        addScaled(ingredient.vitaminDMcg, to: &totals.vitaminDMcg, scale: scale)
        addScaled(ingredient.vitaminEMg, to: &totals.vitaminEMg, scale: scale)
        addScaled(ingredient.vitaminKMcg, to: &totals.vitaminKMcg, scale: scale)
        addScaled(ingredient.thiaminMg, to: &totals.thiaminMg, scale: scale)
        addScaled(ingredient.riboflavinMg, to: &totals.riboflavinMg, scale: scale)
        addScaled(ingredient.niacinMg, to: &totals.niacinMg, scale: scale)
        addScaled(ingredient.pantothenicAcidMg, to: &totals.pantothenicAcidMg, scale: scale)
        addScaled(ingredient.folateMcg, to: &totals.folateMcg, scale: scale)
        addScaled(ingredient.caffeineMg, to: &totals.caffeineMg, scale: scale)
        addScaled(ingredient.cholesterolMg, to: &totals.cholesterolMg, scale: scale)
    }

    private func addScaled(_ value: Double?, to total: inout Double, scale: Double) {
        guard let value else { return }
        total += value * scale
    }

    private func addRecipeTotalsToBreakdown(_ totals: RecipeNutrientTotals, scale: Double, into breakdown: inout DailyNutritionBreakdown) {
        func add(_ value: Double, to keyPath: inout Double?) {
            guard value > 0 else { return }
            keyPath = (keyPath ?? 0) + value * scale
        }
        add(totals.fiberGrams, to: &breakdown.fiberGrams)
        add(totals.sugarGrams, to: &breakdown.sugarGrams)
        add(totals.fatSaturatedGrams, to: &breakdown.fatSaturatedGrams)
        add(totals.fatMonounsaturatedGrams, to: &breakdown.fatMonounsaturatedGrams)
        add(totals.fatPolyunsaturatedGrams, to: &breakdown.fatPolyunsaturatedGrams)
        add(totals.sodiumMg, to: &breakdown.sodiumMg)
        add(totals.potassiumMg, to: &breakdown.potassiumMg)
        add(totals.calciumMg, to: &breakdown.calciumMg)
        add(totals.ironMg, to: &breakdown.ironMg)
        add(totals.magnesiumMg, to: &breakdown.magnesiumMg)
        add(totals.zincMg, to: &breakdown.zincMg)
        add(totals.copperMg, to: &breakdown.copperMg)
        add(totals.manganeseMg, to: &breakdown.manganeseMg)
        add(totals.phosphorusMg, to: &breakdown.phosphorusMg)
        add(totals.seleniumMcg, to: &breakdown.seleniumMcg)
        add(totals.vitaminAMcg, to: &breakdown.vitaminAMcg)
        add(totals.vitaminB6Mg, to: &breakdown.vitaminB6Mg)
        add(totals.vitaminB12Mcg, to: &breakdown.vitaminB12Mcg)
        add(totals.vitaminCMg, to: &breakdown.vitaminCMg)
        add(totals.vitaminDMcg, to: &breakdown.vitaminDMcg)
        add(totals.vitaminEMg, to: &breakdown.vitaminEMg)
        add(totals.vitaminKMcg, to: &breakdown.vitaminKMcg)
        add(totals.thiaminMg, to: &breakdown.thiaminMg)
        add(totals.riboflavinMg, to: &breakdown.riboflavinMg)
        add(totals.niacinMg, to: &breakdown.niacinMg)
        add(totals.pantothenicAcidMg, to: &breakdown.pantothenicAcidMg)
        add(totals.folateMcg, to: &breakdown.folateMcg)
        add(totals.caffeineMg, to: &breakdown.caffeineMg)
        add(totals.cholesterolMg, to: &breakdown.cholesterolMg)
    }
}
