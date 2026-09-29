//
//  SearchPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/01/2026.
//

import SwiftUI

@Observable
@MainActor
class SearchPresenter {
    
    private let interactor: SearchInteractor
    private let router: SearchRouter
    private let followFlow: FollowFlow
    
    var searchString: String = ""
    
    var trimmedSearchString: String {
        Self.normalised(searchString)
    }
    
    var currentUser: UserModel? {
        interactor.currentUser
    }

    /// Every collection is matched the same way: substring of the normalised query against each
    /// normalised field. Five hand-copied filters used to do this, one per section.
    private static func normalised(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .alphanumerics.inverted)
            .lowercased()
    }

    private func matches(_ fields: [String?]) -> Bool {
        let query = trimmedSearchString
        return fields.contains { $0.map { Self.normalised($0).contains(query) } == true }
    }

    var filteredExercises: [ExerciseModel] {
        interactor.allExercises
            .filter { matches([$0.name, $0.description] + $0.muscleGroups.keys.map(\.rawValue) + $0.alternateNames) }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }
    
    var filteredWorkoutTemplates: [WorkoutTemplateModel] {
        interactor.allWorkoutTemplates
            .filter { matches([$0.name, $0.description] + $0.exercises.map(\.exercise.name)) }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }
    
    var filteredRecipeTemplates: [RecipeTemplateModel] {
        interactor.userRecipeTemplates
            .filter { matches([$0.name, $0.description] + $0.ingredients.map(\.name)) }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }

    var filteredFoods: [FoodModel] {
        interactor.foods
            .filter { matches([$0.name, $0.description]) }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }
    
    var filteredUsers: [UserModel] {
        (interactor.followingUsers + users).filter { matches([$0.firstNameCalculated, $0.username]) }
    }
    
    private(set) var users: [UserModel] = []

    /// Only the People section waits on the network. The rest is in memory and shows at once;
    /// it used to hide behind one spinner for the whole 350ms debounce plus the round trip.
    private(set) var isLoadingPeople: Bool = false

    private var searchTask: Task<Void, Never>?

    private(set) var recentQueries: [String] = []

    var userImageUrl: String? {
        interactor.userImageUrl
    }

    var hasSearchQuery: Bool {
        !trimmedSearchString.isEmpty
    }

    /// Checks `filteredUsers`, not `users`: the view renders the filtered list, so a remote search
    /// that returned people whose names the local filter then rejected showed a list of five empty
    /// sections instead of "no results".
    var hasResults: Bool {
        !filteredExercises.isEmpty
            || !filteredWorkoutTemplates.isEmpty
            || !filteredRecipeTemplates.isEmpty
            || !filteredFoods.isEmpty
            || !filteredUsers.isEmpty
    }

    func followState(for user: UserModel) -> FollowState {
        followFlow.state(for: user)
    }

    init(
        interactor: SearchInteractor,
        router: SearchRouter
    ) {
        self.interactor = interactor
        self.router = router
        self.followFlow = FollowFlow(interactor: interactor, router: router)
    }

    func performUnifiedSearch() {
        searchTask?.cancel()

        guard hasSearchQuery else {
            onSearchCleared()
            return
        }

        // Not `trimmedSearchString`, which strips a leading `@`: that `@` is what routes a query to
        // handles only. See `Username.searchRoute`.
        let query = searchString.trimmingCharacters(in: .whitespacesAndNewlines)
        // Raised here, not in the task, so the header shows the spinner on the same tick. A task
        // superseded by a newer query leaves the flag to that query.
        isLoadingPeople = true
        searchTask = Task {
            defer { if !Task.isCancelled { isLoadingPeople = false } }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            // Silent: search-as-you-type; a failed query shows no results rather than an alert per keystroke.
            let fetchedUsers = (try? await interactor.searchUsers(query: query)) ?? []
            guard !Task.isCancelled else { return }

            users = fetchedUsers
        }
    }

    /// Recents used to be written after the debounce, so every pause mid-word was saved as a
    /// search. Now only a query the user committed to — submitted, or tapped a result of — is kept.
    func onSearchSubmitted() {
        commitRecentSearch()
    }

    private func commitRecentSearch() {
        guard hasSearchQuery else { return }
        interactor.addRecentSearch(query: trimmedSearchString)
    }

    func onSearchCleared() {
        users = []
        reloadRecentQueries()
    }

    func loadRecentSearches() async {
        reloadRecentQueries()
    }

    private func reloadRecentQueries() {
        recentQueries = interactor.recentSearchQueries
    }

    func onExercisePressed(exercise: ExerciseModel) {
        commitRecentSearch()
        router.showExerciseDetailView(
            templateId: exercise.id,
            name: exercise.name,
            delegate: ExerciseDetailDelegate(),
            themeColor: nil
        )
    }

    func onWorkoutPressed(workout: WorkoutTemplateModel) {
        commitRecentSearch()
        router.showWorkoutTemplateDetailView(
            delegate: WorkoutTemplateDetailDelegate(
                workoutTemplate: workout,
                trainingProgramId: nil,
                onStartWorkoutPressed: { [weak self] in
                    Task { @MainActor in
                        self?.router.showWorkoutTrackerView()
                    }
                }
            )
        )
    }

    /// The row's Start button: the workout is started here rather than after a detour through
    /// its detail screen.
    func onStartWorkoutPressed(workout: WorkoutTemplateModel) {
        commitRecentSearch()
        startAfterActiveSessionCheck { [weak self] in
            try await self?.interactor.startWorkout(for: workout, in: nil)
        }
    }

    func onRecipePressed(recipe: RecipeTemplateModel) {
        commitRecentSearch()
        router.showRecipeDetailView(
            delegate: RecipeDetailDelegate(recipeTemplate: recipe)
        )
    }

    func onIngredientPressed(ingredient: FoodModel) {
        commitRecentSearch()
        router.showFoodDetailView(delegate: FoodDetailDelegate(food: ingredient))
    }

    /// The row used to offer Follow and nothing else; the person's profile was unreachable from here.
    func onUserPressed(user: UserModel) {
        commitRecentSearch()
        router.showSocialProfileView(delegate: SocialProfileDelegate(user: user))
    }

    func onRecentSearchTapped(query: String) {
        searchString = query
        performUnifiedSearch()
    }

    func onClearRecentSearchesPressed() {
        interactor.clearRecentSearches()
        recentQueries = []
    }

    // MARK: - Quick actions

    /// The empty state's shortcut row, as chosen on the Shortcuts screen.
    var quickActions: [QuickAction] {
        interactor.shortcutSettings.quickActions
    }

    /// One switch instead of a per-action closure at the call site, so adding a `QuickAction` case is
    /// a compile error here until it is routed somewhere.
    func onQuickActionPressed(_ action: QuickAction) {
        // The eventName overload rather than a nested `Event` enum: this presenter tracks nothing
        // else, and one case does not justify the enum.
        interactor.trackEvent(
            eventName: "SearchView_QuickAction_Press",
            parameters: ["action": action.rawValue],
            type: .analytic
        )
        switch action {
        case .startWorkout:    onStartWorkoutPressed()
        case .logMeal:         onLogMealPressed()
        case .logWeight:       router.showLogWeightView()
        case .logMeasurement:  router.showBodyMetricsView(delegate: BodyMetricsDelegate())
        case .addExercise:     router.showCreateExerciseView()
        case .newWorkout:      router.showCreateWorkoutView(delegate: CreateWorkoutDelegate())
        case .newFood:         router.showCreateFoodView(delegate: CreateFoodDelegate())
        case .newRecipe:       router.showCreateRecipeView()
        case .browseExercises: onBrowseExercisesPressed()
        case .browseRecipes:   router.showRecipesView()
        }
    }

    /// The list was opened with an empty delegate, so every row tapped into a nil closure and the
    /// screen was a dead end. Selecting an exercise goes where the search results' own rows go.
    func onBrowseExercisesPressed() {
        router.showExerciseListBuilderView(
            delegate: ExerciseListBuilderDelegate(
                onExerciseSelectionChanged: { [weak self] exercise in
                    self?.onExercisePressed(exercise: exercise)
                }
            )
        )
    }

    /// "Start Workout" opened the workout library, which starts nothing. It now starts a blank
    /// session the tracker fills in as it goes.
    func onStartWorkoutPressed() {
        startAfterActiveSessionCheck { [weak self] in
            try await self?.interactor.startBlankWorkout()
        }
    }

    private func startAfterActiveSessionCheck(_ start: @escaping @MainActor () async throws -> Void) {
        if interactor.activeSession != nil {
            router.showActiveWorkoutAlert(
                onResume: { [weak self] in
                    Task { @MainActor in self?.router.showWorkoutTrackerView() }
                },
                onReplace: { [weak self] in
                    Task { @MainActor in
                        try? self?.interactor.deleteActiveSession()
                        await self?.startThenShowTracker(start)
                    }
                }
            )
        } else {
            Task { await startThenShowTracker(start) }
        }
    }

    private func startThenShowTracker(_ start: @MainActor () async throws -> Void) async {
        do {
            try await start()
            router.showWorkoutTrackerView()
        } catch {
            router.showSimpleAlert(title: String(localized: "Could Not Start Workout"), subtitle: String(localized: "Please try again."))
        }
    }

    func onLogMealPressed() {
        guard let userId = currentUser?.userId else { return }
        if let meal = interactor.draftMeal {
            router.showAlert(
                title: String(localized: "Unable to add new meal"),
                subtitle: String(localized: "You already have an draft meal."),
                buttons: {
                    AnyView(
                        VStack {
                            Button("Continue editing") {
                                self.router.showAddMealView(
                                    delegate: AddMealDelegate(mealLog: meal)
                                )
                            }
                            Button("Delete drafted meal", role: .destructive) {
                                self.router.showAddMealView(
                                    delegate: AddMealDelegate(
                                        mealLog: MealLogModel(
                                            authorId: userId,
                                            dayKey: Date().dayKey,
                                            date: Date(),
                                            items: []
                                        )
                                    )
                                )
                            }
                            Button("Cancel", role: .cancel) { }
                        }
                    )
                }
            )
        } else {
            self.router.showAddMealView(
                delegate: AddMealDelegate(
                    mealLog: MealLogModel(
                        authorId: userId,
                        dayKey: Date().dayKey,
                        date: Date(),
                        items: []
                    )
                )
            )
        }
    }

    func onFollowButtonPressed(user: UserModel) {
        followFlow.onButtonPressed(user: user)
    }

    /// The way to the screen that fills the shortcut row.
    func onChooseShortcutsPressed() {
        router.showShortcutsView(delegate: ShortcutsDelegate())
    }

    func onProfilePressed(transitionId: String, namespace: Namespace.ID) {
        router.showProfileViewZoom(transitionId: transitionId, namespace: namespace)
    }

    // MARK: - Invite code

    /// For an invite link received on another device: the code is typed in here instead.
    var isEnteringInviteCode = false
    var inviteCodeInput = ""

    func onEnterInviteCodePressed() {
        inviteCodeInput = ""
        isEnteringInviteCode = true
    }

    func onInviteCodeSubmitted() async {
        await InviteAcceptFlow(interactor: interactor, router: router).accept(code: inviteCodeInput)
    }
}
