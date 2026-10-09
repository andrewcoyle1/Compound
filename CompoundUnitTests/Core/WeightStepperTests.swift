//
//  WeightStepperTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// What − and + do on the weight keyboard, for every kind of equipment a gym can hold.
@MainActor
struct WeightStepperTests {

    // MARK: - Fixtures

    private static func plates(_ weights: [Double], unit: ExerciseWeightUnit = .kilograms) -> FreeWeights {
        FreeWeights(
            id: "weight_plates", name: "Plates", needsColour: true, isPlates: true,
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

    /// An assisted machine on the cable stack (5–50 kg in fives): the stack's range, below zero,
    /// stopping at zero for an exercise that cannot be loaded.
    @Test func anAssistedMachineStepsBelowZeroToItsDeepest() {
        let step = step(.cableMachine, "cable").assisted(bodyweightOnly: true)
        #expect(step.next(after: -30) == -25)
        #expect(step.previous(before: -30) == -35)
        #expect(step.previous(before: -50) == -50)
        #expect(step.next(after: -5) == 0)
        #expect(step.next(after: 0) == 0)
        #expect(step.previous(before: nil) == -5)
    }

    /// Without assistance nothing steps below zero, whatever the equipment.
    @Test(arguments: [EquipmentKind.cableMachine, .freeWeight, .bodyWeight, .supportEquipment])
    func nothingElseStepsBelowZero(_ kind: EquipmentKind) {
        let ids: [EquipmentKind: String] = [.cableMachine: "cable", .freeWeight: "dumbbells", .bodyWeight: "vest", .supportEquipment: "bench"]
        let step = step(kind, ids[kind] ?? "")
        #expect((step.previous(before: 0) ?? 0) >= 0)
        #expect((step.previous(before: nil) ?? 0) >= 0)
    }

    @Test func barShowsItsWeightAndPlates() {
        let step = step(.loadableBar, "barbell")
        #expect(step.chip == "Bar 20 kg")
        #expect(step.baseWeight == 20)
        #expect(step.plates.map(\.weight) == [1.25, 2.5, 5, 10, 20])
        #expect(step.isPlateLoaded)
    }

    @Test func bodyWeightShowsBW() {
        #expect(step(.bodyWeight, "vest").chip == "BW")
        #expect(!step(.bodyWeight, "vest").isPlateLoaded)
    }

    @Test func bandsCycleByNameLightestFirst() {
        let step = step(.bands, "bands")
        #expect(step.kind == .bands)
        #expect(step.bands == ["Light", "Heavy"])
        #expect(step.band(after: nil, forward: true) == 0)
        #expect(step.band(after: 1, forward: true) == 0)
        #expect(step.band(after: 0, forward: false) == 1)
        #expect(step.next(after: 10) == nil)
    }

    /// A variation's items are used together, so a bar with bands steps the bar and offers the
    /// bands beside it, whichever is listed first. Before G6 only the first item the gym had counted.
    @Test func aBarWithBandsOffersTheBarStepAndTheBands() {
        let bar = step(.loadableBar, "barbell")
        for refs in [
            [EquipmentRef(kind: .loadableBar, id: "barbell"), EquipmentRef(kind: .bands, id: "bands")],
            [EquipmentRef(kind: .bands, id: "bands"), EquipmentRef(kind: .loadableBar, id: "barbell")]
        ] {
            let step = WeightStepper.steps(for: refs, profile: Self.profile, unit: .kilograms)
            #expect(step.kind == bar.kind)
            #expect(step.baseWeight == 20)
            #expect(step.constrainsWeight)
            #expect(step.bands == ["Light", "Heavy"])
        }
        #expect(bar.bands.isEmpty)
    }

    /// A band switched on in both kg and lb is one band, not two chips with the same name.
    @Test func aBandListedInBothUnitsIsOfferedOnce() {
        let gym = GymProfileModel(authorId: "u", bands: [
            Bands(id: "bands", name: "Bands", range: [
                BandsAvailable(id: "lb", name: "Light", bandColour: "", availableResistance: 18, unit: .pounds, isActive: true),
                BandsAvailable(id: "kg", name: "Light", bandColour: "", availableResistance: 8, unit: .kilograms, isActive: true),
                BandsAvailable(id: "h", name: "Heavy", bandColour: "", availableResistance: 30, unit: .kilograms, isActive: true)
            ], isActive: true)
        ])
        let step = WeightStepper.steps(for: [EquipmentRef(kind: .bands, id: "bands")], profile: gym, unit: .kilograms)
        #expect(step.bands == ["Light", "Heavy"])
    }

    /// Only equipment the gym has limits what a weight may be; the fallback, body weight and bands
    /// only say how far a tap moves it (`WeightRoundingRule`).
    @Test func onlyEquipmentTheGymHasConstrainsTheWeight() {
        for (kind, id) in [(EquipmentKind.cableMachine, "cable"), (.freeWeight, "dumbbells"), (.fixedWeightBar, "fixed"), (.loadableBar, "barbell"), (.plateLoadedMachine, "sled")] {
            #expect(step(kind, id).constrainsWeight, "\(id)")
        }
        for (kind, id) in [(EquipmentKind.cableMachine, "missing"), (.bodyWeight, "vest"), (.bands, "bands")] {
            #expect(!step(kind, id).constrainsWeight, "\(id)")
        }
    }

    @Test func theSmallestStepIsTheGridOrTheSmallestGap() {
        #expect(step(.cableMachine, "cable").smallestStep == 5)
        #expect(step(.freeWeight, "dumbbells").smallestStep == 2.5)
        #expect(step(.fixedWeightBar, "fixed").smallestStep == 10)
        #expect(step(.loadableBar, "barbell").smallestStep == 2.5)
        #expect(step(.bands, "bands").smallestStep == nil)
    }

    @Test func nearestPicksTheLighterOfTwoEquallyCloseWeights() {
        #expect(step(.freeWeight, "dumbbells").nearest(to: 17.5) == 15)
        #expect(step(.freeWeight, "dumbbells").nearest(to: 100) == 20)
        #expect(step(.cableMachine, "cable").nearest(to: 1) == 5)
        #expect(step(.loadableBar, "barbell").nearest(to: 61) == 60)
        #expect(step(.bands, "bands").nearest(to: 7) == 7)
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
        #expect(step.chip == "Bar 44.09 lb")
        #expect(step.next(after: 44.092) == 49.604)
    }

    @Test func platesInTheUsersUnitAreUsedWhenThereAreAny() {
        var profile = Self.profile
        profile.freeWeights = [Self.plates([1.25, 20]), Self.plates([2.5, 45], unit: .pounds)]
        #expect(WeightStepper.availablePlates(profile: profile, unit: .pounds).map(\.weight) == [2.5, 45])
        #expect(WeightStepper.availablePlates(profile: profile, unit: .kilograms).map(\.weight) == [1.25, 20])
    }

    // MARK: - Sleeves, counts and collars

    private func step(_ kind: EquipmentKind, _ id: String, in profile: GymProfileModel) -> WeightStep {
        WeightStepper.steps(for: exercise(kind, id), profile: profile, unit: .kilograms)
    }

    private static func counted(_ plates: [(weight: Double, count: Int?)], id: String = "weight_plates") -> FreeWeights {
        FreeWeights(
            id: id, name: id, needsColour: false, isPlates: true,
            range: plates.map {
                FreeWeightsAvailable(id: UUID().uuidString, availableWeights: $0.weight, unit: .kilograms, isActive: true, count: $0.count)
            },
            isActive: true
        )
    }

    /// A T-bar row takes its plates on one post, so a tap adds one plate rather than a pair, and
    /// 18 kg + 2.5 kg is a load it can make.
    @Test func aSingleSleeveMachineStepsOnePlate() {
        var profile = Self.profile
        profile.plateLoadedMachines = [
            PlateLoadedMachine(id: "t_bar", name: "T-Bar", baseWeight: 18, unit: .kilograms, sleeves: 1, isActive: true)
        ]
        let step = step(.plateLoadedMachine, "t_bar", in: profile)

        #expect(step.sleeves == 1)
        #expect(step.smallestStep == 1.25)
        #expect(step.next(after: 18) == 19.25)
        #expect(step.nearest(to: 20.5) == 20.5)
        #expect(PlateCalculator.load(total: 20.5, bar: 18, plates: step.plates, sleeves: 1) == .loadable(perSide: [2.5]))
        #expect(step.plateText([2.5], unit: .kilograms) == "Plates: 2.5 kg")
    }

    @Test func aTwoSleeveMachineStillStepsAPair() {
        let step = step(.plateLoadedMachine, "sled")

        #expect(step.sleeves == 2)
        #expect(step.smallestStep == 2.5)
        #expect(step.plateText([2.5], unit: .kilograms) == "Per side: 2.5 kg")
    }

    /// Two 20s are one a side, so 100 kg on a 20 kg bar takes 20 + 15 + 5 a side.
    @Test func limitedPlatesFallToTheNextOneDown() {
        var profile = Self.profile
        profile.freeWeights = [Self.counted([(5, nil), (15, nil), (20, 2)])]
        let step = step(.loadableBar, "barbell", in: profile)

        #expect(step.plates == [Plate(weight: 5), Plate(weight: 15), Plate(weight: 20, perSleeve: 1)])
        #expect(PlateCalculator.load(total: 100, bar: 20, plates: step.plates, sleeves: 2) == .loadable(perSide: [20, 15, 5]))
    }

    /// Iron and bumper plates of one weight are one pile: their counts add, and either having no
    /// limit leaves the pile without one.
    @Test func ironAndBumperPlatesOfOneWeightAddUp() {
        var profile = Self.profile
        profile.freeWeights = [Self.counted([(10, 1), (20, 2)]), Self.counted([(10, nil), (20, 2)], id: "bumper_plates")]

        #expect(WeightStepper.availablePlates(profile: profile, unit: .kilograms) == [Plate(weight: 10), Plate(weight: 20, perSleeve: 2)])
    }

    /// One 1.25 kg plate cannot go on both sides of a bar, so the bar steps by the 2.5s; a
    /// single-sleeve machine can still use it.
    @Test func aPlateTooFewForEverySleeveIsLeftOut() {
        var profile = Self.profile
        profile.freeWeights = [Self.counted([(1.25, 1), (2.5, nil)])]

        #expect(WeightStepper.availablePlates(profile: profile, unit: .kilograms).map(\.weight) == [2.5])
        #expect(WeightStepper.availablePlates(profile: profile, unit: .kilograms, sleeves: 1) == [Plate(weight: 1.25, perSleeve: 1), Plate(weight: 2.5)])
        #expect(step(.loadableBar, "barbell", in: profile).smallestStep == 5)
    }

    /// Plates are whatever the gym marks as plates, not whatever its id ends in.
    @Test func anItemMarkedAsPlatesIsLoaded() {
        var profile = Self.profile
        profile.freeWeights = [
            FreeWeights(id: "change_discs", name: "Change Discs", needsColour: false, isPlates: true, range: [
                FreeWeightsAvailable(id: "c", availableWeights: 0.5, unit: .kilograms, isActive: true)
            ], isActive: true),
            FreeWeights(id: "fractional_plates", name: "Fractional", needsColour: false, isPlates: false, range: [
                FreeWeightsAvailable(id: "f", availableWeights: 0.25, unit: .kilograms, isActive: true)
            ], isActive: true)
        ]

        #expect(WeightStepper.availablePlates(profile: profile, unit: .kilograms).map(\.weight) == [0.5])
    }

    /// A 20 kg bar with 2.5 kg collars weighs 25 kg empty, so nothing lighter can be loaded.
    @Test func collarsAreAddedToTheBar() {
        var profile = Self.profile
        profile.loadableBars[0].collarWeight = 2.5
        let step = step(.loadableBar, "barbell", in: profile)

        #expect(step.baseWeight == 25)
        #expect(step.chip == "Bar 20 kg + collars")
        #expect(step.next(after: nil) == 25)
        #expect(step.nearest(to: 22) == 25)
        #expect(step.nearest(to: 61) == 60)
    }
}

/// The plates for each side of a bar.
struct PlateCalculatorTests {

    private let plates = [1.25, 2.5, 5, 10, 15, 20, 25].map { Plate(weight: $0) }

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
        let result = PlateCalculator.load(total: 80, bar: 20, plates: [Plate(weight: 15), Plate(weight: 20)])
        #expect(result == .notLoadable(below: 60, above: 90))
    }

    @Test func noPlatesAtAll() {
        #expect(PlateCalculator.load(total: 60, bar: 20, plates: []) == .notLoadable(below: nil, above: nil))
    }

    /// With only two 20s and nothing else, 100 kg cannot be loaded; 60 kg, one a side, is the most.
    @Test func runningOutOfPlatesIsNotLoadable() {
        let plates = [Plate(weight: 20, perSleeve: 1)]
        #expect(PlateCalculator.load(total: 100, bar: 20, plates: plates) == .notLoadable(below: 60, above: nil))
        #expect(PlateCalculator.nearestLoadable(total: 100, bar: 20, plates: plates) == 60)
    }

    @Test func oneSleeveTakesTheWholeLoad() {
        #expect(PlateCalculator.load(total: 58, bar: 18, plates: plates, sleeves: 1) == .loadable(perSide: [25, 15]))
        #expect(PlateCalculator.nearestLoadable(total: 19, bar: 18, plates: plates, sleeves: 1) == 19.25)
    }
}
