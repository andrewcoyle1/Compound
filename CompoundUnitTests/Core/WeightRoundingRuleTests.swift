//
//  WeightRoundingRuleTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// Prefill, warm-ups and progression round a weight by the same answer the weight keyboard steps
/// by (`WeightStepper`), so nothing prescribes a weight the user cannot then reach with − and +.
@MainActor
struct WeightRoundingRuleTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Fixtures

    private static func cable(_ id: String = "cable", ranges: [CableMachineRange], isActive: Bool = true) -> CableMachine {
        CableMachine(id: id, name: "Cable", ranges: ranges, isActive: isActive)
    }

    private static func range(
        _ id: String, min: Double, max: Double, increment: Double, unit: ExerciseWeightUnit = .kilograms, isActive: Bool = true
    ) -> CableMachineRange {
        CableMachineRange(id: id, name: id, minWeight: min, maxWeight: max, increment: increment, unit: unit, isActive: isActive)
    }

    private static func rack(_ weights: [Double], id: String = "dumbbells") -> FreeWeights {
        FreeWeights(
            id: id, name: id, needsColour: false,
            range: weights.map { FreeWeightsAvailable(id: UUID().uuidString, availableWeights: $0, unit: .kilograms, isActive: true) },
            isActive: true
        )
    }

    private static func gym(cables: [CableMachine] = [], freeWeights: [FreeWeights] = []) -> GymProfileModel {
        GymProfileModel(
            authorId: "u", freeWeights: freeWeights, loadableBars: [], fixedWeightBars: [], bands: [], bodyWeights: [],
            cableMachines: cables, plateLoadedMachines: [], pinLoadedMachines: []
        )
    }

    /// Every shape of equipment that constrains a weight, for the keyboard-agreement property.
    private static let everything = GymProfileModel(
        authorId: "u",
        freeWeights: [
            rack([1.25, 2.5, 5, 10, 20], id: "weight_plates"),
            rack([2, 4, 6, 8, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30, 32.5])
        ],
        loadableBars: [
            LoadableBars(id: "barbell", name: "Barbell", description: nil, baseWeights: [
                LoadableBarsBaseWeight(id: "b20", baseWeight: 20, unit: .kilograms, isActive: true)
            ], isActive: true)
        ],
        fixedWeightBars: [
            FixedWeightBars(id: "fixed", name: "Fixed", description: nil, baseWeights: [10, 15, 20, 30, 40].map {
                FixedWeightBarsBaseWeight(id: "f\($0)", baseWeight: $0, unit: .kilograms, isActive: true)
            }, isActive: true)
        ],
        bands: [],
        bodyWeights: [],
        cableMachines: [
            cable(ranges: [range("c", min: 5, max: 50, increment: 5)]),
            cable("pounds", ranges: [range("lb", min: 10, max: 200, increment: 10, unit: .pounds)])
        ],
        plateLoadedMachines: [
            PlateLoadedMachine(id: "sled", name: "Sled", baseWeight: 40, unit: .kilograms, isActive: true)
        ],
        pinLoadedMachines: []
    )

    private func exercise(_ refs: [EquipmentRef], assisted: Bool = false) -> ExerciseModel {
        ExerciseModel(
            id: "lift", authorId: "u", name: "Lift", trackableMetrics: assisted ? [.reps, .weightPerSideAssistance] : [.weight, .reps],
            type: .compoundUpper, laterality: .bilateral, muscleGroups: [.lats: .primary], isBodyweight: assisted,
            equipmentVariations: [EquipmentVariation(id: "v", resistanceEquipment: refs)],
            rangeOfMotion: 4, stability: 4, bodyWeightContribution: assisted ? 100 : 0, alternateNames: []
        )
    }

    /// What the keyboard steps by for the same exercise, gym and unit.
    private func keyboard(_ refs: [EquipmentRef], gym: GymProfileModel?, unit: ExerciseWeightUnit) -> WeightStep {
        let session = WorkoutExerciseModel(
            id: "e", authorId: "u", templateId: "lift", name: "Lift", trackingMode: .weightReps, index: 0, sets: [],
            equipmentVariations: [EquipmentVariation(id: "v", resistanceEquipment: refs)]
        )
        return WeightStepper.steps(for: session, profile: gym, unit: unit)
    }

    private func rule(_ refs: [EquipmentRef], gym: GymProfileModel?, unit: ExerciseWeightUnit = .kilograms) -> WeightRoundingRule {
        WeightRoundingRule(exercise: exercise(refs), gymProfile: gym, preferredWeightUnit: unit)
    }

    private let cableRef = [EquipmentRef(kind: .cableMachine, id: "cable")]

    // MARK: - Ranges

    /// A switched-off range is not on the machine: 23 kg goes to the active 2.5 kg grid, not the
    /// inactive 10 kg one.
    @Test func anInactiveRangeIsIgnored() {
        let gym = Self.gym(cables: [Self.cable(ranges: [
            Self.range("off", min: 0, max: 100, increment: 10, isActive: false),
            Self.range("on", min: 5, max: 50, increment: 2.5)
        ])])
        let rule = rule(cableRef, gym: gym)

        #expect(rule.round(23) == 22.5)
        #expect(rule.minimumIncrementKg == 2.5)
        #expect(keyboard(cableRef, gym: gym, unit: .kilograms).next(after: 20) == 22.5)
    }

    /// The catalogue's lat pulldown has its kilogram range switched off and its pound range on. A
    /// kilogram user's keyboard steps 5 lb (2.268 kg); prefill and progression used to prescribe
    /// 5 kg jumps from the inactive range. Both now use the pound range.
    @Test func aKilogramUserOnAPoundStackUsesThePoundStack() {
        let gym = GymProfileModel(authorId: "u")
        let refs = [EquipmentRef(kind: .cableMachine, id: "cable_lat_pulldown_machine")]
        let rule = rule(refs, gym: gym)

        #expect(rule.step == keyboard(refs, gym: gym, unit: .kilograms))
        #expect(rule.step.kind == .increment(2.268, min: 0, max: 226.796))
        #expect(abs(rule.round(50) - 49.896) < 0.0001)
        #expect(rule.minimumIncrementKg == 2.268)
    }

    /// Neither range is in the user's unit, so the machine's default range is the one used.
    @Test func theDefaultRangeIsUsedWhenNoneIsInTheUsersUnit() {
        var machine = Self.cable(ranges: [
            Self.range("coarse", min: 10, max: 200, increment: 20, unit: .pounds),
            Self.range("fine", min: 5, max: 200, increment: 5, unit: .pounds)
        ])
        machine.defaultRangeId = "fine"
        let rule = rule(cableRef, gym: Self.gym(cables: [machine]))

        // The fine stack's 5 lb is 2.268 kg, so 45 kg lands on 45.36 kg (100 lb); the first,
        // coarse stack would have given 40.824 kg (90 lb).
        #expect(rule.minimumIncrementKg == 2.268)
        #expect(abs(rule.round(45) - 45.36) < 0.0001)
    }

    // MARK: - Equipment the gym does not have

    /// Missing from the gym, or switched off, the machine no longer borrows the catalogue's grid:
    /// the weight is rounded as though nothing constrained it, as the keyboard falls back to 2.5 kg.
    @Test(arguments: [false, true])
    func aMachineMissingOrOffIsUnconstrained(_ present: Bool) {
        let refs = [EquipmentRef(kind: .cableMachine, id: "cable_lat_pulldown_machine")]
        let off = CableMachine.defaultCableMachines.map { machine in
            var machine = machine
            machine.isActive = false
            return machine
        }
        let rule = rule(refs, gym: Self.gym(cables: present ? off : []))

        #expect(!rule.step.constrainsWeight)
        #expect(rule.round(23.3) == 23.5)
        #expect(rule.minimumIncrementKg == 2.5)
        #expect(keyboard(refs, gym: Self.gym(cables: present ? off : []), unit: .kilograms) == WeightStepper.fallback(.kilograms))
    }

    /// A stack with no increment resolves to nothing, so nothing divides by it.
    @Test func aZeroIncrementNeverDivides() {
        let gym = Self.gym(cables: [Self.cable(ranges: [Self.range("zero", min: 0, max: 100, increment: 0)])])
        let rule = rule(cableRef, gym: gym)

        #expect(!rule.step.constrainsWeight)
        #expect(rule.round(23.3) == 23.5)
        #expect(rule.minimumIncrementKg == 2.5)
    }

    // MARK: - Racks

    /// Prefill puts last time's 23 kg on the nearest dumbbell the rack has, the lighter on a tie.
    @Test func prefillRoundsToADumbbellOnTheRack() {
        let gym = Self.gym(freeWeights: [Self.rack([20, 22.5, 25])])
        let previous = WorkoutSetModel(
            id: "p", authorId: "u", index: 1, reps: 10, weightKg: 23, isWarmup: false, completedAt: start, dateCreated: start
        )
        var sets = [WorkoutSetModel(id: "s", authorId: "u", index: 1, reps: nil, weightKg: nil, isWarmup: false, completedAt: nil, dateCreated: start)]
        WorkingSetPrefill(
            prefill: .previousValues, previousSets: [previous], authorId: "u",
            exercise: exercise([EquipmentRef(kind: .freeWeight, id: "dumbbells")]), gymProfile: gym, unitPreferences: nil
        ).apply(to: &sets)

        #expect(sets[0].weightKg == 22.5)
        #expect(rule([EquipmentRef(kind: .freeWeight, id: "dumbbells")], gym: gym).round(23.75) == 22.5)
    }

    /// One warm-up at half of 47 kg is 23.5 kg, which the rack does not have; its nearest is 22.5 kg.
    @Test func warmUpsRoundToADumbbellOnTheRack() {
        let warmups = WorkoutSessionModel.generateWarmupSets(
            trackingMode: .weightReps, authorId: "u", workingWeightKg: 47, workingReps: 8, setTargets: [],
            exercise: exercise([EquipmentRef(kind: .freeWeight, id: "dumbbells")]),
            gymProfile: Self.gym(freeWeights: [Self.rack([20, 22.5, 25, 30])])
        )
        #expect(warmups.map(\.weightKg) == [22.5])
    }

    // MARK: - Assistance

    /// Assistance is stored negative and rounded on the machine mirrored below zero, as the
    /// keyboard steps it; with nothing constraining it, it rounds to the half kilogram as before.
    @Test func anAssistedWeightRoundsOnTheMirroredStack() {
        let gym = Self.gym(cables: [Self.cable(ranges: [Self.range("c", min: 5, max: 50, increment: 5)])])
        let onStack = WeightRoundingRule(exercise: exercise(cableRef, assisted: true), gymProfile: gym, preferredWeightUnit: .kilograms)
        #expect(onStack.round(-27) == -25)
        #expect(onStack.round(-80) == -50)
        #expect(onStack.round(10) == 0)

        let noGym = WeightRoundingRule(exercise: exercise(cableRef, assisted: true), gymProfile: nil, preferredWeightUnit: .kilograms)
        #expect(noGym.round(-27.4) == -27.5)
    }

    // MARK: - Agreement with the keyboard

    struct Shape: Sendable, CustomTestStringConvertible {
        let kind: EquipmentKind
        let id: String
        let unit: ExerciseWeightUnit
        var testDescription: String { "\(id) in \(unit.abbreviation)" }
    }

    /// Whatever a weight rounds to is one the keyboard reaches by stepping up from the lightest.
    @Test(arguments: [
        Shape(kind: .cableMachine, id: "cable", unit: .kilograms),
        Shape(kind: .cableMachine, id: "pounds", unit: .kilograms),
        Shape(kind: .cableMachine, id: "pounds", unit: .pounds),
        Shape(kind: .freeWeight, id: "dumbbells", unit: .kilograms),
        Shape(kind: .fixedWeightBar, id: "fixed", unit: .kilograms),
        Shape(kind: .loadableBar, id: "barbell", unit: .kilograms),
        Shape(kind: .plateLoadedMachine, id: "sled", unit: .kilograms)
    ])
    func everyRoundedWeightIsOneTheKeyboardReaches(_ shape: Shape) {
        let refs = [EquipmentRef(kind: shape.kind, id: shape.id)]
        let rule = rule(refs, gym: Self.everything, unit: shape.unit)
        let keys = keyboard(refs, gym: Self.everything, unit: shape.unit)
        #expect(rule.step == keys)
        #expect(rule.step.constrainsWeight)

        for weightKg in stride(from: 0.0, through: 120, by: 3.7) {
            let rounded = UnitConversion.convertWeight(rule.round(weightKg), to: shape.unit)
            var reached = keys.next(after: nil)
            for _ in 0..<500 {
                guard let value = reached, value < rounded - 0.01, let next = keys.next(after: value), next > value else { break }
                reached = next
            }
            #expect(abs((reached ?? .nan) - rounded) < 0.01, "\(weightKg) kg rounded to \(rounded), keyboard reached \(reached ?? .nan)")
        }
    }
}
