//
//  SearchQuickActionTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The Search tab's shortcut row. Every `QuickAction` has to land somewhere, and the switch in the
/// presenter is what makes a new case a compile error until it does; these pin where each one goes.
@MainActor
struct SearchQuickActionTests {

    private final class Interactor: SpyGlobalInteractor, SearchInteractor {
        var shortcutSettings: ShortcutSettings = ShortcutSettings(authorId: "user-1")
        var userImageUrl: String?
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var draftMeal: MealLogModel?
        var recentSearchQueries: [String] = []
        var followingIds: [String] = []
        var allExercises: [ExerciseModel] = []
        var allWorkoutTemplates: [WorkoutTemplateModel] = []
        var userRecipeTemplates: [RecipeTemplateModel] = []
        var foods: [FoodModel] = []
        var followingUsers: [UserModel] = []
        var activeSession: WorkoutSessionModel?
        private(set) var blankWorkoutStarts = 0
        func acceptInvite(code: String) async throws -> (inviter: UserModel, acceptance: InviteAcceptance) {
            throw InviteError.notFound
        }

        func startWorkout(for template: WorkoutTemplateModel, in trainingProgramId: String?) async throws { }
        func startBlankWorkout() async throws { blankWorkoutStarts += 1 }
        func deleteActiveSession() throws { activeSession = nil }
        func searchUsers(query: String) async throws -> [UserModel] { [] }
        func addRecentSearch(query: String) { }
        func clearRecentSearches() { recentSearchQueries = [] }
        func followUser(userId: String) async throws { }
        func unfollowUser(userId: String) async throws { }
        var sentFollowRequestIds: Set<String> = []
        func sendFollowRequest(to user: UserModel) async throws { sentFollowRequestIds.insert(user.userId) }
        func cancelFollowRequest(userId: String) async throws { sentFollowRequestIds.remove(userId) }
    }

    private final class Router: SearchRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var exerciseListDelegates: [ExerciseListBuilderDelegate] = []
        private(set) var exerciseDetailIds: [String] = []

        func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID) { shown.append("profile") }
        func showExerciseDetailView(templateId: String, name: String, delegate: ExerciseDetailDelegate, themeColor: Color?) {
            shown.append("exerciseDetail")
            exerciseDetailIds.append(templateId)
        }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { shown.append("workoutDetail") }
        func showRecipeDetailView(delegate: RecipeDetailDelegate) { shown.append("recipeDetail") }
        func showFoodDetailView(delegate: FoodDetailDelegate) { shown.append("foodDetail") }
        func showSocialProfileView(delegate: SocialProfileDelegate) { shown.append("socialProfile") }
        func showRecipesView() { shown.append("recipes") }
        func showAddMealView(delegate: AddMealDelegate) { shown.append("addMeal") }
        func showCreateExerciseView() { shown.append("createExercise") }
        func showCreateWorkoutView(delegate: CreateWorkoutDelegate) { shown.append("createWorkout") }
        func showCreateFoodView(delegate: CreateFoodDelegate) { shown.append("createFood") }
        func showCreateRecipeView() { shown.append("createRecipe") }
        func showExerciseListBuilderView(delegate: ExerciseListBuilderDelegate) {
            shown.append("exerciseList")
            exerciseListDelegates.append(delegate)
        }
        func showWorkoutTrackerView() { shown.append("workoutTracker") }
        func showLogWeightView() { shown.append("logWeight") }
        func showBodyMetricsView(delegate: BodyMetricsDelegate) { shown.append("bodyMetrics") }
        func showShortcutsView(delegate: ShortcutsDelegate) { shown.append("shortcuts") }
    }

    private struct Screen {
        let presenter: SearchPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(presenter: SearchPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    @Test("Test Each Shortcut Opens The Screen It Names", arguments: [
        (QuickAction.logMeal, "addMeal"),
        (.logWeight, "logWeight"),
        (.logMeasurement, "bodyMetrics"),
        (.addExercise, "createExercise"),
        (.newWorkout, "createWorkout"),
        (.newFood, "createFood"),
        (.newRecipe, "createRecipe"),
        (.browseExercises, "exerciseList"),
        (.browseRecipes, "recipes")
    ])
    func testEachShortcutOpensTheScreenItNames(action: QuickAction, destination: String) {
        let screen = makeScreen()

        screen.presenter.onQuickActionPressed(action)

        #expect(screen.router.shown == [destination])
    }

    /// "Start Workout" opened the workout library, which starts nothing.
    @Test("Test Start Workout Starts A Blank Session And Opens The Tracker")
    func testStartWorkoutStartsABlankSessionAndOpensTheTracker() async {
        let screen = makeScreen()

        screen.presenter.onQuickActionPressed(.startWorkout)

        #expect(await TestManagers.eventually { screen.router.shown == ["workoutTracker"] })
        #expect(screen.interactor.blankWorkoutStarts == 1)
    }

    /// The old "Workouts" shortcut opened the same library. A row curated with it in an earlier
    /// build must still decode, minus that one.
    @Test("Test The Retired Browse Workouts Id Decodes To Nothing")
    func testTheRetiredBrowseWorkoutsIdDecodesToNothing() {
        var settings = ShortcutSettings(authorId: "user-1")
        settings.quickActionIds = ["browse_workouts", "log_meal"]

        #expect(settings.quickActions == [.logMeal])
    }

    /// The list has no destination of its own: it hands a tapped row to the closure the caller
    /// supplied. "Browse Exercises" opened it with an empty delegate, so the screen it opened was a
    /// dead end — every row tapped into a nil closure and nothing happened.
    @Test("Test A Browsed Exercise Opens Its Detail")
    func testABrowsedExerciseOpensItsDetail() {
        let screen = makeScreen()

        screen.presenter.onQuickActionPressed(.browseExercises)
        screen.router.exerciseListDelegates.first?.onExerciseSelectionChanged?(searchExercise(id: "ex-1"))

        #expect(screen.router.shown == ["exerciseList", "exerciseDetail"])
        #expect(screen.router.exerciseDetailIds == ["ex-1"])
    }

    @Test("Test An Empty Row Offers The Shortcuts Screen")
    func testAnEmptyRowOffersTheShortcutsScreen() {
        let screen = makeScreen()

        screen.presenter.onChooseShortcutsPressed()

        #expect(screen.router.shown == ["shortcuts"])
    }
}

@MainActor
func searchExercise(
    id: String,
    name: String = "Bench Press",
    muscles: [Muscles: MuscleTargetType] = [.chest: .primary],
    alternateNames: [String] = []
) -> ExerciseModel {
    ExerciseModel(
        id: id,
        authorId: "user-1",
        name: name,
        trackableMetrics: [.weight, .reps],
        type: .compoundUpper,
        laterality: .bilateral,
        muscleGroups: muscles,
        isBodyweight: false,
        rangeOfMotion: 4,
        stability: 5,
        bodyWeightContribution: 0,
        alternateNames: alternateNames
    )
}
