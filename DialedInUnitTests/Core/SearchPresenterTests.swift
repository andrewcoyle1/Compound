//
//  SearchPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 24/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Searching itself: what matches, what waits on the network, what is remembered, and where a
/// result goes when tapped.
@MainActor
struct SearchPresenterTests {

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
        var remoteUsers: [UserModel] = []
        var remoteDelay: Duration = .zero
        private(set) var startedTemplateNames: [String] = []
        private(set) var didDeleteActiveSession = false
        private(set) var acceptedInviteCodes: [String] = []
        func acceptInvite(code: String) async throws -> (inviter: UserModel, acceptance: InviteAcceptance) {
            acceptedInviteCodes.append(code)
            return (UserModel(userId: "inviter"), InviteAcceptance(inviterId: "inviter", youFollow: .following, theyFollow: .following))
        }

        func startWorkout(for template: WorkoutTemplateModel, in trainingProgramId: String?) async throws {
            startedTemplateNames.append(template.name)
        }
        func startBlankWorkout() async throws { }
        func deleteActiveSession() throws { didDeleteActiveSession = true; activeSession = nil }
        func searchUsers(query: String) async throws -> [UserModel] {
            try? await Task.sleep(for: remoteDelay)
            return remoteUsers
        }
        func addRecentSearch(query: String) { recentSearchQueries.insert(query, at: 0) }
        func clearRecentSearches() { recentSearchQueries = [] }
        func followUser(userId: String) async throws { followingIds.append(userId) }
        func unfollowUser(userId: String) async throws { followingIds.removeAll { $0 == userId } }
        var sentFollowRequestIds: Set<String> = []
        func sendFollowRequest(to user: UserModel) async throws { sentFollowRequestIds.insert(user.userId) }
        func cancelFollowRequest(userId: String) async throws { sentFollowRequestIds.remove(userId) }
    }

    private final class Router: SearchRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var alertTitles: [String] = []
        private(set) var socialProfileUserIds: [String] = []

        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID) { shown.append("profile") }
        func showExerciseDetailView(templateId: String, name: String, delegate: ExerciseDetailDelegate, themeColor: Color?) {
            shown.append("exerciseDetail")
        }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { shown.append("workoutDetail") }
        func showRecipeDetailView(delegate: RecipeDetailDelegate) { shown.append("recipeDetail") }
        func showFoodDetailView(delegate: FoodDetailDelegate) { shown.append("foodDetail") }
        func showSocialProfileView(delegate: SocialProfileDelegate) {
            shown.append("socialProfile")
            socialProfileUserIds.append(delegate.user.userId)
        }
        func showRecipesView() { shown.append("recipes") }
        func showAddMealView(delegate: AddMealDelegate) { shown.append("addMeal") }
        func showCreateExerciseView() { shown.append("createExercise") }
        func showCreateWorkoutView(delegate: CreateWorkoutDelegate) { shown.append("createWorkout") }
        func showCreateFoodView(delegate: CreateFoodDelegate) { shown.append("createFood") }
        func showCreateRecipeView() { shown.append("createRecipe") }
        func showExerciseListBuilderView(delegate: ExerciseListBuilderDelegate) { shown.append("exerciseList") }
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
        interactor.allExercises = [
            searchExercise(id: "bench", name: "Bench Press", alternateNames: ["Flat Press"]),
            searchExercise(id: "squat", name: "Squat", muscles: [.quads: .primary])
        ]
        interactor.allWorkoutTemplates = [WorkoutTemplateModel(id: "push", authorId: "user-1", name: "Push Day")]
        interactor.followingUsers = [UserModel(userId: "friend", firstName: "Benny")]
        let router = Router()
        return Screen(presenter: SearchPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    // MARK: - Matching

    @Test("Test Every Library Is Matched On Name Ignoring Case And Punctuation")
    func testEveryLibraryIsMatchedOnNameIgnoringCaseAndPunctuation() {
        let screen = makeScreen()

        screen.presenter.searchString = " PUSH! "

        #expect(screen.presenter.filteredWorkoutTemplates.map(\.name) == ["Push Day"])
        #expect(screen.presenter.filteredExercises.isEmpty)
        #expect(screen.presenter.hasResults)
    }

    /// An exercise is also found by its other names and the muscles it works.
    @Test("Test An Exercise Is Found By Alternate Name And Muscle")
    func testAnExerciseIsFoundByAlternateNameAndMuscle() {
        let screen = makeScreen()

        screen.presenter.searchString = "chest"
        #expect(screen.presenter.filteredExercises.map(\.name) == ["Bench Press"])

        screen.presenter.searchString = "flat"
        #expect(screen.presenter.filteredExercises.map(\.name) == ["Bench Press"])
    }

    // MARK: - Loading

    /// The whole screen used to sit behind a spinner for the debounce plus the round trip, even
    /// though everything but People is in memory.
    @Test("Test Local Results Show While People Are Still Loading")
    func testLocalResultsShowWhilePeopleAreStillLoading() async {
        let screen = makeScreen()
        screen.interactor.remoteDelay = .seconds(5)

        screen.presenter.searchString = "ben"
        screen.presenter.performUnifiedSearch()

        #expect(screen.presenter.isLoadingPeople)
        #expect(screen.presenter.filteredExercises.map(\.name) == ["Bench Press"])
        #expect(screen.presenter.filteredUsers.map(\.userId) == ["friend"])
    }

    @Test("Test Remote People Join The Followed Ones When They Arrive")
    func testRemotePeopleJoinTheFollowedOnesWhenTheyArrive() async {
        let screen = makeScreen()
        screen.interactor.remoteUsers = [UserModel(userId: "stranger", firstName: "Ben")]

        screen.presenter.searchString = "ben"
        screen.presenter.performUnifiedSearch()

        #expect(await TestManagers.eventually { !screen.presenter.isLoadingPeople })
        #expect(screen.presenter.filteredUsers.map(\.userId) == ["friend", "stranger"])
    }

    // MARK: - Recents

    /// Recents were written after the debounce, so every pause mid-word became a saved search.
    @Test("Test A Query Is Remembered Only When Committed")
    func testAQueryIsRememberedOnlyWhenCommitted() async {
        let screen = makeScreen()

        screen.presenter.searchString = "pus"
        screen.presenter.performUnifiedSearch()
        #expect(await TestManagers.eventually { !screen.presenter.isLoadingPeople })
        #expect(screen.interactor.recentSearchQueries.isEmpty)

        screen.presenter.searchString = "push"
        screen.presenter.onSearchSubmitted()
        #expect(screen.interactor.recentSearchQueries == ["push"])

        screen.presenter.searchString = "squat"
        screen.presenter.onExercisePressed(exercise: searchExercise(id: "squat", name: "Squat"))
        #expect(screen.interactor.recentSearchQueries == ["squat", "push"])
    }

    @Test("Test Nothing Is Remembered For A Blank Query")
    func testNothingIsRememberedForABlankQuery() {
        let screen = makeScreen()

        screen.presenter.searchString = "  "
        screen.presenter.onSearchSubmitted()

        #expect(screen.interactor.recentSearchQueries.isEmpty)
    }

    // MARK: - Results that act

    /// The row offered Follow and nothing else; the person's profile was unreachable from search.
    @Test("Test Tapping A Person Opens Their Profile")
    func testTappingAPersonOpensTheirProfile() {
        let screen = makeScreen()

        screen.presenter.onUserPressed(user: UserModel(userId: "friend"))

        #expect(screen.router.shown == ["socialProfile"])
        #expect(screen.router.socialProfileUserIds == ["friend"])
    }

    @Test("Test A Workout Row Starts The Workout And Opens The Tracker")
    func testAWorkoutRowStartsTheWorkoutAndOpensTheTracker() async {
        let screen = makeScreen()

        screen.presenter.onStartWorkoutPressed(workout: WorkoutTemplateModel(id: "push", authorId: "user-1", name: "Push Day"))

        #expect(await TestManagers.eventually { screen.router.shown == ["workoutTracker"] })
        #expect(screen.interactor.startedTemplateNames == ["Push Day"])
    }

    /// With a workout already running, the row asks rather than replacing it.
    @Test("Test Starting A Workout While One Is Running Asks First")
    func testStartingAWorkoutWhileOneIsRunningAsksFirst() async {
        let screen = makeScreen()
        screen.interactor.activeSession = WorkoutSessionModel(authorId: "user-1", name: "Live", dateCreated: .now, exercises: [])

        screen.presenter.onStartWorkoutPressed(workout: WorkoutTemplateModel(id: "push", authorId: "user-1", name: "Push Day"))
        try? await Task.sleep(for: .milliseconds(100))

        #expect(screen.router.alertTitles == ["Active Workout"])
        #expect(screen.interactor.startedTemplateNames.isEmpty)
        #expect(screen.router.shown.isEmpty)
    }

    // MARK: - Invite code

    /// A code typed in Search is accepted the same way as a link, and lands on the inviter.
    @Test("Test An Entered Invite Code Is Accepted And Opens The Inviter")
    func testAnEnteredInviteCodeIsAcceptedAndOpensTheInviter() async {
        let screen = makeScreen()
        screen.presenter.inviteCodeInput = "stale"

        screen.presenter.onEnterInviteCodePressed()
        #expect(screen.presenter.isEnteringInviteCode)
        #expect(screen.presenter.inviteCodeInput.isEmpty)

        screen.presenter.inviteCodeInput = "push-2345"
        await screen.presenter.onInviteCodeSubmitted()

        #expect(screen.interactor.acceptedInviteCodes == ["push-2345"])
        #expect(screen.router.socialProfileUserIds == ["inviter"])
        #expect(screen.interactor.shownToasts.map(\.message) == ["You're now following each other"])
    }
}
