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

/// A cable or pin-loaded machine's stacks. One presenter serves both kinds, so each scenario runs
/// on the machine kind it was first written for, and on both where they used to differ.
@MainActor
struct GymEditStackMachinePresenterTests {

    private struct Screen<Machine: StackMachine> {
        let presenter: EditStackMachinePresenter<Machine>
        let box: GymEquipmentBox<Machine>
        let router: GymEquipmentRouter
        let interactor: GymEquipmentInteractor
    }

    private func makeScreen<Machine: StackMachine>(_ machine: Machine) -> Screen<Machine> {
        let box = GymEquipmentBox(machine)
        let router = GymEquipmentRouter()
        let interactor = GymEquipmentInteractor()
        return Screen(
            presenter: EditStackMachinePresenter(interactor: interactor, router: router, machineBinding: box.binding),
            box: box,
            router: router,
            interactor: interactor
        )
    }

    private func cable(_ ranges: [WeightStack]) -> Screen<CableMachine> {
        makeScreen(GymEquipmentFixtures.cableMachine(ranges))
    }

    private func pin(_ ranges: [WeightStack]) -> Screen<PinLoadedMachine> {
        makeScreen(GymEquipmentFixtures.pinMachine(ranges))
    }

    private var mixedCableRanges: [WeightStack] {
        [
            GymEquipmentFixtures.cableRange("Stack", unit: .kilograms),
            GymEquipmentFixtures.cableRange("Accessory", unit: .kilograms),
            GymEquipmentFixtures.cableRange("Pounds Stack", unit: .pounds)
        ]
    }

    private var mixedPinRanges: [WeightStack] {
        [
            GymEquipmentFixtures.pinRange("Stack", unit: .kilograms),
            GymEquipmentFixtures.pinRange("Assisted", unit: .kilograms),
            GymEquipmentFixtures.pinRange("Pounds Stack", unit: .pounds)
        ]
    }

    /// The screen opens on the unit of the stack the machine is taken to be set to, so a machine
    /// whose stack is marked in pounds does not open on an empty kilograms tab.
    @Test("Test The Screen Opens On The Default Ranges Unit")
    func testTheScreenOpensOnTheDefaultRangesUnit() {
        let cable = cable([
            GymEquipmentFixtures.cableRange("Pounds Stack", unit: .pounds),
            GymEquipmentFixtures.cableRange("Stack", unit: .kilograms)
        ])
        let pin = pin([
            GymEquipmentFixtures.pinRange("Pounds Stack", unit: .pounds),
            GymEquipmentFixtures.pinRange("Stack", unit: .kilograms)
        ])

        #expect(cable.presenter.selectedUnit == .pounds)
        #expect(pin.presenter.selectedUnit == .pounds)
    }

    @Test("Test A Machine With No Ranges Opens On Kilograms")
    func testAMachineWithNoRangesOpensOnKilograms() {
        #expect(cable([]).presenter.selectedUnit == .kilograms)
    }

    /// Listed by name, not by the order they happened to be added, so the list does not reshuffle
    /// as stacks come and go.
    @Test("Test Ranges Are Listed In Name Order")
    func testRangesAreListedInNameOrder() {
        #expect(cable(mixedCableRanges).presenter.filteredWeightIDs(for: .kilograms) == ["cable-Accessory", "cable-Stack"])
        #expect(pin(mixedPinRanges).presenter.filteredWeightIDs(for: .kilograms) == ["pin-Assisted", "pin-Stack"])
    }

    @Test("Test Only The Chosen Units Ranges Are Listed")
    func testOnlyTheChosenUnitsRangesAreListed() {
        #expect(cable(mixedCableRanges).presenter.filteredWeightIDs(for: .pounds) == ["cable-Pounds Stack"])
    }

    /// Rows are sorted but the machine's own list is not, so the write-back has to follow the row's
    /// identifier. Editing the stack that sorts first must change that stack, not whichever one
    /// happens to sit first in storage.
    @Test("Test Editing A Range Changes The Range That Was Tapped")
    func testEditingARangeChangesTheRangeThatWasTapped() {
        let screen = cable(mixedCableRanges)
        let firstListed = screen.presenter.filteredWeightIDs(for: .kilograms).first ?? ""
        let binding = screen.presenter.bindingForWeight(id: firstListed, fallbackUnit: .kilograms)

        binding.wrappedValue.increment = 2.5

        #expect(screen.box.value.ranges.first(where: { $0.id == "cable-Accessory" })?.increment == 2.5)
        #expect(screen.box.value.ranges.first(where: { $0.id == "cable-Stack" })?.increment == 5)
    }

    /// The step a machine moves in is the number a working weight is rounded onto, so editing it on
    /// one stack must not move another.
    @Test("Test Editing A Pin Loaded Range Changes Only That Range")
    func testEditingAPinLoadedRangeChangesOnlyThatRange() {
        let screen = pin(mixedPinRanges)
        let binding = screen.presenter.bindingForWeight(id: "pin-Assisted", fallbackUnit: .kilograms)

        binding.wrappedValue.increment = 7.5

        #expect(screen.box.value.ranges.first(where: { $0.id == "pin-Assisted" })?.increment == 7.5)
        #expect(screen.box.value.ranges.first(where: { $0.id == "pin-Stack" })?.increment == 5)
    }

    /// A row mid-removal falls back to a placeholder in the unit being viewed, and writing into it
    /// must not land on some other stack.
    @Test("Test Editing A Range That Is Gone Changes Nothing")
    func testEditingARangeThatIsGoneChangesNothing() {
        let screen = cable(mixedCableRanges)
        let binding = screen.presenter.bindingForWeight(id: "missing", fallbackUnit: .pounds)

        #expect(binding.wrappedValue.unit == .pounds)

        binding.wrappedValue.maxWeight = 999

        #expect(screen.box.value.ranges.map(\.maxWeight) == [100, 100, 100])
    }

    /// Swiping the first row of a tab removes that row's stack, not the first stack the machine
    /// holds.
    @Test("Test Deleting A Row Deletes That Rows Range")
    func testDeletingARowDeletesThatRowsRange() {
        let cable = cable(mixedCableRanges)
        cable.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: cable.presenter.filteredWeightIDs(for: .pounds))
        #expect(cable.box.value.ranges.map(\.id) == ["cable-Stack", "cable-Accessory"])

        let pin = pin(mixedPinRanges)
        pin.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: pin.presenter.filteredWeightIDs(for: .kilograms))
        #expect(pin.box.value.ranges.map(\.id) == ["pin-Stack", "pin-Pounds Stack"])
    }

    /// Deleting the default stack used to leave the machine naming a stack that no longer
    /// existed. The first remaining active stack takes over, else the first, else none.
    @Test("Test Deleting The Default Range Points The Default At What Remains")
    func testDeletingTheDefaultRangePointsTheDefaultAtWhatRemains() {
        var off = GymEquipmentFixtures.cableRange("Accessory")
        off.isActive = false
        let screen = cable([GymEquipmentFixtures.cableRange("Stack"), off, GymEquipmentFixtures.cableRange("Pounds Stack", unit: .pounds)])
        #expect(screen.box.value.defaultRangeId == "cable-Stack")

        screen.presenter.deleteWeights(at: IndexSet(integer: 1), weightIDs: ["cable-Accessory", "cable-Stack"])
        #expect(screen.box.value.defaultRangeId == "cable-Pounds Stack")

        screen.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: ["cable-Pounds Stack"])
        #expect(screen.box.value.defaultRangeId == "cable-Accessory")

        screen.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: ["cable-Accessory"])
        #expect(screen.box.value.defaultRangeId == nil)
    }

    /// Deleting any other stack leaves the default alone.
    @Test("Test Deleting Another Range Keeps The Default")
    func testDeletingAnotherRangeKeepsTheDefault() {
        let screen = pin(mixedPinRanges)

        screen.presenter.deleteWeights(at: IndexSet(integer: 0), weightIDs: ["pin-Assisted"])

        #expect(screen.box.value.defaultRangeId == "pin-Stack")
    }

    /// The edit-a-stack screen is shown the machine's name so the user can tell which machine's
    /// numbers they are changing.
    @Test("Test Editing A Range Opens It Against Its Machine")
    func testEditingARangeOpensItAgainstItsMachine() {
        let cable = cable(mixedCableRanges)
        cable.presenter.onEditRangePressed(range: cable.presenter.bindingForWeight(id: "cable-Stack", fallbackUnit: .kilograms))
        #expect(cable.router.shown == ["editWeightRange"])
        #expect(cable.router.editedRangeEquipment == ["Lat Pulldown"])

        let pin = pin(mixedPinRanges)
        pin.presenter.onEditRangePressed(range: pin.presenter.bindingForWeight(id: "pin-Stack", fallbackUnit: .kilograms))
        #expect(pin.router.editedRangeEquipment == ["Leg Press"])
    }

    @Test("Test Adding Opens On The Unit Being Viewed")
    func testAddingOpensOnTheUnitBeingViewed() {
        let cable = cable(mixedCableRanges)
        cable.presenter.selectedUnit = .pounds
        cable.presenter.onAddPressed()
        #expect(cable.router.shown == ["addWeightStack"])
        #expect(cable.router.addUnits == [.pounds])

        let pin = pin(mixedPinRanges)
        pin.presenter.selectedUnit = .pounds
        pin.presenter.onAddPressed()
        #expect(pin.router.shown == ["addWeightStack"])
        #expect(pin.router.addUnits == [.pounds])
    }

    /// The add form saves through the editor, onto the machine being viewed, and the first stack a
    /// bare machine gains becomes its default.
    @Test("Test A Stack Added From The Form Reaches The Machine")
    func testAStackAddedFromTheFormReachesTheMachine() throws {
        let screen = pin([])
        screen.presenter.onAddPressed()
        let delegate = try #require(screen.router.addStackDelegate)
        #expect(delegate.machineName == "Leg Press")

        delegate.onAdd(GymEquipmentFixtures.pinRange("Stack"))

        #expect(screen.box.value.ranges.map(\.id) == ["pin-Stack"])
        #expect(screen.box.value.defaultRangeId == "pin-Stack")
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = cable([])

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["EditStackMachineView_Appear"])
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

/// One stack: its lightest pin, heaviest and step (or an uneven list of pins), and its add-ons.
///
/// The fields write into the presenter's copy of the stack, which writes through to the machine,
/// so what is worth testing is what reaches the machine and what happens to a stack left in a state
/// no weight can come out of.
@MainActor
struct GymEditWeightRangePresenterTests {

    private struct Screen {
        let presenter: EditWeightRangePresenter
        let box: GymEquipmentBox<WeightStack>
        let interactor: GymEquipmentInteractor
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
            presenter: EditWeightRangePresenter(
                interactor: interactor,
                router: GymEquipmentRouter(),
                delegate: EditWeightRangeDelegate(equipmentName: "Lat Pulldown", range: box.binding)
            ),
            box: box,
            interactor: interactor
        )
    }

    /// A stack that already made sense is left exactly as the user typed it.
    @Test("Test A Usable Range Is Left Alone")
    func testAUsableRangeIsLeftAlone() {
        let screen = makeScreen(min: 5, max: 120, increment: 2.5)

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

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

        screen.presenter.stack.increment = 0
        #expect(screen.box.value.increment == 0)
        screen.presenter.onViewDisappear()

        #expect(screen.box.value.increment == 5)
    }

    /// A negative step is no more usable than a zero one.
    @Test("Test A Negative Increment Is Restored")
    func testANegativeIncrementIsRestored() {
        let screen = makeScreen(increment: 2.5)

        screen.presenter.stack.increment = -2.5
        screen.presenter.onViewDisappear()

        #expect(screen.box.value.increment == 2.5)
    }

    /// If the stack arrived unusable there is nothing to restore, so it falls back to the step the
    /// equipment lists are usually built in — in the stack's own unit, not a kilogram figure
    /// stamped onto a pounds stack.
    @Test("Test A Range With No Usable Increment Falls Back To Its Units Step")
    func testARangeWithNoUsableIncrementFallsBackToItsUnitsStep() {
        let kilograms = makeScreen(increment: 0, unit: .kilograms)
        kilograms.presenter.onViewDisappear()

        #expect(kilograms.box.value.increment == 2.5)

        let pounds = makeScreen(increment: 0, unit: .pounds)
        pounds.presenter.onViewDisappear()

        #expect(pounds.box.value.increment == 5)
    }

    /// An end below the start clamps every weight to the start, so a full cable stack would read as
    /// its lightest plate. The two are swapped back rather than left as a stack with nothing in it.
    @Test("Test A Range Entered Back To Front Is Turned Round")
    func testARangeEnteredBackToFrontIsTurnedRound() {
        let screen = makeScreen(min: 10, max: 120)

        screen.presenter.stack.minWeight = 120
        screen.presenter.stack.maxWeight = 10
        screen.presenter.onViewDisappear()

        #expect(screen.box.value.minWeight == 10)
        #expect(screen.box.value.maxWeight == 120)
    }

    /// A sheet is as likely to be swiped away as closed with the button, so the repair cannot live
    /// only on the button.
    @Test("Test Closing With The Button Repairs The Range Too")
    func testClosingWithTheButtonRepairsTheRangeToo() {
        let screen = makeScreen(increment: 5)

        screen.presenter.stack.increment = 0
        screen.presenter.onDismissPressed()

        #expect(screen.box.value.increment == 5)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["EditWeightRangeView_Appear"])
    }

    // MARK: - Add-ons

    /// Two equal add-ons are a real machine (a pair of 2 kg toggles), so the second is allowed.
    @Test("Test Add-ons Are Added, Repeated And Removed")
    func testAddOnsAreAddedRepeatedAndRemoved() {
        let screen = makeScreen()

        screen.presenter.newAddOn = 2
        screen.presenter.onAddAddOnPressed()
        screen.presenter.newAddOn = 2
        screen.presenter.onAddAddOnPressed()

        #expect(screen.box.value.addOns == [2, 2])
        #expect(screen.presenter.newAddOn == nil)

        screen.presenter.onDeleteAddOns(at: IndexSet(integer: 0))
        #expect(screen.box.value.addOns == [2])
    }

    /// A cleared field reads as zero, and a zero or negative add-on describes nothing.
    @Test("Test An Add-on Must Weigh Something", arguments: [0.0, -2])
    func testAnAddOnMustWeighSomething(_ value: Double) {
        let screen = makeScreen()

        screen.presenter.newAddOn = value
        #expect(screen.presenter.addOnMessage != nil)
        #expect(!screen.presenter.canAddAddOn)
        screen.presenter.onAddAddOnPressed()

        #expect(screen.box.value.addOns.isEmpty)
    }

    @Test("Test Add-ons Stop At The Cap")
    func testAddOnsStopAtTheCap() {
        let screen = makeScreen()
        screen.presenter.stack.addOns = Array(repeating: 1, count: WeightStack.maxAddOns)

        screen.presenter.newAddOn = 1
        screen.presenter.onAddAddOnPressed()

        #expect(screen.box.value.addOns.count == WeightStack.maxAddOns)
        #expect(screen.presenter.addOnMessage != nil)
    }

    // MARK: - Uneven stack

    /// Pin weights are kept in order whatever order they are typed in, and replace the grid.
    @Test("Test An Uneven Stack Lists Its Pins In Order")
    func testAnUnevenStackListsItsPinsInOrder() {
        let screen = makeScreen()
        screen.presenter.isUneven = true
        #expect(screen.box.value.weights == [])

        for weight in [12.0, 5, 8.5] {
            screen.presenter.newPinWeight = weight
            screen.presenter.onAddPinWeightPressed()
        }

        #expect(screen.box.value.weights == [5, 8.5, 12])
        screen.presenter.onDeletePinWeights(at: IndexSet(integer: 1))
        #expect(screen.box.value.weights == [5, 12])
    }

    /// The same weight twice is one pin position, and zero is none.
    @Test("Test A Pin Weight Must Be New And More Than Zero")
    func testAPinWeightMustBeNewAndMoreThanZero() {
        let screen = makeScreen()
        screen.presenter.isUneven = true
        screen.presenter.newPinWeight = 5
        screen.presenter.onAddPinWeightPressed()

        screen.presenter.newPinWeight = 5
        #expect(screen.presenter.pinWeightMessage != nil)
        screen.presenter.onAddPinWeightPressed()
        screen.presenter.newPinWeight = 0
        #expect(!screen.presenter.canAddPinWeight)
        screen.presenter.onAddPinWeightPressed()

        #expect(screen.box.value.weights == [5])
    }

    /// Turning uneven off goes back to the grid, which was never touched; an uneven stack left
    /// with no weights does the same as the screen closes, rather than describing no weights.
    @Test("Test An Empty Or Abandoned Uneven Stack Goes Back To Its Grid")
    func testAnEmptyOrAbandonedUnevenStackGoesBackToItsGrid() {
        let screen = makeScreen(min: 5, max: 100, increment: 5)
        screen.presenter.isUneven = true
        screen.presenter.onViewDisappear()
        #expect(screen.box.value.weights == nil)

        screen.presenter.isUneven = true
        screen.presenter.newPinWeight = 7
        screen.presenter.onAddPinWeightPressed()
        screen.presenter.isUneven = false

        #expect(screen.box.value.weights == nil)
        #expect(screen.box.value.minWeight == 5)
        #expect(screen.box.value.maxWeight == 100)
    }
}
