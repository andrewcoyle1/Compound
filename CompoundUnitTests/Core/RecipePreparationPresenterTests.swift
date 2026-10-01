//
//  RecipePreparationPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The last step of building a recipe: the method, the times, and the two ways out — save it, or
/// save it and put a serving straight on the plate.
///
/// The steps list is ordinary editing. What is worth pinning is the second exit, which is the only
/// place in the app that turns a recipe's ingredients into a single meal item: each ingredient is
/// scaled from its per-100g figures to the amount used, the lot is summed, and the total divided
/// across the servings. Every one of those three can be wrong in a way that still looks plausible.
@MainActor
struct RecipePreparationPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, RecipePreparationInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        private(set) var savedRecipes: [RecipeTemplateModel] = []
        var saveError: Error?

        func saveRecipeTemplate(_ recipe: RecipeTemplateModel, image: PlatformImage?) async throws {
            if let saveError { throw saveError }
            savedRecipes.append(recipe)
        }
    }

    /// `RecipePreparationRouter` adds nothing to `GlobalRouter`, so both the dismissal and the
    /// failure alert go through extension methods that dispatch statically and never reach a
    /// double. The failure path is asserted through its analytics event instead.
    private final class Router: RecipePreparationRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: RecipePreparationPresenter
        let interactor: Interactor
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        return Screen(
            presenter: RecipePreparationPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    /// A food whose figures are per 100g, which is how everything in the library is stored.
    private func food(name: String, caloriesPer100g: Double, proteinPer100g: Double = 0) -> FoodModel {
        FoodModel(
            name: name,
            nutrients: NutrientMap([.calories: caloriesPer100g, .protein: proteinPer100g])
        )
    }

    private func delegate(
        name: String = "Chilli",
        servings: Double = 1,
        totalWeight: Double = 0,
        ingredients: [RecipeIngredientModel] = []
    ) -> RecipePreparationDelegate {
        RecipePreparationDelegate(
            recipeName: name,
            servingQuantity: servings,
            recipeTotalWeight: totalWeight,
            ingredients: ingredients
        )
    }

    /// Runs "create and add" and hands back the item the plate was given.
    private func createAndAdd(
        _ screen: Screen,
        delegate: RecipePreparationDelegate
    ) async -> MealItemModel? {
        let box = ItemBox()
        screen.presenter.onCreateAndAddPressed(delegate: delegate) { box.item = $0 }
        await TestManagers.eventually { box.item != nil }
        return box.item
    }

    /// Main-actor isolated so it is `Sendable`, which the confirm closure requires.
    @MainActor
    private final class ItemBox {
        var item: MealItemModel?
    }

    // MARK: - Editing the method

    /// The list starts with one empty row so there is something to type into.
    @Test("Test The Steps List Starts With One Empty Row")
    func testTheStepsListStartsWithOneEmptyRow() {
        let screen = makeScreen()

        #expect(screen.presenter.preparationSteps == [""])
    }

    @Test("Test Adding A Step Appends An Empty Row")
    func testAddingAStepAppendsAnEmptyRow() {
        let screen = makeScreen()
        screen.presenter.preparationSteps = ["Brown the mince"]

        screen.presenter.onAddStepPressed()

        #expect(screen.presenter.preparationSteps == ["Brown the mince", ""])
    }

    @Test("Test Removing A Step Removes That One")
    func testRemovingAStepRemovesThatOne() {
        let screen = makeScreen()
        screen.presenter.preparationSteps = ["One", "Two", "Three"]

        screen.presenter.onRemoveStep(atOffsets: IndexSet(integer: 1))

        #expect(screen.presenter.preparationSteps == ["One", "Three"])
    }

    /// A recipe's steps are an ordered method, so reordering has to hold.
    @Test("Test Moving A Step Reorders The Method")
    func testMovingAStepReordersTheMethod() {
        let screen = makeScreen()
        screen.presenter.preparationSteps = ["One", "Two", "Three"]

        screen.presenter.onMoveStep(from: IndexSet(integer: 2), toOffset: 0)

        #expect(screen.presenter.preparationSteps == ["Three", "One", "Two"])
    }

    // MARK: - What gets saved

    /// The empty row the list starts with, and any the user added and left blank, are editing
    /// artefacts rather than steps. Saving them would print blank lines in the method.
    @Test("Test Blank Steps Are Not Saved")
    func testBlankStepsAreNotSaved() async {
        let screen = makeScreen()
        screen.presenter.preparationSteps = ["Brown the mince", "", "   ", "Simmer"]

        screen.presenter.onCreatePressed(delegate: delegate())
        await TestManagers.eventually { !screen.interactor.savedRecipes.isEmpty }

        #expect(screen.interactor.savedRecipes.first?.preparationSteps == ["Brown the mince", "Simmer"])
    }

    @Test("Test The Recipe Carries Its Times And Source")
    func testTheRecipeCarriesItsTimesAndSource() async {
        let screen = makeScreen()
        screen.presenter.prepTime = 15
        screen.presenter.cookTime = 40
        screen.presenter.sourceURL = "https://example.com/chilli"

        screen.presenter.onCreatePressed(delegate: delegate())
        await TestManagers.eventually { !screen.interactor.savedRecipes.isEmpty }

        let recipe = screen.interactor.savedRecipes.first
        #expect(recipe?.prepTimeMins == 15)
        #expect(recipe?.cookTimeMins == 40)
        #expect(recipe?.sourceURL == "https://example.com/chilli")
    }

    /// An empty source field is absent rather than an empty string, so nothing downstream has to
    /// decide whether "" means a link.
    @Test("Test An Empty Source Is Absent Not Blank")
    func testAnEmptySourceIsAbsentNotBlank() async {
        let screen = makeScreen()

        screen.presenter.onCreatePressed(delegate: delegate())
        await TestManagers.eventually { !screen.interactor.savedRecipes.isEmpty }

        #expect(screen.interactor.savedRecipes.first?.sourceURL == nil)
    }

    /// Total weight is optional, and zero means "not given" rather than a weightless recipe.
    @Test("Test A Zero Total Weight Is Stored As Absent")
    func testAZeroTotalWeightIsStoredAsAbsent() async {
        let screen = makeScreen()

        screen.presenter.onCreatePressed(delegate: delegate(totalWeight: 0))
        await TestManagers.eventually { !screen.interactor.savedRecipes.isEmpty }

        #expect(screen.interactor.savedRecipes.first?.totalWeight == nil)
    }

    @Test("Test A Given Total Weight Is Kept")
    func testAGivenTotalWeightIsKept() async {
        let screen = makeScreen()

        screen.presenter.onCreatePressed(delegate: delegate(totalWeight: 850))
        await TestManagers.eventually { !screen.interactor.savedRecipes.isEmpty }

        #expect(screen.interactor.savedRecipes.first?.totalWeight == 850)
    }

    @Test("Test The Recipe Is Authored By The Current User")
    func testTheRecipeIsAuthoredByTheCurrentUser() async {
        let screen = makeScreen()

        screen.presenter.onCreatePressed(delegate: delegate())
        await TestManagers.eventually { !screen.interactor.savedRecipes.isEmpty }

        #expect(screen.interactor.savedRecipes.first?.authorId == "user-1")
    }

    /// Without a user there is nobody to author the recipe, so nothing is written.
    @Test("Test Nothing Is Saved Without A User")
    func testNothingIsSavedWithoutAUser() {
        let screen = makeScreen()
        screen.interactor.currentUser = nil

        screen.presenter.onCreatePressed(delegate: delegate())

        #expect(screen.interactor.savedRecipes.isEmpty)
    }

    @Test("Test A Successful Save Is Tracked Start And Success")
    func testASuccessfulSaveIsTrackedStartAndSuccess() async {
        let screen = makeScreen()

        screen.presenter.onCreatePressed(delegate: delegate())
        await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("RecipePreparationView_CreateRecipe_Success")
        }

        #expect(screen.interactor.trackedEventNames.contains("RecipePreparationView_CreateRecipe_Start"))
    }

    /// The failure alert goes through a `GlobalRouter` extension, so it cannot be observed — the
    /// severe event is what proves the failure was not swallowed.
    @Test("Test A Failed Save Is Reported")
    func testAFailedSaveIsReported() async {
        let screen = makeScreen()
        screen.interactor.saveError = URLError(.networkConnectionLost)

        screen.presenter.onCreatePressed(delegate: delegate())
        await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("RecipePreparationView_CreateRecipe_Fail")
        }

        #expect(!screen.interactor.trackedEventNames.contains("RecipePreparationView_CreateRecipe_Success"))
    }

    // MARK: - Creating and adding a serving

    /// The heart of it: an ingredient's figures are per 100g, so 200g of a 150kcal/100g food
    /// contributes 300kcal.
    @Test("Test An Ingredient Is Scaled From Per 100g To The Amount Used")
    func testAnIngredientIsScaledFromPer100gToTheAmountUsed() async {
        let screen = makeScreen()
        let mince = RecipeIngredientModel(
            ingredient: food(name: "Mince", caloriesPer100g: 150),
            amount: 200,
            unit: .grams
        )

        let item = await createAndAdd(screen, delegate: delegate(servings: 1, ingredients: [mince]))

        #expect(item?.nutrients[.calories] == 300)
    }

    /// Every ingredient contributes, and every nutrient they share is summed rather than the last
    /// one winning.
    @Test("Test Every Ingredient And Nutrient Is Summed")
    func testEveryIngredientAndNutrientIsSummed() async {
        let screen = makeScreen()
        let ingredients = [
            RecipeIngredientModel(
                ingredient: food(name: "Mince", caloriesPer100g: 150, proteinPer100g: 20),
                amount: 100,
                unit: .grams
            ),
            RecipeIngredientModel(
                ingredient: food(name: "Beans", caloriesPer100g: 100, proteinPer100g: 8),
                amount: 100,
                unit: .grams
            )
        ]

        let item = await createAndAdd(screen, delegate: delegate(servings: 1, ingredients: ingredients))

        #expect(item?.nutrients[.calories] == 250)
        #expect(item?.nutrients[.protein] == 28)
    }

    /// A recipe is logged a serving at a time, so the total is divided across the servings. Adding
    /// the whole pot as one item is the mistake this guards.
    @Test("Test The Item Is One Serving Not The Whole Recipe")
    func testTheItemIsOneServingNotTheWholeRecipe() async {
        let screen = makeScreen()
        let mince = RecipeIngredientModel(
            ingredient: food(name: "Mince", caloriesPer100g: 150),
            amount: 400,
            unit: .grams
        )

        let item = await createAndAdd(screen, delegate: delegate(servings: 4, ingredients: [mince]))

        // 400g at 150/100g is 600kcal for the pot, across four servings.
        #expect(item?.nutrients[.calories] == 150)
    }

    /// A recipe claiming zero servings would divide by zero, so the divisor floors at one and the
    /// item reads as the whole recipe rather than as infinity.
    @Test("Test Zero Servings Does Not Divide By Zero")
    func testZeroServingsDoesNotDivideByZero() async {
        let screen = makeScreen()
        let mince = RecipeIngredientModel(
            ingredient: food(name: "Mince", caloriesPer100g: 150),
            amount: 200,
            unit: .grams
        )

        let item = await createAndAdd(screen, delegate: delegate(servings: 0, ingredients: [mince]))

        #expect(item?.nutrients[.calories] == 300)
    }

    /// An ingredient counted in units is taken as 100g each, which is the assumption the scaling
    /// makes when there is no weight behind a count.
    @Test("Test An Ingredient Counted In Units Is Taken As 100g Each")
    func testAnIngredientCountedInUnitsIsTakenAs100gEach() async {
        let screen = makeScreen()
        let eggs = RecipeIngredientModel(
            ingredient: food(name: "Egg", caloriesPer100g: 140),
            amount: 2,
            unit: .units
        )

        let item = await createAndAdd(screen, delegate: delegate(servings: 1, ingredients: [eggs]))

        #expect(item?.nutrients[.calories] == 280)
    }

    /// Millilitres are taken one-for-one with grams, so a recipe's liquids are not silently
    /// dropped or counted a hundred times over.
    @Test("Test Millilitres Are Taken One For One With Grams")
    func testMillilitresAreTakenOneForOneWithGrams() async {
        let screen = makeScreen()
        let stock = RecipeIngredientModel(
            ingredient: food(name: "Stock", caloriesPer100g: 10),
            amount: 500,
            unit: .milliliters
        )

        let item = await createAndAdd(screen, delegate: delegate(servings: 1, ingredients: [stock]))

        #expect(item?.nutrients[.calories] == 50)
    }

    /// The item points back at the recipe it came from, so the log can tell where it originated.
    @Test("Test The Item Points Back At The Saved Recipe")
    func testTheItemPointsBackAtTheSavedRecipe() async {
        let screen = makeScreen()

        let item = await createAndAdd(screen, delegate: delegate(name: "Chilli"))

        let recipe = screen.interactor.savedRecipes.first
        #expect(item?.sourceType == .recipe)
        #expect(item?.sourceId == recipe?.recipeId)
        #expect(item?.displayName == "Chilli")
    }

    /// Its nutrients are already a serving's worth, so there is no weight to scale by — a
    /// `resolvedGrams` here would invite something downstream to scale them a second time.
    @Test("Test The Item Is One Unscaled Serving")
    func testTheItemIsOneUnscaledServing() async {
        let screen = makeScreen()

        let item = await createAndAdd(screen, delegate: delegate())

        #expect(item?.amount == 1)
        #expect(item?.unit == "serving")
        #expect(item?.resolvedGrams == nil)
        #expect(item?.resolvedMilliliters == nil)
    }

    /// Create-and-add saves the recipe as well as handing back a serving — the recipe is meant to
    /// be reusable, not consumed by being logged once.
    @Test("Test Create And Add Also Saves The Recipe")
    func testCreateAndAddAlsoSavesTheRecipe() async {
        let screen = makeScreen()

        _ = await createAndAdd(screen, delegate: delegate(name: "Chilli"))

        #expect(screen.interactor.savedRecipes.map(\.name) == ["Chilli"])
    }

    /// If the recipe cannot be saved, nothing reaches the plate: an item pointing at a recipe that
    /// does not exist would be unopenable from the log.
    @Test("Test Nothing Reaches The Plate If The Recipe Cannot Be Saved")
    func testNothingReachesThePlateIfTheRecipeCannotBeSaved() async {
        let screen = makeScreen()
        screen.interactor.saveError = URLError(.networkConnectionLost)
        let box = ItemBox()

        screen.presenter.onCreateAndAddPressed(delegate: delegate()) { box.item = $0 }
        await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("RecipePreparationView_CreateRecipe_Fail")
        }

        #expect(box.item == nil)
        await TestManagers.eventually { !screen.interactor.playedHaptics.isEmpty }
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    @Test("Test Creating A Recipe Plays A Success Haptic")
    func testCreatingARecipePlaysASuccessHaptic() async {
        let screen = makeScreen()

        screen.presenter.onCreatePressed(delegate: delegate())
        await TestManagers.eventually { !screen.interactor.playedHaptics.isEmpty }

        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: delegate())

        #expect(screen.interactor.trackedScreenEventNames == ["RecipePreparationView_Appear"])
    }
}
