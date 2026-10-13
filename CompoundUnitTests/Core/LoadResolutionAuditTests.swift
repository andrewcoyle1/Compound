//
//  LoadResolutionAuditTests.swift
//  CompoundUnitTests
//
//  The resolver fixes from the 10 Oct 2026 audit
//  (docs/reviews/2026-10-10-equipment-variation-progression-audit.md): what an exercise's
//  equipment lets it weigh, and the plates that make a weight.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct LoadResolutionAuditTests {

    // MARK: - Fixtures

    nonisolated private static func plates(_ weights: [Double], unit: ExerciseWeightUnit = .kilograms, id: String = "weight_plates", active: Bool = true) -> FreeWeights {
        FreeWeights(
            id: id, name: "Plates", needsColour: true, isPlates: true,
            range: weights.map { FreeWeightsAvailable(id: UUID().uuidString, availableWeights: $0, unit: unit, isActive: active) },
            isActive: true
        )
    }

    private static func gym(
        freeWeights: [FreeWeights] = [plates([1.25, 2.5, 5, 10, 15, 20, 25])],
        bars: [LoadableBars] = [bar()],
        plateMachines: [PlateLoadedMachine] = [],
        pins: [PinLoadedMachine] = [],
        cables: [CableMachine] = []
    ) -> GymProfileModel {
        GymProfileModel(
            authorId: "u", freeWeights: freeWeights, loadableBars: bars, fixedWeightBars: [], bands: [], bodyWeights: [],
            cableMachines: cables, plateLoadedMachines: plateMachines, pinLoadedMachines: pins
        )
    }

    nonisolated private static func bar(_ weight: Double = 20, unit: ExerciseWeightUnit = .kilograms) -> LoadableBars {
        LoadableBars(id: "barbell", name: "Barbell", description: nil, baseWeights: [
            LoadableBarsBaseWeight(id: "b", baseWeight: weight, unit: unit, isActive: true)
        ], isActive: true)
    }

    private static func ref(_ kind: EquipmentKind, _ id: String) -> EquipmentRef {
        EquipmentRef(kind: kind, id: id)
    }

    // MARK: - Plates are not the load beside a bar or machine

    /// Smith Machine Back Squat lists its plates first; they load the machine, they are not the load.
    @Test func platesListedFirstLoadTheMachine() {
        let profile = Self.gym(plateMachines: [PlateLoadedMachine(id: "smith_machine", name: "Smith", baseWeight: 15, unit: .kilograms, isActive: true)])
        let step = WeightStepper.steps(
            for: [Self.ref(.freeWeight, "weight_plates"), Self.ref(.plateLoadedMachine, "smith_machine")],
            profile: profile, unit: .kilograms
        )
        #expect(step.baseWeight == 15)
        #expect(step.nearest(to: 100) == 100)
    }

    /// The machine switched off is not a reason to load the single plates instead.
    @Test func platesBesideAnInactiveMachineAreStillNotTheLoad() {
        let profile = Self.gym(plateMachines: [PlateLoadedMachine(id: "leg_press", name: "Leg press", baseWeight: 0, unit: .kilograms, isActive: false)])
        let step = WeightStepper.steps(
            for: [Self.ref(.plateLoadedMachine, "leg_press"), Self.ref(.freeWeight, "weight_plates")],
            profile: profile, unit: .kilograms
        )
        #expect(step.constrainsWeight == false)
        #expect(step.nearest(to: 180) == 180)
    }

    /// A plate held in the hands is the load: there is nothing to put it on.
    @Test func platesAloneAreTheLoad() {
        let step = WeightStepper.steps(for: [Self.ref(.freeWeight, "weight_plates")], profile: Self.gym(), unit: .kilograms)
        #expect(step.kind == .list([1.25, 2.5, 5, 10, 15, 20, 25]))
    }

    // MARK: - Plate search

    /// Pound plates for a kilogram user convert to weights off any quarter grid; the old scan fell
    /// to the bare bar.
    @Test func platesInTheOtherUnitLoadTheirNearestTotal() {
        let plates = [45, 25, 10, 5, 2.5].map { Plate(weight: UnitConversion.convertWeightToKg($0, from: ExerciseWeightUnit.pounds)) }
        let nearest = PlateCalculator.nearestLoadable(total: 100, bar: 20, plates: plates)
        #expect(abs(nearest - 100) < 1.2)
        #expect(nearest > 90)
    }

    /// The default pound bumpers (10, 25, 35, 45, 55) make 30 lb a side as three tens.
    @Test func nonCanonicalPlatesFindTheCombinationGreedyMisses() {
        let plates = [10, 25, 35, 45, 55].map { Plate(weight: $0) }
        #expect(PlateCalculator.load(total: 105, bar: 45, plates: plates) == .loadable(perSide: [10, 10, 10]))
        #expect(PlateCalculator.load(total: 85, bar: 45, plates: plates) == .loadable(perSide: [10, 10]))
    }

    /// 15 + 15 made 80 kg all along; greedy took a 20 first and gave up.
    @Test func limitedPlatesStillFindTheirCombination() {
        #expect(PlateCalculator.load(total: 80, bar: 20, plates: [Plate(weight: 15), Plate(weight: 20)]) == .loadable(perSide: [15, 15]))
    }

    /// Past what the plates can make, the most they make.
    @Test func aTotalBeyondThePlatesClampsToTheMost() {
        let plates = [Plate(weight: 20, perSleeve: 2), Plate(weight: 2.5, perSleeve: 2)]
        #expect(PlateCalculator.nearestLoadable(total: 200, bar: 20, plates: plates) == 110)
    }

    /// With pound plates listed but all switched off, a pound user has no plates, not converted
    /// kilogram ones, as the plate calculator shows it.
    @Test func switchedOffPlatesInTheUnitLeaveNone() {
        let profile = Self.gym(freeWeights: [
            Self.plates([45, 25], unit: .pounds, id: "bumper_plates", active: false),
            Self.plates([20, 10])
        ])
        #expect(WeightStepper.availablePlates(profile: profile, unit: .pounds).isEmpty)
        #expect(WeightStepper.availablePlates(profile: profile, unit: .kilograms).map(\.weight) == [10, 20])
    }

    // MARK: - Stacks and grids

    /// 5 to 100 in sevens: the top pin is 96, not the stored 100.
    @Test func aStackTopsOutAtItsTopPin() {
        let profile = Self.gym(pins: [PinLoadedMachine(id: "pin", name: "Pin", ranges: [
            PinLoadedMachineRange(id: "s", name: "Stack", minWeight: 5, maxWeight: 100, increment: 7, unit: .kilograms, isActive: true)
        ], isActive: true)])
        let step = WeightStepper.steps(for: [Self.ref(.pinLoadedMachine, "pin")], profile: profile, unit: .kilograms)
        #expect(step.nearest(to: 100) == 96)
        #expect(step.next(after: 96) == 96)
    }

    /// Ties go to the lighter weight on a grid, as on plates and racks.
    @Test func aTieOnAGridRoundsDown() {
        let step = WeightStep(kind: .increment(2.5, min: 0, max: nil), chip: nil, baseWeight: nil, plates: [])
        #expect(step.nearest(to: 21.25) == 20)
        #expect(step.nearest(to: 21.3) == 22.5)
    }

    /// A stack whose first pin is off its step mirrors onto the real pins: −5, −15, −25.
    @Test func assistanceMirrorsTheRealPins() {
        let step = WeightStep(kind: .increment(10, min: 5, max: 45), chip: nil, baseWeight: nil, plates: []).assisted(bodyweightOnly: true)
        #expect(step.previous(before: 0) == -5)
        #expect(step.previous(before: -5) == -15)
    }

    /// A bar in a landmine is loaded on one end, a plate a step.
    @Test func aLandmineBarLoadsOneSleeve() {
        let step = WeightStepper.steps(
            for: [Self.ref(.loadableBar, "barbell"), Self.ref(.accessoryEquipment, "landmine_attachment_wall_corner")],
            profile: Self.gym(), unit: .kilograms
        )
        #expect(step.sleeves == 1)
        #expect(step.smallestStep == 1.25)
    }

    // MARK: - The unit the equipment is labelled in

    @Test func theEquipmentNamesItsUnit() {
        let pounds = Self.gym(freeWeights: [Self.plates([45, 25], unit: .pounds)])
        #expect(WeightStepper.equipmentUnit(for: [Self.ref(.loadableBar, "barbell")], profile: pounds) == .pounds)
        let both = Self.gym(freeWeights: [Self.plates([45], unit: .pounds), Self.plates([20], id: "iron")])
        #expect(WeightStepper.equipmentUnit(for: [Self.ref(.loadableBar, "barbell")], profile: both) == nil)
        #expect(WeightStepper.equipmentUnit(for: [Self.ref(.bodyWeight, "weighted_vest")], profile: pounds) == nil)
    }

    @Test func aChosenUnitWinsOverTheEquipment() {
        let pounds = Self.gym(freeWeights: [Self.plates([45], unit: .pounds)])
        let refs = [Self.ref(.loadableBar, "barbell")]
        let chosen = ExerciseUnitPreference(exerciseModelId: "x", weightUnit: .kilograms, weightUnitIsChosen: true)
        let defaulted = ExerciseUnitPreference(exerciseModelId: "x", weightUnit: .kilograms)
        #expect(SessionLoadChoice.weightUnit(preference: chosen, refs: refs, gym: pounds) == .kilograms)
        #expect(SessionLoadChoice.weightUnit(preference: defaulted, refs: refs, gym: pounds) == .pounds)
        #expect(SessionLoadChoice.weightUnit(preference: defaulted, refs: [], gym: pounds) == .kilograms)
    }

    /// A preference stored before the flag existed was stored because the user chose something.
    @Test func aStoredPreferenceReadsAsChosen() throws {
        let data = Data(#"{"exerciseModelId":"x","weightUnit":"pounds","distanceUnit":"meters"}"#.utf8)
        let preference = try JSONDecoder().decode(ExerciseUnitPreference.self, from: data)
        #expect(preference.weightUnitIsChosen)
    }

    // MARK: - New gyms

    @Test func aPoundGymLoadsTheFortyFivePoundBar() throws {
        let gym = GymProfileModel(authorId: "u").adaptingDefaults(to: .pounds)
        let bar = try #require(gym.loadableBars.first { $0.typeId == "barbell" })
        #expect(bar.loadedBaseWeight?.baseWeight == 45)
        #expect(bar.loadedBaseWeight?.unit == .pounds)
        let kilograms = try #require(GymProfileModel(authorId: "u").loadableBars.first { $0.typeId == "barbell" })
        #expect(kilograms.loadedBaseWeight?.baseWeight == 20)
    }

    @Test func aKilogramGymStacksInKilograms() throws {
        let gym = GymProfileModel(authorId: "u").adaptingDefaults(to: .kilograms)
        let stacks = gym.pinLoadedMachines.map { ($0.ranges, $0.defaultRange) } + gym.cableMachines.map { ($0.ranges, $0.defaultRange) }
        for (ranges, defaultRange) in stacks {
            let active = ranges.filter(\.isActive)
            #expect(!active.isEmpty && active.allSatisfy { $0.unit == .kilograms })
            #expect(defaultRange?.unit == .kilograms)
        }
        let first = try #require(gym.pinLoadedMachines.first)
        let step = WeightStepper.steps(for: [first.equipmentRef], profile: gym, unit: .kilograms)
        #expect(step.smallestStep == 5)
    }

    // MARK: - The plate calculator

    /// The bars the plate calculator and the keyboard's bar menu offer: switched on, lightest first.
    @Test func barChoicesAreTheActiveBarsLightestFirst() {
        let bar = LoadableBars(id: "barbell", name: "Barbell", description: nil, baseWeights: [
            LoadableBarsBaseWeight(id: "20", baseWeight: 20, unit: .kilograms, isActive: true),
            LoadableBarsBaseWeight(id: "45", baseWeight: 45, unit: .pounds, isActive: true),
            LoadableBarsBaseWeight(id: "10", baseWeight: 10, unit: .kilograms, isActive: false)
        ], isActive: true)
        var gym = Self.gym(bars: [bar])
        #expect(gym.barChoices(typeId: "barbell").map(\.id) == ["20", "45"])
        gym.chooseBarWeight("45", typeId: "barbell")
        #expect(gym.loadedBar(typeId: "barbell")?.loadedBaseWeight?.id == "45")
    }

    /// Done lays the bar choice and plates onto the gym as it is now, and nothing else.
    @Test func thePlateCalculatorOnlyChangesLoading() {
        var current = Self.gym()
        current.name = "Renamed meanwhile"
        var edited = Self.gym()
        edited.loadableBars[0].chosenBaseWeightId = "b"
        edited.freeWeights[0].range[0].isActive = false
        let merged = current.takingLoading(from: edited)
        #expect(merged.name == "Renamed meanwhile")
        #expect(merged.loadableBars[0].chosenBaseWeightId == "b")
        #expect(merged.freeWeights[0].range[0].isActive == false)
    }
}
