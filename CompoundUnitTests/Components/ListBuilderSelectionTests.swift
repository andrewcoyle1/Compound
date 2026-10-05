//
//  ListBuilderSelectionTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

// The three pickers — exercises, workouts and ingredients — and the one action each exists for.
// Every one of them handed the tapped row straight to the caller's closure without telling the
// presenter, so the screens reported how often they were opened and never what was chosen from
// them. These tests pin the selection to the presenter: the delegate still gets its value, and the
// tap is now counted.

// MARK: - Exercises

@MainActor
struct ExerciseListBuilderPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ExerciseListBuilderInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var userExercises: [ExerciseModel] = []
        var systemExercises: [ExerciseModel] = []
        var allExercises: [ExerciseModel] = []
        var gymProfiles: [GymProfileModel] = []
    }

    private final class Router: ExerciseListBuilderRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showCreateExerciseView() { shown.append("createExercise") }
    }

    private func makePresenter() -> (ExerciseListBuilderPresenter, Interactor) {
        let interactor = Interactor()
        return (ExerciseListBuilderPresenter(interactor: interactor, router: Router()), interactor)
    }

    @Test("Test Selecting An Exercise Is Tracked And Reaches The Delegate")
    func testSelectingAnExerciseIsTrackedAndReachesTheDelegate() {
        let (presenter, interactor) = makePresenter()
        let exercise = listBuilderExercise(id: "ex-1", name: "Bench Press")
        var selected: [ExerciseModel] = []

        presenter.onExercisePressed(
            exercise: exercise,
            onExerciseSelectionChanged: { selected.append($0) }
        )

        #expect(selected.map(\.id) == ["ex-1"])
        #expect(interactor.trackedEventNames == ["ExercisesView_Exercise_Selected"])
    }

    /// A picker opened purely to browse has no selection closure. The tap still has to be counted,
    /// and must not trap on the nil.
    @Test("Test A Selection With No Delegate Closure Is Still Tracked")
    func testASelectionWithNoDelegateClosureIsStillTracked() {
        let (presenter, interactor) = makePresenter()

        presenter.onExercisePressed(
            exercise: listBuilderExercise(id: "ex-1", name: "Bench Press"),
            onExerciseSelectionChanged: nil
        )

        #expect(interactor.trackedEventNames == ["ExercisesView_Exercise_Selected"])
    }
}

// MARK: - Workouts

@MainActor
struct WorkoutListBuilderPresenterTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutListInteractorBuilder {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var userWorkoutTemplates: [WorkoutTemplateModel] = []
        var systemWorkoutTemplates: [WorkoutTemplateModel] = []
        var allWorkoutTemplates: [WorkoutTemplateModel] = []
    }

    private final class Router: WorkoutListRouterBuilder {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        /// Deliberately not behind `#if DEV || MOCK` the way the protocol's requirement is: the app
        /// target gets `DEV` from its Debug build settings and the test target does not.
        func showDevSettingsView() { shown.append("devSettings") }
        func showCreateWorkoutView(delegate: CreateWorkoutDelegate) { shown.append("createWorkout") }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { shown.append("workoutDetail") }
    }

    private func makePresenter() -> (WorkoutListPresenterBuilder, Interactor) {
        let interactor = Interactor()
        return (WorkoutListPresenterBuilder(interactor: interactor, router: Router()), interactor)
    }

    @Test("Test Selecting A Workout Is Tracked And Reaches The Delegate")
    func testSelectingAWorkoutIsTrackedAndReachesTheDelegate() {
        let (presenter, interactor) = makePresenter()
        let workout = WorkoutTemplateModel(id: "wo-1", authorId: "user-1", name: "Push Day")
        var selected: [WorkoutTemplateModel] = []

        presenter.onWorkoutPressed(workout: workout, onWorkoutPressed: { selected.append($0) })

        #expect(selected.map(\.id) == ["wo-1"])
        #expect(interactor.trackedEventNames == ["WorkoutsView_Workout_Selected"])
    }

    @Test("Test A Selection With No Delegate Closure Is Still Tracked")
    func testASelectionWithNoDelegateClosureIsStillTracked() {
        let (presenter, interactor) = makePresenter()

        presenter.onWorkoutPressed(workout: WorkoutTemplateModel(id: "wo-1", authorId: "user-1", name: "Push Day"))

        #expect(interactor.trackedEventNames == ["WorkoutsView_Workout_Selected"])
    }
}

// MARK: - Ingredients

@MainActor
struct IngredientListBuilderPresenterTests {

    private final class Interactor: SpyGlobalInteractor, IngredientListBuilderInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var foods: [FoodModel] = []
        var userMeals: [MealLogModel] = []
        var foodLogSettings: FoodLogSettings = FoodLogSettings(authorId: "user-1")
    }

    private final class Router: IngredientListBuilderRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showCreateFoodView(delegate: CreateFoodDelegate) { shown.append("createFood") }
        private(set) var amountDelegates: [IngredientAmountDelegate] = []
        func showIngredientAmountView(delegate: IngredientAmountDelegate) {
            shown.append("ingredientAmount")
            amountDelegates.append(delegate)
        }
        func showRecipeIngredientAmountView(delegate: RecipeIngredientAmountDelegate) { shown.append("recipeIngredientAmount") }
    }

    private struct Screen {
        let presenter: IngredientListBuilderPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: IngredientListBuilderPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The amount screen is the normal route out of the picker, and it was the untracked one.
    @Test("Test Choosing An Ingredient For The Amount Screen Is Tracked")
    func testChoosingAnIngredientForTheAmountScreenIsTracked() {
        let screen = makeScreen()
        var confirmed: [RecipeIngredientModel] = []

        screen.presenter.navToIngredientAmountView(
            food: FoodModel(ingredientId: "food-1", name: "Oats"),
            delegate: IngredientListBuilderDelegate(
                onRecipeIngredientConfirmed: { confirmed.append($0) }
            )
        )

        #expect(screen.router.shown == ["recipeIngredientAmount"])
        #expect(screen.interactor.trackedEventNames == ["IngredientsView_Ingredient_Selected"])
        #expect(confirmed.isEmpty)
    }

    /// Logging, a food opens the same amount screen search does, and it carries the plate's Log.
    @Test("Test A Food Picked While Logging Opens The Amount Screen With Log")
    func testAFoodPickedWhileLoggingOpensTheAmountScreenWithLog() {
        let screen = makeScreen()
        var logged = 0

        screen.presenter.navToIngredientAmountView(
            food: FoodModel(ingredientId: "food-1", name: "Oats"),
            delegate: IngredientListBuilderDelegate(onMealItemConfirmed: { _ in }, onLog: { logged += 1 })
        )
        screen.router.amountDelegates.first?.onLog?()

        #expect(screen.router.shown == ["ingredientAmount"])
        #expect(logged == 1)
    }

    /// Quick Add skips the amount screen entirely, so it is the other half of the same number.
    @Test("Test Quick Adding An Ingredient Is Tracked Under The Same Name")
    func testQuickAddingAnIngredientIsTrackedUnderTheSameName() {
        let screen = makeScreen()
        var confirmed: [RecipeIngredientModel] = []

        screen.presenter.quickAdd(
            food: FoodModel(ingredientId: "food-1", name: "Oats"),
            delegate: IngredientListBuilderDelegate(
                onRecipeIngredientConfirmed: { confirmed.append($0) }
            )
        )

        #expect(confirmed.map(\.ingredient.id) == ["food-1"])
        #expect(screen.interactor.trackedEventNames == ["IngredientsView_Ingredient_Selected"])
    }

    /// The two routes are one metric split by a parameter, so the parameter has to distinguish them
    /// or the split is unrecoverable on a dashboard.
    @Test("Test The Two Selection Routes Are Told Apart By Their Parameters")
    func testTheTwoSelectionRoutesAreToldApartByTheirParameters() {
        let food = FoodModel(ingredientId: "food-1", name: "Oats")

        let amount = IngredientListBuilderPresenter.Event.ingredientSelected(food: food, method: "amount")
        let quick = IngredientListBuilderPresenter.Event.ingredientSelected(food: food, method: "quickAdd")

        #expect(amount.parameters?["method"] as? String == "amount")
        #expect(quick.parameters?["method"] as? String == "quickAdd")
        #expect(amount.parameters?["ingredient_id"] as? String == food.id)
    }

    @Test("Test The Screen Is Tracked Under Its Own Name")
    func testTheScreenIsTrackedUnderItsOwnName() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["IngredientsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["IngredientsView_Disappear"])
    }
}

/// An exercise with the minimum a picker row needs.
@MainActor
private func listBuilderExercise(id: String, name: String) -> ExerciseModel {
    ExerciseModel(
        id: id,
        authorId: "user-1",
        name: name,
        trackableMetrics: [.weight, .reps],
        type: .compoundUpper,
        laterality: .bilateral,
        muscleGroups: [.chest: .primary],
        isBodyweight: false,
        rangeOfMotion: 4,
        stability: 5,
        bodyWeightContribution: 0,
        alternateNames: []
    )
}
