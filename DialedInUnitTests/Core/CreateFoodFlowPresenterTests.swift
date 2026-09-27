//
//  CreateFoodFlowPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The first screens of creating a food by hand: the name and barcode, then optionally the
/// packaging photos, on the way to the nutrition panel.
///
/// Neither screen saves anything. They are a funnel, and the only thing they can get wrong is
/// losing what the user typed on the way to the next step — which is exactly what a delegate
/// handed on by hand, field by field, invites. Every test here is about what survives the hop.
@MainActor
struct CreateFoodPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, CreateFoodInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")

        func saveFood(_ ingredient: FoodModel, image: PlatformImage?) async throws { }

        func generateImage(input: String) async throws -> UIImage {
            UIImage()
        }
    }

    /// `showDevSettingsView()` is declared unguarded: the test target builds without `-DDEV`, so a
    /// double that guards it the way the router does would not satisfy the protocol.
    private final class Router: CreateFoodRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var portionDelegates: [PortionDefinitionDelegate] = []
        private(set) var packagingDelegates: [FoodPackagingDelegate] = []
        private(set) var barcodeDelegates: [BarcodeScannerDelegate] = []
        private(set) var simpleAlerts: [String] = []

        func showDevSettingsView() { }

        func showPortionDefinitionView(delegate: PortionDefinitionDelegate) {
            portionDelegates.append(delegate)
        }

        func showFoodPackagingView(delegate: FoodPackagingDelegate) {
            packagingDelegates.append(delegate)
        }

        func showBarcodeScannerView(delegate: BarcodeScannerDelegate) {
            barcodeDelegates.append(delegate)
        }

        func showSimpleAlert(title: String, subtitle: String?) {
            simpleAlerts.append(title)
        }
    }

    private struct Screen {
        let presenter: CreateFoodPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: CreateFoodPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// A screen with the fields the user would have filled in.
    private func filledScreen() -> Screen {
        let screen = makeScreen()
        screen.presenter.name = "Oat Milk"
        screen.presenter.brandName = "Brand"
        screen.presenter.barcode = "5012345678900"
        return screen
    }

    // MARK: - What can be saved

    @Test("Test A Food Cannot Be Saved Without A Name")
    func testAFoodCannotBeSavedWithoutAName() {
        let screen = makeScreen()
        screen.presenter.name = "   "

        #expect(!screen.presenter.canSave)
    }

    @Test("Test A Named Food Can Be Saved")
    func testANamedFoodCanBeSaved() {
        let screen = makeScreen()
        screen.presenter.name = "Oat Milk"

        #expect(screen.presenter.canSave)
    }

    // MARK: - Which way the flow forks

    /// With the contribute toggle off, the packaging step is skipped: those photos exist for the
    /// public database, so a private food has no reason to ask for them.
    @Test("Test A Private Food Goes Straight To The Portion Step")
    func testAPrivateFoodGoesStraightToThePortionStep() {
        let screen = filledScreen()
        screen.presenter.contributeToPublicDatabase = false

        screen.presenter.onNextPressed(delegate: CreateFoodDelegate())

        #expect(screen.router.portionDelegates.count == 1)
        #expect(screen.router.packagingDelegates.isEmpty)
    }

    @Test("Test A Contributed Food Goes Through The Packaging Step")
    func testAContributedFoodGoesThroughThePackagingStep() {
        let screen = filledScreen()
        screen.presenter.contributeToPublicDatabase = true

        screen.presenter.onNextPressed(delegate: CreateFoodDelegate())

        #expect(screen.router.packagingDelegates.count == 1)
        #expect(screen.router.portionDelegates.isEmpty)
    }

    // MARK: - What survives the hop

    /// The fork is the risky part: two call sites build the next delegate by hand, so one of them
    /// dropping a field is the obvious failure. Both are checked.
    @Test("Test The Typed Fields Reach The Portion Step")
    func testTheTypedFieldsReachThePortionStep() {
        let screen = filledScreen()

        screen.presenter.onNextPressed(delegate: CreateFoodDelegate())

        let delegate = screen.router.portionDelegates.first
        #expect(delegate?.name == "Oat Milk")
        #expect(delegate?.brandName == "Brand")
        #expect(delegate?.barcode == "5012345678900")
    }

    @Test("Test The Typed Fields Reach The Packaging Step")
    func testTheTypedFieldsReachThePackagingStep() {
        let screen = filledScreen()
        screen.presenter.contributeToPublicDatabase = true

        screen.presenter.onNextPressed(delegate: CreateFoodDelegate())

        let delegate = screen.router.packagingDelegates.first
        #expect(delegate?.name == "Oat Milk")
        #expect(delegate?.brandName == "Brand")
        #expect(delegate?.barcode == "5012345678900")
    }

    /// Skipping the packaging step means there are no packaging photos to carry, and the portion
    /// step must be told that rather than left with something stale.
    @Test("Test The Private Route Carries No Packaging Photos")
    func testThePrivateRouteCarriesNoPackagingPhotos() {
        let screen = filledScreen()

        screen.presenter.onNextPressed(delegate: CreateFoodDelegate())

        let delegate = screen.router.portionDelegates.first
        #expect(delegate?.productFront == nil)
        #expect(delegate?.nutritionPhoto == nil)
    }

    // MARK: - The barcode scanner

    /// The scanner hands its result back through a closure, and the field has to receive it —
    /// otherwise the scan appears to work and the barcode is silently lost at the next step.
    @Test("Test A Scanned Barcode Lands In The Field")
    func testAScannedBarcodeLandsInTheField() {
        let screen = makeScreen()

        screen.presenter.onBarcodeScannerPressed()
        let delegate = screen.router.barcodeDelegates.first
        delegate?.onBarcodeScanned?("5012345678900")

        #expect(screen.presenter.barcode == "5012345678900")
    }

    /// And it has to survive the hop, which is the whole point of catching it.
    @Test("Test A Scanned Barcode Reaches The Next Step")
    func testAScannedBarcodeReachesTheNextStep() {
        let screen = makeScreen()
        screen.presenter.name = "Oat Milk"

        screen.presenter.onBarcodeScannerPressed()
        screen.router.barcodeDelegates.first?.onBarcodeScanned?("5012345678900")
        screen.presenter.onNextPressed(delegate: CreateFoodDelegate())

        #expect(screen.router.portionDelegates.first?.barcode == "5012345678900")
    }

    // MARK: - Odds and ends

    @Test("Test Learn More Explains The Toggle")
    func testLearnMoreExplainsTheToggle() {
        let screen = makeScreen()

        screen.presenter.onLearnMorePressed()

        #expect(screen.router.simpleAlerts == ["Contributing Foods"])
        #expect(screen.interactor.trackedEventNames.contains("CreateFoodView_LearnMore_Press"))
    }

    @Test("Test Opening The Image Picker Is Tracked")
    func testOpeningTheImagePickerIsTracked() {
        let screen = makeScreen()

        screen.presenter.onImageSelectorPressed()

        #expect(screen.presenter.isImagePickerPresented)
        #expect(screen.interactor.trackedEventNames.contains("IngredientImageSelector_Start"))
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["CreateFoodView_Appear"])
    }
}

/// The optional packaging-photo step, between naming a food and defining its portions.
///
/// It holds nothing of its own worth testing — its whole job is to add two photos to what it was
/// handed and pass everything on. So that is what is tested: the two photos arrive, and nothing
/// that came in goes missing on the way out.
@MainActor
struct FoodPackagingPresenterTests {

    private final class Interactor: SpyGlobalInteractor, FoodPackagingInteractor { }

    private final class Router: FoodPackagingRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var portionDelegates: [PortionDefinitionDelegate] = []

        func showPortionDefinitionView(delegate: PortionDefinitionDelegate) {
            portionDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: FoodPackagingPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: FoodPackagingPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func delegate() -> FoodPackagingDelegate {
        FoodPackagingDelegate(
            name: "Oat Milk",
            brandName: "Brand",
            barcode: "5012345678900",
            image: nil
        )
    }

    /// A one-pixel PNG, so `PlatformImage(data:)` has something real to decode.
    private var imageData: Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }.pngData() ?? Data()
    }

    /// The name, brand and barcode came from two screens back. This step neither shows nor edits
    /// them, which is exactly why they are easy to drop here.
    @Test("Test Everything Handed In Is Handed On")
    func testEverythingHandedInIsHandedOn() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: delegate())

        let passed = screen.router.portionDelegates.first
        #expect(passed?.name == "Oat Milk")
        #expect(passed?.brandName == "Brand")
        #expect(passed?.barcode == "5012345678900")
    }

    @Test("Test The Chosen Photos Reach The Portion Step")
    func testTheChosenPhotosReachThePortionStep() {
        let screen = makeScreen()
        screen.presenter.selectedFrontImageData = imageData
        screen.presenter.selectedNutritionImageData = imageData

        screen.presenter.onNextPressed(delegate: delegate())

        let passed = screen.router.portionDelegates.first
        #expect(passed?.productFront != nil)
        #expect(passed?.nutritionPhoto != nil)
    }

    /// Both photos are optional, and the two are independent — picking only the label should not
    /// carry an empty front image, or vice versa.
    @Test("Test One Photo Can Be Chosen Without The Other")
    func testOnePhotoCanBeChosenWithoutTheOther() {
        let screen = makeScreen()
        screen.presenter.selectedNutritionImageData = imageData

        screen.presenter.onNextPressed(delegate: delegate())

        let passed = screen.router.portionDelegates.first
        #expect(passed?.productFront == nil)
        #expect(passed?.nutritionPhoto != nil)
    }

    @Test("Test Skipping Both Photos Carries Neither")
    func testSkippingBothPhotosCarriesNeither() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: delegate())

        let passed = screen.router.portionDelegates.first
        #expect(passed?.productFront == nil)
        #expect(passed?.nutritionPhoto == nil)
    }

    @Test("Test The Photo Pickers Open Independently")
    func testThePhotoPickersOpenIndependently() {
        let screen = makeScreen()

        screen.presenter.onFrontImageSelectorPressed()

        #expect(screen.presenter.isFrontImagePickerPresented)
        #expect(!screen.presenter.isRearImagePickerPresented)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: delegate())

        #expect(screen.interactor.trackedScreenEventNames == ["FoodPackagingView_Appear"])
    }
}

/// Picking the foods that go into a recipe.
@MainActor
struct AddFoodPresenterTests {

    private final class Interactor: SpyGlobalInteractor, AddFoodInteractor {
        var foods: [FoodModel] = []
    }

    private final class Router: AddFoodRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showDevSettingsView() { }
    }

    private func makeScreen(foods: [FoodModel] = []) -> (AddFoodPresenter, Interactor) {
        let interactor = Interactor()
        interactor.foods = foods
        return (AddFoodPresenter(interactor: interactor, router: Router()), interactor)
    }

    private func food(_ name: String) -> FoodModel {
        FoodModel(ingredientId: name, name: name)
    }

    @Test("Test The Library Is Offered As It Stands")
    func testTheLibraryIsOfferedAsItStands() {
        let (presenter, _) = makeScreen(foods: [food("Oats"), food("Milk")])

        #expect(presenter.foods.map(\.name) == ["Oats", "Milk"])
    }

    @Test("Test Pressing A Food Selects It")
    func testPressingAFoodSelectsIt() {
        let (presenter, interactor) = makeScreen()
        var selected: [FoodModel] = []

        presenter.onIngredientPressed(ingredient: food("Oats"), selectedIngredients: &selected)

        #expect(selected.map(\.name) == ["Oats"])
        #expect(interactor.playedHaptics.map { "\($0)" } == ["selection"])
    }

    @Test("Test Search Narrows The Library By Name Or Description")
    func testSearchNarrowsTheLibraryByNameOrDescription() {
        let milk = FoodModel(ingredientId: "Milk", name: "Milk", description: "Semi-skimmed")
        let (presenter, _) = makeScreen(foods: [food("Oats"), milk])

        presenter.searchText = " skimmed "
        #expect(presenter.filteredFoods.map(\.name) == ["Milk"])

        presenter.searchText = ""
        #expect(presenter.filteredFoods.map(\.name) == ["Oats", "Milk"])
    }

    /// The row is a toggle, so pressing a selected food takes it back out rather than adding a
    /// second copy of it to the recipe.
    @Test("Test Pressing A Selected Food Deselects It")
    func testPressingASelectedFoodDeselectsIt() {
        let (presenter, _) = makeScreen()
        var selected: [FoodModel] = [food("Oats")]

        presenter.onIngredientPressed(ingredient: food("Oats"), selectedIngredients: &selected)

        #expect(selected.isEmpty)
    }

    @Test("Test Deselecting One Food Leaves The Others Selected")
    func testDeselectingOneFoodLeavesTheOthersSelected() {
        let (presenter, _) = makeScreen()
        var selected: [FoodModel] = [food("Oats"), food("Milk"), food("Honey")]

        presenter.onIngredientPressed(ingredient: food("Milk"), selectedIngredients: &selected)

        #expect(selected.map(\.name) == ["Oats", "Honey"])
    }
}
