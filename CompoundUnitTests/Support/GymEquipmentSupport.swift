//
//  GymEquipmentSupport.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Foundation
import SwiftUI
@testable import Compound

/// Scaffolding shared by the gym equipment screens — the eighteen presenters behind "what weights
/// does this gym have", which between them add, edit and delete every kind of load the app can
/// round a working weight onto.
///
/// Each of those screens is handed a `Binding` into the gym profile being edited rather than a copy,
/// so a test drives one by holding the equipment in a box and reading the box back afterwards. The
/// box is main-actor isolated because a `Binding`'s accessors are `@Sendable`.

/// The equipment a screen was opened over, standing in for the gym profile screen's own binding.
@MainActor
final class GymEquipmentBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }

    var binding: Binding<Value> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
}

/// None of these screens ask their interactor for anything beyond the analytics and haptics every
/// screen gets, so one spy serves all of them.
@MainActor
final class GymEquipmentInteractor: SpyGlobalInteractor,
                                    AddFreeWeightInteractor,
                                    AddBodyWeightInteractor,
                                    AddLoadableBarInteractor,
                                    AddFixedWeightBarInteractor,
                                    AddBandInteractor,
                                    AddWeightStackInteractor,
                                    AddGymMachineInteractor,
                                    EditFreeWeightInteractor,
                                    EditBodyWeightInteractor,
                                    EditBandInteractor,
                                    EditLoadableBarInteractor,
                                    EditFixedWeightBarInteractor,
                                    EditStackMachineInteractor,
                                    EditPlateLoadedMachineInteractor,
                                    EditLoadableAccessoryInteractor,
                                    EditWeightRangeInteractor { }

/// Records where a screen navigated to.
///
/// `dismissScreen` and `showSimpleAlert` are deliberately absent: both are `GlobalRouter` extension
/// methods that none of these screens' router protocols restate as requirements, so they are
/// dispatched statically and a double would never be called. Tests assert on the state those calls
/// accompany instead.
@MainActor
final class GymEquipmentRouter: AddFreeWeightRouter,
                                AddBodyWeightRouter,
                                AddLoadableBarRouter,
                                AddFixedWeightBarRouter,
                                AddBandRouter,
                                AddWeightStackRouter,
                                AddGymMachineRouter,
                                EditFreeWeightRouter,
                                EditBodyWeightRouter,
                                EditBandRouter,
                                EditLoadableBarRouter,
                                EditFixedWeightBarRouter,
                                EditStackMachineRouter,
                                EditPlateLoadedMachineRouter,
                                EditLoadableAccessoryRouter,
                                EditWeightRangeRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var shown: [String] = []

    /// The unit each "add" screen was opened for, which is what decides the unit of the weight the
    /// user is about to type.
    private(set) var addUnits: [ExerciseWeightUnit] = []

    func showAddFreeWeightView(delegate: AddFreeWeightDelegate) {
        shown.append("addFreeWeight")
        addUnits.append(delegate.unit)
    }

    func showAddBodyWeightView(delegate: AddBodyWeightDelegate) {
        shown.append("addBodyWeight")
        addUnits.append(delegate.unit)
    }

    func showAddBandView(delegate: AddBandDelegate) {
        shown.append("addBand")
        addUnits.append(delegate.unit)
    }

    func showAddLoadableBarView(delegate: AddLoadableBarDelegate) {
        shown.append("addLoadableBar")
        addUnits.append(delegate.unit)
    }

    func showAddFixedWeightBarView(delegate: AddFixedWeightBarDelegate) {
        shown.append("addFixedWeightBar")
        addUnits.append(delegate.unit)
    }

    /// The last add-a-stack form opened, so a test can save through it as the form would.
    private(set) var addStackDelegate: AddWeightStackDelegate?

    func showAddWeightStackView(delegate: AddWeightStackDelegate) {
        shown.append("addWeightStack")
        addUnits.append(delegate.unit)
        addStackDelegate = delegate
    }

    /// The equipment each edit-a-range screen was opened for, so a test can check the range handed
    /// over belongs to the machine whose row was tapped.
    private(set) var editedRangeEquipment: [String] = []

    func showEditWeightRangeView(delegate: EditWeightRangeDelegate) {
        shown.append("editWeightRange")
        editedRangeEquipment.append(delegate.equipmentName)
    }
}

/// The equipment fixtures. Ids are derived from the values so a test can name one without holding
/// on to it.
@MainActor
enum GymEquipmentFixtures {

    static func freeWeights(_ range: [FreeWeightsAvailable] = []) -> FreeWeights {
        FreeWeights(id: "dumbbells", name: "Dumbbells", needsColour: false, range: range, isActive: true)
    }

    static func plate(_ weight: Double, unit: ExerciseWeightUnit = .kilograms) -> FreeWeightsAvailable {
        FreeWeightsAvailable(
            id: "plate-\(weight)-\(unit.rawValue)",
            plateColour: nil,
            availableWeights: weight,
            unit: unit,
            isActive: true
        )
    }

    static func bodyWeights(_ range: [BodyWeightsAvailable] = []) -> BodyWeights {
        BodyWeights(id: "belt", name: "Dip Belt", range: range, isActive: true)
    }

    static func bodyWeight(_ weight: Double, unit: ExerciseWeightUnit = .kilograms) -> BodyWeightsAvailable {
        BodyWeightsAvailable(
            id: "body-\(weight)-\(unit.rawValue)",
            plateColour: nil,
            availableWeights: weight,
            unit: unit,
            isActive: true
        )
    }

    static func loadableBars(_ baseWeights: [LoadableBarsBaseWeight] = []) -> LoadableBars {
        LoadableBars(id: "barbell", name: "Barbell", description: nil, baseWeights: baseWeights, isActive: true)
    }

    static func barBase(_ weight: Double, unit: ExerciseWeightUnit = .kilograms) -> LoadableBarsBaseWeight {
        LoadableBarsBaseWeight(id: "bar-\(weight)-\(unit.rawValue)", baseWeight: weight, unit: unit, isActive: true)
    }

    static func fixedWeightBars(_ baseWeights: [FixedWeightBarsBaseWeight] = []) -> FixedWeightBars {
        FixedWeightBars(id: "ez", name: "Fixed EZ Bar", description: nil, baseWeights: baseWeights, isActive: true)
    }

    static func fixedBase(_ weight: Double, unit: ExerciseWeightUnit = .kilograms) -> FixedWeightBarsBaseWeight {
        FixedWeightBarsBaseWeight(id: "fixed-\(weight)-\(unit.rawValue)", baseWeight: weight, unit: unit, isActive: true)
    }

    static func bands(_ range: [BandsAvailable] = []) -> Bands {
        Bands(id: "bands", name: "Long Bands", range: range, isActive: true)
    }

    static func band(
        _ resistance: Double,
        name: String = "Light",
        unit: ExerciseWeightUnit = .kilograms
    ) -> BandsAvailable {
        BandsAvailable(
            id: "band-\(resistance)-\(unit.rawValue)",
            name: name,
            bandColour: "#FF0000",
            availableResistance: resistance,
            unit: unit,
            isActive: true
        )
    }

    static func cableMachine(_ ranges: [CableMachineRange] = []) -> CableMachine {
        CableMachine(id: "lat-pulldown", name: "Lat Pulldown", ranges: ranges, isActive: true)
    }

    static func cableRange(
        _ name: String,
        min: Double = 0,
        max: Double = 100,
        increment: Double = 5,
        unit: ExerciseWeightUnit = .kilograms
    ) -> CableMachineRange {
        CableMachineRange(
            id: "cable-\(name)",
            name: name,
            minWeight: min,
            maxWeight: max,
            increment: increment,
            unit: unit,
            isActive: true
        )
    }

    /// The add-a-stack form's hand-off, saving into `box` as the machine editor does.
    static func addStackDelegate<Machine: StackMachine>(
        _ box: GymEquipmentBox<Machine>,
        unit: ExerciseWeightUnit = .kilograms
    ) -> AddWeightStackDelegate {
        AddWeightStackDelegate(machineName: box.value.name, stacks: box.value.ranges, unit: unit) { box.value.addStack($0) }
    }

    static func pinMachine(_ ranges: [PinLoadedMachineRange] = []) -> PinLoadedMachine {
        PinLoadedMachine(id: "leg-press", name: "Leg Press", ranges: ranges, isActive: true)
    }

    static func pinRange(
        _ name: String,
        min: Double = 0,
        max: Double = 100,
        increment: Double = 5,
        unit: ExerciseWeightUnit = .kilograms
    ) -> PinLoadedMachineRange {
        PinLoadedMachineRange(
            id: "pin-\(name)",
            name: name,
            minWeight: min,
            maxWeight: max,
            increment: increment,
            unit: unit,
            isActive: true
        )
    }
}
