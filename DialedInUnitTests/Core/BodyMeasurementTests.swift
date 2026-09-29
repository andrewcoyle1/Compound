//
//  BodyMeasurementTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The table behind all eighteen circumference measurements.
///
/// These used to be eighteen copied modules, so a wrong field was a typo in one screen that only
/// that screen could suffer. They are one module driven by one table now, which is the trade: a
/// mispaired row is compile-clean and silently writes, reads or clears the wrong body part on a
/// screen that otherwise looks right. Nothing but these tests would catch it.
@MainActor
struct BodyMeasurementKindTests {

    private let date = Date(timeIntervalSince1970: 1_000_000)

    private func emptyEntry() -> BodyMeasurementEntry {
        BodyMeasurementEntry(authorId: "author-1", date: date)
    }

    /// Every kind has a distinct name, so a duplicated row in the table is visible here rather
    /// than as two screens quietly sharing a field.
    @Test("Test Every Kind Has A Distinct Display Name")
    func testEveryKindHasADistinctDisplayName() {
        let names = BodyMeasurementKind.allCases.map(\.displayName)
        #expect(Set(names).count == BodyMeasurementKind.allCases.count)
        #expect(names.allSatisfy { !$0.isEmpty })
    }

    /// Writing a measurement and reading it back has to return the same number. A row whose
    /// `update` and `keyPath` name different fields passes the compiler and fails here.
    @Test("Test Writing A Measurement Reads Back The Same Value")
    func testWritingAMeasurementReadsBackTheSameValue() {
        for kind in BodyMeasurementKind.allCases {
            let updated = emptyEntry().withUpdated(kind.update(to: 42.5))
            #expect(updated[keyPath: kind.entryValue] == 42.5, "\(kind.displayName) did not read back what it wrote")
        }
    }

    /// Writing one measurement must leave the other seventeen alone. Two rows pointing at the same
    /// field round-trip happily on their own and are only caught here.
    @Test("Test Writing One Measurement Leaves The Others Untouched")
    func testWritingOneMeasurementLeavesTheOthersUntouched() {
        for kind in BodyMeasurementKind.allCases {
            let updated = emptyEntry().withUpdated(kind.update(to: 42.5))
            for other in BodyMeasurementKind.allCases where other != kind {
                #expect(
                    updated[keyPath: other.entryValue] == nil,
                    "writing \(kind.displayName) also wrote \(other.displayName)"
                )
            }
        }
    }

    /// `clearedField` has to name the same field as `entryValue`. It is the one column of the
    /// table that is not exercised by simply opening the screen.
    @Test("Test Clearing A Measurement Clears The Field It Reads")
    func testClearingAMeasurementClearsTheFieldItReads() {
        for kind in BodyMeasurementKind.allCases {
            let written = emptyEntry().withUpdated(kind.update(to: 42.5))
            let cleared = written.withCleared(kind.clearedField)
            #expect(cleared[keyPath: kind.entryValue] == nil, "\(kind.displayName) did not clear the field it reads")
        }
    }

    /// Clearing one measurement must leave its neighbours in place — the delete swipe on a detail
    /// screen would otherwise wipe an unrelated body part.
    @Test("Test Clearing One Measurement Leaves The Others Intact")
    func testClearingOneMeasurementLeavesTheOthersIntact() {
        // An entry carrying every measurement at once, so a stray clear has something to destroy.
        var full = BodyMeasurementEntry(authorId: "author-1", date: date)
        for kind in BodyMeasurementKind.allCases {
            full = full.withUpdated(kind.update(to: 42.5))
        }

        for kind in BodyMeasurementKind.allCases {
            let cleared = full.withCleared(kind.clearedField)
            for other in BodyMeasurementKind.allCases where other != kind {
                #expect(
                    cleared[keyPath: other.entryValue] == 42.5,
                    "clearing \(kind.displayName) also cleared \(other.displayName)"
                )
            }
        }
    }

    /// The pickers have to admit the value they open on, or the wheel starts on a row that is not
    /// in it and the first save writes a different number than the one shown.
    @Test("Test Each Default Sits Inside Its Own Picker Range")
    func testEachDefaultSitsInsideItsOwnPickerRange() {
        for kind in BodyMeasurementKind.allCases {
            #expect(kind.centimetreRange.contains(kind.defaultCentimetres), "\(kind.displayName) cm default is off its wheel")
            #expect(kind.inchRange.contains(kind.defaultInches), "\(kind.displayName) inch default is off its wheel")
        }
    }

    /// The two wheels are the same measurement in different units, so the inch range has to be the
    /// centimetre range converted — not an independently guessed pair of numbers.
    @Test("Test The Inch Range Agrees With The Centimetre Range")
    func testTheInchRangeAgreesWithTheCentimetreRange() {
        for kind in BodyMeasurementKind.allCases {
            let expectedLower = Double(kind.centimetreRange.lowerBound) / 2.54
            let expectedUpper = Double(kind.centimetreRange.upperBound) / 2.54
            #expect(
                abs(Double(kind.inchRange.lowerBound) - expectedLower) <= 1,
                "\(kind.displayName) inch floor \(kind.inchRange.lowerBound) does not match \(kind.centimetreRange.lowerBound)cm"
            )
            #expect(
                abs(Double(kind.inchRange.upperBound) - expectedUpper) <= 1,
                "\(kind.displayName) inch ceiling \(kind.inchRange.upperBound) does not match \(kind.centimetreRange.upperBound)cm"
            )
        }
    }

    /// `BodyMetricType` covers these eighteen plus weight and body fat. The eighteen must map
    /// across, and the two that are not circumferences must not.
    @Test("Test Body Metric Types Map Onto Kinds")
    func testBodyMetricTypesMapOntoKinds() {
        #expect(BodyMetricType.scaleWeight.measurementKind == nil)
        #expect(BodyMetricType.visualBodyFat.measurementKind == nil)
        #expect(BodyMetricType.waist.measurementKind == .waist)
        #expect(BodyMetricType.leftAnkle.measurementKind == .leftAnkle)

        // The mapped type must read the same field as the kind it names.
        let entry = emptyEntry().withUpdated(BodyMeasurementKind.rightThigh.update(to: 61))
        #expect(BodyMetricType.rightThigh.value(from: entry) == 61)
        #expect(BodyMetricType.rightThigh.displayTitle == BodyMeasurementKind.rightThigh.displayName)
    }
}

/// The screen that logs a circumference.
@MainActor
struct LogMeasurementPresenterTests {

    private final class Interactor: SpyGlobalInteractor, LogMeasurementInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var bodyMeasurements: [BodyMeasurementEntry] = []
        private(set) var saved: [BodyMeasurementEntry] = []
        var saveError: Error?

        func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
            if let saveError { throw saveError }
            saved.append(bodyMeasurement)
        }
    }

    private final class Router: LogMeasurementRouter {
        private(set) var didDismiss = false
        private(set) var alertedErrors: [Error] = []

        func showAlert(error: Error) { alertedErrors.append(error) }
        func dismissScreen() { didDismiss = true }
    }

    private struct Screen {
        let presenter: LogMeasurementPresenter
        let interactor: Interactor
        let router: Router
    }

    private let today = Date(timeIntervalSince1970: 1_000_000)

    private func makeScreen(
        kind: BodyMeasurementKind = .waist,
        user: UserModel? = UserModel(userId: "user-1"),
        measurements: [BodyMeasurementEntry] = []
    ) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        interactor.bodyMeasurements = measurements
        let router = Router()
        let presenter = LogMeasurementPresenter(kind: kind, interactor: interactor, router: router)
        presenter.selectedDate = today
        return Screen(presenter: presenter, interactor: interactor, router: router)
    }

    private func entry(id: String, kind: BodyMeasurementKind, centimetres: Double, daysAgo: Int) -> BodyMeasurementEntry {
        let date = today.addingTimeInterval(Double(-daysAgo) * 86400)
        return BodyMeasurementEntry(id: id, authorId: "author-1", date: date)
            .withUpdated(kind.update(to: centimetres))
    }

    /// With nothing logged before, the wheels open on the kind's own defaults rather than a shared
    /// number — a wrist and a waist are not plausible at the same value.
    @Test("Test An Unlogged Measurement Opens On Its Own Defaults")
    func testAnUnloggedMeasurementOpensOnItsOwnDefaults() async {
        let wrist = makeScreen(kind: .leftWrist)
        let waist = makeScreen(kind: .waist)

        await wrist.presenter.loadInitialData()
        await waist.presenter.loadInitialData()

        #expect(wrist.presenter.selectedCentimeters == BodyMeasurementKind.leftWrist.defaultCentimetres)
        #expect(waist.presenter.selectedCentimeters == BodyMeasurementKind.waist.defaultCentimetres)
        #expect(wrist.presenter.selectedCentimeters != waist.presenter.selectedCentimeters)
    }

    /// The wheel opens on what was logged last, so a repeat measurement is a small adjustment.
    @Test("Test The Latest Reading Becomes The Starting Value")
    func testTheLatestReadingBecomesTheStartingValue() async {
        let screen = makeScreen(
            kind: .waist,
            measurements: [
                entry(id: "old", kind: .waist, centimetres: 90, daysAgo: 10),
                entry(id: "new", kind: .waist, centimetres: 84, daysAgo: 1)
            ]
        )

        await screen.presenter.loadInitialData()

        #expect(screen.presenter.selectedCentimeters == 84)
        #expect(screen.presenter.selectedInches == Int(84 / 2.54))
    }

    /// Only this measurement's own history counts. A logged waist must not preload the neck wheel.
    @Test("Test Another Measurements History Is Ignored")
    func testAnotherMeasurementsHistoryIsIgnored() async {
        let screen = makeScreen(kind: .neck, measurements: [entry(id: "w", kind: .waist, centimetres: 90, daysAgo: 1)])

        await screen.presenter.loadInitialData()

        #expect(screen.presenter.selectedCentimeters == BodyMeasurementKind.neck.defaultCentimetres)
    }

    /// The screen opens in the unit the user chose during onboarding.
    @Test("Test The Users Unit Preference Is Applied")
    func testTheUsersUnitPreferenceIsApplied() async {
        let screen = makeScreen(user: UserModel(userId: "user-1", submittedLengthUnitPreference: .inches))

        await screen.presenter.loadInitialData()

        #expect(screen.presenter.unit == .inches)
    }

    /// Storage is centimetres, so an imperial user's inches are converted on the way in — not
    /// written as though they were centimetres.
    @Test("Test Inches Are Converted To Centimetres On Save")
    func testInchesAreConvertedToCentimetresOnSave() async {
        let screen = makeScreen(kind: .waist)
        screen.presenter.unit = .inches
        screen.presenter.selectedInches = 32

        await screen.presenter.saveMeasurement()

        let saved = screen.interactor.saved.first
        #expect(saved?.waistCircumference == 32 * 2.54)
        #expect(screen.router.didDismiss)
    }

    /// A second measurement on a day that already has an entry updates it. Creating another would
    /// leave the day with two conflicting readings.
    @Test("Test Logging Twice In A Day Updates The Same Entry")
    func testLoggingTwiceInADayUpdatesTheSameEntry() async {
        let existing = entry(id: "today", kind: .neck, centimetres: 38, daysAgo: 0)
        let screen = makeScreen(kind: .waist, measurements: [existing])
        screen.presenter.unit = .centimeters
        screen.presenter.selectedCentimeters = 81

        await screen.presenter.saveMeasurement()

        let saved = screen.interactor.saved.first
        #expect(saved?.id == existing.id)
        #expect(saved?.waistCircumference == 81)
        // The neck logged earlier the same day survives the waist being written onto it.
        #expect(saved?.neckCircumference == 38)
    }

    /// With no entry for the day, one is created against the signed-in user.
    @Test("Test Logging On An Empty Day Creates An Entry")
    func testLoggingOnAnEmptyDayCreatesAnEntry() async {
        let screen = makeScreen(kind: .chest, measurements: [entry(id: "old", kind: .chest, centimetres: 100, daysAgo: 5)])
        screen.presenter.unit = .centimeters
        screen.presenter.selectedCentimeters = 104

        await screen.presenter.saveMeasurement()

        let saved = screen.interactor.saved.first
        #expect(saved?.id != "old")
        #expect(saved?.authorId == "user-1")
        #expect(saved?.chestCircumference == 104)
    }

    /// A failed write says so and keeps the screen open, rather than dismissing as though the
    /// measurement had been recorded.
    @Test("Test A Failed Save Reports The Error And Stays Open")
    func testAFailedSaveReportsTheErrorAndStaysOpen() async {
        let screen = makeScreen()
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        await screen.presenter.saveMeasurement()

        #expect(screen.router.alertedErrors.count == 1)
        #expect(screen.router.didDismiss == false)
        #expect(screen.presenter.isLoading == false)
    }

    /// Signed out there is no one to attribute the entry to, so nothing is written.
    @Test("Test No User Means Nothing Is Saved")
    func testNoUserMeansNothingIsSaved() async {
        let screen = makeScreen(user: nil)

        await screen.presenter.saveMeasurement()

        #expect(screen.interactor.saved.isEmpty)
    }
}

/// The detail screen behind a measurement card — its chart, its rows and its delete swipe.
@MainActor
struct BodyMeasurementDetailPresenterTests {

    private final class Interactor: SpyGlobalInteractor, BodyMetricsInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var bodyMeasurements: [BodyMeasurementEntry] = []
        private(set) var saved: [BodyMeasurementEntry] = []
        var saveError: Error?

        func backfillBodyFatFromHealthKit() async { }

        func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
            if let saveError { throw saveError }
            saved.append(bodyMeasurement)
        }

        func uploadImage(image: PlatformImage, path: String) async throws -> URL {
            URL(string: "https://example.invalid/\(path)")!
        }

        func deleteImage(path: String) async throws { }
    }

    private final class Router: BodyMetricsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var loggedKinds: [BodyMeasurementKind] = []

        func showScaleWeightView(delegate: ScaleWeightDelegate, themeColor: Color?) { }
        func showVisualBodyFatView(delegate: VisualBodyFatDelegate, themeColor: Color?) { }
        func showBodyRatioView(delegate: BodyRatioDelegate, themeColor: Color?) { }
        func showBodyMeasurementDetailView(kind: BodyMeasurementKind, themeColor: Color?) { }
        func showLogMeasurementView(kind: BodyMeasurementKind) { loggedKinds.append(kind) }
        func showProgressPhotosView() { }
    }

    private struct Screen {
        let presenter: BodyMeasurementDetailPresenter
        let interactor: Interactor
        let router: Router
    }

    private let today = Date(timeIntervalSince1970: 1_000_000)

    private func entry(id: String, kind: BodyMeasurementKind, centimetres: Double, daysAgo: Int, deleted: Bool = false) -> BodyMeasurementEntry {
        let date = today.addingTimeInterval(Double(-daysAgo) * 86400)
        return BodyMeasurementEntry(
            id: id,
            authorId: "author-1",
            date: date,
            deletedAt: deleted ? date : nil
        ).withUpdated(kind.update(to: centimetres))
    }

    private func makeScreen(
        kind: BodyMeasurementKind = .waist,
        unit: LengthUnitPreference = .centimeters,
        measurements: [BodyMeasurementEntry] = []
    ) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = UserModel(userId: "user-1", submittedLengthUnitPreference: unit)
        interactor.bodyMeasurements = measurements
        let router = Router()
        return Screen(
            presenter: BodyMeasurementDetailPresenter(kind: kind, interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// Only entries carrying this measurement become rows. An entry that recorded a weight and
    /// nothing else is not a blank waist reading.
    @Test("Test Only Entries With This Measurement Become Rows")
    func testOnlyEntriesWithThisMeasurementBecomeRows() async {
        let screen = makeScreen(
            kind: .waist,
            measurements: [
                entry(id: "waist", kind: .waist, centimetres: 80, daysAgo: 1),
                entry(id: "neck", kind: .neck, centimetres: 38, daysAgo: 2)
            ]
        )

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["waist"])
    }

    /// Soft-deleted entries stay out of the chart and the list.
    @Test("Test Deleted Entries Are Left Out")
    func testDeletedEntriesAreLeftOut() async {
        let screen = makeScreen(
            kind: .waist,
            measurements: [
                entry(id: "live", kind: .waist, centimetres: 80, daysAgo: 1),
                entry(id: "gone", kind: .waist, centimetres: 99, daysAgo: 2, deleted: true)
            ]
        )

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["live"])
    }

    /// Storage is centimetres. An imperial user's rows and chart have to be converted, and the
    /// axis suffix has to agree with them — sixteen of the old screens printed centimetres under
    /// a hardcoded inch suffix.
    @Test("Test Values Are Converted To The Users Unit")
    func testValuesAreConvertedToTheUsersUnit() async {
        let screen = makeScreen(kind: .waist, unit: .inches, measurements: [entry(id: "w", kind: .waist, centimetres: 80, daysAgo: 1)])

        await screen.presenter.onAppear()

        let value = screen.presenter.entries.first?.value
        #expect(abs((value ?? 0) - (80 / 2.54)) < 0.0001)
        #expect(screen.presenter.configuration.yAxisSuffix.contains("in"))
    }

    /// A metric user sees the stored number untouched.
    @Test("Test Metric Users See Stored Centimetres")
    func testMetricUsersSeeStoredCentimetres() async {
        let screen = makeScreen(kind: .waist, unit: .centimeters, measurements: [entry(id: "w", kind: .waist, centimetres: 80, daysAgo: 1)])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.first?.value == 80)
    }

    /// Rows run oldest to newest so the chart reads left to right.
    @Test("Test Entries Are Ordered Oldest First")
    func testEntriesAreOrderedOldestFirst() async {
        let screen = makeScreen(
            kind: .waist,
            measurements: [
                entry(id: "newest", kind: .waist, centimetres: 78, daysAgo: 1),
                entry(id: "oldest", kind: .waist, centimetres: 84, daysAgo: 9)
            ]
        )

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["oldest", "newest"])
    }

    /// The add button opens the logger for the measurement being viewed, not a fixed one.
    @Test("Test Adding Opens The Logger For This Measurement")
    func testAddingOpensTheLoggerForThisMeasurement() {
        let screen = makeScreen(kind: .rightCalf)

        screen.presenter.onAddPressed()

        #expect(screen.router.loggedKinds == [.rightCalf])
    }

    /// Deleting a row clears that measurement and leaves the rest of the day's entry alone — the
    /// entry is shared by every measurement taken that day.
    @Test("Test Deleting A Row Clears Only That Measurement")
    func testDeletingARowClearsOnlyThatMeasurement() async {
        let shared = entry(id: "day", kind: .waist, centimetres: 80, daysAgo: 1).withUpdated(BodyMeasurementKind.neck.update(to: 38))
        let screen = makeScreen(kind: .waist, measurements: [shared])
        await screen.presenter.onAppear()
        let row = screen.presenter.entries.first

        if let row { await screen.presenter.onDeleteEntry(row) }

        let saved = screen.interactor.saved.first
        #expect(saved?.waistCircumference == nil)
        #expect(saved?.neckCircumference == 38)
    }

    /// A delete that fails leaves the row in place. It used to be a `try?`, so the refresh put the
    /// row straight back and the failure looked like the swipe simply not registering.
    @Test("Test A Failed Delete Keeps The Row")
    func testAFailedDeleteKeepsTheRow() async {
        let screen = makeScreen(kind: .waist, measurements: [entry(id: "w", kind: .waist, centimetres: 80, daysAgo: 1)])
        await screen.presenter.onAppear()
        screen.interactor.saveError = URLError(.timedOut)
        let row = screen.presenter.entries.first

        if let row { await screen.presenter.onDeleteEntry(row) }

        #expect(screen.presenter.entries.map(\.id) == ["w"])
    }

    /// The screen names the measurement it is showing, everywhere it names it.
    @Test("Test The Screen Is Titled For Its Measurement")
    func testTheScreenIsTitledForItsMeasurement() {
        let screen = makeScreen(kind: .leftForearm)

        #expect(screen.presenter.configuration.title == "Left Forearm Circumference")
        #expect(screen.presenter.configuration.seriesNames == ["Left Forearm Circumference"])
        #expect(screen.presenter.configuration.emptyStateMessage == "No left forearm measurement entries")
    }
}
