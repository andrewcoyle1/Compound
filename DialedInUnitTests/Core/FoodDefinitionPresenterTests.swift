//
//  FoodDefinitionPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The last step of creating a food: the nutrition panel the user types off a label.
///
/// What is entered here is stored forever and scaled on every future serving, so two things
/// matter more than the rest — that a figure entered per-serving is normalised to per-100g before
/// it is saved, and that a nutrient nobody entered is absent rather than zero.
@MainActor
struct FoodDefinitionPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, FoodDefinitionInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        private(set) var savedFoods: [FoodModel] = []
        var saveError: Error?

        func saveFood(_ ingredient: FoodModel, image: PlatformImage?) async throws {
            if let saveError { throw saveError }
            savedFoods.append(ingredient)
        }
    }

    private final class Router: FoodDefinitionRouter {
        let router: AnyRouter = TestRouting.anyRouter

        /// Bound here, on the class declaring the conformance — a subclass witness would not
        /// replace the protocol's default implementation and the alert would escape unseen.
        private(set) var alertTitles: [String] = []

        func showAlert(error: Error) { alertTitles.append("Error") }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    /// Holds the meal items the "create and add" path appends to.
    ///
    /// Main-actor isolated so it is `Sendable` and can be captured by the `@Sendable` accessors of
    /// the `Binding` built from it; the accessors assume that isolation rather than hop, which
    /// holds because the presenter writes through the binding on the main actor.
    @MainActor
    private final class ItemBox {
        var items: [MealItemModel] = []

        var binding: Binding<[MealItemModel]> {
            Binding(
                get: { MainActor.assumeIsolated { self.items } },
                set: { newValue in MainActor.assumeIsolated { self.items = newValue } }
            )
        }
    }

    private struct Screen {
        let presenter: FoodDefinitionPresenter
        let interactor: Interactor
        let router: Router
        let box: ItemBox
        let delegate: FoodDefinitionDelegate
    }

    private func makeScreen(
        option: NutritionDefinitionOption = .standardMass,
        servingWeight: Double? = nil,
        name: String = "Oat Milk",
        brandName: String? = "Brand",
        barcode: String? = "5012345678900"
    ) -> Screen {
        let interactor = Interactor()
        let box = ItemBox()
        let delegate = FoodDefinitionDelegate(
            mealItems: box.binding,
            nutritionDefinitionOption: option,
            image: nil,
            name: name,
            brandName: brandName,
            barcode: barcode,
            imageFront: nil,
            nutritionImage: nil,
            servingWeight: servingWeight,
            portionSize: 250,
            portionName: "glass"
        )
        let router = Router()
        return Screen(
            presenter: FoodDefinitionPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router,
            box: box,
            delegate: delegate
        )
    }

    /// Waits for the presenter's detached save task to reach the interactor.
    private func create(_ screen: Screen) async {
        screen.presenter.onCreatePressed(delegate: screen.delegate)
        await TestManagers.eventually { !screen.interactor.savedFoods.isEmpty }
    }

    // MARK: - What gets stored

    /// The figures typed in are the figures stored.
    @Test("Test Entered Nutrients Are Saved")
    func testEnteredNutrientsAreSaved() async {
        let screen = makeScreen()
        screen.presenter.energy = 250
        screen.presenter.protein = 12
        screen.presenter.carbs = 30
        screen.presenter.fats = 8

        await create(screen)

        let saved = screen.interactor.savedFoods.first
        #expect(saved?.nutrients[.calories] == 250)
        #expect(saved?.nutrients[.protein] == 12)
        #expect(saved?.nutrients[.carbs] == 30)
        #expect(saved?.nutrients[.fatTotal] == 8)
    }

    /// A nutrient left blank is absent, not zero. A label that does not print its iron is not a
    /// food with no iron, and storing 0 would assert something the label never said.
    @Test("Test Untouched Nutrients Are Absent Not Zero")
    func testUntouchedNutrientsAreAbsentNotZero() async {
        let screen = makeScreen()
        screen.presenter.energy = 250

        await create(screen)

        let saved = screen.interactor.savedFoods.first
        #expect(saved?.nutrients[.calories] == 250)
        #expect(saved?.nutrients[.ironMg] == nil)
        #expect(saved?.nutrients[.vitaminCMg] == nil)
    }

    /// Zero entered deliberately is kept — "contains none" is a claim the label can make.
    @Test("Test An Entered Zero Is Kept")
    func testAnEnteredZeroIsKept() async {
        let screen = makeScreen()
        screen.presenter.energy = 250
        screen.presenter.fats = 0

        await create(screen)

        #expect(screen.interactor.savedFoods.first?.nutrients[.fatTotal] == 0)
    }

    /// The food carries what the earlier steps collected.
    @Test("Test The Food Carries Its Identifying Details")
    func testTheFoodCarriesItsIdentifyingDetails() async {
        let screen = makeScreen(name: "Oat Milk", brandName: "Oatly", barcode: "5012345678900")
        screen.presenter.energy = 250

        await create(screen)

        let saved = screen.interactor.savedFoods.first
        #expect(saved?.name == "Oat Milk")
        #expect(saved?.brandName == "Oatly")
        #expect(saved?.barcode == "5012345678900")
        #expect(saved?.authorId == "user-1")
        #expect(saved?.portionSize == 250)
        #expect(saved?.portionName == "glass")
    }

    // MARK: - Normalising to per-100g

    /// Figures typed off a per-serving label are scaled to per-100g before they are stored, since
    /// that is the basis every later serving is computed from. A 50g serving at 100 kcal is a
    /// 200 kcal per 100g food.
    @Test("Test Per Serving Figures Are Normalised To Per Hundred Grams")
    func testPerServingFiguresAreNormalisedToPerHundredGrams() async {
        let screen = makeScreen(option: .serving, servingWeight: 50)
        screen.presenter.energy = 100
        screen.presenter.protein = 5

        await create(screen)

        let saved = screen.interactor.savedFoods.first
        #expect(saved?.nutrients[.calories] == 200)
        #expect(saved?.nutrients[.protein] == 10)
    }

    /// A serving that already weighs 100g needs no adjustment.
    @Test("Test A Hundred Gram Serving Is Unchanged")
    func testAHundredGramServingIsUnchanged() async {
        let screen = makeScreen(option: .serving, servingWeight: 100)
        screen.presenter.energy = 100

        await create(screen)

        #expect(screen.interactor.savedFoods.first?.nutrients[.calories] == 100)
    }

    /// Figures already given per 100g are stored as they are.
    @Test("Test Standard Mass Figures Are Not Scaled")
    func testStandardMassFiguresAreNotScaled() async {
        let screen = makeScreen(option: .standardMass, servingWeight: 50)
        screen.presenter.energy = 100

        await create(screen)

        #expect(screen.interactor.savedFoods.first?.nutrients[.calories] == 100)
    }

    /// Without a serving weight there is nothing to scale by, so the figures are left alone
    /// rather than divided by zero.
    @Test("Test A Serving Without A Weight Is Not Scaled")
    func testAServingWithoutAWeightIsNotScaled() async {
        let screen = makeScreen(option: .serving, servingWeight: nil)
        screen.presenter.energy = 100

        await create(screen)

        #expect(screen.interactor.savedFoods.first?.nutrients[.calories] == 100)
    }

    /// A zero serving weight is the same case, and must not produce an infinite figure.
    @Test("Test A Zero Serving Weight Is Not Scaled")
    func testAZeroServingWeightIsNotScaled() async {
        let screen = makeScreen(option: .serving, servingWeight: 0)
        screen.presenter.energy = 100

        await create(screen)

        let calories = screen.interactor.savedFoods.first?.nutrients[.calories]
        #expect(calories == 100)
        #expect(calories?.isFinite == true)
    }

    // MARK: - Create and add

    /// Creating from inside a meal drops the new food straight onto the plate, at 100g — the
    /// basis its nutrients were just normalised to.
    @Test("Test Create And Add Puts The Food On The Plate")
    func testCreateAndAddPutsTheFoodOnThePlate() async {
        let screen = makeScreen(name: "Oat Milk")
        screen.presenter.energy = 250

        screen.presenter.onCreateAndAddPressed(delegate: screen.delegate)
        await TestManagers.eventually { !screen.box.items.isEmpty }

        let added = screen.box.items.first
        let saved = screen.interactor.savedFoods.first
        #expect(added?.displayName == "Oat Milk")
        #expect(added?.sourceId == saved?.id)
        #expect(added?.amount == 100)
        #expect(added?.unit == "g")
        #expect(added?.resolvedGrams == 100)
    }

    /// The plate item carries the food's nutrients at 100g. It used to carry none, so the new food
    /// added nothing to the meal's totals.
    @Test("Test Create And Add Puts The Food's Nutrients On The Plate")
    func testCreateAndAddPutsTheFoodsNutrientsOnThePlate() async {
        let screen = makeScreen(name: "Oat Milk")
        screen.presenter.energy = 250
        screen.presenter.protein = 12

        screen.presenter.onCreateAndAddPressed(delegate: screen.delegate)
        await TestManagers.eventually { !screen.box.items.isEmpty }

        #expect(screen.box.items.first?.nutrients[.calories] == 250)
        #expect(screen.box.items.first?.nutrients[.protein] == 12)
    }

    /// Plain create does not touch the plate.
    @Test("Test Plain Create Leaves The Plate Alone")
    func testPlainCreateLeavesThePlateAlone() async {
        let screen = makeScreen()
        screen.presenter.energy = 250

        await create(screen)

        #expect(screen.box.items.isEmpty)
    }

    // MARK: - Failure

    /// A failed save is reported and nothing reaches the plate.
    @Test("Test A Failed Save Is Reported")
    func testAFailedSaveIsReported() async {
        let screen = makeScreen()
        screen.presenter.energy = 250
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        screen.presenter.onCreateAndAddPressed(delegate: screen.delegate)
        await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("FoodDefinitionView_CreateFood_Fail")
        }

        #expect(screen.interactor.savedFoods.isEmpty)
        #expect(screen.box.items.isEmpty)
    }

    /// Reported to the user, not only to analytics: the form stays open on failure, so without an
    /// alert Create reads as a button that does nothing.
    @Test("Test A Failed Save Is Reported To The User")
    func testAFailedSaveIsReportedToTheUser() async {
        let screen = makeScreen()
        screen.presenter.energy = 250
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        screen.presenter.onCreatePressed(delegate: screen.delegate)
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.router.alertTitles == ["Unable to Create Food"])
    }

    /// Signed out there is nobody to attribute the food to, so nothing is written and the attempt
    /// is not even logged as started.
    @Test("Test No User Means No Food Is Created")
    func testNoUserMeansNoFoodIsCreated() async {
        let screen = makeScreen()
        screen.interactor.currentUser = nil
        screen.presenter.energy = 250

        screen.presenter.onCreatePressed(delegate: screen.delegate)

        #expect(screen.interactor.savedFoods.isEmpty)
        #expect(screen.interactor.trackedEventNames.contains("FoodDefinitionView_CreateFood_Start") == false)
    }

    // MARK: - The whole form

    /// Every nutrient the form collects reaches the saved food.
    ///
    /// Twenty-one of these fields used to be discarded on save — trans fats, omega-3 and its
    /// fractions, omega-6, starch, added sugars, alcohol, water and all eleven amino acids had no
    /// `NutrientKey` to be stored under, so the user typed them in and they were dropped without
    /// a word. They have keys now, and this holds them there.
    @Test("Test Every Collected Nutrient Is Stored")
    func testEveryCollectedNutrientIsStored() async {
        let screen = makeScreen()
        screen.presenter.energy = 250
        screen.presenter.transFats = 1.5
        screen.presenter.omega3 = 0.8
        screen.presenter.omega3Ala = 0.3
        screen.presenter.omega3Dha = 0.2
        screen.presenter.omega3Epa = 0.1
        screen.presenter.omega6 = 2.4
        screen.presenter.starch = 30
        screen.presenter.addedSugars = 6
        screen.presenter.alcohol = 12
        screen.presenter.water = 88
        screen.presenter.leucine = 2.2
        screen.presenter.lysine = 1.8

        await create(screen)

        let saved = screen.interactor.savedFoods.first
        #expect(saved?.nutrients[.fatTrans] == 1.5)
        #expect(saved?.nutrients[.omega3] == 0.8)
        #expect(saved?.nutrients[.omega3Ala] == 0.3)
        #expect(saved?.nutrients[.omega3Dha] == 0.2)
        #expect(saved?.nutrients[.omega3Epa] == 0.1)
        #expect(saved?.nutrients[.omega6] == 2.4)
        #expect(saved?.nutrients[.starch] == 30)
        #expect(saved?.nutrients[.addedSugars] == 6)
        #expect(saved?.nutrients[.alcohol] == 12)
        #expect(saved?.nutrients[.water] == 88)
        #expect(saved?.nutrients[.leucine] == 2.2)
        #expect(saved?.nutrients[.lysine] == 1.8)
    }

    /// The newly stored nutrients are normalised with the rest — a per-serving amino acid figure
    /// is per-100g in the library too.
    @Test("Test New Nutrients Are Normalised Too")
    func testNewNutrientsAreNormalisedToo() async {
        let screen = makeScreen(option: .serving, servingWeight: 50)
        screen.presenter.energy = 100
        screen.presenter.leucine = 1
        screen.presenter.water = 20

        await create(screen)

        let saved = screen.interactor.savedFoods.first
        #expect(saved?.nutrients[.leucine] == 2)
        #expect(saved?.nutrients[.water] == 40)
    }

    /// Each new nutrient falls under a category the breakdown already draws, so it is reachable
    /// once stored rather than saved into a section nothing renders.
    @Test("Test New Nutrients Belong To A Drawn Category")
    func testNewNutrientsBelongToADrawnCategory() {
        #expect(NutrientKey.fatTrans.category == .fat)
        #expect(NutrientKey.omega3.category == .fat)
        #expect(NutrientKey.starch.category == .carbs)
        #expect(NutrientKey.addedSugars.category == .carbs)
        #expect(NutrientKey.leucine.category == .protein)
        #expect(NutrientKey.alcohol.category == .other)
        #expect(NutrientKey.water.category == .other)
        // They are entered in grams on the form, so that is what they are stored and shown in.
        #expect(NutrientKey.leucine.unit == "g")
        #expect(NutrientKey.omega3Dha.unit == "g")
    }

    /// A successful creation is logged, so the success rate can be read from the events. It used
    /// to log a start and a failure only, leaving an abandoned form and a completed one
    /// indistinguishable.
    @Test("Test Success Is Logged")
    func testSuccessIsLogged() async {
        let screen = makeScreen()
        screen.presenter.energy = 250

        await create(screen)
        await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("FoodDefinitionView_CreateFood_Success")
        }

        #expect(screen.interactor.trackedEventNames.contains("FoodDefinitionView_CreateFood_Start"))
        #expect(screen.interactor.trackedEventNames.contains("FoodDefinitionView_CreateFood_Success"))
    }

    /// Create-and-add logs it too — it is the same creation with a different next step.
    @Test("Test Create And Add Logs Success")
    func testCreateAndAddLogsSuccess() async {
        let screen = makeScreen()
        screen.presenter.energy = 250

        screen.presenter.onCreateAndAddPressed(delegate: screen.delegate)
        await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("FoodDefinitionView_CreateFood_Success")
        }

        #expect(screen.box.items.count == 1)
    }
}
