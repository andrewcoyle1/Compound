//
//  AIFoodInputPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The two screens that let a model do the logging: photograph the plate, or describe it in words.
///
/// Both end in the same place — a list of `FoodAnalysisItem` the user taps to add — and both are
/// fed by a language model, so malformed or surprising output is a normal Tuesday rather than a
/// programming error. What matters is that a bad answer lands as a message with the spinner
/// stopped, that a retry clears the last one, and that the item built from a result carries what
/// the model actually said rather than zeroes standing in for what it did not.
@MainActor
struct FoodPhotoScannerPresenterTests {

    private final class Interactor: SpyGlobalInteractor, FoodPhotoScannerInteractor {
        var json: String = ""
        var error: Error?
        private(set) var analysedByteCounts: [Int] = []

        func analyzeFood(imageData: Data) async throws -> String {
            analysedByteCounts.append(imageData.count)
            if let error { throw error }
            return json
        }

        var cameraPermission: CameraAccess = .authorized
        private(set) var settingsOpened = 0
        func requestCameraPermission() async -> Bool { false }
        func openAppSettings() { settingsOpened += 1 }
    }

    private final class Router: FoodPhotoScannerRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []
        private(set) var amountDelegates: [IngredientAmountDelegate] = []
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
        func showIngredientAmountView(delegate: IngredientAmountDelegate) { amountDelegates.append(delegate) }
    }

    private struct Screen {
        let presenter: FoodPhotoScannerPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: FoodPhotoScannerPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// A real one-pixel image, so `jpegData` has something to encode.
    private var image: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    /// One item in the shape the analyser returns it.
    private func json(name: String = "Scrambled Eggs", extra: String = "") -> String {
        """
        {"items": [{
            "id": "1",
            "name": "\(name)",
            "amountGrams": 150,
            "calories": 220,
            "proteinGrams": 14,
            "carbGrams": 2,
            "fatGrams": 17
            \(extra)
        }]}
        """
    }

    @Test("Test A Photo Is Analysed Into Items")
    func testAPhotoIsAnalysedIntoItems() async {
        let screen = makeScreen()
        screen.interactor.json = json()

        await screen.presenter.onCapture(image)

        #expect(screen.presenter.analysisResults.map(\.name) == ["Scrambled Eggs"])
        #expect(screen.presenter.errorMessage == nil)
        #expect(!screen.presenter.isAnalysing)
    }

    @Test("Test The Captured Image Reaches The Analyser")
    func testTheCapturedImageReachesTheAnalyser() async {
        let screen = makeScreen()
        screen.interactor.json = json()

        await screen.presenter.onCapture(image)

        #expect(screen.interactor.analysedByteCounts.count == 1)
        #expect((screen.interactor.analysedByteCounts.first ?? 0) > 0)
    }

    /// The analyser is a language model, so unparseable output is an ordinary outcome and has to
    /// land as a message rather than a crash.
    @Test("Test Unreadable Output Is An Error Not A Crash")
    func testUnreadableOutputIsAnErrorNotACrash() async {
        let screen = makeScreen()
        screen.interactor.json = "I could not see the plate clearly."

        await screen.presenter.onCapture(image)

        #expect(screen.presenter.errorMessage != nil)
        #expect(screen.presenter.analysisResults.isEmpty)
        #expect(!screen.presenter.isAnalysing)
    }

    /// A failure must stop the spinner. A spinner that never stops is indistinguishable from a
    /// request still in flight, and the user has no way back.
    /// The analyser is a Cloud Function: offline, the photo is not sent and no spinner starts.
    @Test("Test Offline A Photo Is Not Sent And Says You're Offline")
    func testOfflineAPhotoIsNotSentAndSaysYoureOffline() async {
        let interactor = Interactor()
        interactor.isOffline = true
        let router = Router()
        let presenter = FoodPhotoScannerPresenter(interactor: interactor, router: router)

        await presenter.onCapture(image)

        #expect(router.alertTitles == [OfflineError.title])
        #expect(interactor.analysedByteCounts.isEmpty)
        #expect(!presenter.isAnalysing)
        // The photo is already on screen; an empty Results section under it said nothing.
        #expect(presenter.errorMessage != nil)
    }

    @Test("Test A Failed Analysis Stops The Spinner And Is Reported")
    func testAFailedAnalysisStopsTheSpinnerAndIsReported() async {
        let screen = makeScreen()
        screen.interactor.error = URLError(.notConnectedToInternet)

        await screen.presenter.onCapture(image)

        #expect(screen.presenter.errorMessage != nil)
        #expect(!screen.presenter.isAnalysing)
        #expect(screen.interactor.trackedEventNames.contains("FoodPhotoScanner_Error"))
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    /// A second capture clears the first one's results and error, so a retry that works does not
    /// show its plate under the message explaining why the last one failed.
    @Test("Test A Second Capture Clears The First Ones Outcome")
    func testASecondCaptureClearsTheFirstOnesOutcome() async {
        let screen = makeScreen()
        screen.interactor.error = URLError(.timedOut)
        await screen.presenter.onCapture(image)
        #expect(screen.presenter.errorMessage != nil)

        screen.interactor.error = nil
        screen.interactor.json = json(name: "Porridge")
        await screen.presenter.onCapture(image)

        #expect(screen.presenter.errorMessage == nil)
        #expect(screen.presenter.analysisResults.map(\.name) == ["Porridge"])
    }

    @Test("Test Retaking Clears Everything From The Last Shot")
    func testRetakingClearsEverythingFromTheLastShot() async {
        let screen = makeScreen()
        screen.interactor.json = json()
        await screen.presenter.onCapture(image)

        screen.presenter.onRetakePressed()

        #expect(screen.presenter.analysisResults.isEmpty)
        #expect(screen.presenter.errorMessage == nil)
        #expect(!screen.presenter.isAnalysing)
    }

    /// The model's figures are absolute for the amount it estimated, so they go through unscaled
    /// and the amount becomes the item's weight.
    @Test("Test An Item Carries The Models Figures Unscaled")
    func testAnItemCarriesTheModelsFiguresUnscaled() async {
        let screen = makeScreen()
        screen.interactor.json = json()
        await screen.presenter.onCapture(image)
        let result = screen.presenter.analysisResults.first

        let item = result?.mealItem

        #expect(item?.displayName == "Scrambled Eggs")
        #expect(item?.amount == 150)
        #expect(item?.unit == "g")
        #expect(item?.resolvedGrams == 150)
        #expect(item?.nutrients[.calories] == 220)
        #expect(item?.nutrients[.protein] == 14)
    }

    /// A nutrient the model did not give is absent rather than zero — it did not say the food has
    /// none of it, only that it did not estimate it.
    @Test("Test A Nutrient The Model Omitted Is Absent")
    func testANutrientTheModelOmittedIsAbsent() async {
        let screen = makeScreen()
        screen.interactor.json = """
        {"items": [{"id": "1", "name": "Toast", "amountGrams": 40, "calories": 110}]}
        """
        await screen.presenter.onCapture(image)
        let result = screen.presenter.analysisResults.first

        let item = result?.mealItem

        #expect(item?.nutrients[.calories] == 110)
        #expect(item?.nutrients[.protein] == nil)
        #expect(item?.nutrients[.fatTotal] == nil)
    }

    /// When the model recognises a food already in the library the item points at it, so the row
    /// opens the real food rather than a one-off guess.
    @Test("Test A Recognised Food Is Pointed At")
    func testARecognisedFoodIsPointedAt() async {
        let screen = makeScreen()
        screen.interactor.json = json(extra: ", \"ingredientId\": \"food-1\"")
        await screen.presenter.onCapture(image)
        let result = screen.presenter.analysisResults.first

        let item = result?.mealItem

        #expect(item?.sourceId == "food-1")
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["FoodPhotoScannerView_Appear"])
    }

    /// Estimates can be wrong, so a tapped result opens the amount screen prefilled at the
    /// model's amount, rather than adding the estimate as is.
    @Test("Test Tapping A Result Opens The Amount Screen Prefilled")
    func testTappingAResultOpensTheAmountScreenPrefilled() async {
        let screen = makeScreen()
        screen.interactor.json = json()
        await screen.presenter.onCapture(image)
        let result = screen.presenter.analysisResults.first

        var picked: MealItemModel?
        if let result {
            screen.presenter.onResultTapped(result) { picked = $0 }
        }

        let delegate = screen.router.amountDelegates.first
        #expect(delegate?.ingredient.name == "Scrambled Eggs")
        #expect(delegate?.initialAmountText == "150")
        // Per 100g at 150g estimated 220 kcal, the amount screen has to read back 220 at 150.
        #expect(delegate?.ingredient.calories == 220 / 150.0 * 100.0)

        delegate?.onPick(MealItemModel(itemId: "x", sourceType: .ingredient, sourceId: "food-1", displayName: "Scrambled Eggs", amount: 150, unit: "g", nutrients: NutrientMap()))
        #expect(picked?.displayName == "Scrambled Eggs")
    }

    /// Add All puts every result on the plate at its estimate in one tap, and only once.
    @Test("Test Add All Adds Every Result Once")
    func testAddAllAddsEveryResultOnce() async {
        let screen = makeScreen()
        screen.interactor.json = """
        {"items": [
            {"id": "1", "name": "Eggs", "amountGrams": 150, "calories": 220},
            {"id": "2", "name": "Toast", "amountGrams": 40, "calories": 110}
        ]}
        """
        await screen.presenter.onCapture(image)

        var picked: [MealItemModel] = []
        screen.presenter.onAddAllPressed { picked.append($0) }
        screen.presenter.onAddAllPressed { picked.append($0) }

        #expect(picked.map(\.displayName) == ["Eggs", "Toast"])
        #expect(picked.map(\.amount) == [150, 40])
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
        #expect(screen.router.amountDelegates.isEmpty)
    }

    /// A refused camera used to show a capture button over a black preview. It is now its own
    /// state, with Settings as the way back, and kept apart from a device with no camera.
    @Test("Test A Refused Camera Is Told Apart From A Missing One")
    func testARefusedCameraIsToldApartFromAMissingOne() async {
        let refused = makeScreen()
        refused.interactor.cameraPermission = .denied
        await refused.presenter.onCameraNeeded(isSupported: true)
        refused.presenter.onOpenSettingsPressed()

        let missing = makeScreen()
        await missing.presenter.onCameraNeeded(isSupported: false)

        #expect(refused.presenter.cameraAccess == .denied)
        #expect(refused.interactor.settingsOpened == 1)
        #expect(missing.presenter.cameraAccess == .unsupported)
    }
}

/// Describing a meal in words and letting the model break it into items.
@MainActor
struct MealDescribePresenterTests {

    private final class Interactor: SpyGlobalInteractor, MealDescribeInteractor {
        var json: String = ""
        var error: Error?
        private(set) var describedTexts: [String] = []

        func describeMeal(text: String) async throws -> String {
            describedTexts.append(text)
            if let error { throw error }
            return json
        }
    }

    private final class Router: MealDescribeRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []
        private(set) var amountDelegates: [IngredientAmountDelegate] = []
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
        func showIngredientAmountView(delegate: IngredientAmountDelegate) { amountDelegates.append(delegate) }
    }

    /// Main-actor isolated so it is `Sendable` for the pick closure.
    @MainActor
    private final class PickBox {
        var picked: [MealItemModel] = []
    }

    private struct Screen {
        let presenter: MealDescribePresenter
        let interactor: Interactor
        let router: Router
        let box: PickBox
        let delegate: MealDescribeDelegate
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        let box = PickBox()
        return Screen(
            presenter: MealDescribePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router,
            box: box,
            delegate: MealDescribeDelegate(onPick: { box.picked.append($0) })
        )
    }

    /// Simulates the amount screen's own "Add": taps the result to open it, then confirms with the
    /// prefilled amount, the way `IngredientAmountPresenter.add` hands the item back.
    private func tapAndConfirm(_ item: FoodAnalysisItem, on screen: Screen) {
        screen.presenter.onResultTapped(item, delegate: screen.delegate)
        guard let delegate = screen.router.amountDelegates.last else { return }
        delegate.onPick(delegate.ingredient.mealItem(amount: Double(delegate.initialAmountText ?? "") ?? 0))
    }

    private var json: String {
        """
        {"items": [
            {"id": "1", "name": "Porridge", "amountGrams": 200, "calories": 180, "proteinGrams": 6},
            {"id": "2", "name": "Banana", "amountGrams": 120, "calories": 105}
        ]}
        """
    }

    @Test("Test A Description Is Broken Into Items")
    func testADescriptionIsBrokenIntoItems() async {
        let screen = makeScreen()
        screen.interactor.json = json
        screen.presenter.descriptionText = "Porridge and a banana"

        await screen.presenter.onAnalysePressed()

        #expect(screen.presenter.analysisResults.map(\.name) == ["Porridge", "Banana"])
        #expect(screen.interactor.describedTexts == ["Porridge and a banana"])
        #expect(!screen.presenter.isAnalysing)
    }

    /// Submitting nothing asks the model nothing — an empty description has no answer worth
    /// paying for.
    @Test("Test An Empty Description Is Not Submitted")
    func testAnEmptyDescriptionIsNotSubmitted() async {
        let screen = makeScreen()
        screen.presenter.descriptionText = "   "

        await screen.presenter.onAnalysePressed()

        #expect(screen.interactor.describedTexts.isEmpty)
        #expect(!screen.presenter.isAnalysing)
    }

    @Test("Test Offline A Description Is Not Sent And Says You're Offline")
    func testOfflineADescriptionIsNotSentAndSaysYoureOffline() async {
        let interactor = Interactor()
        interactor.isOffline = true
        let router = Router()
        let presenter = MealDescribePresenter(interactor: interactor, router: router)
        presenter.descriptionText = "Porridge with honey"

        await presenter.onAnalysePressed()

        #expect(router.alertTitles == [OfflineError.title])
        #expect(interactor.describedTexts.isEmpty)
        #expect(!presenter.isAnalysing)
    }

    @Test("Test A Failed Description Stops The Spinner And Is Reported")
    func testAFailedDescriptionStopsTheSpinnerAndIsReported() async {
        let screen = makeScreen()
        screen.interactor.error = URLError(.notConnectedToInternet)
        screen.presenter.descriptionText = "Porridge"

        await screen.presenter.onAnalysePressed()

        #expect(screen.presenter.errorMessage != nil)
        #expect(!screen.presenter.isAnalysing)
        #expect(screen.interactor.trackedEventNames.contains("MealDescribe_Error"))
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    @Test("Test A Description Is Held To The Character Limit")
    func testADescriptionIsHeldToTheCharacterLimit() {
        let screen = makeScreen()
        let long = String(repeating: "a", count: screen.presenter.characterLimit + 20)
        screen.presenter.descriptionText = long

        screen.presenter.onDescriptionChanged(long)

        #expect(screen.presenter.descriptionText.count == screen.presenter.characterLimit)
    }

    @Test("Test Analyse Is Enabled Only With A Description")
    func testAnalyseIsEnabledOnlyWithADescription() {
        let screen = makeScreen()
        screen.presenter.descriptionText = "  "
        #expect(!screen.presenter.canAnalyse)

        screen.presenter.descriptionText = "Porridge"
        #expect(screen.presenter.canAnalyse)
    }

    @Test("Test Unreadable Output Is An Error Not A Crash")
    func testUnreadableOutputIsAnErrorNotACrash() async {
        let screen = makeScreen()
        screen.interactor.json = "I am not sure what you ate."
        screen.presenter.descriptionText = "Porridge"

        await screen.presenter.onAnalysePressed()

        #expect(screen.presenter.errorMessage != nil)
        #expect(screen.presenter.analysisResults.isEmpty)
    }

    /// Resubmitting clears the last answer, so a second description does not show its items
    /// alongside the first one's.
    @Test("Test Resubmitting Clears The Previous Answer")
    func testResubmittingClearsThePreviousAnswer() async {
        let screen = makeScreen()
        screen.interactor.json = json
        screen.presenter.descriptionText = "Porridge and a banana"
        await screen.presenter.onAnalysePressed()

        screen.interactor.json = """
        {"items": [{"id": "3", "name": "Toast", "amountGrams": 40, "calories": 110}]}
        """
        screen.presenter.descriptionText = "Toast"
        await screen.presenter.onAnalysePressed()

        #expect(screen.presenter.analysisResults.map(\.name) == ["Toast"])
    }

    /// Estimates can be wrong, so tapping a result opens the amount screen prefilled rather than
    /// adding it directly; confirming there hands exactly that item to the plate.
    @Test("Test Tapping A Result Opens The Amount Screen, And Confirming Hands It To The Plate")
    func testTappingAResultOpensTheAmountScreenAndConfirmingHandsItToThePlate() async {
        let screen = makeScreen()
        screen.interactor.json = json
        screen.presenter.descriptionText = "Porridge and a banana"
        await screen.presenter.onAnalysePressed()
        let result = screen.presenter.analysisResults.first

        if let result {
            tapAndConfirm(result, on: screen)
        }

        #expect(screen.router.amountDelegates.first?.initialAmountText == "200")
        #expect(screen.box.picked.map(\.displayName) == ["Porridge"])
        #expect(screen.box.picked.first?.amount == 200)
        #expect(screen.box.picked.first?.nutrients[.calories] == 180)
        #expect(screen.interactor.trackedEventNames.contains("MealDescribe_AddItem"))
    }

    /// Adding one result does not add the others: the list is a set of suggestions, and the user
    /// picks the ones they actually ate.
    @Test("Test Adding One Result Leaves The Others Alone")
    func testAddingOneResultLeavesTheOthersAlone() async {
        let screen = makeScreen()
        screen.interactor.json = json
        screen.presenter.descriptionText = "Porridge and a banana"
        await screen.presenter.onAnalysePressed()

        if let second = screen.presenter.analysisResults.last {
            tapAndConfirm(second, on: screen)
        }

        #expect(screen.box.picked.map(\.displayName) == ["Banana"])
        #expect(screen.presenter.analysisResults.count == 2)
    }

    /// Add All puts every result on the plate at its estimate in one tap, and only once; a new
    /// analysis allows it again.
    @Test("Test Add All Adds Every Result Once")
    func testAddAllAddsEveryResultOnce() async {
        let screen = makeScreen()
        screen.interactor.json = json
        screen.presenter.descriptionText = "Porridge and a banana"
        await screen.presenter.onAnalysePressed()

        screen.presenter.onAddAllPressed(delegate: screen.delegate)
        screen.presenter.onAddAllPressed(delegate: screen.delegate)

        #expect(screen.box.picked.map(\.displayName) == ["Porridge", "Banana"])
        #expect(screen.box.picked.map(\.amount) == [200, 120])
        #expect(screen.box.picked.first?.nutrients[.calories] == 180)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
        #expect(screen.router.amountDelegates.isEmpty)

        await screen.presenter.onAnalysePressed()
        #expect(!screen.presenter.didAddAll)
    }

    @Test("Test A Nutrient The Model Omitted Is Absent")
    func testANutrientTheModelOmittedIsAbsent() async {
        let screen = makeScreen()
        screen.interactor.json = json
        screen.presenter.descriptionText = "Porridge and a banana"
        await screen.presenter.onAnalysePressed()

        if let banana = screen.presenter.analysisResults.last {
            tapAndConfirm(banana, on: screen)
        }

        #expect(screen.box.picked.first?.nutrients[.calories] == 105)
        #expect(screen.box.picked.first?.nutrients[.protein] == nil)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["MealDescribeView_Appear"])
    }
}
