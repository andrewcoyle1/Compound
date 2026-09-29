//
//  TestManagers.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Foundation
import Testing
@testable import DialedIn

/// Managers built the way `Dependencies` builds them for `.mock`, but with local persistence off.
///
/// Every manager now takes sync engines rather than a services struct, and a sync engine with
/// persistence on opens SwiftData storage keyed by its `managerKey` — shared between tests, and
/// left behind after them. Passing `enableLocalPersistence: false` keeps each test to the data it
/// was given.
@MainActor
enum TestManagers {

    /// A unique key per call, so two engines in the same run never read each other's storage even
    /// if persistence is switched on.
    static func key(_ name: String = "test") -> String {
        "\(name)-\(UUID().uuidString)"
    }

    static func collectionEngine<T: DataSyncModelProtocol>(
        _ collection: [T],
        key name: String = "collection"
    ) -> CollectionSyncEngine<T> {
        CollectionSyncEngine<T>(
            remote: MockRemoteCollectionService(collection: collection),
            managerKey: key(name),
            enableLocalPersistence: false
        )
    }

    static func documentEngine<T: DataSyncModelProtocol>(
        _ document: T?,
        key name: String = "document"
    ) -> DocumentSyncEngine<T> {
        DocumentSyncEngine<T>(
            remote: MockRemoteDocumentService(document: document),
            managerKey: key(name),
            enableLocalPersistence: false
        )
    }

    static func userManager(
        user: UserModel?,
        following: [UserModel] = [],
        privateSettings: PrivateUserSettings? = nil
    ) -> UserManager {
        UserManager(
            queryService: MockUserQueryService(),
            userSyncEngine: documentEngine(user, key: "user"),
            followingUsersSyncEngine: collectionEngine(following, key: "following-users"),
            privateSettingsSyncEngine: documentEngine(privateSettings, key: "private-user-settings")
        )
    }

    /// Waits for `condition` to hold, polling until `timeout`. Returns whether it ever did.
    ///
    /// A sync engine applies a write when its listener next emits, which happens on its own task
    /// after the write returns — so `currentCollection` is not up to date the instant `saveDocument`
    /// does. Polling keeps that from being either a fixed sleep or a race.
    ///
    /// The timeout is generous because it only costs anything when a test is already failing: the
    /// wait returns the moment the condition holds. At three seconds a busy machine — several
    /// simulator clones running at once — timed thirty of these out in one run, every one of them
    /// a listener that had simply not emitted yet. Twenty seconds is the window the auto-dismiss
    /// test in `AppShellPresenterTests` already needed for the same reason.
    @discardableResult
    /// The default ceiling is deliberately far above what any condition here needs. Locally these
    /// resolve in milliseconds, but CI runs the whole suite in parallel on about three cores, where
    /// a condition that is merely slow rather than wrong has repeatedly outlived a 20s ceiling
    /// (GitHub Actions runs 35778253166 and 35781891366). Raising it cannot mask a failure: a
    /// condition that never holds still fails, and one that holds returns immediately — only a
    /// genuine regression waits out the full timeout.
    static func eventually(
        timeout: Duration = .seconds(60),
        _ condition: () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    /// A `UserManager` already listening, so `currentUser` is `user`. Anything reading the signed-in
    /// user's preferences needs this rather than `userManager(user:)`, whose engine holds nothing
    /// until it starts listening.
    static func signedInUserManager(_ user: UserModel?) async throws -> UserManager {
        let manager = userManager(user: user)
        try await manager.signIn(auth: UserAuthInfo(uid: user?.userId ?? "test-user"), isNewUser: false)
        if user != nil {
            // Named here rather than left to whichever assertion reads `currentUser` next, so a
            // listener that never emitted does not look like a wrong value.
            let signedIn = await eventually { manager.currentUser != nil }
            if !signedIn {
                Issue.record("The user sync engine never emitted, so the manager has no user.")
            }
        }
        return manager
    }

    static func exerciseModelManager(
        user userExercises: [ExerciseModel] = [],
        system systemExercises: [ExerciseModel] = []
    ) -> ExerciseModelManager {
        ExerciseModelManager(
            userExerciseSyncEngine: collectionEngine(userExercises, key: "user-exercises"),
            systemExercisePersistence: MockLocalCollectionPersistence(collection: systemExercises)
        )
    }

    static func gymProfileManager(profiles: [GymProfileModel] = []) -> GymProfileManager {
        GymProfileManager(gymProfileSyncEngine: collectionEngine(profiles, key: "gym-profiles"))
    }

    /// A gym profile manager already listening, so `gymProfiles` holds `profiles`.
    static func signedInGymProfileManager(profiles: [GymProfileModel] = []) async -> GymProfileManager {
        let manager = gymProfileManager(profiles: profiles)
        await manager.signIn()
        await eventually { manager.gymProfiles.count == profiles.count }
        return manager
    }

    static func goalManager(goal: WeightGoal? = nil) -> GoalManager {
        GoalManager(userGoalSyncEngine: documentEngine(goal, key: "user-goal"))
    }

    /// A goal manager already listening on `userId`, so `currentGoal` holds `goal`.
    ///
    /// `WeightGoal.id` is the user id, so the id listened to and the goal's own id have to be the
    /// same string — otherwise every status change resolves to a document that is not there.
    static func signedInGoalManager(
        goal: WeightGoal?,
        userId: String = "user-1"
    ) async throws -> GoalManager {
        let manager = goalManager(goal: goal)
        try await manager.signIn(userId: userId)
        if goal != nil {
            await eventually { manager.currentGoal != nil }
        }
        return manager
    }

    /// Passing `comments: nil` leaves the mock service on `WorkoutSessionComment.mocks`, which sits
    /// on `session-1`; every other session then reads as empty.
    static func commentsManager(
        comments: [WorkoutSessionComment]? = nil,
        showError: Bool = false
    ) -> CommentsManager {
        CommentsManager(service: MockCommentsService(comments: comments, showError: showError))
    }

    static func workoutSessionManager(
        sessions: [WorkoutSessionModel] = [],
        following: [WorkoutSessionModel] = []
    ) -> WorkoutSessionManager {
        WorkoutSessionManager(
            likeService: MockWorkoutSessionLikeService(),
            activeWorkoutSessionPersistence: MockLocalDocumentPersistence<WorkoutSessionModel>(),
            userWorkoutSessionSyncEngine: collectionEngine(sessions, key: "workout-sessions"),
            followingWorkoutSessionSyncEngine: CollectionGroupSyncEngine<WorkoutSessionModel>(
                remote: MockRemoteCollectionGroupService(collection: following),
                managerKey: key("following-sessions"),
                enableLocalPersistence: false
            )
        )
    }

    /// A workout session manager already listening, so `workoutSessions` holds `sessions`.
    static func signedInWorkoutSessionManager(
        sessions: [WorkoutSessionModel]
    ) async -> WorkoutSessionManager {
        let manager = workoutSessionManager(sessions: sessions)
        await manager.signIn(userId: "author-1")
        await eventually { manager.workoutSessions.count == sessions.count }
        return manager
    }

    static func bodyMeasurementsManager(
        entries: [BodyMeasurementEntry] = []
    ) -> BodyMeasurementsManager {
        BodyMeasurementsManager(
            bodyMeasurementsSyncEngine: collectionEngine(entries, key: "body-measurements"),
            healthKitService: MockHealthKitWeightService()
        )
    }

    /// A body measurements manager already listening, so `bodyMeasurements` holds `entries`.
    static func signedInBodyMeasurementsManager(
        entries: [BodyMeasurementEntry]
    ) async -> BodyMeasurementsManager {
        let manager = bodyMeasurementsManager(entries: entries)
        await manager.signIn(userId: "author-1")
        await eventually { manager.bodyMeasurements.count == entries.count }
        return manager
    }

    static func mealLogManager(meals: [MealLogModel] = []) -> MealLogManager {
        MealLogManager(
            draftMealLogPersistence: MockLocalDocumentPersistence<MealLogModel>(),
            mealLogSyncEngine: collectionEngine(meals, key: "meal-logs")
        )
    }

    /// A meal log manager already listening, so `userMeals` holds `meals`.
    static func signedInMealLogManager(meals: [MealLogModel]) async -> MealLogManager {
        let manager = mealLogManager(meals: meals)
        await manager.signIn(userId: "author-1")
        await eventually { manager.userMeals.count == meals.count }
        return manager
    }

    #if canImport(HealthKit)
    static func stepsManager(
        entries: [StepsModel] = [],
        healthKitService: HealthKitStepsService? = nil
    ) -> StepsManager {
        StepsManager(
            stepsSyncEngine: collectionEngine(entries, key: "steps"),
            healthKitService: healthKitService ?? MockHealthKitStepsService()
        )
    }

    /// A steps manager already listening, so `stepsHistory` holds `entries`.
    static func signedInStepsManager(
        entries: [StepsModel] = [],
        healthKitService: HealthKitStepsService? = nil
    ) async -> StepsManager {
        let manager = stepsManager(entries: entries, healthKitService: healthKitService)
        await manager.signIn()
        await eventually { manager.stepsHistory.count == entries.count }
        return manager
    }
    #endif
    // MARK: - Training

    static func workoutTemplateManager(
        user userTemplates: [WorkoutTemplateModel] = [],
        system systemTemplates: [WorkoutTemplateModel] = [],
        userDefaults: UserDefaults = .standard
    ) -> WorkoutTemplateManager {
        WorkoutTemplateManager(
            userWorkoutTemplateSyncEngine: collectionEngine(userTemplates, key: "user-workout-templates"),
            systemWorkoutTemplatePersistence: MockLocalCollectionPersistence(collection: systemTemplates),
            userDefaults: userDefaults
        )
    }

    /// A workout template manager already listening, so `userWorkoutTemplates` holds `user`.
    static func signedInWorkoutTemplateManager(
        user userTemplates: [WorkoutTemplateModel] = [],
        system systemTemplates: [WorkoutTemplateModel] = [],
        userDefaults: UserDefaults = .standard
    ) async -> WorkoutTemplateManager {
        let manager = workoutTemplateManager(user: userTemplates, system: systemTemplates, userDefaults: userDefaults)
        await manager.signIn()
        await eventually { manager.userWorkoutTemplates.count == userTemplates.count }
        return manager
    }

    /// A `UserDefaults` of its own, so a test that writes the seeding flags cannot disturb the
    /// flags another suite is asserting on — they are real entries in `UserDefaults.standard`
    /// otherwise, shared by every test in the process.
    static func scratchDefaults(_ name: String = "seeding") -> UserDefaults {
        UserDefaults(suiteName: key(name)) ?? .standard
    }

    static func trainingProgramManager(
        programs: [TrainingProgram] = [],
        prebuilt: [TrainingProgram] = [],
        logManager: LogManager? = nil,
        userDefaults: UserDefaults = .standard
    ) -> TrainingProgramManager {
        TrainingProgramManager(
            trainingProgramSyncEngine: collectionEngine(programs, key: "training-programs"),
            systemProgramPersistence: MockLocalCollectionPersistence(collection: prebuilt),
            logManager: logManager ?? LogManager(services: []),
            userDefaults: userDefaults
        )
    }

    /// A training program manager already listening, so `trainingPrograms` holds `programs`.
    static func signedInTrainingProgramManager(
        programs: [TrainingProgram] = [],
        logManager: LogManager? = nil
    ) async -> TrainingProgramManager {
        let manager = trainingProgramManager(programs: programs, logManager: logManager)
        await manager.signIn(userId: "author-1")
        await eventually { manager.trainingPrograms.count == programs.count }
        return manager
    }

    static func exerciseSettingsManager(
        settings: [ExerciseSettingsModel] = []
    ) -> ExerciseSettingsManager {
        ExerciseSettingsManager(syncEngine: collectionEngine(settings, key: "exercise-settings"))
    }

    /// An exercise settings manager already listening, so `allExerciseSettings` holds `settings`.
    static func signedInExerciseSettingsManager(
        settings: [ExerciseSettingsModel] = [],
        userId: String = "author-1"
    ) async -> ExerciseSettingsManager {
        let manager = exerciseSettingsManager(settings: settings)
        await manager.signIn(userId: userId)
        await eventually { manager.allExerciseSettings.count == settings.count }
        return manager
    }

    static func workoutSettingsManager(_ settings: WorkoutSettings? = nil) -> WorkoutSettingsManager {
        WorkoutSettingsManager(workoutSettingsSyncEngine: documentEngine(settings, key: "workout-settings"))
    }

    /// A workout settings manager already listening, so `workoutSettings` is `settings` rather than
    /// the defaults its engine hands back before the listener emits.
    static func signedInWorkoutSettingsManager(
        _ settings: WorkoutSettings,
        userId: String = "author-1"
    ) async throws -> WorkoutSettingsManager {
        let manager = workoutSettingsManager(settings)
        try await manager.signIn(userId: userId, isNewUser: false)
        // Compared on a field the defaults cannot match: the fallback `WorkoutSettings(authorId:)`
        // carries the same author id, so that alone would pass without the listener ever emitting.
        let emitted = await eventually {
            manager.workoutSettings.defaultRestDurationSeconds == settings.defaultRestDurationSeconds
                && manager.workoutSettings.useRestTimers == settings.useRestTimers
        }
        if !emitted {
            Issue.record("The workout settings sync engine never emitted, so the manager holds defaults.")
        }
        return manager
    }
}

// MARK: - Nutrition, settings and shortcut managers

@MainActor
extension TestManagers {

    static func foodManager(foods: [FoodModel] = []) -> FoodManager {
        FoodManager(foodSyncEngine: collectionEngine(foods, key: "foods"))
    }

    /// A food manager already listening, so `foods` holds what its remote was given.
    static func signedInFoodManager(foods: [FoodModel]) async -> FoodManager {
        let manager = foodManager(foods: foods)
        await manager.signIn()
        await eventually { manager.foods.count == foods.count }
        return manager
    }

    static func recipeTemplateManager(recipes: [RecipeTemplateModel] = []) -> RecipeTemplateManager {
        RecipeTemplateManager(userRecipeTemplateSyncEngine: collectionEngine(recipes, key: "recipes"))
    }

    /// A recipe manager already listening, so `userRecipeTemplates` holds what its remote was given.
    static func signedInRecipeTemplateManager(recipes: [RecipeTemplateModel]) async -> RecipeTemplateManager {
        let manager = recipeTemplateManager(recipes: recipes)
        await manager.signIn()
        await eventually { manager.userRecipeTemplates.count == recipes.count }
        return manager
    }

    static func foodLogSettingsManager(stored: FoodLogSettings? = nil) -> FoodLogSettingsManager {
        FoodLogSettingsManager(foodLogSettingsSyncEngine: documentEngine(stored, key: "food-log-settings"))
    }

    static func analyticsSettingsManager(stored: AnalyticsSettings? = nil) -> AnalyticsSettingsManager {
        AnalyticsSettingsManager(settingsSyncEngine: documentEngine(stored, key: "analytics-settings"))
    }

    static func shortcutSettingsManager(stored: ShortcutSettings? = nil) -> ShortcutSettingsManager {
        ShortcutSettingsManager(settingsSyncEngine: documentEngine(stored, key: "shortcut-settings"))
    }

    static func nutritionStrategySettingsManager(
        stored: NutritionStrategySettings? = nil
    ) -> NutritionStrategySettingsManager {
        NutritionStrategySettingsManager(
            settingsSyncEngine: documentEngine(stored, key: "nutrition-strategy-settings")
        )
    }

    static func nutritionStrategyManager(
        annotations: [NutritionDayAnnotation] = [],
        loggingBreak: LoggingBreak? = nil,
        record: CheckInRecord? = nil
    ) -> NutritionStrategyManager {
        NutritionStrategyManager(
            dayAnnotationSyncEngine: collectionEngine(annotations, key: "nutrition-day-annotations"),
            loggingBreakSyncEngine: documentEngine(loggingBreak, key: "logging-break"),
            checkInRecordSyncEngine: documentEngine(record, key: "check-in-record")
        )
    }

    /// A strategy manager already listening, so its three properties hold what it was given.
    static func signedInNutritionStrategyManager(
        annotations: [NutritionDayAnnotation] = [],
        loggingBreak: LoggingBreak? = nil,
        record: CheckInRecord? = nil,
        userId: String = "user-1"
    ) async throws -> NutritionStrategyManager {
        let manager = nutritionStrategyManager(annotations: annotations, loggingBreak: loggingBreak, record: record)
        try await manager.signIn(userId: userId)
        if !annotations.isEmpty {
            await eventually { manager.dayAnnotations.count == annotations.count }
        }
        if loggingBreak != nil {
            await eventually { manager.loggingBreak != nil }
        }
        if record != nil {
            await eventually { manager.checkInRecord != nil }
        }
        return manager
    }

    static func nutritionManager(plan: DietPlan? = nil) -> NutritionManager {
        NutritionManager(dietPlanSyncEngine: documentEngine(plan, key: "diet-plan"))
    }

    /// A nutrition manager already listening, so `currentDietPlan` holds `plan`.
    ///
    /// The document id is the plan's own id, which is what `deleteDietPlan` later resolves against
    /// — the engine deletes whatever id it was told to listen to. Signing in under an unrelated id
    /// leaves a delete pointing at a document that is not there.
    static func signedInNutritionManager(plan: DietPlan?) async throws -> NutritionManager {
        let manager = nutritionManager(plan: plan)
        try await manager.signIn(dietPlanId: plan?.id ?? "diet-plan-1")
        if plan != nil {
            // Named here rather than left to whichever assertion reads `currentDietPlan` next, so
            // a listener that never emitted does not look like a wrong plan.
            let listening = await eventually { manager.currentDietPlan != nil }
            if !listening {
                Issue.record("The diet plan sync engine never emitted, so the manager has no plan.")
            }
        }
        return manager
    }

    static func pushManager(logManager: LogManager? = nil) -> PushManager {
        PushManager(logManager: logManager)
    }
}
