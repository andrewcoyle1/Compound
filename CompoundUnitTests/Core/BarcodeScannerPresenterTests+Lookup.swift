//
//  BarcodeScannerPresenterTests+Lookup.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

extension BarcodeScannerPresenterTests {

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
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    /// Open Food Facts rate-limits bursts of lookups with a 429 page. That, or no connection, is
    /// not "this product doesn't exist", and saying so sends people to re-type a good barcode.
    @Test("Test Only A Missing Product Is Reported As Not Found")
    func testOnlyAMissingProductIsReportedAsNotFound() async {
        let missing = makeScreen()
        missing.interactor.lookupError = OFFError.productNotFound
        await detect("5012345678900", on: missing)

        let unreachable = makeScreen()
        unreachable.interactor.lookupError = URLError(.badServerResponse)
        await detect("5012345678900", on: unreachable)

        #expect(missing.presenter.barcodeError?.hasPrefix("Couldn't find") == true)
        #expect(unreachable.presenter.barcodeError?.hasPrefix("Couldn't reach") == true)
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
