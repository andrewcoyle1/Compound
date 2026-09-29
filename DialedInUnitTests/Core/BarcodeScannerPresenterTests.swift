//
//  BarcodeScannerPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The camera route into the food library: point at a barcode and get the product, or point at a
/// nutrition panel and have it read.
///
/// Both halves end in the same place — a `FoodModel` held in `parsedIngredient` — but they get
/// there differently, and the screen has to stay honest about which of the four things it is
/// doing at any moment: scanning, looking up, parsing, or showing a result. Most of what can go
/// wrong here is a stale flag: a spinner that never stops, or last scan's product still on screen
/// under this scan's barcode.
@MainActor
struct BarcodeScannerPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, BarcodeScannerInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")

        /// The JSON the label analyser returns, or an error instead of it.
        var labelJson: String = ""
        var labelError: Error?

        /// The food the remote barcode service returns, or an error instead of it.
        var remoteFood: FoodModel?
        var lookupError: Error?

        /// The food already in the user's library under a given barcode.
        var localFoods: [String: FoodModel] = [:]

        private(set) var analysedTexts: [String] = []
        private(set) var lookedUpCodes: [String] = []
        private(set) var savedFoods: [FoodModel] = []
        var saveError: Error?

        func analyzeNutritionLabel(text: String) async throws -> String {
            analysedTexts.append(text)
            if let labelError { throw labelError }
            return labelJson
        }

        func saveFood(_ ingredient: FoodModel, image: PlatformImage?) async throws {
            if let saveError { throw saveError }
            savedFoods.append(ingredient)
        }

        func lookupBarcode(_ code: String) async throws -> FoodModel {
            lookedUpCodes.append(code)
            if let lookupError { throw lookupError }
            return remoteFood ?? FoodModel(name: "Remote Food", barcode: code)
        }

        func findLocalFood(withBarcode barcode: String) -> FoodModel? {
            localFoods[barcode]
        }
    }

    /// `BarcodeScannerRouter` adds nothing to `GlobalRouter`, and the one navigation the screen
    /// performs — `dismissScreen()` — is a `GlobalRouter` extension, so it dispatches statically
    /// and never reaches a double. There is nothing here to observe; the screen is asserted
    /// through its own state and its analytics instead.
    private final class Router: BarcodeScannerRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: BarcodeScannerPresenter
        let interactor: Interactor
        let delegate = BarcodeScannerDelegate()
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        return Screen(
            presenter: BarcodeScannerPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    /// A nutrition-panel reading in the shape the analyser returns it.
    private func labelJson(
        name: String = "Oat Milk",
        measurementMethod: String = "weight",
        extra: String = ""
    ) -> String {
        """
        {
          "name": "\(name)",
          "measurementMethod": "\(measurementMethod)",
          "calories": 46,
          "protein": 1.2,
          "carbs": 7.1,
          "fatTotal": 1.5
          \(extra)
        }
        """
    }

    /// Drives a barcode through the presenter's detached lookup task and waits for it to settle.
    private func detect(_ code: String, on screen: Screen) async {
        screen.presenter.onBarcodeDetected(code)
        await TestManagers.eventually { !screen.presenter.isLookingUpBarcode }
    }

    // MARK: - The camera

    /// The scanner runs only while the screen is up. Leaving it running behind a pushed screen
    /// would hold the capture session and the torch open with nothing to show for it.
    @Test("Test Scanning Follows The Screen")
    func testScanningFollowsTheScreen() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: screen.delegate)
        #expect(screen.presenter.isScanning)

        screen.presenter.onViewDisappear(delegate: screen.delegate)
        #expect(!screen.presenter.isScanning)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["BarcodeScannerView_Appear"])
    }

    /// The two modes read different things, and the scanner is told which through this set.
    @Test("Test Each Mode Recognises Its Own Data Type")
    func testEachModeRecognisesItsOwnDataType() {
        #expect(ScanningMode.barcode.recognisedTypes == [.barcode()])
        #expect(ScanningMode.label.recognisedTypes == [.text()])
    }

    /// No torch on a simulator or an iPad without one, so the button is hidden rather than dead,
    /// and pressing it anyway leaves the flag alone instead of claiming a light that is not lit.
    @Test("Test The Torch Stays Off When There Is No Torch")
    func testTheTorchStaysOffWhenThereIsNoTorch() {
        let screen = makeScreen()
        guard !screen.presenter.isTorchAvailable else { return }

        screen.presenter.onTorchPressed()

        #expect(!screen.presenter.isTorchOn)
    }

    // MARK: - Typing it in instead

    /// Manual entry is the fallback for a barcode the camera cannot read, so whatever it did
    /// manage to catch is offered rather than making the user type all thirteen digits again.
    @Test("Test Manual Entry Prefills What Was Scanned")
    func testManualEntryPrefillsWhatWasScanned() async {
        let screen = makeScreen()
        screen.interactor.localFoods["5012345678900"] = FoodModel(name: "Oat Milk")
        await detect("5012345678900", on: screen)

        screen.presenter.onManualEntryPressed()

        #expect(screen.presenter.manualEntryText == "5012345678900")
        #expect(screen.presenter.isEnteringManually)
    }

    @Test("Test Manual Entry Starts Empty When Nothing Was Scanned")
    func testManualEntryStartsEmptyWhenNothingWasScanned() {
        let screen = makeScreen()

        screen.presenter.onManualEntryPressed()

        #expect(screen.presenter.manualEntryText.isEmpty)
    }

    /// Submitting nothing keeps the field open rather than dismissing it and looking up "".
    @Test("Test Submitting Blank Manual Entry Does Nothing")
    func testSubmittingBlankManualEntryDoesNothing() {
        let screen = makeScreen()
        screen.presenter.onManualEntryPressed()
        screen.presenter.manualEntryText = "   "

        screen.presenter.onManualEntrySubmitted()

        #expect(screen.presenter.isEnteringManually)
        #expect(screen.presenter.scannedCode == nil)
        #expect(screen.interactor.lookedUpCodes.isEmpty)
    }

    /// A typed barcode goes down the same path a scanned one does — the camera is an input
    /// method, not a separate feature.
    @Test("Test A Typed Barcode Is Looked Up Like A Scanned One")
    func testATypedBarcodeIsLookedUpLikeAScannedOne() async {
        let screen = makeScreen()
        screen.presenter.scanningMode = .barcode
        screen.presenter.manualEntryText = "  5012345678900  "

        screen.presenter.onManualEntrySubmitted()
        await TestManagers.eventually { !screen.interactor.lookedUpCodes.isEmpty }

        #expect(screen.presenter.scannedCode == "5012345678900")
        #expect(screen.interactor.lookedUpCodes == ["5012345678900"])
        #expect(!screen.presenter.isEnteringManually)
    }

    /// In label mode the typed text is panel text, so it is parsed rather than looked up.
    @Test("Test Typed Label Text Is Parsed Not Looked Up")
    func testTypedLabelTextIsParsedNotLookedUp() async {
        let screen = makeScreen()
        screen.presenter.scanningMode = .label
        screen.interactor.labelJson = labelJson()
        screen.presenter.manualEntryText = "Energy 46kcal per 100ml"

        screen.presenter.onManualEntrySubmitted()
        await TestManagers.eventually { screen.presenter.parsedIngredient != nil }

        #expect(screen.interactor.analysedTexts == ["Energy 46kcal per 100ml"])
        #expect(screen.interactor.lookedUpCodes.isEmpty)
    }

    // MARK: - Reading a nutrition panel

    @Test("Test A Parsed Label Becomes A Food")
    func testAParsedLabelBecomesAFood() async {
        let screen = makeScreen()
        screen.interactor.labelJson = labelJson()
        screen.presenter.scannedCode = "Energy 46kcal"

        await screen.presenter.onParseLabelPressed()

        let food = screen.presenter.parsedIngredient
        #expect(food?.name == "Oat Milk")
        #expect(food?.calories == 46)
        #expect(food?.protein == 1.2)
        #expect(food?.fatTotal == 1.5)
        #expect(screen.presenter.labelError == nil)
        #expect(!screen.presenter.isParsingLabel)
    }

    /// The food is the user's own, so it is authored by them — otherwise it would save as
    /// ownerless and never appear in their library.
    @Test("Test A Parsed Label Is Authored By The Current User")
    func testAParsedLabelIsAuthoredByTheCurrentUser() async {
        let screen = makeScreen()
        screen.interactor.labelJson = labelJson()
        screen.presenter.scannedCode = "Energy 46kcal"

        await screen.presenter.onParseLabelPressed()

        #expect(screen.presenter.parsedIngredient?.authorId == "user-1")
    }

    /// A nutrient the panel did not print is absent, not zero. Storing 0 would assert the food
    /// contains none of it, which the label never said.
    @Test("Test Nutrients Absent From The Label Are Absent From The Food")
    func testNutrientsAbsentFromTheLabelAreAbsentFromTheFood() async {
        let screen = makeScreen()
        screen.interactor.labelJson = labelJson()
        screen.presenter.scannedCode = "Energy 46kcal"

        await screen.presenter.onParseLabelPressed()

        #expect(screen.presenter.parsedIngredient?.ironMg == nil)
        #expect(screen.presenter.parsedIngredient?.sodiumMg == nil)
    }

    /// A drink is measured in millilitres, and the panel says so. Getting this wrong makes every
    /// future serving of it scale against the wrong unit.
    @Test("Test A Volume Label Produces A Volume Food")
    func testAVolumeLabelProducesAVolumeFood() async {
        let screen = makeScreen()
        screen.interactor.labelJson = labelJson(measurementMethod: "volume")
        screen.presenter.scannedCode = "Energy 46kcal"

        await screen.presenter.onParseLabelPressed()

        #expect(screen.presenter.parsedIngredient?.measurementMethod == .volume)
    }

    @Test("Test An Unrecognised Measurement Method Falls Back To Weight")
    func testAnUnrecognisedMeasurementMethodFallsBackToWeight() async {
        let screen = makeScreen()
        screen.interactor.labelJson = labelJson(measurementMethod: "nonsense")
        screen.presenter.scannedCode = "Energy 46kcal"

        await screen.presenter.onParseLabelPressed()

        #expect(screen.presenter.parsedIngredient?.measurementMethod == .weight)
    }

    @Test("Test Parsing Without Any Text Does Nothing")
    func testParsingWithoutAnyTextDoesNothing() async {
        let screen = makeScreen()

        await screen.presenter.onParseLabelPressed()

        #expect(screen.interactor.analysedTexts.isEmpty)
        #expect(!screen.presenter.isParsingLabel)
    }

    /// The analyser failing leaves the user something to read and the spinner stopped — a parse
    /// that fails silently reads as one that is still running.
    @Test("Test Offline A Label Is Not Sent And Says You're Offline")
    func testOfflineALabelIsNotSentAndSaysYoureOffline() async {
        let interactor = Interactor()
        interactor.isOffline = true
        let router = Router()
        let presenter = BarcodeScannerPresenter(interactor: interactor, router: router)
        presenter.scannedCode = "Energy 46kcal"

        await presenter.onParseLabelPressed()

        #expect(router.alertTitles == [OfflineError.title])
        #expect(interactor.analysedTexts.isEmpty)
        #expect(!presenter.isParsingLabel)
    }

    /// The library is on the device, so a food already in it is still found offline; only the
    /// remote lookup is refused.
    @Test("Test Offline A Barcode Is Found Locally Or Says You're Offline")
    func testOfflineABarcodeIsFoundLocallyOrSaysYoureOffline() async {
        let interactor = Interactor()
        interactor.isOffline = true
        interactor.localFoods = ["111": FoodModel(name: "Local Oats", barcode: "111")]
        let router = Router()
        let presenter = BarcodeScannerPresenter(interactor: interactor, router: router)

        presenter.onBarcodeDetected("111")
        await TestManagers.eventually { !presenter.isLookingUpBarcode }
        #expect(presenter.parsedIngredient?.name == "Local Oats")
        #expect(router.alertTitles.isEmpty)

        presenter.onBarcodeDetected("222")
        await TestManagers.eventually { !presenter.isLookingUpBarcode }
        #expect(router.alertTitles == [OfflineError.title])
        #expect(interactor.lookedUpCodes.isEmpty)
    }

    @Test("Test A Failed Parse Is Reported And Stops The Spinner")
    func testAFailedParseIsReportedAndStopsTheSpinner() async {
        let screen = makeScreen()
        screen.interactor.labelError = URLError(.notConnectedToInternet)
        screen.presenter.scannedCode = "Energy 46kcal"

        await screen.presenter.onParseLabelPressed()

        #expect(screen.presenter.labelError != nil)
        #expect(screen.presenter.parsedIngredient == nil)
        #expect(!screen.presenter.isParsingLabel)
        #expect(screen.interactor.trackedEventNames.contains("BarcodeScanner_LabelError"))
    }

    /// The analyser is a language model, so malformed JSON is a normal outcome rather than a
    /// programming error, and it has to land as an error message like any other.
    @Test("Test Unreadable Analyser Output Is An Error Not A Crash")
    func testUnreadableAnalyserOutputIsAnErrorNotACrash() async {
        let screen = makeScreen()
        screen.interactor.labelJson = "Sorry, I could not read that label."
        screen.presenter.scannedCode = "Energy 46kcal"

        await screen.presenter.onParseLabelPressed()

        #expect(screen.presenter.labelError != nil)
        #expect(screen.presenter.parsedIngredient == nil)
    }

    /// A second parse clears the first one's error, so a retry that succeeds does not show its
    /// result next to the message explaining why it failed.
    @Test("Test Reparsing Clears The Previous Error")
    func testReparsingClearsThePreviousError() async {
        let screen = makeScreen()
        screen.presenter.scannedCode = "Energy 46kcal"
        screen.interactor.labelError = URLError(.timedOut)
        await screen.presenter.onParseLabelPressed()
        #expect(screen.presenter.labelError != nil)

        screen.interactor.labelError = nil
        screen.interactor.labelJson = labelJson()
        await screen.presenter.onParseLabelPressed()

        #expect(screen.presenter.labelError == nil)
        #expect(screen.presenter.parsedIngredient != nil)
    }

    // MARK: - Keeping what was read

    /// Saving hands the food to the library and puts the camera straight back to work, since the
    /// usual next move is the next item on the shelf.
    @Test("Test Saving An Ingredient Stores It And Resumes Scanning")
    func testSavingAnIngredientStoresItAndResumesScanning() async {
        let screen = makeScreen()
        screen.interactor.labelJson = labelJson()
        screen.presenter.scannedCode = "Energy 46kcal"
        await screen.presenter.onParseLabelPressed()

        await screen.presenter.onSaveIngredientPressed()

        #expect(screen.interactor.savedFoods.map(\.name) == ["Oat Milk"])
        #expect(screen.presenter.savedSuccessfully)
        #expect(screen.presenter.parsedIngredient == nil)
        #expect(screen.presenter.scannedCode == nil)
        #expect(screen.presenter.isScanning)
        #expect(!screen.presenter.isSavingIngredient)
    }

    @Test("Test Saving Without An Ingredient Does Nothing")
    func testSavingWithoutAnIngredientDoesNothing() async {
        let screen = makeScreen()

        await screen.presenter.onSaveIngredientPressed()

        #expect(screen.interactor.savedFoods.isEmpty)
        #expect(!screen.presenter.savedSuccessfully)
    }

    /// A save that fails must not report success or clear the result: the parse was expensive and
    /// throwing it away would make the user rescan the panel to try again.
    @Test("Test A Failed Save Keeps The Parsed Ingredient")
    func testAFailedSaveKeepsTheParsedIngredient() async {
        let screen = makeScreen()
        screen.interactor.labelJson = labelJson()
        screen.presenter.scannedCode = "Energy 46kcal"
        await screen.presenter.onParseLabelPressed()
        screen.interactor.saveError = URLError(.networkConnectionLost)

        await screen.presenter.onSaveIngredientPressed()

        #expect(!screen.presenter.savedSuccessfully)
        #expect(screen.presenter.parsedIngredient != nil)
        #expect(screen.presenter.labelError != nil)
        #expect(screen.interactor.trackedEventNames.contains("BarcodeScanner_LabelError"))
    }

    @Test("Test Dismissing A Result Clears It And Resumes Scanning")
    func testDismissingAResultClearsItAndResumesScanning() async {
        let screen = makeScreen()
        screen.interactor.labelJson = labelJson()
        screen.presenter.scannedCode = "Energy 46kcal"
        await screen.presenter.onParseLabelPressed()

        screen.presenter.onDismissLabelResultPressed()

        #expect(screen.presenter.parsedIngredient == nil)
        #expect(screen.presenter.labelError == nil)
        #expect(!screen.presenter.savedSuccessfully)
        #expect(screen.presenter.isScanning)
    }

    /// Re-scan is the "none of that was right" button, so it has to leave the screen as blank as
    /// it was on arrival — a leftover result or spinner would attach itself to the next scan.
    @Test("Test Rescanning Clears Everything From The Last Scan")
    func testRescanningClearsEverythingFromTheLastScan() async {
        let screen = makeScreen()
        screen.interactor.lookupError = URLError(.badServerResponse)
        await detect("5012345678900", on: screen)
        #expect(screen.presenter.barcodeError != nil)

        screen.presenter.onRescanPressed()

        #expect(screen.presenter.scannedCode == nil)
        #expect(screen.presenter.parsedIngredient == nil)
        #expect(screen.presenter.labelError == nil)
        #expect(screen.presenter.barcodeError == nil)
        #expect(!screen.presenter.isLookingUpBarcode)
        #expect(screen.presenter.isScanning)
    }

    // MARK: - Looking up a barcode

    /// A food already in the library is used as it stands. Going to the network for something the
    /// user has already saved would replace their own edits with the vendor's version.
    @Test("Test A Barcode Already In The Library Is Not Looked Up Remotely")
    func testABarcodeAlreadyInTheLibraryIsNotLookedUpRemotely() async {
        let screen = makeScreen()
        screen.interactor.localFoods["5012345678900"] = FoodModel(name: "My Oat Milk")

        await detect("5012345678900", on: screen)

        #expect(screen.presenter.parsedIngredient?.name == "My Oat Milk")
        #expect(screen.interactor.lookedUpCodes.isEmpty)
        #expect(screen.interactor.savedFoods.isEmpty)
    }

    /// An unknown barcode is fetched and kept, so the next scan of the same product is local.
    @Test("Test An Unknown Barcode Is Fetched And Saved To The Library")
    func testAnUnknownBarcodeIsFetchedAndSavedToTheLibrary() async {
        let screen = makeScreen()
        screen.interactor.remoteFood = FoodModel(name: "Vendor Oat Milk", barcode: "5012345678900")

        await detect("5012345678900", on: screen)

        #expect(screen.interactor.lookedUpCodes == ["5012345678900"])
        #expect(screen.presenter.parsedIngredient?.name == "Vendor Oat Milk")
        #expect(screen.interactor.savedFoods.map(\.name) == ["Vendor Oat Milk"])
        #expect(screen.interactor.savedFoods.first?.authorId == "user-1")
    }

    /// The view feeds every `scannedCode` change back into `onBarcodeDetected`, and typing a
    /// barcode sets the code *and* calls through itself, so the lookup used to run twice. Each run
    /// files its own copy of the product in the library under a fresh id, so the user ends up with
    /// the same food twice and no way to tell which is which.
    @Test("Test A Typed Barcode Is Only Looked Up Once")
    func testATypedBarcodeIsOnlyLookedUpOnce() async {
        let screen = makeScreen()
        screen.interactor.remoteFood = FoodModel(name: "Vendor Oat Milk", barcode: "5012345678900")
        screen.presenter.manualEntryText = "5012345678900"

        screen.presenter.onManualEntrySubmitted()
        // The binding change the view observes, replayed here the way SwiftUI delivers it.
        screen.presenter.onBarcodeDetected(screen.presenter.scannedCode ?? "")
        await TestManagers.eventually { !screen.presenter.isLookingUpBarcode }

        #expect(screen.interactor.lookedUpCodes == ["5012345678900"])
        #expect(screen.interactor.savedFoods.count == 1)
    }

    /// Re-scan is the deliberate retry, so it has to let the same code through again — otherwise a
    /// lookup that failed on a flaky connection could never be tried a second time.
    @Test("Test Rescanning Allows The Same Barcode To Be Looked Up Again")
    func testRescanningAllowsTheSameBarcodeToBeLookedUpAgain() async {
        let screen = makeScreen()
        screen.interactor.lookupError = URLError(.timedOut)
        await detect("5012345678900", on: screen)

        screen.presenter.onRescanPressed()
        screen.interactor.lookupError = nil
        await detect("5012345678900", on: screen)

        #expect(screen.interactor.lookedUpCodes == ["5012345678900", "5012345678900"])
        #expect(screen.presenter.parsedIngredient != nil)
    }

    @Test("Test Detecting A Barcode Is Tracked")
    func testDetectingABarcodeIsTracked() async {
        let screen = makeScreen()
        screen.interactor.localFoods["5012345678900"] = FoodModel(name: "Oat Milk")

        await detect("5012345678900", on: screen)

        #expect(screen.interactor.trackedEventNames.contains("BarcodeScanner_BarcodeDetected"))
    }

    /// An unrecognised barcode is a common, ordinary outcome — most shelves have something
    /// OpenFoodFacts has never seen — so it has to end in a message, not a spinner.
    @Test("Test A Failed Lookup Is Reported And Stops The Spinner")
    func testAFailedLookupIsReportedAndStopsTheSpinner() async {
        let screen = makeScreen()
        screen.interactor.lookupError = URLError(.fileDoesNotExist)

        await detect("5012345678900", on: screen)

        #expect(screen.presenter.barcodeError != nil)
        #expect(screen.presenter.parsedIngredient == nil)
        #expect(!screen.presenter.isLookingUpBarcode)
        #expect(screen.interactor.trackedEventNames.contains("BarcodeScanner_BarcodeError"))
    }

    /// The camera fires repeatedly as it moves across a shelf, so a new code has to displace the
    /// last one's product and the last one's error rather than being shown beside them.
    @Test("Test A New Barcode Replaces The Previous Result")
    func testANewBarcodeReplacesThePreviousResult() async {
        let screen = makeScreen()
        screen.interactor.localFoods["1111111111111"] = FoodModel(name: "First Food")
        screen.interactor.localFoods["2222222222222"] = FoodModel(name: "Second Food")

        await detect("1111111111111", on: screen)
        await detect("2222222222222", on: screen)

        #expect(screen.presenter.scannedCode == "2222222222222")
        #expect(screen.presenter.parsedIngredient?.name == "Second Food")
    }

    /// A successful scan after a failed one clears the failure, so the product is not shown under
    /// the message saying it could not be found.
    @Test("Test A Successful Scan Clears The Previous Barcode Error")
    func testASuccessfulScanClearsThePreviousBarcodeError() async {
        let screen = makeScreen()
        screen.interactor.lookupError = URLError(.fileDoesNotExist)
        await detect("1111111111111", on: screen)
        #expect(screen.presenter.barcodeError != nil)

        screen.interactor.lookupError = nil
        screen.interactor.localFoods["2222222222222"] = FoodModel(name: "Second Food")
        await detect("2222222222222", on: screen)

        #expect(screen.presenter.barcodeError == nil)
        #expect(screen.presenter.parsedIngredient?.name == "Second Food")
    }

    /// The library save is best-effort: the user asked to see a product, not to file it, so a
    /// failed save must still show what was found.
    @Test("Test A Found Product Is Shown Even If It Cannot Be Saved")
    func testAFoundProductIsShownEvenIfItCannotBeSaved() async {
        let screen = makeScreen()
        screen.interactor.remoteFood = FoodModel(name: "Vendor Oat Milk", barcode: "5012345678900")
        screen.interactor.saveError = URLError(.networkConnectionLost)

        await detect("5012345678900", on: screen)

        #expect(screen.presenter.parsedIngredient?.name == "Vendor Oat Milk")
        #expect(screen.presenter.barcodeError == nil)
    }
}
