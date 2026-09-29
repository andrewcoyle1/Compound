//
//  Dependencies.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

// `Dependencies` is the app's single DI root: one `init(config:)` whose three switch arms wire
// every manager for the chosen build configuration, followed by a flat registration list. The
// arms each bind ~32 locals that the registration block consumes, so splitting them into
// functions would mean threading all 32 through a carrier type — scattering the wiring without
// making it simpler. The init is already exempt from `function_body_length` for the same
// reason; these two rules are scoped here on the same grounds.
// swiftlint:disable type_body_length file_length

@MainActor
struct Dependencies {
    let container: DependencyContainer
    let logManager: LogManager

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    init(config: BuildConfiguration) {
        
        let authManager: AuthManager
        let userManager: UserManager
        let abTestManager: ABTestManager
        let logManager: LogManager
        let purchaseManager: PurchaseManager
        let appState: AppState
        let hapticManager: HapticManager
        let soundEffectManager: SoundEffectManager

        let exerciseModelManager: ExerciseModelManager
        let exerciseUnitPreferenceManager: ExerciseUnitPreferenceManager
        let workoutSettingsManager: WorkoutSettingsManager
        let foodLogSettingsManager: FoodLogSettingsManager
        let nutritionStrategySettingsManager: NutritionStrategySettingsManager
        let nutritionStrategyManager: NutritionStrategyManager
        let analyticsSettingsManager: AnalyticsSettingsManager
        let shortcutSettingsManager: ShortcutSettingsManager
        let exerciseSettingsManager: ExerciseSettingsManager
        let workoutTemplateManager: WorkoutTemplateManager
        let workoutSessionManager: WorkoutSessionManager
        let trainingProgramManager: TrainingProgramManager
        let gymProfileManager: GymProfileManager
        let foodManager: FoodManager
        let recipeTemplateManager: RecipeTemplateManager
        let nutritionManager: NutritionManager
        let mealLogManager: MealLogManager
        let pushManager: PushManager
        let aiManager: AIManager
        
        let reportManager: ReportManager
        let healthKitManager: HealthKitManager
        let bodyMeasurementsManager: BodyMeasurementsManager
        let stepsManager: StepsManager
        let goalManager: GoalManager
        let streakManager: StreakManager
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        let hkWorkoutManager: HKWorkoutManager
        let liveActivityManager: LiveActivityManager
        #endif
        let imageUploadManager: ImageUploadManager
        let commentsManager: CommentsManager
        let activityNotificationManager: ActivityNotificationManager
        let stravaManager: StravaManager
        let openFoodFactsService: any OpenFoodFactsService

        switch config {
        case .mock(let scenario):
            logManager = LogManager(services: [
                ConsoleService(printParameters: true)
            ])
            // Not in Keys.swift: that file is gitignored, so a new constant there breaks every
            // existing checkout until it is copied in by hand.
            let privateSettingsSyncEngine = DocumentSyncEngine<PrivateUserSettings>(
                remote: MockRemoteDocumentService(),
                managerKey: "private_user_settings",
                enableLocalPersistence: true,
                logger: logManager
            )
            switch scenario {
            case .newAnonymous:
                authManager = AuthManager(service: MockAuthService(scenario: .newAnonymous))
                let userSyncEngine = DocumentSyncEngine<UserModel>(
                    remote: MockRemoteDocumentService(document: nil),
                    managerKey: Keys.userManagerKey,
                    enableLocalPersistence: true,
                    logger: logManager
                )
                let followingUsersSyncEngine = CollectionSyncEngine<UserModel>(
                    remote: MockRemoteCollectionService(collection: []),
                    managerKey: Keys.followingUsersManagerKey,
                    enableLocalPersistence: true,
                    logger: logManager
                )
                userManager = UserManager(queryService: MockUserQueryService(), userSyncEngine: userSyncEngine, followingUsersSyncEngine: followingUsersSyncEngine, privateSettingsSyncEngine: privateSettingsSyncEngine)
                appState = AppState(startingModuleId: Constants.onboardingModuleId)
            case .existingSignedOut:
                authManager = AuthManager(service: MockAuthService(scenario: .existingSignedOut))
                let userSyncEngine = DocumentSyncEngine<UserModel>(
                    remote: MockRemoteDocumentService(),
                    managerKey: Keys.userManagerKey,
                    enableLocalPersistence: true,
                    logger: logManager
                )
                let followingUsersSyncEngine = CollectionSyncEngine<UserModel>(
                    remote: MockRemoteCollectionService(),
                    managerKey: Keys.followingUsersManagerKey,
                    enableLocalPersistence: true,
                    logger: logManager
                )
                userManager = UserManager(queryService: MockUserQueryService(), userSyncEngine: userSyncEngine, followingUsersSyncEngine: followingUsersSyncEngine, privateSettingsSyncEngine: privateSettingsSyncEngine)
                appState = AppState(startingModuleId: Constants.onboardingModuleId)
            case .existingSignedIn:
                authManager = AuthManager(service: MockAuthService(scenario: .existingSignedIn))
                let userSyncEngine = DocumentSyncEngine<UserModel>(
                    remote: MockRemoteDocumentService(document: UserModel.mockExisting),
                    managerKey: Keys.userManagerKey,
                    enableLocalPersistence: true,
                    logger: logManager
                )
                let followingUsersSyncEngine = CollectionSyncEngine<UserModel>(
                    remote: MockRemoteCollectionService(collection: UserModel.mocks),
                    managerKey: Keys.followingUsersManagerKey,
                    enableLocalPersistence: true,
                    logger: logManager
                )
                userManager = UserManager(queryService: MockUserQueryService(), userSyncEngine: userSyncEngine, followingUsersSyncEngine: followingUsersSyncEngine, privateSettingsSyncEngine: privateSettingsSyncEngine)
                appState = AppState(startingModuleId: Constants.tabBarModuleId)
            }
            purchaseManager = PurchaseManager(service: MockPurchaseService(availableProducts: AnyProduct.mocks))
            abTestManager = ABTestManager(service: MockABTestService(), logger: logManager)
            let userExerciseSyncEngine = CollectionSyncEngine<ExerciseModel>(
                remote: MockRemoteCollectionService(collection: ExerciseModel.userMocks),
                managerKey: Keys.userExerciseManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let systemExercisePersistence = MockLocalCollectionPersistence(collection: ExerciseModel.mocks)
            exerciseModelManager = ExerciseModelManager(userExerciseSyncEngine: userExerciseSyncEngine, systemExercisePersistence: systemExercisePersistence)
            exerciseUnitPreferenceManager = ExerciseUnitPreferenceManager(userManager: userManager)
            let workoutSettingsSyncEngine = DocumentSyncEngine<WorkoutSettings>(
                remote: MockRemoteDocumentService(document: WorkoutSettings.mock),
                managerKey: Keys.workoutSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            workoutSettingsManager = WorkoutSettingsManager(workoutSettingsSyncEngine: workoutSettingsSyncEngine)
            let exerciseSettingsSyncEngineMock = CollectionSyncEngine<ExerciseSettingsModel>(
                remote: MockRemoteCollectionService(collection: []),
                managerKey: Keys.exerciseSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            exerciseSettingsManager = ExerciseSettingsManager(syncEngine: exerciseSettingsSyncEngineMock)
            let foodLogSettingsSyncEngine = DocumentSyncEngine<FoodLogSettings>(
                remote: MockRemoteDocumentService(document: FoodLogSettings.mock),
                managerKey: Keys.foodLogSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            foodLogSettingsManager = FoodLogSettingsManager(foodLogSettingsSyncEngine: foodLogSettingsSyncEngine)
            let nutritionStrategySyncEngine = DocumentSyncEngine<NutritionStrategySettings>(
                remote: MockRemoteDocumentService(document: NutritionStrategySettings.mock),
                managerKey: Keys.nutritionStrategySettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            nutritionStrategySettingsManager = NutritionStrategySettingsManager(settingsSyncEngine: nutritionStrategySyncEngine)
            let dayAnnotationSyncEngine = CollectionSyncEngine<NutritionDayAnnotation>(
                remote: MockRemoteCollectionService(collection: []),
                managerKey: Keys.nutritionDayAnnotationManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let loggingBreakSyncEngine = DocumentSyncEngine<LoggingBreak>(
                remote: MockRemoteDocumentService(document: nil),
                managerKey: Keys.loggingBreakManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let checkInRecordSyncEngine = DocumentSyncEngine<CheckInRecord>(
                remote: MockRemoteDocumentService(document: nil),
                managerKey: Keys.checkInRecordManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            nutritionStrategyManager = NutritionStrategyManager(
                dayAnnotationSyncEngine: dayAnnotationSyncEngine,
                loggingBreakSyncEngine: loggingBreakSyncEngine,
                checkInRecordSyncEngine: checkInRecordSyncEngine
            )
            let analyticsSettingsSyncEngine = DocumentSyncEngine<AnalyticsSettings>(
                remote: MockRemoteDocumentService(document: AnalyticsSettings.mock),
                managerKey: Keys.analyticsSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            analyticsSettingsManager = AnalyticsSettingsManager(settingsSyncEngine: analyticsSettingsSyncEngine)
            let shortcutSettingsSyncEngine = DocumentSyncEngine<ShortcutSettings>(
                remote: MockRemoteDocumentService(document: ShortcutSettings.mock),
                managerKey: Keys.shortcutSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            shortcutSettingsManager = ShortcutSettingsManager(settingsSyncEngine: shortcutSettingsSyncEngine)
            let userWorkoutTemplateSyncEngine = CollectionSyncEngine<WorkoutTemplateModel>(
                remote: MockRemoteCollectionService(collection: WorkoutTemplateModel.userMocks),
                managerKey: Keys.workoutTemplateManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let systemWorkoutTemplatePersistence = MockLocalCollectionPersistence<WorkoutTemplateModel>(collection: WorkoutTemplateModel.mocks)
            workoutTemplateManager = WorkoutTemplateManager(userWorkoutTemplateSyncEngine: userWorkoutTemplateSyncEngine, systemWorkoutTemplatePersistence: systemWorkoutTemplatePersistence)
            let activeWorkoutSessionPersistence = MockLocalDocumentPersistence<WorkoutSessionModel>()
            let userWorkoutSessionSyncEngine = CollectionSyncEngine<WorkoutSessionModel>(
                remote: MockRemoteCollectionService(collection: WorkoutSessionModel.mocks),
                managerKey: Keys.userWorkoutSessionManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let followingWorkoutSessionSyncEngine = CollectionGroupSyncEngine<WorkoutSessionModel>(
                remote: MockRemoteCollectionGroupService(collection: WorkoutSessionModel.mocks),
                managerKey: Keys.followingWorkoutSessionsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            workoutSessionManager = WorkoutSessionManager(
                likeService: MockWorkoutSessionLikeService(),
                activeWorkoutSessionPersistence: activeWorkoutSessionPersistence,
                userWorkoutSessionSyncEngine: userWorkoutSessionSyncEngine,
                followingWorkoutSessionSyncEngine: followingWorkoutSessionSyncEngine
            )
            let trainingProgramSyncEngine = CollectionSyncEngine<TrainingProgram>(
                remote: MockRemoteCollectionService(collection: TrainingProgram.mocks),
                managerKey: Keys.trainingProgramManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            trainingProgramManager = TrainingProgramManager(trainingProgramSyncEngine: trainingProgramSyncEngine, systemProgramPersistence: MockLocalCollectionPersistence(collection: PrebuiltSeedData.programs), logManager: logManager)
                
            let gymProfileSyncEngine = CollectionSyncEngine<GymProfileModel>(
                remote: MockRemoteCollectionService(collection: GymProfileModel.mocks),
                managerKey: Keys.gymProfileManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            gymProfileManager = GymProfileManager(gymProfileSyncEngine: gymProfileSyncEngine)

            let foodSyncEngine = CollectionSyncEngine<FoodModel>(
                remote: MockRemoteCollectionService(collection: FoodModel.mocks),
                managerKey: Keys.foodManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            foodManager = FoodManager(foodSyncEngine: foodSyncEngine)
            
            let userRecipeTemplateSyncEngine = CollectionSyncEngine<RecipeTemplateModel>(
                remote: MockRemoteCollectionService(collection: RecipeTemplateModel.mocks),
                managerKey: Keys.recipeTemplateManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            recipeTemplateManager = RecipeTemplateManager(userRecipeTemplateSyncEngine: userRecipeTemplateSyncEngine)
            let dietPlanSyncEngine = DocumentSyncEngine<DietPlan>(
                remote: MockRemoteDocumentService(document: DietPlan.mock),
                managerKey: Keys.dietPlanManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            nutritionManager = NutritionManager(dietPlanSyncEngine: dietPlanSyncEngine)
            let draftMealLogPersistence = FileManagerDocumentPersistence<MealLogModel>()
            let mealLogSyncEngine = CollectionSyncEngine<MealLogModel>(
                remote: MockRemoteCollectionService(collection: MealLogModel.mockWeekMealsByDay.values.flatMap { $0 }),
                managerKey: Keys.mealLogManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            mealLogManager = MealLogManager(draftMealLogPersistence: draftMealLogPersistence, mealLogSyncEngine: mealLogSyncEngine)
            aiManager = AIManager(service: MockAIService())
            reportManager = ReportManager(service: MockReportService(), userManager: userManager, logManager: logManager)
            let bodyMeasurementsSyncEngine = CollectionSyncEngine<BodyMeasurementEntry>(
                remote: MockRemoteCollectionService(collection: BodyMeasurementEntry.mocks),
                managerKey: Keys.bodyMeasurementsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            bodyMeasurementsManager = BodyMeasurementsManager(
                bodyMeasurementsSyncEngine: bodyMeasurementsSyncEngine,
                healthKitService: ProductionHealthKitWeightService()
            )
            let stepsSyncEngine = CollectionSyncEngine<StepsModel>(
                remote: MockRemoteCollectionService(collection: StepsModel.mocks),
                managerKey: Keys.stepsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            stepsManager = StepsManager(stepsSyncEngine: stepsSyncEngine, healthKitService: MockHealthKitStepsService())
            let userGoalSyncEngine = DocumentSyncEngine<WeightGoal>(
                remote: MockRemoteDocumentService(document: WeightGoal.mock()),
                managerKey: Keys.userGoalManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            goalManager = GoalManager(userGoalSyncEngine: userGoalSyncEngine)
            streakManager = StreakManager(
                services: MockStreakServices(),
                configuration: StreakConfiguration(streakKey: "workout", leewayHours: 2),
                logger: logManager
            )
            #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
            liveActivityManager = LiveActivityManager(logger: logManager, weightUnit: {
                exerciseUnitPreferenceManager.getPreference(for: $0).weightUnit.liveActivityUnit
            })
            hkWorkoutManager = HKWorkoutManager(logger: logManager, liveActivityUpdater: liveActivityManager)
            #endif
            imageUploadManager = ImageUploadManager(service: MockImageUploadService())
            pushManager = PushManager(logManager: logManager)
            // The real service put the Health permission sheet over the tracker in every mock launch.
            healthKitManager = HealthKitManager(service: MockHealthService(canRequestAuthorisation: false))
            commentsManager = CommentsManager(service: MockCommentsService())
            activityNotificationManager = ActivityNotificationManager(service: MockActivityNotificationService())
            stravaManager = StravaManager(service: MockStravaService(), clientId: "", clientSecret: "")
            openFoodFactsService = MockOpenFoodFactsService()

        case .dev:
            logManager = LogManager(services: [
                ConsoleService(printParameters: true),
                FirebaseAnalyticsService(),
                MixpanelService(token: Keys.mixpanelToken, loggingEnabled: false),
                FirebaseCrashlyticsService()
            ] + DataAccessLogging.devServices)
            
            authManager = AuthManager(service: FirebaseAuthService(), logger: logManager)
            let userSyncEngine = DocumentSyncEngine<UserModel>(
                remote: FirebaseRemoteDocumentService(collectionPath: { "users" }),
                managerKey: Keys.userManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let followingUsersSyncEngine = CollectionSyncEngine<UserModel>(
                remote: FirebaseRemoteCollectionService(collectionPath: { "users" }),
                managerKey: Keys.followingUsersManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let privateSettingsSyncEngine = DocumentSyncEngine<PrivateUserSettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/private"
                    }
                ),
                managerKey: "private_user_settings",
                enableLocalPersistence: true,
                logger: logManager
            )
            userManager = UserManager(
                queryService: FirebaseUserQueryService(),
                userSyncEngine: userSyncEngine,
                followingUsersSyncEngine: followingUsersSyncEngine,
                privateSettingsSyncEngine: privateSettingsSyncEngine
            )
            abTestManager = ABTestManager(service: LocalABTestService(), logger: logManager)
            purchaseManager = PurchaseManager(service: RevenueCatPurchaseService(apiKey: Keys.revenueCatAPIKey), logger: logManager)
            let userExerciseSyncEngine = CollectionSyncEngine<ExerciseModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: {
                        "exercise_templates"
                    }
                ),
                managerKey: Keys.userExerciseManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let systemExercisePersistence = SwiftDataCollectionPersistence<ExerciseModel>(managerKey: Keys.systemExerciseManagerKey)
            exerciseModelManager = ExerciseModelManager(userExerciseSyncEngine: userExerciseSyncEngine, systemExercisePersistence: systemExercisePersistence)
            exerciseUnitPreferenceManager = ExerciseUnitPreferenceManager(userManager: userManager)
            let workoutSettingsSyncEngine = DocumentSyncEngine<WorkoutSettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/workout_settings"
                    }
                ),
                managerKey: Keys.workoutSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            workoutSettingsManager = WorkoutSettingsManager(workoutSettingsSyncEngine: workoutSettingsSyncEngine)
            let exerciseSettingsSyncEngineDev = CollectionSyncEngine<ExerciseSettingsModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/exercise_settings"
                    }
                ),
                managerKey: Keys.exerciseSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            exerciseSettingsManager = ExerciseSettingsManager(syncEngine: exerciseSettingsSyncEngineDev)
            let foodLogSettingsSyncEngineDev = DocumentSyncEngine<FoodLogSettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/food_log_settings"
                    }
                ),
                managerKey: Keys.foodLogSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            foodLogSettingsManager = FoodLogSettingsManager(foodLogSettingsSyncEngine: foodLogSettingsSyncEngineDev)
            let nutritionStrategySyncEngineDev = DocumentSyncEngine<NutritionStrategySettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/nutrition_strategy_settings"
                    }
                ),
                managerKey: Keys.nutritionStrategySettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            nutritionStrategySettingsManager = NutritionStrategySettingsManager(settingsSyncEngine: nutritionStrategySyncEngineDev)
            let dayAnnotationSyncEngineDev = CollectionSyncEngine<NutritionDayAnnotation>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/nutrition_day_annotations"
                    }
                ),
                managerKey: Keys.nutritionDayAnnotationManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let loggingBreakSyncEngineDev = DocumentSyncEngine<LoggingBreak>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/logging_break"
                    }
                ),
                managerKey: Keys.loggingBreakManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let checkInRecordSyncEngineDev = DocumentSyncEngine<CheckInRecord>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/check_in_record"
                    }
                ),
                managerKey: Keys.checkInRecordManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            nutritionStrategyManager = NutritionStrategyManager(
                dayAnnotationSyncEngine: dayAnnotationSyncEngineDev,
                loggingBreakSyncEngine: loggingBreakSyncEngineDev,
                checkInRecordSyncEngine: checkInRecordSyncEngineDev
            )
            let analyticsSettingsSyncEngineDev = DocumentSyncEngine<AnalyticsSettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/analytics_settings"
                    }
                ),
                managerKey: Keys.analyticsSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            analyticsSettingsManager = AnalyticsSettingsManager(settingsSyncEngine: analyticsSettingsSyncEngineDev)
            let shortcutSettingsSyncEngineDev = DocumentSyncEngine<ShortcutSettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/shortcut_settings"
                    }
                ),
                managerKey: Keys.shortcutSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            shortcutSettingsManager = ShortcutSettingsManager(settingsSyncEngine: shortcutSettingsSyncEngineDev)

            let userWorkoutTemplateSyncEngine = CollectionSyncEngine<WorkoutTemplateModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/workout_templates"
                    }
                ),
                managerKey: Keys.workoutTemplateManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let systemWorkoutTemplatePersistence = SwiftDataCollectionPersistence<WorkoutTemplateModel>(managerKey: Keys.systemWorkoutTemplateManagerKey)
            workoutTemplateManager = WorkoutTemplateManager(userWorkoutTemplateSyncEngine: userWorkoutTemplateSyncEngine, systemWorkoutTemplatePersistence: systemWorkoutTemplatePersistence)
            let activeWorkoutSessionPersistence = FileManagerDocumentPersistence<WorkoutSessionModel>()
            let userWorkoutSessionSyncEngine = CollectionSyncEngine<WorkoutSessionModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/workout_sessions"
                    }
                ),
                managerKey: Keys.userWorkoutSessionManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let followingWorkoutSessionsSyncEngine = CollectionGroupSyncEngine<WorkoutSessionModel>(
                remote: FirebaseRemoteCollectionGroupService(collectionGroupName: "workout_sessions"),
                managerKey: Keys.followingWorkoutSessionsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            workoutSessionManager = WorkoutSessionManager(
                likeService: FirebaseWorkoutSessionLikeService(),
                activeWorkoutSessionPersistence: activeWorkoutSessionPersistence,
                userWorkoutSessionSyncEngine: userWorkoutSessionSyncEngine,
                followingWorkoutSessionSyncEngine: followingWorkoutSessionsSyncEngine
            )
            let trainingProgramSyncEngine = CollectionSyncEngine<TrainingProgram>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/training_programs"
                    }
                ),
                managerKey: Keys.trainingProgramManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            trainingProgramManager = TrainingProgramManager(trainingProgramSyncEngine: trainingProgramSyncEngine, systemProgramPersistence: SwiftDataCollectionPersistence<TrainingProgram>(managerKey: TrainingProgramManager.systemManagerKey), logManager: logManager)
            let gymProfileSyncEngine = CollectionSyncEngine<GymProfileModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/gym_profiles"
                    }
                ),
                managerKey: Keys.gymProfileManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            gymProfileManager = GymProfileManager(gymProfileSyncEngine: gymProfileSyncEngine)

            let foodSyncEngine = CollectionSyncEngine<FoodModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/foods"
                    }
                ),
                managerKey: Keys.foodManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            foodManager = FoodManager(foodSyncEngine: foodSyncEngine)
            let userRecipeTemplateSyncEngine = CollectionSyncEngine<RecipeTemplateModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/recipe_templates"
                    }
                ),
                managerKey: Keys.recipeTemplateManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            recipeTemplateManager = RecipeTemplateManager(userRecipeTemplateSyncEngine: userRecipeTemplateSyncEngine)
            let dietPlanSyncEngine = DocumentSyncEngine<DietPlan>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: { "diet_plans" }
                ),
                managerKey: Keys.dietPlanManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            nutritionManager = NutritionManager(dietPlanSyncEngine: dietPlanSyncEngine)
            let draftMealLogPersistence = FileManagerDocumentPersistence<MealLogModel>()
            let mealLogSyncEngine = CollectionSyncEngine<MealLogModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/meal_logs"
                    }
                ),
                managerKey: Keys.mealLogManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            mealLogManager = MealLogManager(draftMealLogPersistence: draftMealLogPersistence, mealLogSyncEngine: mealLogSyncEngine)
            aiManager = AIManager(service: GoogleAIService())
            reportManager = ReportManager(service: FirebaseReportService(), userManager: userManager, logManager: logManager)
            let bodyMeasurementsSyncEngine = CollectionSyncEngine<BodyMeasurementEntry>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/body_measurements"
                    }
                ),
                managerKey: Keys.bodyMeasurementsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            bodyMeasurementsManager = BodyMeasurementsManager(
                bodyMeasurementsSyncEngine: bodyMeasurementsSyncEngine,
                healthKitService: ProductionHealthKitWeightService()
            )
            let stepsSyncEngine = CollectionSyncEngine<StepsModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/steps"
                    }
                ),
                managerKey: Keys.stepsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            stepsManager = StepsManager(stepsSyncEngine: stepsSyncEngine, healthKitService: ProductionHealthKitStepsService())
            let userGoalSyncEngine = DocumentSyncEngine<WeightGoal>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/goals"
                    }
                ),
                managerKey: Keys.userGoalManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            goalManager = GoalManager(userGoalSyncEngine: userGoalSyncEngine)
            streakManager = StreakManager(
                services: ProductionStreakServices(rootCollectionName: "user_streaks"),
                configuration: StreakConfiguration(streakKey: "workout", leewayHours: 2),
                logger: logManager
            )
            #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
            liveActivityManager = LiveActivityManager(logger: logManager, weightUnit: {
                exerciseUnitPreferenceManager.getPreference(for: $0).weightUnit.liveActivityUnit
            })
            hkWorkoutManager = HKWorkoutManager(logger: logManager, liveActivityUpdater: liveActivityManager)
            #endif
            appState = AppState()
            imageUploadManager = ImageUploadManager(service: FirebaseImageUploadService())
            pushManager = PushManager(logManager: logManager)
            healthKitManager = HealthKitManager(service: HealthKitService())
            commentsManager = CommentsManager(service: FirebaseCommentsService())
            activityNotificationManager = ActivityNotificationManager(service: FirebaseActivityNotificationService())
            stravaManager = StravaManager(service: ProductionStravaService(), clientId: Keys.stravaClientId, clientSecret: Keys.stravaClientSecret)
            openFoodFactsService = ProductionOpenFoodFactsService()

        case .prod:
            logManager = LogManager(services: [
                ConsoleService(),
                FirebaseAnalyticsService(),
                MixpanelService(token: Keys.mixpanelToken),
                FirebaseCrashlyticsService()
            ])
            authManager = AuthManager(service: FirebaseAuthService(), logger: logManager)
            let userSyncEngine = DocumentSyncEngine<UserModel>(
                remote: FirebaseRemoteDocumentService(collectionPath: { "users" }),
                managerKey: Keys.userManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let followingUsersSyncEngine = CollectionSyncEngine<UserModel>(
                remote: FirebaseRemoteCollectionService(collectionPath: { "users" }),
                managerKey: Keys.followingUsersManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let privateSettingsSyncEngine = DocumentSyncEngine<PrivateUserSettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/private"
                    }
                ),
                managerKey: "private_user_settings",
                enableLocalPersistence: true,
                logger: logManager
            )
            userManager = UserManager(
                queryService: FirebaseUserQueryService(),
                userSyncEngine: userSyncEngine,
                followingUsersSyncEngine: followingUsersSyncEngine,
                privateSettingsSyncEngine: privateSettingsSyncEngine
            )
            abTestManager = ABTestManager(service: FirebaseABTestService(), logger: logManager)
            purchaseManager = PurchaseManager(service: StoreKitPurchaseService())
            let userExerciseSyncEngine = CollectionSyncEngine<ExerciseModel>(
                remote: FirebaseRemoteCollectionService(collectionPath: { "exercise_templates" }),
                managerKey: Keys.userExerciseManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let systemExercisePersistence = SwiftDataCollectionPersistence<ExerciseModel>(managerKey: Keys.systemExerciseManagerKey)
            exerciseModelManager = ExerciseModelManager(userExerciseSyncEngine: userExerciseSyncEngine, systemExercisePersistence: systemExercisePersistence)
            exerciseUnitPreferenceManager = ExerciseUnitPreferenceManager(userManager: userManager)
            let workoutSettingsSyncEngine = DocumentSyncEngine<WorkoutSettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/workout_settings"
                    }
                ),
                managerKey: Keys.workoutSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            workoutSettingsManager = WorkoutSettingsManager(workoutSettingsSyncEngine: workoutSettingsSyncEngine)
            let exerciseSettingsSyncEngineProd = CollectionSyncEngine<ExerciseSettingsModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/exercise_settings"
                    }
                ),
                managerKey: Keys.exerciseSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            exerciseSettingsManager = ExerciseSettingsManager(syncEngine: exerciseSettingsSyncEngineProd)
            let foodLogSettingsSyncEngineProd = DocumentSyncEngine<FoodLogSettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/food_log_settings"
                    }
                ),
                managerKey: Keys.foodLogSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            foodLogSettingsManager = FoodLogSettingsManager(foodLogSettingsSyncEngine: foodLogSettingsSyncEngineProd)
            let nutritionStrategySyncEngineProd = DocumentSyncEngine<NutritionStrategySettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/nutrition_strategy_settings"
                    }
                ),
                managerKey: Keys.nutritionStrategySettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            nutritionStrategySettingsManager = NutritionStrategySettingsManager(settingsSyncEngine: nutritionStrategySyncEngineProd)
            let dayAnnotationSyncEngineProd = CollectionSyncEngine<NutritionDayAnnotation>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/nutrition_day_annotations"
                    }
                ),
                managerKey: Keys.nutritionDayAnnotationManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let loggingBreakSyncEngineProd = DocumentSyncEngine<LoggingBreak>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/logging_break"
                    }
                ),
                managerKey: Keys.loggingBreakManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let checkInRecordSyncEngineProd = DocumentSyncEngine<CheckInRecord>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/check_in_record"
                    }
                ),
                managerKey: Keys.checkInRecordManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            nutritionStrategyManager = NutritionStrategyManager(
                dayAnnotationSyncEngine: dayAnnotationSyncEngineProd,
                loggingBreakSyncEngine: loggingBreakSyncEngineProd,
                checkInRecordSyncEngine: checkInRecordSyncEngineProd
            )
            let analyticsSettingsSyncEngineProd = DocumentSyncEngine<AnalyticsSettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/analytics_settings"
                    }
                ),
                managerKey: Keys.analyticsSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            analyticsSettingsManager = AnalyticsSettingsManager(settingsSyncEngine: analyticsSettingsSyncEngineProd)
            let shortcutSettingsSyncEngineProd = DocumentSyncEngine<ShortcutSettings>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/shortcut_settings"
                    }
                ),
                managerKey: Keys.shortcutSettingsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            shortcutSettingsManager = ShortcutSettingsManager(settingsSyncEngine: shortcutSettingsSyncEngineProd)
            let userWorkoutTemplateSyncEngine = CollectionSyncEngine<WorkoutTemplateModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: {[weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/workout_templates"
                    }
                ),
                managerKey: Keys.workoutTemplateManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let systemWorkoutTemplatePersistence = SwiftDataCollectionPersistence<WorkoutTemplateModel>(managerKey: Keys.systemWorkoutTemplateManagerKey)
            workoutTemplateManager = WorkoutTemplateManager(userWorkoutTemplateSyncEngine: userWorkoutTemplateSyncEngine, systemWorkoutTemplatePersistence: systemWorkoutTemplatePersistence)
            let activeWorkoutSessionPersistence = FileManagerDocumentPersistence<WorkoutSessionModel>()
            let userWorkoutSessionSyncEngine = CollectionSyncEngine<WorkoutSessionModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/workout_sessions"
                    }
                ),
                managerKey: Keys.userWorkoutSessionManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            let followingWorkoutSessionsSyncEngine = CollectionGroupSyncEngine<WorkoutSessionModel>(
                remote: FirebaseRemoteCollectionGroupService(collectionGroupName: "workout_sessions"),
                managerKey: Keys.followingWorkoutSessionsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            workoutSessionManager = WorkoutSessionManager(
                likeService: FirebaseWorkoutSessionLikeService(),
                activeWorkoutSessionPersistence: activeWorkoutSessionPersistence,
                userWorkoutSessionSyncEngine: userWorkoutSessionSyncEngine,
                followingWorkoutSessionSyncEngine: followingWorkoutSessionsSyncEngine
            )
            let trainingProgramSyncEngine = CollectionSyncEngine<TrainingProgram>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/training_programs"
                    }
                ),
                managerKey: Keys.trainingProgramManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            trainingProgramManager = TrainingProgramManager(trainingProgramSyncEngine: trainingProgramSyncEngine, systemProgramPersistence: SwiftDataCollectionPersistence<TrainingProgram>(managerKey: TrainingProgramManager.systemManagerKey), logManager: logManager)
            let gymProfileSyncEngine = CollectionSyncEngine<GymProfileModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/gym_profiles"
                    }
                ),
                managerKey: Keys.gymProfileManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            gymProfileManager = GymProfileManager(gymProfileSyncEngine: gymProfileSyncEngine)

            let foodSyncEngine = CollectionSyncEngine<FoodModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/foods"
                    }
                ),
                managerKey: Keys.foodManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            foodManager = FoodManager(foodSyncEngine: foodSyncEngine)
            let userRecipeTemplateSyncEngine = CollectionSyncEngine<RecipeTemplateModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/recipe_templates"
                    }
                ),
                managerKey: Keys.recipeTemplateManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            recipeTemplateManager = RecipeTemplateManager(userRecipeTemplateSyncEngine: userRecipeTemplateSyncEngine)
            let dietPlanSyncEngine = DocumentSyncEngine<DietPlan>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: { "diet_plans" }
                ),
                managerKey: Keys.dietPlanManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            nutritionManager = NutritionManager(dietPlanSyncEngine: dietPlanSyncEngine)
            let draftMealLogPersistence = FileManagerDocumentPersistence<MealLogModel>()
            let mealLogSyncEngine = CollectionSyncEngine<MealLogModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/meal_logs"
                    }
                ),
                managerKey: Keys.mealLogManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            mealLogManager = MealLogManager(draftMealLogPersistence: draftMealLogPersistence, mealLogSyncEngine: mealLogSyncEngine)
            aiManager = AIManager(service: GoogleAIService())
            reportManager = ReportManager(service: FirebaseReportService(), userManager: userManager, logManager: logManager)
            let bodyMeasurementsSyncEngine = CollectionSyncEngine<BodyMeasurementEntry>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/body_measurements"
                    }
                ),
                managerKey: Keys.bodyMeasurementsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            bodyMeasurementsManager = BodyMeasurementsManager(
                bodyMeasurementsSyncEngine: bodyMeasurementsSyncEngine,
                healthKitService: ProductionHealthKitWeightService()
            )
            let stepsSyncEngine = CollectionSyncEngine<StepsModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/steps"
                    }
                ),
                managerKey: Keys.stepsManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            stepsManager = StepsManager(stepsSyncEngine: stepsSyncEngine, healthKitService: ProductionHealthKitStepsService())
            let userGoalSyncEngine = DocumentSyncEngine<WeightGoal>(
                remote: FirebaseRemoteDocumentService(
                    collectionPath: { [ weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/goals"
                    }
                ),
                managerKey: Keys.userGoalManagerKey,
                enableLocalPersistence: true,
                logger: logManager
            )
            goalManager = GoalManager(userGoalSyncEngine: userGoalSyncEngine)
            streakManager = StreakManager(
                services: ProductionStreakServices(rootCollectionName: "user_streaks"),
                configuration: StreakConfiguration(streakKey: "workout", leewayHours: 2),
                logger: logManager
            )
            #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
            liveActivityManager = LiveActivityManager(logger: logManager, weightUnit: {
                exerciseUnitPreferenceManager.getPreference(for: $0).weightUnit.liveActivityUnit
            })
            hkWorkoutManager = HKWorkoutManager(logger: logManager, liveActivityUpdater: liveActivityManager)
            #endif
            appState = AppState()
            imageUploadManager = ImageUploadManager(service: FirebaseImageUploadService())
            pushManager = PushManager(logManager: logManager)
            healthKitManager = HealthKitManager(service: HealthKitService())
            commentsManager = CommentsManager(service: FirebaseCommentsService())
            activityNotificationManager = ActivityNotificationManager(service: FirebaseActivityNotificationService())
            stravaManager = StravaManager(service: ProductionStravaService(), clientId: Keys.stravaClientId, clientSecret: Keys.stravaClientSecret)
            openFoodFactsService = ProductionOpenFoodFactsService()
        }
        hapticManager = HapticManager(logger: logManager)
        soundEffectManager = SoundEffectManager(logger: logManager)

        // No configuration-specific setup — it holds only what the app learns at runtime, so
        // every build configuration starts it the same way: unresolved.
        let premiumEntitlementResolution = PremiumEntitlementResolution()

        let container = DependencyContainer()
        container.register(AuthManager.self, service: authManager)
        container.register(UserManager.self, service: userManager)
        container.register(ABTestManager.self, service: abTestManager)
        container.register(PurchaseManager.self, service: purchaseManager)
        container.register(LogManager.self, service: logManager)
        container.register(ExerciseModelManager.self, service: exerciseModelManager)
        container.register(ExerciseUnitPreferenceManager.self, service: exerciseUnitPreferenceManager)
        container.register(WorkoutSettingsManager.self, service: workoutSettingsManager)
        container.register(FoodLogSettingsManager.self, service: foodLogSettingsManager)
        container.register(NutritionStrategySettingsManager.self, service: nutritionStrategySettingsManager)
        container.register(NutritionStrategyManager.self, service: nutritionStrategyManager)
        container.register(AnalyticsSettingsManager.self, service: analyticsSettingsManager)
        container.register(ShortcutSettingsManager.self, service: shortcutSettingsManager)
        container.register(ExerciseSettingsManager.self, service: exerciseSettingsManager)
        container.register(WorkoutTemplateManager.self, service: workoutTemplateManager)
        container.register(WorkoutSessionManager.self, service: workoutSessionManager)
        container.register(TrainingProgramManager.self, service: trainingProgramManager)
        container.register(GymProfileManager.self, service: gymProfileManager)
        container.register(FoodManager.self, service: foodManager)
        container.register(RecipeTemplateManager.self, service: recipeTemplateManager)
        container.register(NutritionManager.self, service: nutritionManager)
        container.register(MealLogManager.self, service: mealLogManager)
        container.register(PushManager.self, service: pushManager)
        container.register(AIManager.self, service: aiManager)
        container.register(ReportManager.self, service: reportManager)
        container.register(HealthKitManager.self, service: healthKitManager)
        container.register(BodyMeasurementsManager.self, service: bodyMeasurementsManager)
        container.register(StepsManager.self, service: stepsManager)
        container.register(GoalManager.self, service: goalManager)
        container.register(StreakManager.self, service: streakManager)
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        container.register(HKWorkoutManager.self, service: hkWorkoutManager)
        container.register(LiveActivityManager.self, service: liveActivityManager)
        #endif
        container.register(AppState.self, service: appState)
        container.register(PremiumEntitlementResolution.self, service: premiumEntitlementResolution)
        container.register(ImageUploadManager.self, service: imageUploadManager)
        container.register(HapticManager.self, service: hapticManager)
        container.register(SoundEffectManager.self, service: soundEffectManager)
        container.register(CommentsManager.self, service: commentsManager)
        container.register(ActivityNotificationManager.self, service: activityNotificationManager)
        container.register(StravaManager.self, service: stravaManager)
        container.register(OpenFoodFactsServiceContainer.self, service: OpenFoodFactsServiceContainer(openFoodFactsService))

        // MARK: - Sharing
        let shareService: ShareService
        if case .mock = config {
            shareService = MockShareService()
        } else {
            shareService = FirebaseShareService()
        }
        container.register(ShareManager.self, service: ShareManager(service: shareService))

        // MARK: - Challenges
        let challengeService: ChallengeService
        if case .mock = config {
            challengeService = MockChallengeService()
        } else {
            challengeService = FirebaseChallengeService()
        }
        container.register(ChallengeManager.self, service: ChallengeManager(service: challengeService))

        // MARK: - Invites
        let inviteService: InviteService
        if case .mock = config {
            inviteService = MockInviteService()
        } else {
            inviteService = FirebaseInviteService()
        }
        container.register(InviteManager.self, service: InviteManager(service: inviteService))

        // MARK: - ProgressPhotos
        // Persistence off: the photos are remote images, and a literal key keeps Keys.swift unchanged.
        let progressPhotoSyncEngine: CollectionSyncEngine<ProgressPhotoModel>
        if case .mock = config {
            progressPhotoSyncEngine = CollectionSyncEngine<ProgressPhotoModel>(
                remote: MockRemoteCollectionService(collection: ProgressPhotoModel.mocks),
                managerKey: "progress_photos",
                enableLocalPersistence: false,
                logger: logManager
            )
        } else {
            progressPhotoSyncEngine = CollectionSyncEngine<ProgressPhotoModel>(
                remote: FirebaseRemoteCollectionService(
                    collectionPath: { [weak authManager] in
                        guard let uid = authManager?.auth?.uid else { return nil }
                        return "users/\(uid)/progress_photos"
                    }
                ),
                managerKey: "progress_photos",
                enableLocalPersistence: false,
                logger: logManager
            )
        }
        container.register(
            ProgressPhotoManager.self,
            service: ProgressPhotoManager(syncEngine: progressPhotoSyncEngine, imageUploadManager: imageUploadManager)
        )

        self.logManager = logManager
        self.container = container
    }
}

// swiftlint:enable type_body_length file_length
