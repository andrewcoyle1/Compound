//
//  SearchInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/01/2026.
//

@MainActor
protocol SearchInteractor: FollowInteractor, InviteAcceptInteractor {
    /// Which quick actions the Search tab shows — see `ShortcutsView`.
    var shortcutSettings: ShortcutSettings { get }
    var userImageUrl: String? { get }
    var currentUser: UserModel? { get }
    var draftMeal: MealLogModel? { get }
    var recentSearchQueries: [String] { get }
    var allExercises: [ExerciseModel] { get }
    var allWorkoutTemplates: [WorkoutTemplateModel] { get }
    var userRecipeTemplates: [RecipeTemplateModel] { get }
    var foods: [FoodModel] { get }
    var followingUsers: [UserModel] { get }
    var activeSession: WorkoutSessionModel? { get }
    func startWorkout(for template: WorkoutTemplateModel, in trainingProgramId: String?) async throws
    func startBlankWorkout() async throws
    func deleteActiveSession() throws
    func searchUsers(query: String) async throws -> [UserModel]
    func addRecentSearch(query: String)
    func clearRecentSearches()
}

extension CoreInteractor: SearchInteractor {
    var recentSearchQueries: [String] {
        RecentSearchManager.recentSearchQueries
    }

    func searchUsers(query: String) async throws -> [UserModel] {
        let results = try await userManager.searchUsersByNameOrHandle(query: query)
        // Private profiles are found like any other; following one sends a request.
        return results.filter { $0.userId != currentUser?.userId }
    }

    func addRecentSearch(query: String) {
        RecentSearchManager.addRecentSearch(query: query)
    }

    func clearRecentSearches() {
        RecentSearchManager.clearRecentSearches()
    }
}
