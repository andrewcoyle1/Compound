//
//  DevPreview.swift
//  DialedIn
//
//  Created by Andrew Coyle on 09/03/2026.
//

@MainActor
class DevPreview {
    static let shared = DevPreview()
    
    func container() -> DependencyContainer {
        let container = DependencyContainer()
        container.register(AuthManager.self, service: authManager)
        container.register(UserManager.self, service: userManager)
        container.register(ABTestManager.self, service: abTestManager)
        container.register(PurchaseManager.self, service: purchaseManager)
        container.register(ExerciseModelManager.self, service: exerciseModelManager)
        container.register(ExerciseUnitPreferenceManager.self, service: exerciseUnitPreferenceManager)
        container.register(WorkoutSettingsManager.self, service: workoutSettingsManager)
        container.register(ExerciseSettingsManager.self, service: exerciseSettingsManager)
        container.register(FoodLogSettingsManager.self, service: foodLogSettingsManager)
        container.register(NutritionStrategySettingsManager.self, service: nutritionStrategySettingsManager)
        container.register(AnalyticsSettingsManager.self, service: analyticsSettingsManager)
        container.register(ShortcutSettingsManager.self, service: shortcutSettingsManager)
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
        container.register(LogManager.self, service: logManager)
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
        container.register(SoundEffectManager.self, service: soundEffectManager)
        container.register(HapticManager.self, service: hapticManager)
        container.register(CommentsManager.self, service: commentsManager)
        container.register(ActivityNotificationManager.self, service: activityNotificationManager)
        container.register(StravaManager.self, service: stravaManager)
        container.register(OpenFoodFactsServiceContainer.self, service: OpenFoodFactsServiceContainer(openFoodFactsService))
        container.register(ShareManager.self, service: ShareManager(service: MockShareService()))
        // MARK: - Challenges
        container.register(ChallengeManager.self, service: ChallengeManager(service: MockChallengeService()))
        // MARK: - Invites
        container.register(InviteManager.self, service: InviteManager(service: MockInviteService()))
        // MARK: - ProgressPhotos
        container.register(ProgressPhotoManager.self, service: progressPhotoManager)
        // `CoreInteractor.init` resolves every manager, and this one had never been registered here.
        container.register(NutritionStrategyManager.self, service: nutritionStrategyManager)

        return container
    }

    let authManager: AuthManager
    let userManager: UserManager
    let abTestManager: ABTestManager
    let purchaseManager: PurchaseManager
    let exerciseModelManager: ExerciseModelManager
    let exerciseUnitPreferenceManager: ExerciseUnitPreferenceManager
    let workoutSettingsManager: WorkoutSettingsManager
    let exerciseSettingsManager: ExerciseSettingsManager
    let foodLogSettingsManager: FoodLogSettingsManager
    let nutritionStrategySettingsManager: NutritionStrategySettingsManager
    let analyticsSettingsManager: AnalyticsSettingsManager
    let shortcutSettingsManager: ShortcutSettingsManager
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
    let logManager: LogManager
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
    let appState: AppState
    let premiumEntitlementResolution = PremiumEntitlementResolution()

    let hapticManager: HapticManager
    let soundEffectManager: SoundEffectManager

    let imageUploadManager: ImageUploadManager
    let commentsManager: CommentsManager
    let activityNotificationManager: ActivityNotificationManager
    let stravaManager: StravaManager
    let openFoodFactsService: any OpenFoodFactsService = MockOpenFoodFactsService()

    // swiftlint:disable:next function_body_length
    init(isSignedIn: Bool = true) {
        let logManager = LogManager(services: [ConsoleService(printParameters: true)])
        let userSyncEngine = DocumentSyncEngine<UserModel>(
            remote: MockRemoteDocumentService(document: .mockExisting),
            managerKey: Keys.userManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        let followingUsersSyncEngine = CollectionSyncEngine<UserModel>(
            remote: MockRemoteCollectionService(collection: UserModel.mocks),
            managerKey: Keys.followingUsersManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        let privateSettingsSyncEngine = DocumentSyncEngine<PrivateUserSettings>(
            remote: MockRemoteDocumentService(),
            managerKey: "private_user_settings",
            enableLocalPersistence: false,
            logger: logManager
        )
        let userManager = UserManager(
            queryService: MockUserQueryService(),
            userSyncEngine: userSyncEngine,
            followingUsersSyncEngine: followingUsersSyncEngine,
            privateSettingsSyncEngine: privateSettingsSyncEngine
        )
        
        self.authManager = AuthManager(service: MockAuthService(scenario: isSignedIn ? .existingSignedIn : .newAnonymous), logger: logManager)
        self.userManager = userManager
        self.abTestManager = ABTestManager(service: MockABTestService(), logger: logManager)
        self.purchaseManager = PurchaseManager(service: MockPurchaseService())
        let userExerciseSyncEngine = CollectionSyncEngine<ExerciseModel>(
            remote: MockRemoteCollectionService(collection: ExerciseModel.userMocks),
            managerKey: Keys.userExerciseManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        let systemExercisePersistence = MockLocalCollectionPersistence(collection: ExerciseModel.mocks)
        self.exerciseModelManager = ExerciseModelManager(userExerciseSyncEngine: userExerciseSyncEngine, systemExercisePersistence: systemExercisePersistence)
        self.exerciseUnitPreferenceManager = ExerciseUnitPreferenceManager(userManager: userManager)
        let workoutSettingsSyncEngine = DocumentSyncEngine<WorkoutSettings>(
            remote: MockRemoteDocumentService(document: WorkoutSettings.mock),
            managerKey: Keys.workoutSettingsManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        self.workoutSettingsManager = WorkoutSettingsManager(workoutSettingsSyncEngine: workoutSettingsSyncEngine)
        let exerciseSettingsSyncEngine = CollectionSyncEngine<ExerciseSettingsModel>(
            remote: MockRemoteCollectionService(collection: ExerciseSettingsModel.mocks),
            managerKey: Keys.exerciseSettingsManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        self.exerciseSettingsManager = ExerciseSettingsManager(syncEngine: exerciseSettingsSyncEngine)
        let foodLogSettingsSyncEngine = DocumentSyncEngine<FoodLogSettings>(
            remote: MockRemoteDocumentService(document: FoodLogSettings.mock),
            managerKey: Keys.foodLogSettingsManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        self.foodLogSettingsManager = FoodLogSettingsManager(foodLogSettingsSyncEngine: foodLogSettingsSyncEngine)
        let nutritionStrategySettingsSyncEngine = DocumentSyncEngine<NutritionStrategySettings>(
            remote: MockRemoteDocumentService(document: NutritionStrategySettings.mock),
            managerKey: Keys.nutritionStrategySettingsManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        self.nutritionStrategySettingsManager = NutritionStrategySettingsManager(settingsSyncEngine: nutritionStrategySettingsSyncEngine)
        let analyticsSettingsSyncEngine = DocumentSyncEngine<AnalyticsSettings>(
            remote: MockRemoteDocumentService(document: AnalyticsSettings.mock),
            managerKey: Keys.analyticsSettingsManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        self.analyticsSettingsManager = AnalyticsSettingsManager(settingsSyncEngine: analyticsSettingsSyncEngine)
        let shortcutSettingsSyncEngine = DocumentSyncEngine<ShortcutSettings>(
            remote: MockRemoteDocumentService(document: ShortcutSettings.mock),
            managerKey: Keys.shortcutSettingsManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        self.shortcutSettingsManager = ShortcutSettingsManager(settingsSyncEngine: shortcutSettingsSyncEngine)
        let userWorkoutTemplateSyncEngine = CollectionSyncEngine<WorkoutTemplateModel>(
            remote: MockRemoteCollectionService(collection: WorkoutTemplateModel.userMocks),
            managerKey: Keys.workoutTemplateManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        let systemWorkoutTemplatePersistence = MockLocalCollectionPersistence<WorkoutTemplateModel>(collection: WorkoutTemplateModel.mocks)
        workoutTemplateManager = WorkoutTemplateManager(userWorkoutTemplateSyncEngine: userWorkoutTemplateSyncEngine, systemWorkoutTemplatePersistence: systemWorkoutTemplatePersistence)
        let activeWorkoutSessionPersistence = MockLocalDocumentPersistence<WorkoutSessionModel>(document: WorkoutSessionModel.mock)
        let userWorkoutSessionSyncEngine = CollectionSyncEngine<WorkoutSessionModel>(
            remote: MockRemoteCollectionService(collection: WorkoutSessionModel.mocks),
            managerKey: Keys.userWorkoutSessionManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        let followingWorkoutSessionSyncEngine = CollectionGroupSyncEngine<WorkoutSessionModel>(
            remote: MockRemoteCollectionGroupService(collection: WorkoutSessionModel.mocks),
            managerKey: Keys.followingWorkoutSessionsManagerKey,
            enableLocalPersistence: false,
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
            enableLocalPersistence: false,
            logger: logManager
        )
        self.trainingProgramManager = TrainingProgramManager(trainingProgramSyncEngine: trainingProgramSyncEngine, systemProgramPersistence: MockLocalCollectionPersistence(collection: PrebuiltSeedData.programs), logManager: logManager)
        let gymProfileSyncEngine = CollectionSyncEngine<GymProfileModel>(
            remote: MockRemoteCollectionService(collection: GymProfileModel.mocks),
            managerKey: Keys.gymProfileManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        gymProfileManager = GymProfileManager(gymProfileSyncEngine: gymProfileSyncEngine)

        let foodSyncEngine = CollectionSyncEngine<FoodModel>(
            remote: MockRemoteCollectionService(collection: FoodModel.mocks),
            managerKey: Keys.foodManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        self.foodManager = FoodManager(foodSyncEngine: foodSyncEngine)
        let userRecipeTemplateSyncEngine = CollectionSyncEngine<RecipeTemplateModel>(
            remote: MockRemoteCollectionService(collection: RecipeTemplateModel.mocks),
            managerKey: Keys.recipeTemplateManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        self.recipeTemplateManager = RecipeTemplateManager(userRecipeTemplateSyncEngine: userRecipeTemplateSyncEngine)
        let dietPlanSyncEngine = DocumentSyncEngine<DietPlan>(
            remote: MockRemoteDocumentService(document: DietPlan.mock),
            managerKey: Keys.dietPlanManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        nutritionManager = NutritionManager(dietPlanSyncEngine: dietPlanSyncEngine)
        let draftMealLogPersistence = FileManagerDocumentPersistence<MealLogModel>()
        let mealLogSyncEngine = CollectionSyncEngine<MealLogModel>(
            remote: MockRemoteCollectionService(collection: MealLogModel.previewWeekMealsByDay.values.flatMap { $0 }),
            managerKey: Keys.mealLogManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        self.mealLogManager = MealLogManager(draftMealLogPersistence: draftMealLogPersistence, mealLogSyncEngine: mealLogSyncEngine)
        self.aiManager = AIManager(service: MockAIService())
        self.pushManager = PushManager(logManager: logManager)
        self.logManager = logManager
        self.reportManager = ReportManager(service: MockReportService(), userManager: userManager)
        self.healthKitManager = HealthKitManager(service: MockHealthService())
        let bodyMeasurementsSyncEngine = CollectionSyncEngine<BodyMeasurementEntry>(
            remote: MockRemoteCollectionService(collection: BodyMeasurementEntry.mocks),
            managerKey: Keys.bodyMeasurementsManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        bodyMeasurementsManager = BodyMeasurementsManager(
            bodyMeasurementsSyncEngine: bodyMeasurementsSyncEngine,
            healthKitService: ProductionHealthKitWeightService()
        )
        let stepsSyncEngine = CollectionSyncEngine<StepsModel>(
            remote: MockRemoteCollectionService(collection: StepsModel.mocks),
            managerKey: Keys.stepsManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        stepsManager = StepsManager(stepsSyncEngine: stepsSyncEngine, healthKitService: MockHealthKitStepsService())
        let userGoalSyncEngine = DocumentSyncEngine<WeightGoal>(
            remote: MockRemoteDocumentService(document: WeightGoal.mock()),
            managerKey: Keys.userGoalManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
        self.goalManager = GoalManager(userGoalSyncEngine: userGoalSyncEngine)
        self.streakManager = StreakManager(
            services: MockStreakServices(),
            configuration: StreakConfiguration(streakKey: "workout", leewayHours: 2),
            logger: logManager
        )
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        let unitPreferences = exerciseUnitPreferenceManager
        liveActivityManager = LiveActivityManager(logger: logManager, weightUnit: {
            unitPreferences.getPreference(for: $0).weightUnit.liveActivityUnit
        })
        hkWorkoutManager = HKWorkoutManager(logger: logManager, liveActivityUpdater: liveActivityManager)
        #endif

        self.appState = AppState(startingModuleId: isSignedIn ? Constants.tabBarModuleId : Constants.onboardingModuleId)
        self.imageUploadManager = ImageUploadManager(service: MockImageUploadService())
        self.commentsManager = CommentsManager(service: MockCommentsService())
        self.activityNotificationManager = ActivityNotificationManager(service: MockActivityNotificationService())
        self.stravaManager = StravaManager(service: MockStravaService(), clientId: "", clientSecret: "")
        self.hapticManager = HapticManager()
        self.soundEffectManager = SoundEffectManager()

        if isSignedIn {
            Task { @MainActor in
                let mockUser = UserAuthInfo.mock(isAnonymous: false)
                try? await userManager.signIn(auth: mockUser, isNewUser: false)
                async let workoutSettingsSignIn: () = workoutSettingsManager.signIn(userId: mockUser.uid, isNewUser: false)
                async let exerciseSettingsSignIn: () = exerciseSettingsManager.signIn(userId: mockUser.uid)
                async let foodLogSettingsSignIn: () = foodLogSettingsManager.signIn(userId: mockUser.uid, isNewUser: false)
                async let nutritionStrategySettingsSignIn: () = nutritionStrategySettingsManager.signIn(
                    userId: mockUser.uid, isNewUser: false
                )
                async let analyticsSettingsSignIn: () = analyticsSettingsManager.signIn(userId: mockUser.uid, isNewUser: false)
                async let shortcutSettingsSignIn: () = shortcutSettingsManager.signIn(userId: mockUser.uid, isNewUser: false)
                async let stepsSignIn: () = stepsManager.signIn()
                async let workoutTemplatesSignIn: () = workoutTemplateManager.signIn()
                async let gymProfileSignIn: () = gymProfileManager.signIn()
                async let trainingProgramSignIn: () = trainingProgramManager.signIn(userId: mockUser.uid)
                async let workoutSessionSignIn: () = workoutSessionManager.signIn(userId: mockUser.uid)
                async let exerciseSignIn: () = exerciseModelManager.signIn(userId: mockUser.uid)
                async let recipeTemplatesSignIn: () = recipeTemplateManager.signIn()
                async let foodsSignIn: () = foodManager.signIn()
                async let nutritionSignIn: () = nutritionManager.signIn(dietPlanId: mockUser.uid)
                async let mealLogSignIn: () = mealLogManager.signIn(userId: mockUser.uid)
                async let bodyMeasurementsSignIn: () = bodyMeasurementsManager.signIn(userId: mockUser.uid)
                async let goalSignIn: () = goalManager.signIn(userId: mockUser.uid)
                try? await workoutSettingsSignIn
                await exerciseSettingsSignIn
                try? await foodLogSettingsSignIn
                try? await nutritionStrategySettingsSignIn
                try? await analyticsSettingsSignIn
                try? await shortcutSettingsSignIn
                await stepsSignIn
                await workoutTemplatesSignIn
                await gymProfileSignIn
                await trainingProgramSignIn
                await workoutSessionSignIn
                await exerciseSignIn
                await recipeTemplatesSignIn
                await foodsSignIn
                try? await nutritionSignIn
                await mealLogSignIn
                await bodyMeasurementsSignIn
                try? await goalSignIn
            }
        }
    }

    // MARK: - ProgressPhotos
    lazy var nutritionStrategyManager = NutritionStrategyManager(
        dayAnnotationSyncEngine: CollectionSyncEngine<NutritionDayAnnotation>(
            remote: MockRemoteCollectionService(collection: []),
            managerKey: Keys.nutritionDayAnnotationManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        ),
        loggingBreakSyncEngine: DocumentSyncEngine<LoggingBreak>(
            remote: MockRemoteDocumentService(document: nil),
            managerKey: Keys.loggingBreakManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        ),
        checkInRecordSyncEngine: DocumentSyncEngine<CheckInRecord>(
            remote: MockRemoteDocumentService(document: nil),
            managerKey: Keys.checkInRecordManagerKey,
            enableLocalPersistence: false,
            logger: logManager
        )
    )

    lazy var progressPhotoManager = ProgressPhotoManager(
        syncEngine: CollectionSyncEngine<ProgressPhotoModel>(
            remote: MockRemoteCollectionService(collection: ProgressPhotoModel.mocks),
            managerKey: "progress_photos",
            enableLocalPersistence: false
        ),
        imageUploadManager: imageUploadManager
    )
}
