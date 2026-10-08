//
//  GymEquipmentAdderPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

//
//  Adding one more weight to a piece of equipment a gym already has.
//
//  Seven screens, one shape: a blank entry is prepared in the unit the list was showing, the user
//  sets a figure on it, and saving appends it to the equipment. What a gym holds is not a cosmetic
//  list — a live workout rounds the weight it suggests onto the nearest thing the gym actually has,
//  so a weight added here in the wrong unit, or added twice, changes the load someone is told to
//  lift.
//
//  A refused save shows an alert through `showSimpleAlert`, a `GlobalRouter` extension method that
//  none of these router protocols restate, so it dispatches statically past any double. Each
//  refusal is asserted as "the equipment did not gain a weight" instead, which is the part the user
//  would feel, and each acceptance as "it did". The same goes for the `dismissScreen` that follows
//  a successful save.
//

/// Adding a dumbbell, kettlebell or plate to a rack of them.
@MainActor
struct GymAddFreeWeightPresenterTests {

    private func makePresenter(
        _ box: GymEquipmentBox<FreeWeights>,
        unit: ExerciseWeightUnit = .kilograms,
        interactor: GymEquipmentInteractor? = nil
    ) -> AddFreeWeightPresenter {
        AddFreeWeightPresenter(
            interactor: interactor ?? GymEquipmentInteractor(),
            router: GymEquipmentRouter(),
            delegate: AddFreeWeightDelegate(freeWeight: box.binding, unit: unit)
        )
    }

    /// The unit comes from the list the user was looking at, not from a default, so a dumbbell
    /// added while the pounds tab was showing is a pounds dumbbell.
    @Test("Test A Free Weight Is Prepared In The Unit The List Was Showing")
    func testAFreeWeightIsPreparedInTheUnitTheListWasShowing() {
        let box = GymEquipmentBox(GymEquipmentFixtures.freeWeights())
        let presenter = makePresenter(box, unit: .pounds)

        #expect(presenter.unit == .pounds)
        #expect(presenter.freeWeightAvailable.unit == .pounds)
    }

    @Test("Test A Free Weight Is Added To The Equipment")
    func testAFreeWeightIsAddedToTheEquipment() {
        let box = GymEquipmentBox(GymEquipmentFixtures.freeWeights([GymEquipmentFixtures.plate(10)]))
        let presenter = makePresenter(box)
        presenter.freeWeightAvailable.availableWeights = 12.5

        presenter.onSavePressed()

        #expect(box.value.range.count == 2)
        #expect(box.value.range.last?.availableWeights == 12.5)
        // Added as something the gym has, not as a row that has to be switched on afterwards.
        #expect(box.value.range.last?.isActive == true)
    }

    @Test("Test A Plate Count Travels With The Plate")
    func testAPlateCountTravelsWithThePlate() {
        let box = GymEquipmentBox(GymEquipmentFixtures.freeWeights())
        let presenter = makePresenter(box)
        presenter.freeWeightAvailable.availableWeights = 20
        presenter.freeWeightAvailable.count = 2

        presenter.onSavePressed()

        #expect(box.value.range.last?.count == 2)
    }

    /// A gym cannot hold the same dumbbell twice, and a duplicate row could not be told from its
    /// twin when one of them is later edited or deleted.
    @Test("Test A Free Weight Already Held Is Not Added Again")
    func testAFreeWeightAlreadyHeldIsNotAddedAgain() {
        let box = GymEquipmentBox(GymEquipmentFixtures.freeWeights([GymEquipmentFixtures.plate(10)]))
        let presenter = makePresenter(box)
        presenter.freeWeightAvailable.availableWeights = 10

        presenter.onSavePressed()

        #expect(box.value.range.count == 1)
    }

    /// 10 kg and 10 lb are different dumbbells, so holding one does not block the other — comparing
    /// the figures alone would refuse a gym that stocks both.
    @Test("Test The Same Figure In The Other Unit Is A Different Weight")
    func testTheSameFigureInTheOtherUnitIsADifferentWeight() {
        let box = GymEquipmentBox(GymEquipmentFixtures.freeWeights([GymEquipmentFixtures.plate(10)]))
        let presenter = makePresenter(box, unit: .pounds)
        presenter.freeWeightAvailable.availableWeights = 10

        presenter.onSavePressed()

        #expect(box.value.range.count == 2)
        #expect(box.value.range.last?.unit == .pounds)
        // Stored as typed: converting here and again when the weight is read back would halve or
        // double what the gym is recorded as holding.
        #expect(box.value.range.last?.availableWeights == 10)
    }

    /// Colour is how plates are told apart on a rack, so picking one has to reach the weight being
    /// added rather than only the swatch on screen.
    @Test("Test A Chosen Plate Colour Travels With The Weight")
    func testAChosenPlateColourTravelsWithTheWeight() {
        let box = GymEquipmentBox(GymEquipmentFixtures.freeWeights())
        let presenter = makePresenter(box)

        presenter.onColourPressed(colour: .blue)
        presenter.onSavePressed()

        #expect(presenter.selectedColour == .blue)
        #expect(box.value.range.last?.plateColour == Color.blue.asHex())
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let interactor = GymEquipmentInteractor()
        let box = GymEquipmentBox(GymEquipmentFixtures.freeWeights())
        let presenter = makePresenter(box, interactor: interactor)

        presenter.onViewAppear()

        #expect(interactor.trackedScreenEventNames == ["AddFreeWeightView_Appear"])
    }
}

/// Adding a weight that can be hung from a dip belt or weight vest.
@MainActor
struct GymAddBodyWeightPresenterTests {

    private func makePresenter(
        _ box: GymEquipmentBox<BodyWeights>,
        unit: ExerciseWeightUnit = .kilograms
    ) -> AddBodyWeightPresenter {
        AddBodyWeightPresenter(
            interactor: GymEquipmentInteractor(),
            router: GymEquipmentRouter(),
            delegate: AddBodyWeightDelegate(bodyWeight: box.binding, unit: unit)
        )
    }

    @Test("Test A Body Weight Is Added In The Unit It Was Entered In")
    func testABodyWeightIsAddedInTheUnitItWasEnteredIn() {
        let box = GymEquipmentBox(GymEquipmentFixtures.bodyWeights([GymEquipmentFixtures.bodyWeight(5)]))
        let presenter = makePresenter(box, unit: .pounds)
        presenter.bodyWeightAvailable.availableWeights = 25

        presenter.onSavePressed()

        #expect(box.value.range.count == 2)
        #expect(box.value.range.last?.availableWeights == 25)
        #expect(box.value.range.last?.unit == .pounds)
    }

    @Test("Test A Body Weight Already Held Is Not Added Again")
    func testABodyWeightAlreadyHeldIsNotAddedAgain() {
        let box = GymEquipmentBox(GymEquipmentFixtures.bodyWeights([GymEquipmentFixtures.bodyWeight(5)]))
        let presenter = makePresenter(box)
        presenter.bodyWeightAvailable.availableWeights = 5

        presenter.onSavePressed()

        #expect(box.value.range.count == 1)
    }

    /// The first weight added has nothing to clash with — the case a duplicate check written
    /// against the wrong default would reject outright, leaving an empty belt that can never be
    /// filled.
    @Test("Test The First Body Weight Can Always Be Added")
    func testTheFirstBodyWeightCanAlwaysBeAdded() {
        let box = GymEquipmentBox(GymEquipmentFixtures.bodyWeights())
        let presenter = makePresenter(box)
        presenter.bodyWeightAvailable.availableWeights = 0

        presenter.onSavePressed()

        #expect(box.value.range.count == 1)
    }
}

/// Adding another bar to the rack of bars that plates get loaded onto.
@MainActor
struct GymAddLoadableBarPresenterTests {

    private func makePresenter(
        _ box: GymEquipmentBox<LoadableBars>,
        unit: ExerciseWeightUnit = .kilograms
    ) -> AddLoadableBarPresenter {
        AddLoadableBarPresenter(
            interactor: GymEquipmentInteractor(),
            router: GymEquipmentRouter(),
            delegate: AddLoadableBarDelegate(loadableBar: box.binding, unit: unit)
        )
    }

    @Test("Test A Bar Weight Is Added To The Bar")
    func testABarWeightIsAddedToTheBar() {
        let box = GymEquipmentBox(GymEquipmentFixtures.loadableBars([GymEquipmentFixtures.barBase(20)]))
        let presenter = makePresenter(box)
        presenter.loadableBarBaseWeight.baseWeight = 15

        presenter.onSavePressed()

        #expect(box.value.baseWeights.map(\.baseWeight) == [20, 15])
    }

    /// A bar's own weight is the floor every loaded total is built on, so two bars claiming the
    /// same weight would make the same total reachable two ways.
    @Test("Test A Bar Weight Already Held Is Not Added Again")
    func testABarWeightAlreadyHeldIsNotAddedAgain() {
        let box = GymEquipmentBox(GymEquipmentFixtures.loadableBars([GymEquipmentFixtures.barBase(20)]))
        let presenter = makePresenter(box)
        presenter.loadableBarBaseWeight.baseWeight = 20

        presenter.onSavePressed()

        #expect(box.value.baseWeights.count == 1)
    }

    @Test("Test A Bar Weight In The Other Unit Is Its Own Bar")
    func testABarWeightInTheOtherUnitIsItsOwnBar() {
        let box = GymEquipmentBox(GymEquipmentFixtures.loadableBars([GymEquipmentFixtures.barBase(20)]))
        let presenter = makePresenter(box, unit: .pounds)
        presenter.loadableBarBaseWeight.baseWeight = 20

        presenter.onSavePressed()

        #expect(box.value.baseWeights.count == 2)
        #expect(box.value.baseWeights.last?.unit == .pounds)
    }
}

/// Adding a bar to a rack of bars that come at a weight and cannot be loaded.
@MainActor
struct GymAddFixedWeightBarPresenterTests {

    private func makePresenter(
        _ box: GymEquipmentBox<FixedWeightBars>,
        unit: ExerciseWeightUnit = .kilograms
    ) -> AddFixedWeightBarPresenter {
        AddFixedWeightBarPresenter(
            interactor: GymEquipmentInteractor(),
            router: GymEquipmentRouter(),
            delegate: AddFixedWeightBarDelegate(fixedWeightBar: box.binding, unit: unit)
        )
    }

    @Test("Test A Fixed Bar Weight Is Added To The Rack")
    func testAFixedBarWeightIsAddedToTheRack() {
        let box = GymEquipmentBox(GymEquipmentFixtures.fixedWeightBars([GymEquipmentFixtures.fixedBase(10)]))
        let presenter = makePresenter(box)
        presenter.fixedWeightBarBaseWeight.baseWeight = 12.5

        presenter.onSavePressed()

        #expect(box.value.baseWeights.map(\.baseWeight) == [10, 12.5])
    }

    @Test("Test A Fixed Bar Weight Already Held Is Not Added Again")
    func testAFixedBarWeightAlreadyHeldIsNotAddedAgain() {
        let box = GymEquipmentBox(GymEquipmentFixtures.fixedWeightBars([GymEquipmentFixtures.fixedBase(10)]))
        let presenter = makePresenter(box)
        presenter.fixedWeightBarBaseWeight.baseWeight = 10

        presenter.onSavePressed()

        #expect(box.value.baseWeights.count == 1)
    }

    /// Adding the rack's first bar must not be mistaken for a duplicate of the blank entry the
    /// screen starts from.
    @Test("Test The First Fixed Bar Weight Can Always Be Added")
    func testTheFirstFixedBarWeightCanAlwaysBeAdded() {
        let box = GymEquipmentBox(GymEquipmentFixtures.fixedWeightBars())
        let presenter = makePresenter(box)
        presenter.fixedWeightBarBaseWeight.baseWeight = 0

        presenter.onSavePressed()

        #expect(box.value.baseWeights.count == 1)
    }
}

/// Adding a resistance band to a set of them.
@MainActor
struct GymAddBandPresenterTests {

    private func makePresenter(
        _ box: GymEquipmentBox<Bands>,
        unit: ExerciseWeightUnit = .kilograms
    ) -> AddBandPresenter {
        AddBandPresenter(
            interactor: GymEquipmentInteractor(),
            router: GymEquipmentRouter(),
            delegate: AddBandDelegate(band: box.binding, unit: unit)
        )
    }

    /// Bands are picked off the rack by name and colour rather than by a number stamped on them, so
    /// an unnamed band could not be found again.
    @Test("Test A Band Needs A Name")
    func testABandNeedsAName() {
        let box = GymEquipmentBox(GymEquipmentFixtures.bands())
        let presenter = makePresenter(box)
        presenter.bandAvailable.availableResistance = 12
        presenter.bandAvailable.name = ""

        presenter.onSavePressed()

        #expect(box.value.range.isEmpty)

        presenter.bandAvailable.name = "Medium"
        presenter.onSavePressed()

        #expect(box.value.range.count == 1)
        #expect(box.value.range.last?.name == "Medium")
    }

    @Test("Test A Band Resistance Already Held Is Not Added Again")
    func testABandResistanceAlreadyHeldIsNotAddedAgain() {
        let box = GymEquipmentBox(GymEquipmentFixtures.bands([GymEquipmentFixtures.band(12, name: "Medium")]))
        let presenter = makePresenter(box)
        presenter.bandAvailable.name = "Also Medium"
        presenter.bandAvailable.availableResistance = 12

        presenter.onSavePressed()

        #expect(box.value.range.count == 1)
    }

    @Test("Test A Chosen Band Colour Travels With The Band")
    func testAChosenBandColourTravelsWithTheBand() {
        let box = GymEquipmentBox(GymEquipmentFixtures.bands())
        let presenter = makePresenter(box)
        presenter.bandAvailable.name = "Heavy"
        presenter.bandAvailable.availableResistance = 30

        presenter.onColourPressed(colour: .green)
        presenter.onSavePressed()

        #expect(box.value.range.last?.bandColour == Color.green.asHex())
    }

    @Test("Test A Band Is Added In The Unit It Was Entered In")
    func testABandIsAddedInTheUnitItWasEnteredIn() {
        let box = GymEquipmentBox(GymEquipmentFixtures.bands())
        let presenter = makePresenter(box, unit: .pounds)
        presenter.bandAvailable.name = "Heavy"
        presenter.bandAvailable.availableResistance = 66

        presenter.onSavePressed()

        #expect(box.value.range.last?.unit == .pounds)
        #expect(box.value.range.last?.availableResistance == 66)
    }
}

/// Adding a weight range to a cable machine: the start, the end and the step its stack moves in.
@MainActor
struct GymAddCableMachineRangePresenterTests {

    private func makePresenter(
        _ box: GymEquipmentBox<CableMachine>,
        unit: ExerciseWeightUnit = .kilograms
    ) -> AddCableMachineRangePresenter {
        AddCableMachineRangePresenter(
            interactor: GymEquipmentInteractor(),
            router: GymEquipmentRouter(),
            delegate: AddCableMachineRangeDelegate(cableMachine: box.binding, unit: unit)
        )
    }

    /// A range is the arithmetic the machine's selectable weights are generated from, so a start
    /// above its end describes no weights at all.
    @Test("Test A Cable Range Must Start Below Where It Ends")
    func testACableRangeMustStartBelowWhereItEnds() {
        let box = GymEquipmentBox(GymEquipmentFixtures.cableMachine())
        let presenter = makePresenter(box)
        presenter.range.name = "Stack"
        presenter.range.minWeight = 100
        presenter.range.maxWeight = 20

        presenter.onSavePressed()

        #expect(box.value.ranges.isEmpty)
    }

    /// An increment of zero is what a cleared text field produces, and it is the value that later
    /// divides by zero when a workout rounds a weight onto this machine.
    @Test("Test A Cable Range Must Have An Increment")
    func testACableRangeMustHaveAnIncrement() {
        let box = GymEquipmentBox(GymEquipmentFixtures.cableMachine())
        let presenter = makePresenter(box)
        presenter.range.name = "Stack"
        presenter.range.increment = 0

        presenter.onSavePressed()

        #expect(box.value.ranges.isEmpty)

        presenter.range.increment = -5
        presenter.onSavePressed()

        #expect(box.value.ranges.isEmpty)
    }

    /// Two ranges under the same name cannot be told apart in the machine's list, whatever weights
    /// they describe. Spacing and capitals do not make a name different.
    @Test("Test A Cable Range Name Cannot Be Reused")
    func testACableRangeNameCannotBeReused() {
        let box = GymEquipmentBox(GymEquipmentFixtures.cableMachine([GymEquipmentFixtures.cableRange("Stack A")]))
        let presenter = makePresenter(box)
        presenter.range.name = "  stack a  "
        presenter.range.minWeight = 5
        presenter.range.maxWeight = 200

        presenter.onSavePressed()

        #expect(box.value.ranges.count == 1)
    }

    /// The same weights under a different name is still the same set of weights twice over.
    @Test("Test An Identical Cable Range Is Not Added Twice")
    func testAnIdenticalCableRangeIsNotAddedTwice() {
        let existing = GymEquipmentFixtures.cableRange("Stack A", min: 5, max: 100, increment: 5)
        let box = GymEquipmentBox(GymEquipmentFixtures.cableMachine([existing]))
        let presenter = makePresenter(box)
        presenter.range.name = "Stack B"
        presenter.range.minWeight = 5
        presenter.range.maxWeight = 100
        presenter.range.increment = 5

        presenter.onSavePressed()

        #expect(box.value.ranges.count == 1)
    }

    /// The first range added becomes the one the machine is taken to be set to — a machine with no
    /// default range rounds nothing.
    @Test("Test The First Cable Range Becomes The Machines Default")
    func testTheFirstCableRangeBecomesTheMachinesDefault() {
        let box = GymEquipmentBox(GymEquipmentFixtures.cableMachine())
        let presenter = makePresenter(box)
        presenter.range.name = "Stack"

        presenter.onSavePressed()

        #expect(box.value.ranges.count == 1)
        #expect(box.value.defaultRangeId == presenter.range.id)
    }

    /// A later range must not take over, or adding a light accessory range would silently redefine
    /// what the machine's main stack is.
    @Test("Test A Later Cable Range Does Not Take Over As Default")
    func testALaterCableRangeDoesNotTakeOverAsDefault() {
        let existing = GymEquipmentFixtures.cableRange("Stack A")
        let box = GymEquipmentBox(GymEquipmentFixtures.cableMachine([existing]))
        let presenter = makePresenter(box)
        presenter.range.name = "Stack B"
        presenter.range.maxWeight = 60

        presenter.onSavePressed()

        #expect(box.value.ranges.count == 2)
        #expect(box.value.defaultRangeId == existing.id)
    }

    @Test("Test A Cable Range Is Added In The Unit It Was Entered In")
    func testACableRangeIsAddedInTheUnitItWasEnteredIn() {
        let box = GymEquipmentBox(GymEquipmentFixtures.cableMachine())
        let presenter = makePresenter(box, unit: .pounds)
        presenter.range.name = "Stack"
        presenter.range.minWeight = 10
        presenter.range.maxWeight = 300
        presenter.range.increment = 10

        presenter.onSavePressed()

        let added = box.value.ranges.first
        #expect(added?.unit == .pounds)
        // Stored exactly as typed: these are the figures printed on the stack, not kilograms in
        // disguise, and converting them on the way in would misdescribe the machine.
        #expect(added?.minWeight == 10)
        #expect(added?.maxWeight == 300)
        #expect(added?.increment == 10)
    }
}

/// Adding a weight range to a pin-loaded machine.
@MainActor
struct GymAddPinLoadedRangePresenterTests {

    private func makePresenter(
        _ box: GymEquipmentBox<PinLoadedMachine>,
        unit: ExerciseWeightUnit = .kilograms
    ) -> AddPinLoadedMachineRangePresenter {
        AddPinLoadedMachineRangePresenter(
            interactor: GymEquipmentInteractor(),
            router: GymEquipmentRouter(),
            delegate: AddPinLoadedMachineRangeDelegate(pinLoadedMachine: box.binding, unit: unit)
        )
    }

    /// Equal ends are rejected along with inverted ones: a range holding a single weight is a fixed
    /// weight, not a range.
    @Test("Test A Pin Loaded Range Must Start Below Where It Ends")
    func testAPinLoadedRangeMustStartBelowWhereItEnds() {
        let box = GymEquipmentBox(GymEquipmentFixtures.pinMachine())
        let presenter = makePresenter(box)
        presenter.range.name = "Stack"
        presenter.range.minWeight = 150
        presenter.range.maxWeight = 150

        presenter.onSavePressed()

        #expect(box.value.ranges.isEmpty)
    }

    @Test("Test A Pin Loaded Range Must Have An Increment")
    func testAPinLoadedRangeMustHaveAnIncrement() {
        let box = GymEquipmentBox(GymEquipmentFixtures.pinMachine())
        let presenter = makePresenter(box)
        presenter.range.name = "Stack"
        presenter.range.increment = 0

        presenter.onSavePressed()

        #expect(box.value.ranges.isEmpty)
    }

    @Test("Test A Pin Loaded Range Is Added In The Unit It Was Entered In")
    func testAPinLoadedRangeIsAddedInTheUnitItWasEnteredIn() {
        let box = GymEquipmentBox(GymEquipmentFixtures.pinMachine())
        let presenter = makePresenter(box, unit: .pounds)
        presenter.range.name = "Stack"
        presenter.range.minWeight = 20
        presenter.range.maxWeight = 200
        presenter.range.increment = 10

        presenter.onSavePressed()

        let added = box.value.ranges.first
        #expect(added?.unit == .pounds)
        #expect(added?.minWeight == 20)
        #expect(added?.maxWeight == 200)
        #expect(added?.increment == 10)
    }

    @Test("Test A Pin Loaded Range Name Cannot Be Reused")
    func testAPinLoadedRangeNameCannotBeReused() {
        let box = GymEquipmentBox(GymEquipmentFixtures.pinMachine([GymEquipmentFixtures.pinRange("Stack A")]))
        let presenter = makePresenter(box)
        presenter.range.name = "STACK A"
        presenter.range.maxWeight = 200

        presenter.onSavePressed()

        #expect(box.value.ranges.count == 1)
    }

    @Test("Test The First Pin Loaded Range Becomes The Machines Default")
    func testTheFirstPinLoadedRangeBecomesTheMachinesDefault() {
        let box = GymEquipmentBox(GymEquipmentFixtures.pinMachine())
        let presenter = makePresenter(box)
        presenter.range.name = "Stack"

        presenter.onSavePressed()

        #expect(box.value.defaultRangeId == presenter.range.id)
    }

    @Test("Test An Identical Pin Loaded Range Is Not Added Twice")
    func testAnIdenticalPinLoadedRangeIsNotAddedTwice() {
        let existing = GymEquipmentFixtures.pinRange("Stack A", min: 5, max: 100, increment: 5)
        let box = GymEquipmentBox(GymEquipmentFixtures.pinMachine([existing]))
        let presenter = makePresenter(box)
        presenter.range.name = "Stack B"
        presenter.range.minWeight = 5
        presenter.range.maxWeight = 100
        presenter.range.increment = 5

        presenter.onSavePressed()

        #expect(box.value.ranges.count == 1)
    }
}
