//
//  ClearedFieldSaveTests.swift
//  CompoundUnitTests
//
//  A save used to be `setData(merge: true)`, which skips a nil field and merges a map key by key,
//  so a cleared value never reached Firestore and came back on the next sync. These run each
//  manager against `FirestoreSaveSemantics`, which applies a save the way Firestore does.
//

import Foundation
import Testing
@testable import Compound

@MainActor
struct ClearedFieldSaveTests {

    // MARK: - The write itself

    @Test("Test A Cleared Field Is Written As A Delete And Every Declared Field Is Replaced")
    func testWriteDeletesClearedFields() throws {
        let write = try #require(try FirestoreFieldWrite.replacing(LoggingBreak(authorId: "user-1", startDate: Date(), endDate: nil)))

        #expect((write.data["end_date"] as? FieldValue) == FieldValue.delete())
        #expect(Set(write.mergeFields) == Set(LoggingBreak.CodingKeys.allCases.map(\.stringValue)))
    }

    @Test("Test A Model That Has Not Opted In Keeps The Merge Save")
    func testOtherModelsKeepTheMerge() throws {
        #expect(try FirestoreFieldWrite.replacing(CheckInRecord(authorId: "user-1")) == nil)
    }

    // MARK: - 1. Goals

    @Test("Test Changing A Goal's Objective Leaves A Readable Goal With Only The New Objective")
    func testGoalObjectiveChange() async throws {
        let goal = WeightGoal(userId: "user-1", objective: .loseWeight, startingWeightKg: 80, targetWeightKg: 72, weeklyChangeKg: 0.5)
        let manager = GoalManager(userGoalSyncEngine: TestManagers.documentEngine(goal, firestoreSaves: true))
        try await manager.signIn(userId: "user-1")
        await TestManagers.eventually { manager.currentGoal != nil }

        try await manager.updateGoal(objective: .gainWeight, targetWeightKg: 85, weeklyChangeKg: 0.25)

        #expect(await TestManagers.eventually { manager.currentGoal?.objective == .gainWeight && manager.currentGoal?.targetWeightKg == 85 })
    }

    // MARK: - 2. Body measurements

    @Test("Test Clearing A Weigh-In Removes It And Keeps The Entry's Other Values")
    func testClearingABodyValue() async throws {
        let entry = BodyMeasurementEntry(id: "entry-1", authorId: "author-1", weightKg: 80, waistCircumference: 85, date: Date(), source: .manual, dateCreated: Date())
        let manager = BodyMeasurementsManager(
            bodyMeasurementsSyncEngine: TestManagers.collectionEngine([entry], firestoreSaves: true),
            healthKitService: MockHealthKitWeightService()
        )
        await manager.signIn(userId: "author-1")
        await TestManagers.eventually { manager.bodyMeasurements.count == 1 }

        try await manager.saveBodyMeasurement(bodyMeasurement: entry.withCleared(.weightKg))

        #expect(await TestManagers.eventually {
            manager.bodyMeasurements.first?.weightKg == nil && manager.bodyMeasurements.first?.waistCircumference == 85
        })
    }

    // MARK: - 3. Exercise and workout settings

    @Test("Test Clearing An Exercise Note And Rest Override Removes Them")
    func testClearingExerciseSettings() async throws {
        var settings = ExerciseSettingsModel(id: "bench", authorId: "author-1")
        settings.note = "Grip one finger wider"
        settings.restDurationOverride = 150
        let manager = ExerciseSettingsManager(syncEngine: TestManagers.collectionEngine([settings], firestoreSaves: true))
        await manager.signIn(userId: "author-1")
        await TestManagers.eventually { manager.allExerciseSettings.count == 1 }

        try await manager.setNote(nil, for: "bench")
        #expect(await TestManagers.eventually { manager.note(for: "bench") == nil })
        try await manager.setRestOverride(nil, for: "bench")
        #expect(await TestManagers.eventually { manager.restOverride(for: "bench") == nil })
    }

    @Test("Test Superset Rest Off And Reset Default Timers Reach The Stored Settings")
    func testClearingWorkoutSettings() async throws {
        var stored = WorkoutSettings(authorId: "author-1")
        stored.supersetTransitionRestSeconds = 30
        stored.restDurationsByExerciseType = ["compoundUpper": 180]
        stored.defaultRestDurationSeconds = 120
        let manager = WorkoutSettingsManager(workoutSettingsSyncEngine: TestManagers.documentEngine(stored, firestoreSaves: true))
        try await manager.signIn(userId: "author-1", isNewUser: false)
        await TestManagers.eventually { manager.workoutSettings.defaultRestDurationSeconds == 120 }

        var edited = manager.workoutSettings
        edited.supersetTransitionRestSeconds = nil
        edited.restDurationsByExerciseType = [:]
        try await manager.saveSettings(edited)

        #expect(await TestManagers.eventually {
            manager.workoutSettings.supersetTransitionRestSeconds == nil && manager.workoutSettings.restDurationsByExerciseType.isEmpty
        })
    }

    // MARK: - 4. Logging break and expenditure start date

    @Test("Test A Second Logging Break Opens")
    func testSecondLoggingBreakOpens() async throws {
        let ended = LoggingBreak(authorId: "user-1", startDate: Date(timeIntervalSinceNow: -20 * 86_400), endDate: Date(timeIntervalSinceNow: -10 * 86_400))
        let manager = NutritionStrategyManager(
            dayAnnotationSyncEngine: TestManagers.collectionEngine([NutritionDayAnnotation]()),
            loggingBreakSyncEngine: TestManagers.documentEngine(ended, firestoreSaves: true),
            checkInRecordSyncEngine: TestManagers.documentEngine(CheckInRecord?.none)
        )
        try await manager.signIn(userId: "user-1")
        await TestManagers.eventually { manager.loggingBreak != nil }

        try await manager.startLoggingBreak(startDate: Date(timeIntervalSinceNow: -60))

        #expect(await TestManagers.eventually { manager.openLoggingBreak() != nil })
    }

    @Test("Test Clearing The Expenditure Calculation Start Date Reaches The Stored Settings")
    func testClearingCalculationStartDate() async throws {
        var stored = NutritionStrategySettings(authorId: "user-1")
        stored.calculationStartDate = Date(timeIntervalSinceNow: -30 * 86_400)
        let manager = NutritionStrategySettingsManager(settingsSyncEngine: TestManagers.documentEngine(stored, firestoreSaves: true))
        try await manager.signIn(userId: "user-1", isNewUser: false)
        await TestManagers.eventually { manager.nutritionStrategySettings.calculationStartDate != nil }

        var edited = manager.nutritionStrategySettings
        edited.calculationStartDate = nil
        try await manager.saveSettings(edited)

        #expect(await TestManagers.eventually { manager.nutritionStrategySettings.calculationStartDate == nil })
    }

    // MARK: - 5. Foods

    @Test("Test Removing A Nutrient From A Saved Food Removes It")
    func testRemovingANutrient() async throws {
        let food = FoodModel(ingredientId: "food-1", authorId: "user-1", name: "Oats", nutrients: [.calories: 380, .protein: 13, .sodiumMg: 6])
        let manager = FoodManager(foodSyncEngine: TestManagers.collectionEngine([food], firestoreSaves: true))
        await manager.signIn()
        await TestManagers.eventually { manager.foods.count == 1 }

        try await manager.saveFood(FoodModel(ingredientId: "food-1", authorId: "user-1", name: "Oats", nutrients: [.calories: 380, .protein: 13]), image: nil)

        #expect(await TestManagers.eventually { manager.foods.first?.nutrients[.sodiumMg] == nil && manager.foods.first?.nutrients[.protein] == 13 })
    }
}

/// Documents older builds wrote, which used to fail to decode and vanish.
struct LenientDecodingTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: [String: Any]) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func goal(objective: [String: Any], weeklyChangeKg: Double) -> [String: Any] {
        ["user_id": "user-1", "goal_id": "goal-1", "objective": objective, "starting_weight_kg": 80,
         "target_weight_kg": 75, "weekly_change_kg": weeklyChangeKg, "created_at": 0, "status": "active"]
    }

    @Test("Test A Goal Holding Two Objectives Reads As The One Its Rate Fits")
    func testCorruptedGoalObjectiveRepairs() throws {
        let toMaintain = try decode(WeightGoal.self, goal(objective: ["loseWeight": [:], "maintain": [:]], weeklyChangeKg: 0))
        #expect(toMaintain.objective == .maintain)
        let fromMaintain = try decode(WeightGoal.self, goal(objective: ["maintain": [:], "gainWeight": [:]], weeklyChangeKg: 0.25))
        #expect(fromMaintain.objective == .gainWeight)
    }

    @Test("Test A Goal Holding Both Losing And Gaining Stays Unreadable")
    func testAmbiguousGoalObjectiveIsNotGuessed() {
        #expect(throws: (any Error).self) {
            try decode(WeightGoal.self, goal(objective: ["loseWeight": [:], "gainWeight": [:]], weeklyChangeKg: 0.5))
        }
    }

    @Test("Test Workout Settings Missing A Field Keep The Rest")
    func testWorkoutSettingsMissingAField() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkoutSettings(authorId: "author-1"))) as? [String: Any] ?? [:]
        json["default_rest_duration_seconds"] = 120
        json.removeValue(forKey: "keep_alive")
        json.removeValue(forKey: "previous_workout_reference")

        let decoded = try decode(WorkoutSettings.self, json)

        #expect(decoded.defaultRestDurationSeconds == 120)
        #expect(decoded.keepAlive)
        #expect(decoded.previousWorkoutReference == .sameWorkout)
    }

    @Test("Test Food Log Settings From Before The Favourites Keep The Rest")
    func testFoodLogSettingsMissingFields() throws {
        let decoded = try decode(FoodLogSettings.self, ["id": "food_log_settings", "author_id": "author-1", "show_overages": true, "start_hour": 5])

        #expect(decoded.showOverages)
        #expect(decoded.startHour == 5)
        #expect(decoded.favouriteFoodIds.isEmpty)
        #expect(!decoded.hideEmptyHours)
    }

    @Test("Test A Set Target Without A Set Type Reads As Standard")
    func testSetTargetWithoutSetType() throws {
        let decoded = try decode(SetTarget.self, ["id": "target-1", "set_number": 1, "min_reps": 8])

        #expect(decoded.setType == .standard)
        #expect(decoded.minReps == 8)
    }

    private func food(_ extra: [String: Any]) -> [String: Any] {
        ["ingredient_id": "food-1", "name": "Oats", "measurement_method": "weight", "date_created": 0, "date_modified": 0]
            .merging(extra) { $1 }
    }

    @Test("Test A Food With Only Flat Nutrient Fields Reads Them")
    func testFlatNutrientFood() throws {
        let decoded = try decode(FoodModel.self, food(["calories": 380, "fat_total": 7, "sodium_mg": 6]))

        #expect(decoded.calories == 380)
        #expect(decoded.fatTotal == 7)
        #expect(decoded.sodiumMg == 6)
    }

    @Test("Test A Food Whose Nutrients Are A Key And Value Array Reads Them")
    func testKeyValueArrayNutrientFood() throws {
        let decoded = try decode(FoodModel.self, food(["nutrients": ["calories", 380, "protein", 13]]))

        #expect(decoded.calories == 380)
        #expect(decoded.protein == 13)
    }
}
