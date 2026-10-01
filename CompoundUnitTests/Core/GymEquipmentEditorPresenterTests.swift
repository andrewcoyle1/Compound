//
//  GymEquipmentEditorPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

//
//  Editing the weights a piece of equipment holds.
//
//  Every one of these screens shows one unit at a time — a kilograms tab and a pounds tab over the
//  same underlying list — while the equipment stores both together. So each of them works in two
//  coordinate systems at once: rows are addressed by their position in the filtered list the user
//  can see, and have to be written back to their position in the unfiltered list the gym holds.
//
//  Getting that wrong is not cosmetic. Swiping the first row of the pounds tab would delete the
//  first kilogram weight instead, and editing one dumbbell would change a different one. Both
//  change what a live workout believes the gym has, and so what load it tells someone to lift.
//
//  `dismissScreen` is a `GlobalRouter` extension that none of these router protocols restate, so it
//  cannot be observed through a double; the screens' navigation is asserted where it is a protocol
//  requirement of its own.
//

/// The rack of dumbbells, kettlebells or plates.
@MainActor
struct GymEditFreeWeightPresenterTests {

    private struct Screen {
        let presenter: EditFreeWeightPresenter
        let box: GymEquipmentBox<FreeWeights>
        let router: GymEquipmentRouter
        let interactor: GymEquipmentInteractor
    }

    private func makeScreen(_ range: [FreeWeightsAvailable]) -> Screen {
        let box = GymEquipmentBox(GymEquipmentFixtures.freeWeights(range))
        let router = GymEquipmentRouter()
        let interactor = GymEquipmentInteractor()
        return Screen(
            presenter: EditFreeWeightPresenter(interactor: interactor, router: router, freeWeight: box.binding),
            box: box,
            router: router,
            interactor: interactor
        )
    }

    private var mixedRack: [FreeWeightsAvailable] {
        [
            GymEquipmentFixtures.plate(10, unit: .kilograms),
            GymEquipmentFixtures.plate(20, unit: .pounds),
            GymEquipmentFixtures.plate(15, unit: .kilograms)
        ]
    }

    /// The pounds tab shows pounds weights and nothing else, in the order the gym holds them.
    @Test("Test Only The Chosen Units Weights Are Listed")
    func testOnlyTheChosenUnitsWeightsAreListed() {
        let screen = makeScreen(mixedRack)

        #expect(screen.presenter.filteredWeightIDs(for: .kilograms) == ["plate-10.0-kilograms", "plate-15.0-kilograms"])
        #expect(screen.presenter.filteredWeightIDs(for: .pounds) == ["plate-20.0-pounds"])
    }

    @Test("Test A Weights Figure Is Read Back By Its Own Identifier")
    func testAWeightsFigureIsReadBackByItsOwnIdentifier() {
        let screen = makeScreen(mixedRack)

        #expect(screen.presenter.weightValue(for: "plate-15.0-kilograms") == 15)
        // A row the rack no longer holds reads as nothing rather than as some other row's weight.
        #expect(screen.presenter.weightValue(for: "missing") == 0)
    }

    /// The row the user typed into is the row that changes, and the ones either side of it are left
    /// exactly as they were.
    @Test("Test Editing One Weight Leaves The Others Alone")
    func testEditingOneWeightLeavesTheOthersAlone() {
        let screen = makeScreen(mixedRack)
        let binding = screen.presenter.bindingForWeight(id: "plate-15.0-kilograms", fallbackUnit: .kilograms)

        binding.wrappedValue.availableWeights = 17.5

        #expect(screen.box.value.range.map(\.availableWeights) == [10, 20, 17.5])
        #expect(screen.box.value.range.map(\.unit) == [.kilograms, .pounds, .kilograms])
    }

    /// Writing into a row that has since gone must not land on whatever now sits at that position.
    @Test("Test Editing A Weight That Is Gone Changes Nothing")
    func testEditingAWeightThatIsGoneChangesNothing() {
        let screen = makeScreen(mixedRack)
        let binding = screen.presenter.bindingForWeight(id: "missing", fallbackUnit: .pounds)

        // The placeholder it hands back is in the unit the list was showing, so a row mid-removal
        // does not flash the wrong unit.
        #expect(binding.wrappedValue.unit == .pounds)
        #expect(binding.wrappedValue.availableWeights == 0)

        binding.wrappedValue.availableWeights = 99

        #expect(screen.box.value.range.map(\.availableWeights) == [10, 20, 15])
    }

    /// Swiping the first row of the pounds tab deletes that pounds weight — not the first weight in
    /// the rack, which is a kilogram one the user cannot even see from there.
    @Test("Test Deleting A Row Deletes That Rows Weight")
    func testDeletingARowDeletesThatRowsWeight() {
        let screen = makeScreen(mixedRack)
        let poundsIDs = screen.presenter.filteredWeightIDs(for: .pounds)

        screen.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: poundsIDs)

        #expect(screen.box.value.range.map(\.id) == ["plate-10.0-kilograms", "plate-15.0-kilograms"])
    }

    @Test("Test Deleting Several Rows Leaves The Rest Intact")
    func testDeletingSeveralRowsLeavesTheRestIntact() {
        let screen = makeScreen(mixedRack)
        let kilogramIDs = screen.presenter.filteredWeightIDs(for: .kilograms)

        screen.presenter.deleteWeights(at: IndexSet([0, 1]), weightIDs: kilogramIDs)

        #expect(screen.box.value.range.map(\.id) == ["plate-20.0-pounds"])
    }

    /// A swipe on a list that has already changed underneath must not take an unrelated weight with
    /// it.
    @Test("Test Deleting A Row Off The End Deletes Nothing")
    func testDeletingARowOffTheEndDeletesNothing() {
        let screen = makeScreen(mixedRack)

        screen.presenter.deleteWeights(at: IndexSet(integer: 5), weightIDs: ["plate-10.0-kilograms"])

        #expect(screen.box.value.range.count == 3)
    }

    /// Adding is done on a separate screen, which has to be told which unit the user was looking at
    /// — otherwise a gym in pounds would collect kilogram dumbbells.
    @Test("Test Adding Opens On The Unit Being Viewed")
    func testAddingOpensOnTheUnitBeingViewed() {
        let screen = makeScreen(mixedRack)
        screen.presenter.selectedUnit = .pounds

        screen.presenter.onAddPressed()

        #expect(screen.router.shown == ["addFreeWeight"])
        #expect(screen.router.addUnits == [.pounds])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen([])

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["EditFreeWeightView_Appear"])
    }
}

/// The weights that can be hung from a dip belt or vest.
@MainActor
struct GymEditBodyWeightPresenterTests {

    private struct Screen {
        let presenter: EditBodyWeightPresenter
        let box: GymEquipmentBox<BodyWeights>
        let router: GymEquipmentRouter
    }

    private func makeScreen(_ range: [BodyWeightsAvailable]) -> Screen {
        let box = GymEquipmentBox(GymEquipmentFixtures.bodyWeights(range))
        let router = GymEquipmentRouter()
        return Screen(
            presenter: EditBodyWeightPresenter(
                interactor: GymEquipmentInteractor(),
                router: router,
                bodyWeight: box.binding
            ),
            box: box,
            router: router
        )
    }

    private var mixedBelt: [BodyWeightsAvailable] {
        [
            GymEquipmentFixtures.bodyWeight(5, unit: .kilograms),
            GymEquipmentFixtures.bodyWeight(10, unit: .pounds),
            GymEquipmentFixtures.bodyWeight(20, unit: .kilograms)
        ]
    }

    @Test("Test Only The Chosen Units Weights Are Listed")
    func testOnlyTheChosenUnitsWeightsAreListed() {
        let screen = makeScreen(mixedBelt)

        #expect(screen.presenter.filteredWeightIDs(for: .kilograms).count == 2)
        #expect(screen.presenter.filteredWeightIDs(for: .pounds) == ["body-10.0-pounds"])
    }

    @Test("Test Editing One Weight Leaves The Others Alone")
    func testEditingOneWeightLeavesTheOthersAlone() {
        let screen = makeScreen(mixedBelt)
        let binding = screen.presenter.bindingForWeight(id: "body-20.0-kilograms", fallbackUnit: .kilograms)

        binding.wrappedValue.availableWeights = 25

        #expect(screen.box.value.range.map(\.availableWeights) == [5, 10, 25])
    }

    @Test("Test Deleting A Row Deletes That Rows Weight")
    func testDeletingARowDeletesThatRowsWeight() {
        let screen = makeScreen(mixedBelt)
        let poundsIDs = screen.presenter.filteredWeightIDs(for: .pounds)

        screen.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: poundsIDs)

        #expect(screen.box.value.range.map(\.unit) == [.kilograms, .kilograms])
    }

    @Test("Test Adding Opens On The Unit Being Viewed")
    func testAddingOpensOnTheUnitBeingViewed() {
        let screen = makeScreen(mixedBelt)
        screen.presenter.selectedUnit = .pounds

        screen.presenter.onAddPressed()

        #expect(screen.router.addUnits == [.pounds])
    }
}

/// A set of resistance bands.
@MainActor
struct GymEditBandPresenterTests {

    private struct Screen {
        let presenter: EditBandPresenter
        let box: GymEquipmentBox<Bands>
        let router: GymEquipmentRouter
    }

    private func makeScreen(_ range: [BandsAvailable]) -> Screen {
        let box = GymEquipmentBox(GymEquipmentFixtures.bands(range))
        let router = GymEquipmentRouter()
        return Screen(
            presenter: EditBandPresenter(
                interactor: GymEquipmentInteractor(),
                router: router,
                bandBinding: box.binding
            ),
            box: box,
            router: router
        )
    }

    private var mixedSet: [BandsAvailable] {
        [
            GymEquipmentFixtures.band(4, name: "Light", unit: .kilograms),
            GymEquipmentFixtures.band(9, name: "Light", unit: .pounds),
            GymEquipmentFixtures.band(14, name: "Medium", unit: .kilograms)
        ]
    }

    @Test("Test Only The Chosen Units Bands Are Listed")
    func testOnlyTheChosenUnitsBandsAreListed() {
        let screen = makeScreen(mixedSet)

        #expect(screen.presenter.filteredWeightIDs(for: .pounds) == ["band-9.0-pounds"])
    }

    @Test("Test A Bands Resistance Is Read Back By Its Own Identifier")
    func testABandsResistanceIsReadBackByItsOwnIdentifier() {
        let screen = makeScreen(mixedSet)

        #expect(screen.presenter.weightValue(for: "band-14.0-kilograms") == 14)
    }

    /// Renaming one band must not rename its neighbour — bands are told apart by name, so that
    /// would leave two identical-looking rows.
    @Test("Test Renaming One Band Leaves The Others Alone")
    func testRenamingOneBandLeavesTheOthersAlone() {
        let screen = makeScreen(mixedSet)
        let binding = screen.presenter.bindingForWeight(id: "band-14.0-kilograms", fallbackUnit: .kilograms)

        binding.wrappedValue.name = "Medium-Heavy"

        #expect(screen.box.value.range.map(\.name) == ["Light", "Light", "Medium-Heavy"])
    }

    @Test("Test Deleting A Row Deletes That Rows Band")
    func testDeletingARowDeletesThatRowsBand() {
        let screen = makeScreen(mixedSet)
        let kilogramIDs = screen.presenter.filteredWeightIDs(for: .kilograms)

        screen.presenter.deleteWeights(at: IndexSet(integer: 1), weightIDs: kilogramIDs)

        #expect(screen.box.value.range.map(\.id) == ["band-4.0-kilograms", "band-9.0-pounds"])
    }

    @Test("Test Adding Opens On The Unit Being Viewed")
    func testAddingOpensOnTheUnitBeingViewed() {
        let screen = makeScreen(mixedSet)
        screen.presenter.selectedUnit = .pounds

        screen.presenter.onAddPressed()

        #expect(screen.router.addUnits == [.pounds])
    }
}

/// The bars that plates are loaded onto.
@MainActor
struct GymEditLoadableBarPresenterTests {

    private struct Screen {
        let presenter: EditLoadableBarPresenter
        let box: GymEquipmentBox<LoadableBars>
        let router: GymEquipmentRouter
    }

    private func makeScreen(_ baseWeights: [LoadableBarsBaseWeight]) -> Screen {
        let box = GymEquipmentBox(GymEquipmentFixtures.loadableBars(baseWeights))
        let router = GymEquipmentRouter()
        return Screen(
            presenter: EditLoadableBarPresenter(
                interactor: GymEquipmentInteractor(),
                router: router,
                loadableBarBinding: box.binding
            ),
            box: box,
            router: router
        )
    }

    private var mixedRack: [LoadableBarsBaseWeight] {
        [
            GymEquipmentFixtures.barBase(20, unit: .kilograms),
            GymEquipmentFixtures.barBase(45, unit: .pounds),
            GymEquipmentFixtures.barBase(15, unit: .kilograms)
        ]
    }

    /// The screen opens on the unit of the bar the rack treats as its default, so a rack of pounds
    /// bars does not open on an empty kilograms tab.
    @Test("Test The Screen Opens On The Default Bars Unit")
    func testTheScreenOpensOnTheDefaultBarsUnit() {
        let screen = makeScreen([
            GymEquipmentFixtures.barBase(45, unit: .pounds),
            GymEquipmentFixtures.barBase(20, unit: .kilograms)
        ])

        #expect(screen.presenter.selectedUnit == .pounds)
    }

    /// A rack with no bars in it yet has no default to follow, so it falls back to kilograms rather
    /// than to nothing.
    @Test("Test An Empty Rack Opens On Kilograms")
    func testAnEmptyRackOpensOnKilograms() {
        let screen = makeScreen([])

        #expect(screen.presenter.selectedUnit == .kilograms)
    }

    @Test("Test Only The Chosen Units Bars Are Listed")
    func testOnlyTheChosenUnitsBarsAreListed() {
        let screen = makeScreen(mixedRack)

        #expect(screen.presenter.filteredWeightIDs(for: .pounds) == ["bar-45.0-pounds"])
    }

    @Test("Test Editing One Bar Leaves The Others Alone")
    func testEditingOneBarLeavesTheOthersAlone() {
        let screen = makeScreen(mixedRack)
        let binding = screen.presenter.bindingForWeight(id: "bar-15.0-kilograms", fallbackUnit: .kilograms)

        binding.wrappedValue.baseWeight = 12

        #expect(screen.box.value.baseWeights.map(\.baseWeight) == [20, 45, 12])
    }

    @Test("Test Deleting A Row Deletes That Rows Bar")
    func testDeletingARowDeletesThatRowsBar() {
        let screen = makeScreen(mixedRack)
        let poundsIDs = screen.presenter.filteredWeightIDs(for: .pounds)

        screen.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: poundsIDs)

        #expect(screen.box.value.baseWeights.map(\.baseWeight) == [20, 15])
    }

    @Test("Test Adding Opens On The Unit Being Viewed")
    func testAddingOpensOnTheUnitBeingViewed() {
        let screen = makeScreen(mixedRack)
        screen.presenter.selectedUnit = .pounds

        screen.presenter.onAddPressed()

        #expect(screen.router.addUnits == [.pounds])
    }
}

/// The rack of bars that come at a fixed weight.
@MainActor
struct GymEditFixedWeightBarPresenterTests {

    private struct Screen {
        let presenter: EditFixedWeightBarPresenter
        let box: GymEquipmentBox<FixedWeightBars>
        let router: GymEquipmentRouter
    }

    private func makeScreen(_ baseWeights: [FixedWeightBarsBaseWeight]) -> Screen {
        let box = GymEquipmentBox(GymEquipmentFixtures.fixedWeightBars(baseWeights))
        let router = GymEquipmentRouter()
        return Screen(
            presenter: EditFixedWeightBarPresenter(
                interactor: GymEquipmentInteractor(),
                router: router,
                fixedWeightBarBinding: box.binding
            ),
            box: box,
            router: router
        )
    }

    private var mixedRack: [FixedWeightBarsBaseWeight] {
        [
            GymEquipmentFixtures.fixedBase(10, unit: .kilograms),
            GymEquipmentFixtures.fixedBase(30, unit: .pounds),
            GymEquipmentFixtures.fixedBase(12.5, unit: .kilograms)
        ]
    }

    @Test("Test The Screen Opens On The Default Bars Unit")
    func testTheScreenOpensOnTheDefaultBarsUnit() {
        let screen = makeScreen([
            GymEquipmentFixtures.fixedBase(30, unit: .pounds),
            GymEquipmentFixtures.fixedBase(10, unit: .kilograms)
        ])

        #expect(screen.presenter.selectedUnit == .pounds)
    }

    @Test("Test Only The Chosen Units Bars Are Listed")
    func testOnlyTheChosenUnitsBarsAreListed() {
        let screen = makeScreen(mixedRack)

        #expect(screen.presenter.filteredWeightIDs(for: .kilograms).count == 2)
        #expect(screen.presenter.weightValue(for: "fixed-12.5-kilograms") == 12.5)
    }

    @Test("Test Editing One Bar Leaves The Others Alone")
    func testEditingOneBarLeavesTheOthersAlone() {
        let screen = makeScreen(mixedRack)
        let binding = screen.presenter.bindingForWeight(id: "fixed-10.0-kilograms", fallbackUnit: .kilograms)

        binding.wrappedValue.baseWeight = 11

        #expect(screen.box.value.baseWeights.map(\.baseWeight) == [11, 30, 12.5])
    }

    @Test("Test Deleting A Row Deletes That Rows Bar")
    func testDeletingARowDeletesThatRowsBar() {
        let screen = makeScreen(mixedRack)
        let kilogramIDs = screen.presenter.filteredWeightIDs(for: .kilograms)

        screen.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: kilogramIDs)

        #expect(screen.box.value.baseWeights.map(\.baseWeight) == [30, 12.5])
    }

    @Test("Test Adding Opens On The Unit Being Viewed")
    func testAddingOpensOnTheUnitBeingViewed() {
        let screen = makeScreen(mixedRack)
        screen.presenter.selectedUnit = .kilograms

        screen.presenter.onAddPressed()

        #expect(screen.router.addUnits == [.kilograms])
    }
}
