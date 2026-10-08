//
//  WeightStackTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// A cable or pin-loaded machine's stack: where the pin goes, the add-ons on top, and how the
/// keyboard, rounding and the set row read the loads they make. The machine that prompted it has
/// 7 kg plates and two 2 kg toggles.
@MainActor
struct WeightStackTests {

    private static func stack(
        min: Double = 7, max: Double = 98, increment: Double = 7,
        unit: ExerciseWeightUnit = .kilograms, addOns: [Double] = [], weights: [Double]? = nil
    ) -> WeightStack {
        WeightStack(
            id: "s", name: "Stack", minWeight: min, maxWeight: max, increment: increment,
            unit: unit, isActive: true, addOns: addOns, weights: weights
        )
    }

    private static let sevens = stack(addOns: [2, 2])

    private static func gym(_ stack: WeightStack) -> GymProfileModel {
        GymProfileModel(
            authorId: "u", freeWeights: [], loadableBars: [], fixedWeightBars: [], bands: [], bodyWeights: [],
            cableMachines: [], plateLoadedMachines: [],
            pinLoadedMachines: [PinLoadedMachine(id: "pin", name: "Pin", ranges: [stack], isActive: true)]
        )
    }

    private static let refs = [EquipmentRef(kind: .pinLoadedMachine, id: "pin")]

    private func step(_ stack: WeightStack, unit: ExerciseWeightUnit = .kilograms) -> WeightStep {
        WeightStepper.steps(for: Self.refs, profile: Self.gym(stack), unit: unit)
    }

    // MARK: - Loads

    @Test func sevenKilogramPinsWithTwoTogglesMakeEveryCombination() {
        let loads = Self.sevens.loads()
        #expect(Array(loads.prefix(10)) == [7, 9, 11, 14, 16, 18, 21, 23, 25, 28])
        #expect(loads.last == 102)
        // 14 pins, each with +0, +2 and +4.
        #expect(loads.count == 42)
    }

    @Test func anUnevenStackUsesItsOwnWeights() {
        let stack = Self.stack(weights: [12, 5, 8.5, 5, 0])
        #expect(stack.pinPositions == [5, 8.5, 12])
        #expect(stack.loads() == [5, 8.5, 12])
        #expect(Self.stack(addOns: [1], weights: [5, 10]).loads() == [5, 6, 10, 11])
    }

    /// Every catalogue stack used to start at 0, which no stack can be set to; the first position
    /// is then one increment.
    @Test func aLegacyZeroMinimumStartsOneIncrementUp() {
        let stack = Self.stack(min: 0, max: 30, increment: 5)
        #expect(stack.lightestPin == 5)
        #expect(stack.pinPositions == [5, 10, 15, 20, 25, 30])
        #expect(step(stack).kind == .increment(5, min: 5, max: 30))
    }

    @Test func aZeroIncrementHasNoPositions() {
        let stack = Self.stack(min: 0, increment: 0, addOns: [2])
        #expect(stack.pinPositions.isEmpty)
        #expect(stack.loads().isEmpty)
        #expect(step(stack) == WeightStepper.fallback(.kilograms))
    }

    /// Past six add-ons the rest are ignored: 64 combinations per pin is already more than any
    /// machine has.
    @Test func addOnsAreCappedAtSix() {
        let stack = Self.stack(min: 100, max: 100, increment: 1, addOns: Array(repeating: 1, count: 9))
        #expect(stack.usableAddOns.count == WeightStack.maxAddOns)
        #expect(stack.loads() == [100, 101, 102, 103, 104, 105, 106])
    }

    // MARK: - Keyboard and rounding

    @Test func theKeyboardStepsThroughEveryLoad() {
        let step = step(Self.sevens)
        #expect(step.kind == .list(Self.sevens.loads()))
        #expect(step.next(after: nil) == 7)
        #expect(step.next(after: 7) == 9)
        #expect(step.next(after: 9) == 11)
        #expect(step.next(after: 11) == 14)
        #expect(step.previous(before: 14) == 11)
        #expect(step.stack == PinStack(pins: Self.sevens.pinPositions, addOns: [2, 2]))
    }

    /// A plain stack keeps its grid and has nothing to break down.
    @Test func aPlainStackStepsOnItsGrid() {
        let step = step(Self.stack())
        #expect(step.kind == .increment(7, min: 7, max: 98))
        #expect(step.stack == nil)
    }

    /// A pound stack read in kilograms converts the pins and the add-ons alike.
    @Test func aPoundStackIsConvertedWhole() {
        let step = step(Self.stack(min: 10, max: 20, increment: 10, unit: .pounds, addOns: [5]))
        #expect(step.kind == .list([4.536, 6.804, 9.072, 11.34]))
    }

    /// Progression moves at least the smallest gap the stack makes, which the toggles bring down to
    /// 2 kg; a weight between two loads goes to the nearer, and on a tie (15 between 14 and 16) the
    /// lighter, as rounding does on every listed weight.
    @Test func roundingUsesTheStacksLoads() {
        let exercise = ExerciseModel(
            id: "lift", authorId: "u", name: "Lift", trackableMetrics: [.weight, .reps],
            type: .compoundUpper, laterality: .bilateral, muscleGroups: [.lats: .primary], isBodyweight: false,
            equipmentVariations: [EquipmentVariation(id: "v", resistanceEquipment: Self.refs)],
            rangeOfMotion: 4, stability: 4, bodyWeightContribution: 0, alternateNames: []
        )
        let rule = WeightRoundingRule(exercise: exercise, gymProfile: Self.gym(Self.sevens), preferredWeightUnit: .kilograms)

        #expect(rule.minimumIncrementKg == 2)
        #expect(rule.round(15) == 14)
        #expect(rule.round(15.2) == 16)
        #expect(rule.round(12.4) == 11)
    }

    // MARK: - Breakdown

    @Test func theBreakdownUsesTheFewestAddOns() {
        let stack = PinStack(pins: Self.sevens.pinPositions, addOns: [2, 2])
        #expect(stack.breakdown(total: 14) == PinStack.Breakdown(pin: 14, addOns: []))
        #expect(stack.breakdown(total: 16) == PinStack.Breakdown(pin: 14, addOns: [2]))
        #expect(stack.breakdown(total: 18) == PinStack.Breakdown(pin: 14, addOns: [2, 2]))
        #expect(stack.breakdown(total: 15) == nil)
    }

    /// Among equally few add-ons the one listed first, so 22 on a stack with a 1 and a 2 is never
    /// read two ways.
    @Test func theBreakdownIsDeterministic() {
        let stack = PinStack(pins: [20, 21], addOns: [2, 1])
        #expect(stack.breakdown(total: 22) == PinStack.Breakdown(pin: 20, addOns: [2]))
    }

    @Test func theBreakdownReadsAsPinPlusAddOns() {
        let stack = PinStack(pins: Self.sevens.pinPositions, addOns: [2, 2])
        #expect(stack.summary(total: 16, unit: .kilograms) == "Pin 14 + 2 kg")
        #expect(stack.summary(total: 18, unit: .kilograms) == "Pin 14 + 2 + 2 kg")
        #expect(stack.summary(total: 14, unit: .kilograms) == "Pin 14 kg")
        #expect(stack.summary(total: 15, unit: .kilograms) == nil)
    }

    // MARK: - Catalogue and gym rows

    /// The catalogue's stacks start at their lightest pin, not at 0.
    @Test func catalogueStacksStartAtTheirLightestPin() {
        let stacks = (PinLoadedMachine.defaultPinLoadedMachines.flatMap(\.ranges)
            + CableMachine.defaultCableMachines.flatMap(\.ranges))
        #expect(stacks.allSatisfy { $0.minWeight == 5 && $0.increment == 5 })
    }

    @Test func aGymRowSummarisesTheStack() {
        let locale = Locale(identifier: "en_US")
        #expect(GymEquipmentFormat.stack(Self.stack(min: 5, max: 300, increment: 5, unit: .pounds, addOns: [2, 2]), locale: locale)
                == "5–300 lb, 5 lb increments · +2, +2")
        #expect(GymEquipmentFormat.stack(Self.stack(weights: Array(stride(from: 5.0, through: 60, by: 5))), locale: locale)
                == "Uneven · 12 weights")
    }
}
