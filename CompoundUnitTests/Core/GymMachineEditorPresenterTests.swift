//
//  GymMachineEditorPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

//
//  The machines, and the weight ranges that describe what they can be set to.
//
//  A range is three numbers — a start, an end and the step between them — and it is the only thing
//  the app has to go on when it decides what load a machine can actually be set to. A workout in
//  progress rounds the weight it suggests onto that step, clamped between the start and the end, so
//  every one of these numbers reaches the user as a weight on a bar.
//
//  Unlike the racks, a machine's ranges are listed by name rather than in the order they were
//  added, so these screens sort before they hand positions back to the list.
//

/// A cable machine's ranges.
@MainActor
struct GymEditCableMachinePresenterTests {

    private struct Screen {
        let presenter: EditCableMachinePresenter
        let box: GymEquipmentBox<CableMachine>
        let router: GymEquipmentRouter
        let interactor: GymEquipmentInteractor
    }

    private func makeScreen(_ ranges: [CableMachineRange]) -> Screen {
        let box = GymEquipmentBox(GymEquipmentFixtures.cableMachine(ranges))
        let router = GymEquipmentRouter()
        let interactor = GymEquipmentInteractor()
        return Screen(
            presenter: EditCableMachinePresenter(
                interactor: interactor,
                router: router,
                cableMachineBinding: box.binding
            ),
            box: box,
            router: router,
            interactor: interactor
        )
    }

    private var mixedRanges: [CableMachineRange] {
        [
            GymEquipmentFixtures.cableRange("Stack", unit: .kilograms),
            GymEquipmentFixtures.cableRange("Accessory", unit: .kilograms),
            GymEquipmentFixtures.cableRange("Pounds Stack", unit: .pounds)
        ]
    }

    /// The screen opens on the unit of the range the machine is taken to be set to, so a machine
    /// whose stack is marked in pounds does not open on an empty kilograms tab.
    @Test("Test The Screen Opens On The Default Ranges Unit")
    func testTheScreenOpensOnTheDefaultRangesUnit() {
        let screen = makeScreen([
            GymEquipmentFixtures.cableRange("Pounds Stack", unit: .pounds),
            GymEquipmentFixtures.cableRange("Stack", unit: .kilograms)
        ])

        #expect(screen.presenter.selectedUnit == .pounds)
    }

    @Test("Test A Machine With No Ranges Opens On Kilograms")
    func testAMachineWithNoRangesOpensOnKilograms() {
        let screen = makeScreen([])

        #expect(screen.presenter.selectedUnit == .kilograms)
    }

    /// Listed by name, not by the order they happened to be added, so the list does not reshuffle
    /// as ranges come and go.
    @Test("Test Ranges Are Listed In Name Order")
    func testRangesAreListedInNameOrder() {
        let screen = makeScreen(mixedRanges)

        #expect(screen.presenter.filteredWeightIDs(for: .kilograms) == ["cable-Accessory", "cable-Stack"])
    }

    @Test("Test Only The Chosen Units Ranges Are Listed")
    func testOnlyTheChosenUnitsRangesAreListed() {
        let screen = makeScreen(mixedRanges)

        #expect(screen.presenter.filteredWeightIDs(for: .pounds) == ["cable-Pounds Stack"])
    }

    /// Rows are sorted but the machine's own list is not, so the write-back has to follow the row's
    /// identifier. Editing the range that sorts first must change that range, not whichever one
    /// happens to sit first in storage.
    @Test("Test Editing A Range Changes The Range That Was Tapped")
    func testEditingARangeChangesTheRangeThatWasTapped() {
        let screen = makeScreen(mixedRanges)
        let firstListed = screen.presenter.filteredWeightIDs(for: .kilograms).first ?? ""
        let binding = screen.presenter.bindingForWeight(id: firstListed, fallbackUnit: .kilograms)

        binding.wrappedValue.increment = 2.5

        let accessory = screen.box.value.ranges.first(where: { $0.id == "cable-Accessory" })
        let stack = screen.box.value.ranges.first(where: { $0.id == "cable-Stack" })
        #expect(accessory?.increment == 2.5)
        #expect(stack?.increment == 5)
    }

    /// A row mid-removal falls back to a placeholder in the unit being viewed, and writing into it
    /// must not land on some other range.
    @Test("Test Editing A Range That Is Gone Changes Nothing")
    func testEditingARangeThatIsGoneChangesNothing() {
        let screen = makeScreen(mixedRanges)
        let binding = screen.presenter.bindingForWeight(id: "missing", fallbackUnit: .pounds)

        #expect(binding.wrappedValue.unit == .pounds)

        binding.wrappedValue.maxWeight = 999

        #expect(screen.box.value.ranges.map(\.maxWeight) == [100, 100, 100])
    }

    /// Swiping the first row of the pounds tab removes that pounds range, not the first range the
    /// machine holds.
    @Test("Test Deleting A Row Deletes That Rows Range")
    func testDeletingARowDeletesThatRowsRange() {
        let screen = makeScreen(mixedRanges)
        let poundsIDs = screen.presenter.filteredWeightIDs(for: .pounds)

        screen.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: poundsIDs)

        #expect(screen.box.value.ranges.map(\.id) == ["cable-Stack", "cable-Accessory"])
    }

    /// The edit-a-range screen is shown the machine's name so the user can tell which machine's
    /// numbers they are changing.
    @Test("Test Editing A Range Opens It Against Its Machine")
    func testEditingARangeOpensItAgainstItsMachine() {
        let screen = makeScreen(mixedRanges)
        let binding = screen.presenter.bindingForWeight(id: "cable-Stack", fallbackUnit: .kilograms)

        screen.presenter.onEditRangePressed(range: binding)

        #expect(screen.router.shown == ["editWeightRange"])
        #expect(screen.router.editedRangeEquipment == ["Lat Pulldown"])
    }

    @Test("Test Adding Opens On The Unit Being Viewed")
    func testAddingOpensOnTheUnitBeingViewed() {
        let screen = makeScreen(mixedRanges)
        screen.presenter.selectedUnit = .pounds

        screen.presenter.onAddPressed()

        #expect(screen.router.shown == ["addCableMachineRange"])
        #expect(screen.router.addUnits == [.pounds])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen([])

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["EditCableMachineView_Appear"])
    }
}

/// A pin-loaded machine's ranges.
@MainActor
struct GymEditPinLoadedMachinePresenterTests {

    private struct Screen {
        let presenter: EditPinLoadedMachinePresenter
        let box: GymEquipmentBox<PinLoadedMachine>
        let router: GymEquipmentRouter
    }

    private func makeScreen(_ ranges: [PinLoadedMachineRange]) -> Screen {
        let box = GymEquipmentBox(GymEquipmentFixtures.pinMachine(ranges))
        let router = GymEquipmentRouter()
        return Screen(
            presenter: EditPinLoadedMachinePresenter(
                interactor: GymEquipmentInteractor(),
                router: router,
                pinLoadedMachineBinding: box.binding
            ),
            box: box,
            router: router
        )
    }

    private var mixedRanges: [PinLoadedMachineRange] {
        [
            GymEquipmentFixtures.pinRange("Stack", unit: .kilograms),
            GymEquipmentFixtures.pinRange("Assisted", unit: .kilograms),
            GymEquipmentFixtures.pinRange("Pounds Stack", unit: .pounds)
        ]
    }

    @Test("Test The Screen Opens On The Default Ranges Unit")
    func testTheScreenOpensOnTheDefaultRangesUnit() {
        let screen = makeScreen([
            GymEquipmentFixtures.pinRange("Pounds Stack", unit: .pounds),
            GymEquipmentFixtures.pinRange("Stack", unit: .kilograms)
        ])

        #expect(screen.presenter.selectedUnit == .pounds)
    }

    @Test("Test Ranges Are Listed In Name Order")
    func testRangesAreListedInNameOrder() {
        let screen = makeScreen(mixedRanges)

        #expect(screen.presenter.filteredWeightIDs(for: .kilograms) == ["pin-Assisted", "pin-Stack"])
    }

    /// The step a machine moves in is the number a working weight is rounded onto, so editing it on
    /// one range must not move another.
    @Test("Test Editing A Range Changes The Range That Was Tapped")
    func testEditingARangeChangesTheRangeThatWasTapped() {
        let screen = makeScreen(mixedRanges)
        let binding = screen.presenter.bindingForWeight(id: "pin-Assisted", fallbackUnit: .kilograms)

        binding.wrappedValue.increment = 7.5

        #expect(screen.box.value.ranges.first(where: { $0.id == "pin-Assisted" })?.increment == 7.5)
        #expect(screen.box.value.ranges.first(where: { $0.id == "pin-Stack" })?.increment == 5)
    }

    @Test("Test Deleting A Row Deletes That Rows Range")
    func testDeletingARowDeletesThatRowsRange() {
        let screen = makeScreen(mixedRanges)
        let kilogramIDs = screen.presenter.filteredWeightIDs(for: .kilograms)

        screen.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: kilogramIDs)

        #expect(screen.box.value.ranges.map(\.id) == ["pin-Stack", "pin-Pounds Stack"])
    }

    @Test("Test Editing A Range Opens It Against Its Machine")
    func testEditingARangeOpensItAgainstItsMachine() {
        let screen = makeScreen(mixedRanges)
        let binding = screen.presenter.bindingForWeight(id: "pin-Stack", fallbackUnit: .kilograms)

        screen.presenter.onEditRangePressed(range: binding)

        #expect(screen.router.editedRangeEquipment == ["Leg Press"])
    }

    @Test("Test Adding Opens On The Unit Being Viewed")
    func testAddingOpensOnTheUnitBeingViewed() {
        let screen = makeScreen(mixedRanges)
        screen.presenter.selectedUnit = .pounds

        screen.presenter.onAddPressed()

        #expect(screen.router.shown == ["addPinLoadedMachineRange"])
        #expect(screen.router.addUnits == [.pounds])
    }
}

/// A plate-loaded machine, which has one number: the weight of the sled before any plates go on.
@MainActor
struct GymEditPlateLoadedMachinePresenterTests {

    private func makeScreen(
        baseWeight: Double = 25,
        unit: ExerciseWeightUnit = .kilograms
    ) -> (EditPlateLoadedMachinePresenter, GymEquipmentBox<PlateLoadedMachine>) {
        let box = GymEquipmentBox(
            PlateLoadedMachine(
                id: "hack-squat",
                name: "Hack Squat",
                baseWeight: baseWeight,
                unit: unit,
                isActive: true
            )
        )
        let presenter = EditPlateLoadedMachinePresenter(
            interactor: GymEquipmentInteractor(),
            router: GymEquipmentRouter(),
            plateLoadedMachineBinding: box.binding
        )
        return (presenter, box)
    }

    /// The screen opens on the machine's own unit rather than a default, since a sled marked in
    /// pounds is not a 25 kg sled.
    @Test("Test The Screen Opens On The Machines Unit")
    func testTheScreenOpensOnTheMachinesUnit() {
        let (presenter, _) = makeScreen(unit: .pounds)

        #expect(presenter.plateLoadedMachine.unit == .pounds)
    }

    /// The unit picker writes the machine's unit; it used to change only the screen's copy, so a
    /// 25 lb sled stayed a 25 kg one.
    @Test("Test Choosing A Unit Reaches The Gym Profile")
    func testChoosingAUnitReachesTheGymProfile() {
        let (presenter, box) = makeScreen(unit: .kilograms)

        presenter.plateLoadedMachine.unit = .pounds

        #expect(box.value.unit == .pounds)
    }

    @Test("Test Choosing One Side Reaches The Gym Profile")
    func testChoosingOneSideReachesTheGymProfile() {
        let (presenter, box) = makeScreen()
        #expect(presenter.plateLoadedMachine.sleeves == 2)

        presenter.plateLoadedMachine.sleeves = 1

        #expect(box.value.sleeves == 1)
    }

    /// The presenter reads and writes the gym profile's machine directly rather than a copy, so an
    /// edit is not waiting on a save that never comes.
    @Test("Test Editing The Sled Weight Reaches The Gym Profile")
    func testEditingTheSledWeightReachesTheGymProfile() {
        let (presenter, box) = makeScreen(baseWeight: 25)

        presenter.plateLoadedMachine.baseWeight = 32.5

        #expect(box.value.baseWeight == 32.5)
        #expect(presenter.plateLoadedMachine.baseWeight == 32.5)
    }

    /// A change made elsewhere in the profile shows here without the screen being rebuilt.
    @Test("Test The Machine Is Read Through To The Gym Profile")
    func testTheMachineIsReadThroughToTheGymProfile() {
        let (presenter, box) = makeScreen(baseWeight: 25)

        box.value.isActive = false

        #expect(presenter.plateLoadedMachine.isActive == false)
    }
}

/// A loadable accessory — a belt, a vest or a harness that plates hang from.
@MainActor
struct GymEditLoadableAccessoryPresenterTests {

    private func makeScreen(
        baseWeight: Double = 1.5,
        unit: ExerciseWeightUnit = .kilograms
    ) -> (EditLoadableAccessoryPresenter, GymEquipmentBox<LoadableAccessoryEquipment>) {
        let box = GymEquipmentBox(
            LoadableAccessoryEquipment(
                id: "dip-belt",
                name: "Dip Belt",
                baseWeight: baseWeight,
                unit: unit,
                isActive: true
            )
        )
        let presenter = EditLoadableAccessoryPresenter(
            interactor: GymEquipmentInteractor(),
            router: GymEquipmentRouter(),
            loadableAccessoryBinding: box.binding
        )
        return (presenter, box)
    }

    @Test("Test The Screen Opens On The Accessorys Unit")
    func testTheScreenOpensOnTheAccessorysUnit() {
        let (presenter, _) = makeScreen(unit: .pounds)

        #expect(presenter.selectedUnit == .pounds)
    }

    /// The accessory's own weight is added to whatever is hung from it, so an edit that stopped at
    /// the screen would under-count every set done with it.
    @Test("Test Editing The Accessory Weight Reaches The Gym Profile")
    func testEditingTheAccessoryWeightReachesTheGymProfile() {
        let (presenter, box) = makeScreen(baseWeight: 1.5)

        presenter.loadableAccessory.baseWeight = 2

        #expect(box.value.baseWeight == 2)
    }

    @Test("Test The Accessory Is Read Through To The Gym Profile")
    func testTheAccessoryIsReadThroughToTheGymProfile() {
        let (presenter, box) = makeScreen()

        box.value.name = "Weight Vest"

        #expect(presenter.loadableAccessory.name == "Weight Vest")
    }
}

/// The three numbers behind a machine's range: where it starts, where it ends and the step between.
///
/// All three are free text fields writing straight into the range, which is the whole screen — so
/// what is worth testing is what happens to a range left in a state no weight can come out of.
@MainActor
struct GymEditWeightRangePresenterTests {

    private struct Screen {
        let presenter: EditWeightRangePresenter
        let box: GymEquipmentBox<CableMachineRange>
        let interactor: GymEquipmentInteractor

        @MainActor
        var delegate: EditWeightRangeDelegate<CableMachineRange> {
            EditWeightRangeDelegate(equipmentName: "Lat Pulldown", range: box.binding)
        }
    }

    private func makeScreen(
        min: Double = 0,
        max: Double = 100,
        increment: Double = 5,
        unit: ExerciseWeightUnit = .kilograms
    ) -> Screen {
        let box = GymEquipmentBox(
            GymEquipmentFixtures.cableRange("Stack", min: min, max: max, increment: increment, unit: unit)
        )
        let interactor = GymEquipmentInteractor()
        return Screen(
            presenter: EditWeightRangePresenter(interactor: interactor, router: GymEquipmentRouter()),
            box: box,
            interactor: interactor
        )
    }

    /// A range that already made sense is left exactly as the user typed it.
    @Test("Test A Usable Range Is Left Alone")
    func testAUsableRangeIsLeftAlone() {
        let screen = makeScreen(min: 5, max: 120, increment: 2.5)

        screen.presenter.onViewAppear(delegate: screen.delegate)
        screen.presenter.onViewDisappear(delegate: screen.delegate)

        #expect(screen.box.value.minWeight == 5)
        #expect(screen.box.value.maxWeight == 120)
        #expect(screen.box.value.increment == 2.5)
    }

    /// Clearing the increment field reads as zero, and a zero step divides by zero when a workout
    /// rounds a weight onto this machine — every suggested weight comes back as not-a-number. The
    /// increment the screen opened on is put back instead.
    @Test("Test An Increment Cleared To Nothing Is Restored")
    func testAnIncrementClearedToNothingIsRestored() {
        let screen = makeScreen(increment: 5)
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.box.value.increment = 0
        screen.presenter.onViewDisappear(delegate: screen.delegate)

        #expect(screen.box.value.increment == 5)
    }

    /// A negative step is no more usable than a zero one.
    @Test("Test A Negative Increment Is Restored")
    func testANegativeIncrementIsRestored() {
        let screen = makeScreen(increment: 2.5)
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.box.value.increment = -2.5
        screen.presenter.onViewDisappear(delegate: screen.delegate)

        #expect(screen.box.value.increment == 2.5)
    }

    /// If the range arrived unusable there is nothing to restore, so it falls back to the step the
    /// equipment lists are usually built in — in the range's own unit, not a kilogram figure
    /// stamped onto a pounds stack.
    @Test("Test A Range With No Usable Increment Falls Back To Its Units Step")
    func testARangeWithNoUsableIncrementFallsBackToItsUnitsStep() {
        let kilograms = makeScreen(increment: 0, unit: .kilograms)
        kilograms.presenter.onViewAppear(delegate: kilograms.delegate)
        kilograms.presenter.onViewDisappear(delegate: kilograms.delegate)

        #expect(kilograms.box.value.increment == 2.5)

        let pounds = makeScreen(increment: 0, unit: .pounds)
        pounds.presenter.onViewAppear(delegate: pounds.delegate)
        pounds.presenter.onViewDisappear(delegate: pounds.delegate)

        #expect(pounds.box.value.increment == 5)
    }

    /// An end below the start clamps every weight to the start, so a full cable stack would read as
    /// its lightest plate. The two are swapped back rather than left as a range with nothing in it.
    @Test("Test A Range Entered Back To Front Is Turned Round")
    func testARangeEnteredBackToFrontIsTurnedRound() {
        let screen = makeScreen(min: 10, max: 120)
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.box.value.minWeight = 120
        screen.box.value.maxWeight = 10
        screen.presenter.onViewDisappear(delegate: screen.delegate)

        #expect(screen.box.value.minWeight == 10)
        #expect(screen.box.value.maxWeight == 120)
    }

    /// A sheet is as likely to be swiped away as closed with the button, so the repair cannot live
    /// only on the button.
    @Test("Test Closing With The Button Repairs The Range Too")
    func testClosingWithTheButtonRepairsTheRangeToo() {
        let screen = makeScreen(increment: 5)
        screen.presenter.onViewAppear(delegate: screen.delegate)

        screen.box.value.increment = 0
        screen.presenter.onDismissPressed(delegate: screen.delegate)

        #expect(screen.box.value.increment == 5)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["EditWeightRangeView_Appear"])
    }
}
