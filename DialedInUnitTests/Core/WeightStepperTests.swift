//
//  WeightStepperTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// What − and + do on the weight keyboard, for every kind of equipment a gym can hold.
@MainActor
struct WeightStepperTests {

    // MARK: - Fixtures

    private static func plates(_ weights: [Double], unit: ExerciseWeightUnit = .kilograms) -> FreeWeights {
        FreeWeights(
            id: "weight_plates", name: "Plates", needsColour: true,
            range: weights.map { FreeWeightsAvailable(id: UUID().uuidString, availableWeights: $0, unit: unit, isActive: true) },
            isActive: true
        )
    }

    private static let profile = GymProfileModel(
        authorId: "u",
        freeWeights: [
            plates([1.25, 2.5, 5, 10, 20]),
            FreeWeights(
                id: "dumbbells", name: "Dumbbells", needsColour: false,
                range: [
                    FreeWeightsAvailable(id: "d1", availableWeights: 10, unit: .kilograms, isActive: true),
                    FreeWeightsAvailable(id: "d2", availableWeights: 12.5, unit: .kilograms, isActive: true),
                    FreeWeightsAvailable(id: "d3", availableWeights: 15, unit: .kilograms, isActive: true),
                    FreeWeightsAvailable(id: "d4", availableWeights: 17.5, unit: .kilograms, isActive: false),
                    FreeWeightsAvailable(id: "d5", availableWeights: 20, unit: .kilograms, isActive: true)
                ],
                isActive: true
            )
        ],
        loadableBars: [
            LoadableBars(id: "barbell", name: "Barbell", description: nil, baseWeights: [
                LoadableBarsBaseWeight(id: "b20", baseWeight: 20, unit: .kilograms, isActive: true)
            ], isActive: true)
        ],
        fixedWeightBars: [
            FixedWeightBars(id: "fixed", name: "Fixed", description: nil, baseWeights: [
                FixedWeightBarsBaseWeight(id: "f1", baseWeight: 10, unit: .kilograms, isActive: true),
                FixedWeightBarsBaseWeight(id: "f2", baseWeight: 20, unit: .kilograms, isActive: true),
                FixedWeightBarsBaseWeight(id: "f3", baseWeight: 30, unit: .kilograms, isActive: true)
            ], isActive: true)
        ],
        bands: [
            Bands(id: "bands", name: "Bands", range: [
                BandsAvailable(id: "h", name: "Heavy", bandColour: "", availableResistance: 30, unit: .kilograms, isActive: true),
                BandsAvailable(id: "l", name: "Light", bandColour: "", availableResistance: 8, unit: .kilograms, isActive: true)
            ], isActive: true)
        ],
        bodyWeights: [],
        cableMachines: [
            CableMachine(id: "cable", name: "Cable", ranges: [
                CableMachineRange(id: "c", name: "Stack", minWeight: 5, maxWeight: 50, increment: 5, unit: .kilograms, isActive: true)
            ], isActive: true)
        ],
        plateLoadedMachines: [
            PlateLoadedMachine(id: "sled", name: "Sled", baseWeight: 40, unit: .kilograms, isActive: true)
        ],
        pinLoadedMachines: [
            PinLoadedMachine(id: "pin", name: "Pin", ranges: [
                PinLoadedMachineRange(id: "p", name: "Stack", minWeight: 10, maxWeight: 100, increment: 10, unit: .pounds, isActive: true)
            ], isActive: true)
        ]
    )

    private func exercise(_ kind: EquipmentKind, _ id: String) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "e", authorId: "u", templateId: "t", name: "Lift", trackingMode: .weightReps, index: 0, sets: [],
            equipmentVariations: [EquipmentVariation(id: "v", resistanceEquipment: [EquipmentRef(kind: kind, id: id)])]
        )
    }

    private func step(_ kind: EquipmentKind, _ id: String, unit: ExerciseWeightUnit = .kilograms) -> WeightStep {
        WeightStepper.steps(for: exercise(kind, id), profile: Self.profile, unit: unit)
    }

    // MARK: - Every kind

    struct Case: Sendable, CustomTestStringConvertible {
        let kind: EquipmentKind
        let id: String
        let from: Double?
        let expectedUp: Double?
        let expectedDown: Double?
        var testDescription: String { "\(kind.rawValue) from \(from.map { "\($0)" } ?? "nil")" }
    }

    @Test(arguments: [
        // Bar: 2 × the smallest plate, from the bar's own weight.
        Case(kind: .loadableBar, id: "barbell", from: 60, expectedUp: 62.5, expectedDown: 57.5),
        Case(kind: .loadableBar, id: "barbell", from: nil, expectedUp: 20, expectedDown: 20),
        Case(kind: .loadableBar, id: "barbell", from: 21, expectedUp: 22.5, expectedDown: 20),
        Case(kind: .plateLoadedMachine, id: "sled", from: 40, expectedUp: 42.5, expectedDown: 40),
        // Cable: its increment, clamped to the stack.
        Case(kind: .cableMachine, id: "cable", from: 20, expectedUp: 25, expectedDown: 15),
        Case(kind: .cableMachine, id: "cable", from: 50, expectedUp: 50, expectedDown: 45),
        Case(kind: .cableMachine, id: "cable", from: 5, expectedUp: 10, expectedDown: 5),
        Case(kind: .cableMachine, id: "cable", from: 22, expectedUp: 25, expectedDown: 20),
        // Dumbbells: the next one on the rack, skipping inactive ones, stopping at the ends.
        Case(kind: .freeWeight, id: "dumbbells", from: 15, expectedUp: 20, expectedDown: 12.5),
        Case(kind: .freeWeight, id: "dumbbells", from: 20, expectedUp: 20, expectedDown: 15),
        Case(kind: .freeWeight, id: "dumbbells", from: 10, expectedUp: 12.5, expectedDown: 10),
        Case(kind: .freeWeight, id: "dumbbells", from: 11, expectedUp: 12.5, expectedDown: 10),
        // Fixed bars: the next bar.
        Case(kind: .fixedWeightBar, id: "fixed", from: 20, expectedUp: 30, expectedDown: 10),
        // Body weight: external load in 1.25 kg, never below none.
        Case(kind: .bodyWeight, id: "vest", from: 0, expectedUp: 1.25, expectedDown: 0),
        Case(kind: .bodyWeight, id: "vest", from: nil, expectedUp: 0, expectedDown: 0),
        // Equipment this gym does not have: the default 2.5 kg.
        Case(kind: .cableMachine, id: "missing", from: 20, expectedUp: 22.5, expectedDown: 17.5),
        Case(kind: .supportEquipment, id: "bench", from: 20, expectedUp: 22.5, expectedDown: 17.5)
    ])
    func stepsForEveryKind(_ testCase: Case) {
        let step = step(testCase.kind, testCase.id)
        #expect(step.next(after: testCase.from) == testCase.expectedUp)
        #expect(step.previous(before: testCase.from) == testCase.expectedDown)
    }

    @Test func barShowsItsWeightAndPlates() {
        let step = step(.loadableBar, "barbell")
        #expect(step.chip == "Bar 20 kg")
        #expect(step.baseWeight == 20)
        #expect(step.plates == [1.25, 2.5, 5, 10, 20])
        #expect(step.isPlateLoaded)
    }

    @Test func bodyWeightShowsBW() {
        #expect(step(.bodyWeight, "vest").chip == "BW")
        #expect(!step(.bodyWeight, "vest").isPlateLoaded)
    }

    @Test func bandsCycleByNameLightestFirst() {
        let step = step(.bands, "bands")
        #expect(step.kind == .bands(["Light", "Heavy"]))
        #expect(step.band(after: nil, forward: true) == 0)
        #expect(step.band(after: 1, forward: true) == 0)
        #expect(step.band(after: 0, forward: false) == 1)
        #expect(step.next(after: 10) == nil)
    }

    // MARK: - Fallbacks

    @Test func noProfileFallsBackTo2_5kgOr5lb() {
        let kilograms = WeightStepper.steps(for: exercise(.loadableBar, "barbell"), profile: nil, unit: .kilograms)
        let pounds = WeightStepper.steps(for: exercise(.loadableBar, "barbell"), profile: nil, unit: .pounds)
        #expect(kilograms.next(after: 100) == 102.5)
        #expect(pounds.next(after: 100) == 105)
    }

    @Test func noVariationFallsBack() {
        let plain = WorkoutExerciseModel(id: "e", authorId: "u", templateId: "t", name: "Lift", trackingMode: .weightReps, index: 0, sets: [])
        #expect(WeightStepper.steps(for: plain, profile: Self.profile, unit: .kilograms) == WeightStepper.fallback(.kilograms))
    }

    @Test func chosenVariationWinsOverTheFirst() {
        var lift = exercise(.loadableBar, "barbell")
        lift.equipmentVariations.append(EquipmentVariation(id: "cable-v", resistanceEquipment: [EquipmentRef(kind: .cableMachine, id: "cable")]))
        lift.chosenVariationId = "cable-v"
        #expect(WeightStepper.steps(for: lift, profile: Self.profile, unit: .kilograms).next(after: 20) == 25)
    }

    // MARK: - Units

    @Test func poundRangeConvertsToKilograms() {
        // A 10 lb pin step is 4.536 kg, from a 10 lb (4.536 kg) minimum.
        let step = step(.pinLoadedMachine, "pin", unit: .kilograms)
        #expect(step.next(after: nil) == 4.536)
        #expect(step.next(after: 4.536) == 9.072)
    }

    @Test func poundRangeStaysInPounds() {
        let step = step(.pinLoadedMachine, "pin", unit: .pounds)
        #expect(step.next(after: 50) == 60)
        #expect(step.previous(before: 10) == 10)
        #expect(step.next(after: 100) == 100)
    }

    @Test func kilogramPlatesConvertForAPoundUser() {
        let step = step(.loadableBar, "barbell", unit: .pounds)
        // 20 kg bar is 44.092 lb; 2 × 1.25 kg is 5.512 lb.
        #expect(step.baseWeight == 44.092)
        #expect(step.chip == "Bar 44.09 lbs")
        #expect(step.next(after: 44.092) == 49.604)
    }

    @Test func platesInTheUsersUnitAreUsedWhenThereAreAny() {
        var profile = Self.profile
        profile.freeWeights = [Self.plates([1.25, 20]), Self.plates([2.5, 45], unit: .pounds)]
        #expect(WeightStepper.availablePlates(profile: profile, unit: .pounds) == [2.5, 45])
        #expect(WeightStepper.availablePlates(profile: profile, unit: .kilograms) == [1.25, 20])
    }
}

/// The plates for each side of a bar.
struct PlateCalculatorTests {

    private let plates: [Double] = [1.25, 2.5, 5, 10, 15, 20, 25]

    @Test func greedyFromTheHeaviest() {
        #expect(PlateCalculator.load(total: 100, bar: 20, plates: plates) == .loadable(perSide: [25, 15]))
        #expect(PlateCalculator.load(total: 142.5, bar: 20, plates: plates) == .loadable(perSide: [25, 25, 10, 1.25]))
    }

    @Test func bareBarIsLoadable() {
        #expect(PlateCalculator.load(total: 20, bar: 20, plates: plates) == .loadable(perSide: []))
    }

    @Test func unreachableOffersTheNearestLoadableTotals() {
        #expect(PlateCalculator.load(total: 101, bar: 20, plates: plates) == .notLoadable(below: 100, above: 102.5))
    }

    @Test func belowTheBarOffersTheBar() {
        #expect(PlateCalculator.load(total: 10, bar: 20, plates: plates) == .notLoadable(below: nil, above: 20))
    }

    @Test func greedyMissIsNotLoadable() {
        // 15 + 15 would do it, but greedy takes a 20 first and cannot finish.
        let result = PlateCalculator.load(total: 80, bar: 20, plates: [15, 20])
        #expect(result == .notLoadable(below: 60, above: 90))
    }

    @Test func noPlatesAtAll() {
        #expect(PlateCalculator.load(total: 60, bar: 20, plates: []) == .notLoadable(below: nil, above: nil))
    }
}
