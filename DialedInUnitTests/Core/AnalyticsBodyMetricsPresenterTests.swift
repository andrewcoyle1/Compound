//
//  AnalyticsBodyMetricsPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The Body Metrics grid: twenty cards, each a sparkline over the last seven readings.
///
/// Every number on these cards is stored in one unit and shown in another, so the conversions are
/// what most of this file pins. Dates are fixed and none of them is today.
@MainActor
struct AnalyticsBodyMetricsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, BodyMetricsInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var bodyMeasurements: [BodyMeasurementEntry] = []

        func backfillBodyFatFromHealthKit() async { }
        func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws { }
        func uploadImage(image: PlatformImage, path: String) async throws -> URL {
            URL(string: "https://example.invalid/\(path)")!
        }
        func deleteImage(path: String) async throws { }
    }

    private final class Router: BodyMetricsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showScaleWeightView(delegate: ScaleWeightDelegate, themeColor: Color?) { shown.append("scaleWeight") }
        func showVisualBodyFatView(delegate: VisualBodyFatDelegate, themeColor: Color?) { shown.append("visualBodyFat") }
        func showBodyRatioView(delegate: BodyRatioDelegate, themeColor: Color?) { shown.append("ratio-\(delegate.kind.rawValue)") }
        func showBodyMeasurementDetailView(kind: BodyMeasurementKind, themeColor: Color?) { shown.append("detail-\(kind)") }
        func showLogMeasurementView(kind: BodyMeasurementKind) { shown.append("log-\(kind)") }
        func showProgressPhotosView() { }
    }

    private struct Screen {
        let presenter: BodyMetricsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func date(day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: day, hour: 9)) ?? Date()
    }

    private func makeScreen(
        measurements: [BodyMeasurementEntry] = [],
        weightUnit: WeightUnitPreference = .kilograms,
        lengthUnit: LengthUnitPreference = .centimeters,
        heightCm: Double? = 180
    ) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = UserModel(
            userId: "user-1",
            submittedHeightCentimeters: heightCm,
            submittedLengthUnitPreference: lengthUnit,
            submittedWeightUnitPreference: weightUnit
        )
        interactor.bodyMeasurements = measurements
        let router = Router()
        return Screen(
            presenter: BodyMetricsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Units

    /// A circumference is stored in centimetres. An imperial user's card has to show the converted
    /// number under the "in" caption — every card used to print centimetres under "in", so a 40cm
    /// neck read as a 40 inch one.
    @Test("Test A Circumference Card Converts To Inches")
    func testACircumferenceCardConvertsToInches() {
        let screen = makeScreen(
            measurements: [BodyMeasurementEntry(authorId: "author-1", neckCircumference: 40.64, date: date(day: 4))],
            lengthUnit: .inches
        )

        let card = screen.presenter.displayModel(for: .neck)

        #expect(card.latestValueText == "16.0")
        #expect(card.unitText == "in")
    }

    @Test("Test A Metric User Sees The Stored Centimetres")
    func testAMetricUserSeesTheStoredCentimetres() {
        let screen = makeScreen(measurements: [BodyMeasurementEntry(authorId: "author-1", neckCircumference: 40.6, date: date(day: 4))])

        let card = screen.presenter.displayModel(for: .neck)

        #expect(card.latestValueText == "40.6")
        #expect(card.unitText == "cm")
    }

    /// Weight is kilograms, not centimetres — a shared conversion for both would put a bodyweight
    /// through the length formula.
    @Test("Test The Weight Card Converts To Pounds")
    func testTheWeightCardConvertsToPounds() {
        let screen = makeScreen(
            measurements: [BodyMeasurementEntry(authorId: "author-1", weightKg: 100, date: date(day: 4))],
            weightUnit: .pounds
        )

        let card = screen.presenter.displayModel(for: .scaleWeight)

        #expect(card.latestValueText == "220.5")
        #expect(card.unitText == "lbs")
    }

    /// A body fat percentage is a percentage in every unit system.
    @Test("Test Body Fat Is Never Converted")
    func testBodyFatIsNeverConverted() {
        let screen = makeScreen(
            measurements: [BodyMeasurementEntry(authorId: "author-1", bodyFatPercentage: 18.2, date: date(day: 4))],
            weightUnit: .pounds,
            lengthUnit: .inches
        )

        let card = screen.presenter.displayModel(for: .visualBodyFat)

        #expect(card.latestValueText == "18.2")
        #expect(card.unitText == "%")
    }

    /// The sparkline is drawn in the same unit as the number printed beside it, or the line and the
    /// figure describe different bodies.
    @Test("Test The Sparkline Is In The Same Unit As The Value")
    func testTheSparklineIsInTheSameUnitAsTheValue() {
        let screen = makeScreen(
            measurements: [BodyMeasurementEntry(authorId: "author-1", weightKg: 100, date: date(day: 4))],
            weightUnit: .pounds
        )

        let card = screen.presenter.displayModel(for: .scaleWeight)

        #expect((card.sparklineData.first?.value ?? 0) > 220)
    }

    // MARK: - Which readings a card shows

    /// A card shows its own measurement's history. An entry that recorded a waist says nothing
    /// about a neck.
    @Test("Test A Card Ignores Other Measurements")
    func testACardIgnoresOtherMeasurements() {
        let screen = makeScreen(measurements: [
            BodyMeasurementEntry(authorId: "author-1", waistCircumference: 80, date: date(day: 4))
        ])

        let card = screen.presenter.displayModel(for: .neck)

        #expect(card.latestValueText == "--")
        #expect(card.subtitle == "No Entries")
        #expect(card.sparklineData.isEmpty)
    }

    /// Deleted readings leave the card, rather than staying on as the latest value.
    @Test("Test A Deleted Reading Leaves The Card")
    func testADeletedReadingLeavesTheCard() {
        let deletedDay = date(day: 9)
        let screen = makeScreen(measurements: [
            BodyMeasurementEntry(authorId: "author-1", waistCircumference: 80, date: date(day: 4)),
            BodyMeasurementEntry(authorId: "author-1", waistCircumference: 99, date: deletedDay, deletedAt: deletedDay)
        ])

        let card = screen.presenter.displayModel(for: .waist)

        #expect(card.latestValueText == "80.0")
        #expect(card.sparklineData.count == 1)
    }

    /// The card is the last seven readings — the eighth-oldest drops off rather than being
    /// averaged in.
    @Test("Test A Card Keeps Only The Last Seven Readings")
    func testACardKeepsOnlyTheLastSevenReadings() {
        let measurements = (1...9).map { day in
            BodyMeasurementEntry(authorId: "author-1", waistCircumference: Double(70 + day), date: date(day: day))
        }
        let screen = makeScreen(measurements: measurements)

        let card = screen.presenter.displayModel(for: .waist)

        #expect(card.sparklineData.count == 7)
        // The latest reading is day 9's, not day 1's — the suffix must be taken after sorting.
        #expect(card.latestValueText == "79.0")
        #expect(card.subtitle == "Last 7 Entries")
    }

    /// Readings arrive from the sync engine in no particular order, so the "latest" value has to be
    /// the newest by date rather than whichever happened to be last in the array.
    @Test("Test The Latest Value Is The Newest Reading")
    func testTheLatestValueIsTheNewestReading() {
        let screen = makeScreen(measurements: [
            BodyMeasurementEntry(authorId: "author-1", waistCircumference: 84, date: date(day: 2)),
            BodyMeasurementEntry(authorId: "author-1", waistCircumference: 80, date: date(day: 11)),
            BodyMeasurementEntry(authorId: "author-1", waistCircumference: 82, date: date(day: 6))
        ])

        let card = screen.presenter.displayModel(for: .waist)

        #expect(card.latestValueText == "80.0")
    }

    // MARK: - The ratio cards

    /// Waist-to-height is computed from the profile height, so with no height there is no ratio to
    /// show rather than a number divided by nothing.
    @Test("Test Waist To Height Needs A Height")
    func testWaistToHeightNeedsAHeight() throws {
        let screen = makeScreen(
            measurements: [BodyMeasurementEntry(authorId: "author-1", waistCircumference: 80, date: date(day: 4))],
            heightCm: nil
        )

        let card = try #require(screen.presenter.ratioCards.first { $0.id == .waistToHeight })

        #expect(card.latestValueText == "--")
        #expect(card.subtitle == "No Entries")
    }

    /// Both sides are centimetres, so the ratio is a straight division — an 80cm waist at 180cm
    /// tall is 0.44, on the healthy side of the 0.5 threshold the ratio exists for.
    @Test("Test Waist To Height Divides Centimetres By Centimetres")
    func testWaistToHeightDividesCentimetresByCentimetres() throws {
        let screen = makeScreen(
            measurements: [BodyMeasurementEntry(authorId: "author-1", waistCircumference: 80, date: date(day: 4))],
            lengthUnit: .inches,
            heightCm: 180
        )

        let card = try #require(screen.presenter.ratioCards.first { $0.id == .waistToHeight })

        #expect(card.latestValueText == "0.44")
    }

    /// Waist over hip needs both measured on the same day: a waist from today over a hip from last
    /// month is not a ratio of anything.
    @Test("Test Waist To Hip Needs Both On One Entry")
    func testWaistToHipNeedsBothOnOneEntry() throws {
        let screen = makeScreen(measurements: [
            BodyMeasurementEntry(authorId: "author-1", waistCircumference: 80, date: date(day: 4)),
            BodyMeasurementEntry(authorId: "author-1", hipCircumference: 100, date: date(day: 6))
        ])

        let card = try #require(screen.presenter.ratioCards.first { $0.id == .waistToHip })

        #expect(card.latestValueText == "--")
    }

    @Test("Test Waist To Hip Uses One Days Pair")
    func testWaistToHipUsesOneDaysPair() throws {
        let screen = makeScreen(measurements: [
            BodyMeasurementEntry(authorId: "author-1", waistCircumference: 80, hipCircumference: 100, date: date(day: 4))
        ])

        let card = try #require(screen.presenter.ratioCards.first { $0.id == .waistToHip })

        #expect(card.latestValueText == "0.80")
        #expect(card.subtitle == "Last 1 Entries")
    }

    // MARK: - The grid and its navigation

    /// Twenty cards over four sections, each measurement appearing exactly once — a card listed
    /// twice or missed entirely is only visible here.
    @Test("Test Every Metric Appears Once Across The Sections")
    func testEveryMetricAppearsOnceAcrossTheSections() {
        let screen = makeScreen()

        let ids = screen.presenter.sections.flatMap { $0.cards.map(\.id) }

        #expect(ids.count == 20)
        #expect(Set(ids).count == 20)
        #expect(screen.presenter.sections.map(\.header) == ["Weight & Body Fat", "Upper Body", "Arms", "Legs"])
    }

    /// Weight and body fat have their own screens; every circumference shares one, reached by kind.
    @Test("Test Each Card Opens Its Own Screen")
    func testEachCardOpensItsOwnScreen() {
        let screen = makeScreen()

        screen.presenter.onMeasurementPressed(.scaleWeight, themeColor: nil)
        screen.presenter.onMeasurementPressed(.visualBodyFat, themeColor: nil)
        screen.presenter.onMeasurementPressed(.leftCalf, themeColor: nil)

        #expect(screen.router.shown == ["scaleWeight", "visualBodyFat", "detail-leftCalf"])
    }

    @Test("Test A Ratio Card Opens Its Own Ratio")
    func testARatioCardOpensItsOwnRatio() {
        let screen = makeScreen()

        screen.presenter.onRatioPressed(.waistToHip, themeColor: nil)

        #expect(screen.router.shown == ["ratio-waistToHip"])
    }

    @Test("Test Appearing Is Tracked")
    func testAppearingIsTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["BodyMetricsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["BodyMetricsView_Disappear"])
    }
}

/// The Scale Weight screen: the weight history chart and its rows.
@MainActor
struct AnalyticsScaleWeightPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ScaleWeightInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var bodyMeasurements: [BodyMeasurementEntry] = []
        private(set) var saved: [BodyMeasurementEntry] = []
        var saveError: Error?

        func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
            if let saveError { throw saveError }
            saved.append(bodyMeasurement)
        }
    }

    private final class Router: ScaleWeightRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var didShowLogWeight = false

        func showLogWeightView() { didShowLogWeight = true }
    }

    private struct Screen {
        let presenter: ScaleWeightPresenter
        let interactor: Interactor
        let router: Router
    }

    private func date(day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: day, hour: 9)) ?? Date()
    }

    private func entry(id: String, kilograms: Double?, day: Int, deleted: Bool = false, waistCm: Double? = nil) -> BodyMeasurementEntry {
        let when = date(day: day)
        return BodyMeasurementEntry(
            id: id,
            authorId: "author-1",
            weightKg: kilograms,
            waistCircumference: waistCm,
            date: when,
            deletedAt: deleted ? when : nil
        )
    }

    private func makeScreen(measurements: [BodyMeasurementEntry] = [], unit: WeightUnitPreference = .kilograms) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = UserModel(userId: "user-1", submittedWeightUnitPreference: unit)
        interactor.bodyMeasurements = measurements
        let router = Router()
        return Screen(
            presenter: ScaleWeightPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// Only weigh-ins are plotted: an entry that recorded a waist and nothing else is not a
    /// bodyweight of zero.
    @Test("Test Only Entries Carrying A Weight Are Plotted")
    func testOnlyEntriesCarryingAWeightArePlotted() async throws {
        let screen = makeScreen(measurements: [
            entry(id: "weighed", kilograms: 82, day: 4),
            entry(id: "waist", kilograms: nil, day: 5, waistCm: 80)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["weighed"])
        #expect(try #require(screen.presenter.timeSeries.first).data.map(\.id) == ["weighed"])
    }

    @Test("Test Deleted Weigh Ins Are Left Out")
    func testDeletedWeighInsAreLeftOut() async {
        let screen = makeScreen(measurements: [
            entry(id: "live", kilograms: 82, day: 4),
            entry(id: "gone", kilograms: 99, day: 5, deleted: true)
        ])

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.map(\.id) == ["live"])
    }

    /// The chart is plotted in the user's unit, not in storage's. The card that opens this screen
    /// converts, and the two must agree.
    @Test("Test The Chart Is Plotted In The Users Unit")
    func testTheChartIsPlottedInTheUsersUnit() async throws {
        let screen = makeScreen(measurements: [entry(id: "a", kilograms: 100, day: 4)], unit: .pounds)

        await screen.presenter.onAppear()
        let point = try #require(screen.presenter.timeSeries.first?.data.first)

        #expect(abs(point.value - 220.462) < 0.01)
        #expect(screen.presenter.configuration.yAxisSuffix == " lbs")
    }

    @Test("Test A Kilogram User Sees Stored Kilograms")
    func testAKilogramUserSeesStoredKilograms() async throws {
        let screen = makeScreen(measurements: [entry(id: "a", kilograms: 82.4, day: 4)])

        await screen.presenter.onAppear()

        #expect(try #require(screen.presenter.timeSeries.first?.data.first).value == 82.4)
        #expect(screen.presenter.configuration.yAxisSuffix == " kg")
    }

    /// This screen is the weight line, not the consistency grid, however many weigh-ins there are.
    @Test("Test The Screen Draws A Line Not A Grid")
    func testTheScreenDrawsALineNotAGrid() async {
        let screen = makeScreen(measurements: [entry(id: "a", kilograms: 82, day: 4)])

        await screen.presenter.onAppear()

        #expect(screen.presenter.contributionSeries == nil)
        #expect(screen.presenter.configuration.title == "Scale Weight")
    }

    /// Deleting a weigh-in clears the weight and leaves everything else measured that day, since
    /// one entry carries the whole day.
    @Test("Test Deleting Clears Only The Weight")
    func testDeletingClearsOnlyTheWeight() async throws {
        let screen = makeScreen(measurements: [entry(id: "day", kilograms: 82, day: 4, waistCm: 80)])
        await screen.presenter.onAppear()
        let row = try #require(screen.presenter.entries.first)

        await screen.presenter.onDeleteEntry(row)

        #expect(screen.interactor.saved.first?.weightKg == nil)
        #expect(screen.interactor.saved.first?.waistCircumference == 80)
    }

    /// A failed delete keeps the row. The alert goes through a `GlobalRouter` extension method a
    /// double cannot intercept, so the state is what is asserted.
    @Test("Test A Failed Delete Keeps The Row")
    func testAFailedDeleteKeepsTheRow() async throws {
        let screen = makeScreen(measurements: [entry(id: "a", kilograms: 82, day: 4)])
        await screen.presenter.onAppear()
        screen.interactor.saveError = URLError(.notConnectedToInternet)
        let row = try #require(screen.presenter.entries.first)

        await screen.presenter.onDeleteEntry(row)

        #expect(screen.presenter.entries.map(\.id) == ["a"])
    }

    /// The alert was the only thing a failed delete produced. Nothing reached analytics, so a
    /// backend refusing every write looked the same as nobody deleting anything.
    @Test("Test A Failed Delete Reports The Failure")
    func testAFailedDeleteReportsTheFailure() async throws {
        let screen = makeScreen(measurements: [entry(id: "a", kilograms: 82, day: 4)])
        await screen.presenter.onAppear()
        screen.interactor.saveError = URLError(.notConnectedToInternet)
        let row = try #require(screen.presenter.entries.first)

        await screen.presenter.onDeleteEntry(row)

        #expect(screen.interactor.trackedEventNames == ["ScaleWeightView_DeleteEntry_Fail"])
    }

    @Test("Test A Delete That Works Reports Nothing")
    func testADeleteThatWorksReportsNothing() async throws {
        let screen = makeScreen(measurements: [entry(id: "a", kilograms: 82, day: 4)])
        await screen.presenter.onAppear()
        let row = try #require(screen.presenter.entries.first)

        await screen.presenter.onDeleteEntry(row)

        #expect(screen.interactor.trackedEventNames.isEmpty)
    }

    @Test("Test Adding Opens The Weight Logger")
    func testAddingOpensTheWeightLogger() {
        let screen = makeScreen()

        screen.presenter.onAddPressed()

        #expect(screen.router.didShowLogWeight)
    }

    @Test("Test With No Weigh Ins The Chart Is Empty")
    func testWithNoWeighInsTheChartIsEmpty() async throws {
        let screen = makeScreen()

        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.isEmpty)
        #expect(try #require(screen.presenter.timeSeries.first).data.isEmpty)
    }
}

/// The weight logger behind the Add button.
@MainActor
struct AnalyticsLogWeightPresenterTests {

    private final class Interactor: SpyGlobalInteractor, LogWeightInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var bodyMeasurements: [BodyMeasurementEntry] = []
        private(set) var saved: [BodyMeasurementEntry] = []
        private(set) var profileWeights: [(Double, WeightUnitPreference)] = []
        var saveError: Error?

        func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
            if let saveError { throw saveError }
            saved.append(bodyMeasurement)
        }

        func updateWeight(userId: String, weight: Double, weightUnitPreference: WeightUnitPreference) async throws {
            profileWeights.append((weight, weightUnitPreference))
        }
    }

    /// `LogWeightRouter` adds nothing to `GlobalRouter`, and `dismissScreen()` is a protocol
    /// extension method — statically dispatched, so a double's own copy is never the one called.
    /// The tests below assert what was written rather than whether the screen closed.
    private final class Router: LogWeightRouter {
        let router: AnyRouter = TestRouting.anyRouter

        // Unguarded on purpose: the requirement is behind `#if DEV || MOCK` and the test target
        // builds without `-DDEV`, so a guarded stub would be missing in exactly the configuration
        // that needs it.
        func showDevSettingsView() { }
    }

    private struct Screen {
        let presenter: LogWeightPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(user: UserModel? = UserModel(userId: "user-1")) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        let router = Router()
        return Screen(
            presenter: LogWeightPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The wheels open on the weight already on the profile, in both units, so switching the unit
    /// picker does not jump to an unrelated number.
    @Test("Test The Wheels Open On The Profile Weight")
    func testTheWheelsOpenOnTheProfileWeight() async {
        let screen = makeScreen(user: UserModel(
            userId: "user-1",
            submittedWeightKilograms: 82,
            submittedWeightUnitPreference: .pounds
        ))

        await screen.presenter.loadInitialData()

        #expect(screen.presenter.unit == .pounds)
        #expect(screen.presenter.selectedKilograms == 82)
        #expect(screen.presenter.selectedPounds == 180)
    }

    /// A kilogram entry is stored as typed.
    @Test("Test Kilograms Are Stored As Typed")
    func testKilogramsAreStoredAsTyped() async {
        let screen = makeScreen()
        screen.presenter.unit = .kilograms
        screen.presenter.selectedKilograms = 84

        await screen.presenter.saveWeight()

        #expect(screen.interactor.saved.first?.weightKg == 84)
    }

    /// Storage is kilograms, so a pounds entry is converted on the way in — writing 185 as though
    /// it were kilograms would double the user's recorded bodyweight.
    @Test("Test Pounds Are Converted To Kilograms On Save")
    func testPoundsAreConvertedToKilogramsOnSave() async throws {
        let screen = makeScreen()
        screen.presenter.unit = .pounds
        screen.presenter.selectedPounds = 185

        await screen.presenter.saveWeight()

        let saved = try #require(screen.interactor.saved.first?.weightKg)
        #expect(abs(saved - 83.91) < 0.05)
    }

    /// The entry is recorded on the day the user picked, not the day they typed it in — a weigh-in
    /// backdated to Monday belongs on Monday.
    @Test("Test The Entry Takes The Chosen Date")
    func testTheEntryTakesTheChosenDate() async {
        let screen = makeScreen()
        let chosen = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 7)) ?? Date()
        screen.presenter.selectedDate = chosen
        screen.presenter.selectedKilograms = 80

        await screen.presenter.saveWeight()

        #expect(screen.interactor.saved.first?.date == chosen)
    }

    /// The profile's current weight is updated alongside the history entry, in kilograms, so the
    /// two cannot drift apart.
    @Test("Test The Profile Weight Is Updated In Kilograms")
    func testTheProfileWeightIsUpdatedInKilograms() async throws {
        let screen = makeScreen()
        screen.presenter.unit = .pounds
        screen.presenter.selectedPounds = 185

        await screen.presenter.saveWeight()

        let update = try #require(screen.interactor.profileWeights.first)
        #expect(abs(update.0 - 83.91) < 0.05)
        #expect(update.1 == .pounds)
    }

    /// A write that fails records nothing — neither the history entry nor the profile weight, so
    /// the two cannot end up disagreeing — and the screen is left usable rather than spinning.
    @Test("Test A Failed Save Records Nothing")
    func testAFailedSaveRecordsNothing() async {
        let screen = makeScreen()
        screen.interactor.saveError = URLError(.timedOut)

        await screen.presenter.saveWeight()

        #expect(screen.interactor.saved.isEmpty)
        #expect(screen.interactor.profileWeights.isEmpty)
        #expect(screen.presenter.isLoading == false)
    }

    /// Signed out there is nobody to attribute the weigh-in to, so nothing is written.
    @Test("Test Signed Out Nothing Is Saved")
    func testSignedOutNothingIsSaved() async {
        let screen = makeScreen(user: nil)

        await screen.presenter.saveWeight()

        #expect(screen.interactor.saved.isEmpty)
        #expect(screen.interactor.profileWeights.isEmpty)
    }

    /// The history rows on this screen read in the unit being logged in.
    @Test("Test The History Reads In The Chosen Unit")
    func testTheHistoryReadsInTheChosenUnit() {
        let screen = makeScreen()
        screen.presenter.unit = .pounds

        #expect(screen.presenter.formatWeight(100) == "220.5 lbs")
        screen.presenter.unit = .kilograms
        #expect(screen.presenter.formatWeight(100) == "100.0 kg")
        #expect(screen.presenter.formatWeight(nil) == "--")
    }
}
