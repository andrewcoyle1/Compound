//
//  WeightTrendPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The Weight Trend screen's presenter, and the pattern for testing any of the others.
///
/// A presenter needs two doubles: its interactor, which is a small protocol listing exactly what
/// the screen reads, and its router, which `GlobalRouter` reduces to one `AnyRouter` property.
/// Both are written below in about thirty lines, which is what each of the remaining screens costs.
///
/// What is worth testing here is the shaping: deleted and weightless entries are filtered out, the
/// readings are smoothed into a trend, and the trend line only appears once there is enough data to
/// draw one.
@MainActor
struct WeightTrendPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, WeightTrendInteractor {
        var currentUser: UserModel?
        var bodyMeasurements: [BodyMeasurementEntry] = []
        private(set) var savedMeasurements: [BodyMeasurementEntry] = []

        func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
            savedMeasurements.append(bodyMeasurement)
        }
    }

    private final class Router: WeightTrendRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var didShowLogWeight = false

        func showLogWeightView() {
            didShowLogWeight = true
        }
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func entry(id: String, weightKg: Double?, daysAgo: Int, deleted: Bool = false) -> BodyMeasurementEntry {
        let date = start.addingTimeInterval(Double(-daysAgo) * 86400)
        return BodyMeasurementEntry(
            id: id,
            authorId: "author-1",
            weightKg: weightKg,
            date: date,
            source: .manual,
            dateCreated: date,
            deletedAt: deleted ? date : nil
        )
    }

    /// A presenter with its doubles, so a test can reach whichever it needs.
    private struct Screen {
        let presenter: WeightTrendPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(_ measurements: [BodyMeasurementEntry] = []) -> Screen {
        let interactor = Interactor()
        interactor.bodyMeasurements = measurements
        let router = Router()
        return Screen(
            presenter: WeightTrendPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - What the chart plots

    @Test("Test The Scale Weight Series Holds Every Weigh-In")
    func testTheScaleWeightSeriesHoldsEveryWeighIn() {
        let screen = makeScreen([
            entry(id: "e1", weightKg: 73.0, daysAgo: 2),
            entry(id: "e2", weightKg: 72.6, daysAgo: 1),
            entry(id: "e3", weightKg: 72.4, daysAgo: 0)
        ])

        let scale = screen.presenter.timeSeries.first { $0.name == "Scale Weight" }

        #expect(scale?.data.count == 3)
    }

    /// The trend is what the screen is for, so both series are plotted together.
    @Test("Test A Trend Line Is Plotted Alongside The Readings")
    func testATrendLineIsPlottedAlongsideTheReadings() {
        let screen = makeScreen([
            entry(id: "e1", weightKg: 73.0, daysAgo: 2),
            entry(id: "e2", weightKg: 72.6, daysAgo: 1)
        ])

        #expect(screen.presenter.timeSeries.map(\.name) == ["Scale Weight", "Trend Weight"])
    }

    /// One reading is not a trend, so the line is left off rather than drawn through a single point.
    @Test("Test One Weigh-In Gets No Trend Line")
    func testOneWeighInGetsNoTrendLine() {
        let screen = makeScreen([entry(id: "e1", weightKg: 73.0, daysAgo: 0)])

        #expect(screen.presenter.timeSeries.map(\.name) == ["Scale Weight"])
    }

    @Test("Test No Weigh-Ins Leave The Chart Empty")
    func testNoWeighInsLeaveTheChartEmpty() {
        let screen = makeScreen([])

        #expect(screen.presenter.entries.isEmpty)
        #expect(screen.presenter.timeSeries.first { $0.name == "Scale Weight" }?.data.isEmpty == true)
    }

    // MARK: - What is left out

    /// A deleted weigh-in must not reappear on the chart.
    @Test("Test Deleted Weigh-Ins Are Left Out")
    func testDeletedWeighInsAreLeftOut() {
        let screen = makeScreen([
            entry(id: "e1", weightKg: 73.0, daysAgo: 2),
            entry(id: "gone", weightKg: 99.0, daysAgo: 1, deleted: true),
            entry(id: "e3", weightKg: 72.4, daysAgo: 0)
        ])

        let scale = screen.presenter.timeSeries.first { $0.name == "Scale Weight" }

        #expect(scale?.data.count == 2)
        #expect(scale?.data.allSatisfy { $0.value != 99.0 } == true)
    }

    /// An entry recording only a waist measurement has no weight to plot.
    @Test("Test Entries Without A Weight Are Left Out")
    func testEntriesWithoutAWeightAreLeftOut() {
        let screen = makeScreen([
            entry(id: "e1", weightKg: 73.0, daysAgo: 1),
            entry(id: "waist", weightKg: nil, daysAgo: 0)
        ])

        #expect(screen.presenter.timeSeries.first { $0.name == "Scale Weight" }?.data.count == 1)
    }

    // MARK: - The trend itself

    /// The rows under the chart are the smoothed values, not the raw readings, and the first of
    /// them starts on the scale.
    @Test("Test The Trend Starts At The First Reading")
    func testTheTrendStartsAtTheFirstReading() throws {
        let screen = makeScreen([
            entry(id: "e1", weightKg: 80.0, daysAgo: 2),
            entry(id: "e2", weightKg: 70.0, daysAgo: 1),
            entry(id: "e3", weightKg: 70.0, daysAgo: 0)
        ])

        let first = try #require(screen.presenter.entries.first)

        #expect(first.trendValue == 80.0)
    }

    /// A single heavy day barely moves the trend — the whole reason the screen shows one.
    @Test("Test A Spike Barely Moves The Trend")
    func testASpikeBarelyMovesTheTrend() throws {
        let steady = (2...10).reversed().map { entry(id: "e\($0)", weightKg: 72.0, daysAgo: $0) }
        let screen = makeScreen(steady + [entry(id: "spike", weightKg: 78.0, daysAgo: 0)])

        let last = try #require(screen.presenter.entries.last)

        #expect(last.trendValue > 72.0)
        #expect(last.trendValue < 74.0)
    }

    @Test("Test The Trend Has A Row Per Weigh-In, Oldest First")
    func testTheTrendHasARowPerWeighInOldestFirst() {
        let screen = makeScreen([
            entry(id: "e3", weightKg: 72.4, daysAgo: 0),
            entry(id: "e1", weightKg: 73.0, daysAgo: 2),
            entry(id: "e2", weightKg: 72.6, daysAgo: 1)
        ])

        #expect(screen.presenter.entries.count == 3)
        #expect(screen.presenter.entries.map(\.date) == screen.presenter.entries.map(\.date).sorted())
    }

    // MARK: - The screen

    @Test("Test The Screen Is Configured As A Weight Chart")
    func testTheScreenIsConfiguredAsAWeightChart() {
        let screen = makeScreen([])

        #expect(screen.presenter.configuration.title == "Weight Trend")
        #expect(screen.presenter.supportsDeletion)
    }

    @Test("Test Adding A Weight Opens The Logging Screen")
    func testAddingAWeightOpensTheLoggingScreen() {
        let screen = makeScreen([])

        screen.presenter.onAddWeightPressed()

        #expect(screen.router.didShowLogWeight)
    }

    /// The screen builds its data in `init`, so returning from the Add flow would show a stale
    /// chart without this — the weight just logged would be missing until the screen was reopened.
    @Test("Test Appearing Again Picks Up A Newly Logged Weight")
    func testAppearingAgainPicksUpANewlyLoggedWeight() async {
        let screen = makeScreen([entry(id: "e1", weightKg: 73.0, daysAgo: 1)])
        #expect(screen.presenter.entries.count == 1)

        screen.interactor.bodyMeasurements.append(entry(id: "e2", weightKg: 72.6, daysAgo: 0))
        await screen.presenter.onAppear()

        #expect(screen.presenter.entries.count == 2)
    }

    /// Deleting a weigh-in clears its weight rather than removing the entry, because the same entry
    /// may also hold circumferences the user did not ask to delete.
    @Test("Test Deleting A Weigh-In Clears Only Its Weight")
    func testDeletingAWeighInClearsOnlyItsWeight() async throws {
        let measured = entry(id: "e1", weightKg: 73.0, daysAgo: 0).withUpdated(.waist(81))
        let screen = makeScreen([measured])
        let row = try #require(screen.presenter.entries.first)

        await screen.presenter.onDeleteEntry(row)

        let saved = try #require(screen.interactor.savedMeasurements.first)
        #expect(saved.weightKg == nil)
        #expect(saved.waistCircumference == 81)
    }
}
