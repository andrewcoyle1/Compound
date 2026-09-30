//
//  AppViewForUITesting.swift
//  DialedIn
//
//  Created by Andrew Coyle on 29/01/2026.
//

import SwiftUI

/// The root under `UI_TESTING`. A `STARTSCREEN_*` launch argument opens one flow directly on
/// its own router, signed in to the mock scenario the way `AppView` would be, so a UI test does
/// not have to walk the tab bar to reach it.
struct AppViewForUITesting: View {
    
    var container: DependencyContainer
    
    private var interactor: CoreInteractor {
        CoreInteractor(container: container)
    }

    private var builder: CoreBuilder {
        CoreBuilder(interactor: interactor)
    }
    
    private func processInfoContains(_ value: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(value)
    }

    var body: some View {
        if processInfoContains("STARTSCREEN_CREATE_EXERCISE") {
            startScreen { builder.createExerciseView(router: $0) }
        } else if processInfoContains("STARTSCREEN_CREATE_WORKOUT") {
            startScreen { builder.createWorkoutView(router: $0, delegate: CreateWorkoutDelegate()) }
        } else if processInfoContains("STARTSCREEN_CREATE_PROGRAM") {
            startScreen { builder.createMesocycleView(router: $0, delegate: CreateMesocycleDelegate()) }
        } else if processInfoContains("STARTSCREEN_SOCIAL_PROFILE") {
            startScreen { builder.socialProfileView(router: $0, delegate: SocialProfileDelegate(user: UserModel.mocks[2])) }
        } else if processInfoContains("STARTSCREEN_COMMENTS") {
            // The shipped mock comments all sit on "session-1".
            let session = WorkoutSessionModel.mocks.first { $0.id == "session-1" } ?? .mock
            startScreen { builder.commentsView(router: $0, delegate: CommentsDelegate(session: session)) }
        } else if processInfoContains("STARTSCREEN_OWN_PROFILE") {
            startScreen { builder.socialProfileView(router: $0, delegate: SocialProfileDelegate(user: UserModel.mocks[0])) }
        } else if processInfoContains("STARTSCREEN_NOTIFICATIONS") {
            startScreen { builder.notificationsView(router: $0) }
        } else if processInfoContains("STARTSCREEN_NOTIFICATION_SETTINGS") {
            startScreen { builder.notificationSettingsView(delegate: NotificationSettingsDelegate(), router: $0) }
        } else if processInfoContains("STARTSCREEN_USERNAME") {
            startScreen { builder.editUsernameView(router: $0) }
        } else if processInfoContains("STARTSCREEN_SHARED_ITEM") {
            // MARK: - Sharing
            startScreen { builder.sharedItemView(router: $0, delegate: SharedItemDelegate(share: ShareModel.mocks[0], senderName: "Alice")) }
        } else if processInfoContains("STARTSCREEN_SHARE_CARD") {
            // The card alone, full screen, for a screenshot. Later mock sessions carry records.
            WorkoutShareCardView(content: .preview, format: .story)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
        } else if let screen = challengesScreen {
            // MARK: - Challenges
            startScreen { screen($0) }
        } else if let screen = progressPhotosScreen {
            // MARK: - ProgressPhotos
            startScreen { screen($0) }
        } else if let screen = screenDeckScreen {
            // MARK: - ScreenDeck
            startScreen { screen($0) }
        } else {
            builder.build()
        }
    }

    /// The flows are covers in the app, so they are presented as covers here too: a flow mounted
    /// as the root could not dismiss itself. The sign-in `AppView` performs at launch has already
    /// happened by the time a cover opens in the app; here nothing else does it.
    private func startScreen<Screen: View>(@ViewBuilder _ screen: @escaping (AnyRouter) -> Screen) -> some View {
        RouterView { router in
            Color.clear
                .task {
                    if let auth = interactor.auth {
                        try? await interactor.logIn(user: auth, isNewUser: false)
                    }
                    router.showScreen(.fullScreenCover) { router in
                        screen(router)
                    }
                }
        }
    }
}

// MARK: - ScreenDeck

/// One `STARTSCREEN_*` argument per top-level and major detail screen, for the screenshot deck.
/// `scripts/screenshots.sh` finds every argument by grepping this file for `"STARTSCREEN_`, so a
/// new entry here (or a new branch above) is picked up by the next run without touching the script.
extension AppViewForUITesting {

    private var screenDeckScreen: ((AnyRouter) -> AnyView)? {
        let arguments = ProcessInfo.processInfo.arguments
        return screenDeck.first { arguments.contains($0.argument) }?.screen
    }

    private var screenDeck: [(argument: String, screen: (AnyRouter) -> AnyView)] {
        let builder = builder
        let interactor = interactor
        return [
            ("STARTSCREEN_TODAY", { builder.todayView(router: $0, delegate: TodayDelegate()).any() }),
            ("STARTSCREEN_SOCIAL", { builder.socialView(router: $0, delegate: SocialDelegate()).any() }),
            ("STARTSCREEN_TRAINING", { builder.trainingView(delegate: TrainingDelegate(), router: $0).any() }),
            ("STARTSCREEN_WORKOUT_TRACKER", { router in
                ActiveSessionScreen(interactor: interactor) { try? builder.workoutTrackerView(router: router) }.any()
            }),
            ("STARTSCREEN_TEMPLATE_DETAIL", {
                builder.workoutTemplateDetailView(
                    router: $0,
                    delegate: WorkoutTemplateDetailDelegate(workoutTemplate: .mock, mesocycleId: nil, onStartWorkoutPressed: nil)
                ).any()
            }),
            ("STARTSCREEN_PROGRAM_LIBRARY", { builder.mesocycleLibraryView(router: $0).any() }),
            ("STARTSCREEN_MACROCYCLES", { builder.macrocyclesView(router: $0).any() }),
            ("STARTSCREEN_MACROCYCLE_DETAIL", {
                builder.macrocycleDetailView(router: $0, delegate: MacrocycleDetailDelegate(macrocycle: .mock)).any()
            }),
            ("STARTSCREEN_WORKOUTS", { builder.workoutsView(router: $0, delegate: WorkoutsDelegate()).any() }),
            // Two muscles already chosen, so both badges are in the shot.
            ("STARTSCREEN_MUSCLE_PICKER", { router in
                let presenter = MuscleGroupPickerPresenter(interactor: interactor, router: CoreRouter(router: router, builder: builder))
                presenter.selectedMuscleGroups = [.triceps: .primary, .upperTraps: .secondary]
                return MuscleGroupPickerView(
                    presenter: presenter,
                    delegate: MuscleGroupPickerDelegate(name: "Dip", trackableMetricA: .reps, trackableMetricB: nil, exerciseType: nil, laterality: nil)
                ).any()
            }),
            ("STARTSCREEN_ACTIVE_PROGRAM", { router in
                // A List section, so it needs the List the Training tab gives it.
                List { builder.activeMesocycleView(router: router, delegate: ActiveMesocycleDelegate(mesocycle: .mock)) }.any()
            }),
            ("STARTSCREEN_EXERCISE_DETAIL", {
                builder.exerciseModelDetailView(router: $0, delegate: ExerciseModelDetailDelegate(exerciseModel: .mock)).any()
            }),
            ("STARTSCREEN_EXERCISES", { builder.exercisesView(router: $0).any() }),
            ("STARTSCREEN_WORKOUT_HISTORY", { builder.workoutHistoryView(router: $0).any() }),
            ("STARTSCREEN_SESSION_DETAIL", {
                builder.workoutSessionDetailView(router: $0, delegate: WorkoutSessionDetailDelegate(workoutSession: .mock)).any()
            }),
            ("STARTSCREEN_GYM_PROFILES", { builder.gymProfilesView(router: $0).any() }),
            ("STARTSCREEN_NUTRITION", { builder.nutritionView(delegate: NutritionDelegate(), router: $0).any() }),
            ("STARTSCREEN_MEAL_DETAIL", { builder.mealDetailView(router: $0, delegate: MealDetailDelegate(meal: .mock)).any() }),
            ("STARTSCREEN_RECIPES", { builder.recipesView(router: $0).any() }),
            ("STARTSCREEN_RECIPE_DETAIL", {
                builder.recipeDetailView(router: $0, delegate: RecipeDetailDelegate(recipeTemplate: .mock)).any()
            }),
            ("STARTSCREEN_FOODS", { builder.foodsView(router: $0).any() }),
            ("STARTSCREEN_FOOD_DETAIL", { builder.foodDetailView(router: $0, delegate: FoodDetailDelegate(food: .mock)).any() }),
            ("STARTSCREEN_CREATE_FOOD", { builder.createFoodView(router: $0, delegate: CreateFoodDelegate()).any() }),
            ("STARTSCREEN_MEAL_DESCRIBE", { builder.mealDescribeView(router: $0, delegate: MealDescribeDelegate(onPick: { _ in })).any() }),
            // One item already on the plate, so the "N on plate" toolbar text and a quick-add
            // checkmark have something to show.
            ("STARTSCREEN_NUTRITION_LIBRARY_PICKER", { router in
                builder.nutritionLibraryPickerView(
                    router: router,
                    delegate: NutritionLibraryPickerDelegate(items: .constant([.mock]), onPick: { _ in })
                ).any()
            }),
            ("STARTSCREEN_ANALYTICS", { builder.analyticsView(delegate: AnalyticsDelegate(), router: $0).any() }),
            ("STARTSCREEN_BODY_METRICS", { builder.bodyMetricsView(router: $0, delegate: BodyMetricsDelegate()).any() }),
            ("STARTSCREEN_SCALE_WEIGHT", { builder.scaleWeightView(router: $0, delegate: ScaleWeightDelegate()).any() }),
            ("STARTSCREEN_MEASUREMENT_DETAIL", { builder.bodyMeasurementDetailView(router: $0, kind: .waist).any() }),
            ("STARTSCREEN_LOG_WEIGHT", { builder.logWeightView(router: $0).any() }),
            ("STARTSCREEN_LOG_MEASUREMENT", { builder.logMeasurementView(router: $0, kind: .waist).any() }),
            ("STARTSCREEN_NUTRITION_ANALYTICS", {
                builder.nutritionAnalyticsView(router: $0, delegate: NutritionAnalyticsDelegate()).any()
            }),
            ("STARTSCREEN_PROFILE", { builder.profileView(router: $0).any() }),
            ("STARTSCREEN_ACCOUNT", { builder.accountView(router: $0, delegate: AccountDelegate()).any() }),
            ("STARTSCREEN_DELETE_ACCOUNT", { builder.deleteAccountView(router: $0).any() }),
            ("STARTSCREEN_SIRI", { builder.siriView(router: $0, delegate: SiriDelegate()).any() }),
            ("STARTSCREEN_WHY_SUBSCRIBE", { builder.subscriptionView(router: $0).any() }),
            ("STARTSCREEN_PAYWALL", { builder.paywallView(router: $0, isOnboarding: true).any() }),
            ("STARTSCREEN_FOLLOWERS", {
                builder.followersListView(router: $0, delegate: FollowersListDelegate(followers: UserModel.mocks)).any()
            }),
            // MARK: - Invites
            // Social receiving the mock invite link, as a tapped `compound://join/` would.
            ("STARTSCREEN_INVITE", { router in
                builder.socialView(router: router, delegate: SocialDelegate())
                    .task {
                        try? await Task.sleep(for: .seconds(1))
                        DeepLink.join(code: MockInviteService.sampleCode).post()
                    }
                    .any()
            }),
            // MARK: - Keyboards
            // The tracker with the first set's weight keyboard open; `SetKeyboardLaunch` opens it.
            ("STARTSCREEN_SET_KEYBOARD", { router in
                ActiveSessionScreen(interactor: interactor) { try? builder.workoutTrackerView(router: router) }.any()
            }),
            // MARK: - Tab bar accessory
            // The whole tab bar, so the accessory above it is in the shot: a workout, a workout
            // resting, and a draft meal.
            ("STARTSCREEN_TAB_ACCESSORY_WORKOUT", { router in
                ActiveSessionScreen(interactor: interactor) { builder.tabBarView(router: router) }.any()
            }),
            ("STARTSCREEN_TAB_ACCESSORY_REST", { router in
                ActiveSessionScreen(interactor: interactor) { builder.tabBarView(router: router) }
                    .task {
                        try? await Task.sleep(for: .seconds(1))
                        guard let session = interactor.activeSession else { return }
                        interactor.startRest(durationSeconds: 90, session: session, currentExerciseIndex: 0)
                    }
                    .any()
            }),
            ("STARTSCREEN_TAB_ACCESSORY_MEAL", { router in
                builder.tabBarView(router: router)
                    .task { try? interactor.updateDraftMeal(.mock) }
                    .any()
            }),
            // MARK: - WeeklyReview
            ("STARTSCREEN_WEEKLY_REVIEW", { builder.weeklyReviewView(router: $0).any() }),
            // MARK: - Muscle Balance
            ("STARTSCREEN_MUSCLE_BALANCE", { builder.muscleBalanceView(router: $0).any() })
        ]
    }
}

/// Starts a workout from the mock template before showing the tracker, which cannot be built
/// without an active session. The mock scenario keeps the session in memory, so it does not
/// leak into the next launch.
private struct ActiveSessionScreen<Content: View>: View {
    let interactor: CoreInteractor
    @ViewBuilder let content: () -> Content
    @State private var isReady = false

    var body: some View {
        if isReady {
            content()
        } else {
            ProgressView()
                .task {
                    try? await interactor.startWorkout(for: .mock, in: nil)
                    isReady = true
                }
        }
    }
}

// MARK: - Challenges

extension AppViewForUITesting {

    /// `STARTSCREEN_CHALLENGES` opens the create screen, `STARTSCREEN_CHALLENGE_DETAIL` the first
    /// seeded mock challenge's standings.
    private var challengesScreen: ((AnyRouter) -> AnyView)? {
        let arguments = ProcessInfo.processInfo.arguments
        let builder = builder
        if arguments.contains("STARTSCREEN_CHALLENGE_DETAIL") {
            return { builder.challengeDetailView(router: $0, delegate: ChallengeDetailDelegate(challenge: .mock)).any() }
        }
        if arguments.contains("STARTSCREEN_CHALLENGES") {
            return { builder.createChallengeView(router: $0).any() }
        }
        return nil
    }
}

// MARK: - ProgressPhotos

extension AppViewForUITesting {

    /// `STARTSCREEN_PROGRESS_PHOTOS` opens the grid on the two mock photos, whose images are
    /// asset-catalogue names.
    private var progressPhotosScreen: ((AnyRouter) -> AnyView)? {
        guard ProcessInfo.processInfo.arguments.contains("STARTSCREEN_PROGRESS_PHOTOS") else { return nil }
        let builder = builder
        return { builder.progressPhotosView(router: $0).any() }
    }
}
