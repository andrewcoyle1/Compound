//
//  CoreInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/10/2025.
//

import Foundation
import UserNotifications
import UIKit
import HealthKit
import ActivityKit

enum CoreInteractorError: Error {
    case incompleteUserBuilder
}

@MainActor
struct CoreInteractor: GlobalInteractor {
    let authManager: AuthManager
    let userManager: UserManager
    let abTestManager: ABTestManager
    let purchaseManager: PurchaseManager
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
    let logManager: LogManager
    let reportManager: ReportManager
    let healthKitManager: HealthKitManager
    let bodyMeasurementsManager: BodyMeasurementsManager
    let stepsManager: StepsManager
    let goalManager: GoalManager
    let imageUploadManager: ImageUploadManager
    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
    let hkWorkoutManager: HKWorkoutManager
    let liveActivityManager: LiveActivityManager
    #endif
    let streakManager: StreakManager
    let commentsManager: CommentsManager
    let activityNotificationManager: ActivityNotificationManager
    let stravaManager: StravaManager
    let openFoodFactsService: any OpenFoodFactsService
    let appState: AppState
    let premiumEntitlementResolution: PremiumEntitlementResolution
    let hapticManager: HapticManager
    let soundEffectManager: SoundEffectManager
    // MARK: - Sharing
    let shareManager: ShareManager
    // MARK: - Challenges
    let challengeManager: ChallengeManager
    // MARK: - Invites
    let inviteManager: InviteManager
    // MARK: - ProgressPhotos
    let progressPhotoManager: ProgressPhotoManager

    init(container: DependencyContainer) {
        // Safe: Dependencies registers every one of these for every BuildConfiguration.
        self.authManager = container.resolve(AuthManager.self)!
        self.userManager = container.resolve(UserManager.self)!
        self.abTestManager = container.resolve(ABTestManager.self)!
        self.purchaseManager = container.resolve(PurchaseManager.self)!
        self.exerciseModelManager = container.resolve(ExerciseModelManager.self)!
        self.exerciseUnitPreferenceManager = container.resolve(ExerciseUnitPreferenceManager.self)!
        self.workoutSettingsManager = container.resolve(WorkoutSettingsManager.self)!
        self.foodLogSettingsManager = container.resolve(FoodLogSettingsManager.self)!
        self.nutritionStrategySettingsManager = container.resolve(NutritionStrategySettingsManager.self)!
        self.nutritionStrategyManager = container.resolve(NutritionStrategyManager.self)!
        self.analyticsSettingsManager = container.resolve(AnalyticsSettingsManager.self)!
        self.shortcutSettingsManager = container.resolve(ShortcutSettingsManager.self)!
        self.exerciseSettingsManager = container.resolve(ExerciseSettingsManager.self)!
        self.workoutTemplateManager = container.resolve(WorkoutTemplateManager.self)!
        self.workoutSessionManager = container.resolve(WorkoutSessionManager.self)!
        self.trainingProgramManager = container.resolve(TrainingProgramManager.self)!
        self.gymProfileManager = container.resolve(GymProfileManager.self)!
        self.foodManager = container.resolve(FoodManager.self)!
        self.recipeTemplateManager = container.resolve(RecipeTemplateManager.self)!
        self.nutritionManager = container.resolve(NutritionManager.self)!
        self.mealLogManager = container.resolve(MealLogManager.self)!
        self.pushManager = container.resolve(PushManager.self)!
        self.aiManager = container.resolve(AIManager.self)!
        self.logManager = container.resolve(LogManager.self)!
        self.reportManager = container.resolve(ReportManager.self)!
        self.healthKitManager = container.resolve(HealthKitManager.self)!
        self.bodyMeasurementsManager = container.resolve(BodyMeasurementsManager.self)!
        self.stepsManager = container.resolve(StepsManager.self)!
        self.goalManager = container.resolve(GoalManager.self)!
        self.imageUploadManager = container.resolve(ImageUploadManager.self)!
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        self.hkWorkoutManager = container.resolve(HKWorkoutManager.self)!
        self.liveActivityManager = container.resolve(LiveActivityManager.self)!
        #endif
        self.streakManager = container.resolve(StreakManager.self)!
        self.commentsManager = container.resolve(CommentsManager.self)!
        self.activityNotificationManager = container.resolve(ActivityNotificationManager.self)!
        self.stravaManager = container.resolve(StravaManager.self)!
        self.openFoodFactsService = container.resolve(OpenFoodFactsServiceContainer.self)!.service
        self.appState = container.resolve(AppState.self)!
        self.premiumEntitlementResolution = container.resolve(PremiumEntitlementResolution.self)!

        self.hapticManager = container.resolve(HapticManager.self)!
        self.soundEffectManager = container.resolve(SoundEffectManager.self)!
        // MARK: - Sharing
        self.shareManager = container.resolve(ShareManager.self)!
        // MARK: - Challenges
        self.challengeManager = container.resolve(ChallengeManager.self)!
        // MARK: - Invites
        self.inviteManager = container.resolve(InviteManager.self)!
        // MARK: - ProgressPhotos
        self.progressPhotoManager = container.resolve(ProgressPhotoManager.self)!
    }

    // MARK: Shared
    
    // One concurrent fan-out over every manager's sign-in. `async let` bindings have to be awaited
    // in the scope that declares them, so splitting this in two would mean either serialising the
    // sign-ins or threading twenty task handles through a carrier type — the same trade-off that
    // exempts `Dependencies.init`. Adding a manager adds two lines here, which is the cost of the
    // concurrency.
    // swiftlint:disable:next function_body_length
    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws {
        try await userManager.signIn(auth: user, isNewUser: isNewUser)
        async let workoutSettingsSignIn: () = workoutSettingsManager.signIn(userId: user.uid, isNewUser: isNewUser)
        async let foodLogSettingsSignIn: () = foodLogSettingsManager.signIn(userId: user.uid, isNewUser: isNewUser)
        async let nutritionStrategySignIn: () = nutritionStrategySettingsManager.signIn(
            userId: user.uid, isNewUser: isNewUser
        )
        async let nutritionStrategyDataSignIn: () = nutritionStrategyManager.signIn(userId: user.uid)
        async let analyticsSettingsSignIn: () = analyticsSettingsManager.signIn(userId: user.uid, isNewUser: isNewUser)
        async let shortcutSettingsSignIn: () = shortcutSettingsManager.signIn(userId: user.uid, isNewUser: isNewUser)
        async let exerciseSettingsSignIn: () = exerciseSettingsManager.signIn(userId: user.uid)
        async let stepsSignIn: () = stepsManager.signIn()
        async let workoutTemplatesSignIn: () = workoutTemplateManager.signIn()
        async let gymProfileSignIn: () = gymProfileManager.signIn()
        async let trainingProgramSignIn: () = trainingProgramManager.signIn(userId: user.uid)
        // Not `currentUser` directly: on a fresh install the listener has not delivered the
        // profile yet, and an empty list here left the feed and the circle empty until relaunch.
        let followingIds = await userManager.currentUserOrFetched(userId: user.uid)?.followingIds ?? []
        async let workoutSessionSignIn: () = workoutSessionManager.signIn(userId: user.uid, followingIds: followingIds)
        async let followingUsersSignIn: () = userManager.refreshFollowingUsers(followingIds: followingIds)
        async let exerciseSignIn: () = exerciseModelManager.signIn(userId: user.uid)
        async let recipeTemplatesSignIn: () = recipeTemplateManager.signIn()
        async let foodsSignIn: () = foodManager.signIn()
        async let nutritionSignIn: () = nutritionManager.signIn(dietPlanId: user.uid)
        async let mealLogSignIn: () = mealLogManager.signIn(userId: user.uid)
        async let bodyMeasurementsSignIn: () = bodyMeasurementsManager.signIn(userId: user.uid)
        async let goalSignIn: () = goalManager.signIn(userId: user.uid)
        async let streakSignIn: () = streakManager.logIn(userId: user.uid)

        try await workoutSettingsSignIn
        try await foodLogSettingsSignIn
        try await nutritionStrategySignIn
        try await nutritionStrategyDataSignIn
        try await analyticsSettingsSignIn
        try await shortcutSettingsSignIn
        await exerciseSettingsSignIn
        await trainingProgramSignIn
        try await nutritionSignIn
        try await goalSignIn
        await stepsSignIn
        await workoutTemplatesSignIn
        await gymProfileSignIn
        await workoutSessionSignIn
        await followingUsersSignIn
        await exerciseSignIn
        await recipeTemplatesSignIn
        await foodsSignIn
        await mealLogSignIn
        await bodyMeasurementsSignIn
        try await streakSignIn

        // Seed system content after all sync engines have started listening,
        // so local persistence is loaded and allExercises is populated before
        // workout templates try to resolve exercises by ID.
        try? exerciseModelManager.seedExercisesIfNeeded()
        try? workoutTemplateManager.seedWorkoutTemplatesIfNeeded(exercises: exerciseModelManager.allExercises)
        try? trainingProgramManager.seedProgramsIfNeeded(workouts: workoutTemplateManager.systemWorkoutTemplates)

        // A push tapped to launch the app waits for this point; see `PushManager.pendingDeepLink`.
        routePendingDeepLinkAfterLogIn()

        try await purchaseManager.logIn(
            userId: user.uid,
            userAttributes: PurchaseProfileAttributes(
                email: user.email,
                mixpanelDistinctId: Constants.mixpanelDistinctId,
                firebaseAppInstanceId: Constants.firebaseAnalyticsAppInstanceID
            )
        )
        // The one moment the store has definitively answered. Until this lands, `isPremium` cannot
        // tell "no subscription" from "no answer yet" and stays optimistic; if the store throws
        // (offline, most often) this line is skipped, `logIn` rethrows, and the caller retries — so
        // the question gets asked again rather than answered wrongly.
        premiumEntitlementResolution.markResolved()
        logManager.addUserProperties(dict: Utilities.offDeviceEventParameters, isHighPriority: false)

        activityNotificationManager.startListening(userId: user.uid)
    }

    func signOut() async throws {
        try authManager.signOut()
        try await purchaseManager.logOut()
        premiumEntitlementResolution.reset()
        userManager.signOut()
        stopListeningBeforeAccountDeletion()
        pushManager.setReadyForDeepLinks(false)
    }
    
    func deleteAccount() async throws {
        guard let auth else {
            throw AppError("Auth not found.")
        }
        
        var option: SignInOption = .anonymous
        if auth.authProviders.contains(.apple) {
            option = .apple
        } else if auth.authProviders.contains(.google), let clientId = Constants.firebaseAppClientId {
            option = .google(GIDClientID: clientId)
        }

        // Delete auth
        try await authManager.deleteAccountWithReauthentication(option: option, revokeToken: false) {
            // Must run inside this closure, before Auth is revoked and the rules shut the user out.
            // Only the user document is deleted here; the onUserDeleted Cloud Function deletes the
            // rest, so every listener is stopped first rather than left watching it disappear.
            stopListeningBeforeAccountDeletion()
            try await userManager.deleteCurrentUser(userId: auth.uid)
        }

        // Delete Purchases (RevenueCat)
        try await purchaseManager.logOut()
        
        // Delete logs (Mixpanel)
        logManager.deleteUserProfile()
    }
    
    func startWorkout(for template: WorkoutTemplateModel, in trainingProgramId: String?) async throws {
        guard let userId = self.userId else { throw CoreError.noCurrentUser }
        var unitPreferences: [String: ExerciseUnitPreference] = [:]
        for exerciseModel in template.exercises {
            let preference = self.getPreference(templateId: exerciseModel.exercise.id)
            unitPreferences[exerciseModel.exercise.id] = preference
        }
        let previousSession = try await self.workoutSessionManager.getLastWorkoutSessionForTemplate(templateId: template.id)
        let prefill = await sessionPrefill(
            for: template,
            authorId: userId,
            trainingProgramId: trainingProgramId,
            unitPreferences: unitPreferences
        )

        let session = WorkoutSessionModel(
            authorId: userId,
            template: template,
            notes: nil,
            trainingProgramId: trainingProgramId,
            previousWorkoutSession: previousSession,
            unitPreferences: unitPreferences,
            prefill: prefill
        )
        
        try self.updateActiveSession(session)
        hkWorkoutManager.startWorkout(workout: session)
        ensureLiveActivity(session: session)
    }
    
    /// A session with no template and no exercises; the tracker adds exercises as it goes.
    /// "Start Empty Workout" used to run the template wizard and save a template first.
    func startBlankWorkout() async throws {
        guard let userId = self.userId else { throw CoreError.noCurrentUser }
        let session = WorkoutSessionModel(authorId: userId, name: "Workout", dateCreated: .now, exercises: [])
        try self.updateActiveSession(session)
        hkWorkoutManager.startWorkout(workout: session)
        ensureLiveActivity(session: session)
    }

    func deleteActiveSession() throws {
        try workoutSessionManager.deleteActiveSession()
        hkWorkoutManager.discardWorkout()
    }
                            
    func syncAllRemoteDataIfLoggedIn() async {
        NotificationCenter.default.post(name: Constants.remoteDataSyncDidComplete, object: nil)
    }
}

enum CoreError: LocalizedError { case noCurrentUser }
