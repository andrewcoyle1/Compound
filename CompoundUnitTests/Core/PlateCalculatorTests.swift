//
//  PlateCalculatorTests.swift
//  CompoundUnitTests
//
//  Which bar a gym loads, the plate calculator's edits to the gym, the loading bar's words, and
//  the sheet's presenter.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

@MainActor
struct BarChoiceTests {

    /// Bars by id and weight; those in `off` are switched off.
    private static func gym(bars: [(String, Double)], off: Set<String> = [], chosen: String? = nil) -> GymProfileModel {
        var bar = LoadableBars(
            id: "barbell", name: "Barbell", description: nil,
            baseWeights: bars.map { LoadableBarsBaseWeight(id: $0.0, baseWeight: $0.1, unit: .kilograms, isActive: !off.contains($0.0)) },
            isActive: true
        )
        bar.chosenBaseWeightId = chosen
        return GymProfileModel(
            authorId: "u",
            freeWeights: [FreeWeights(
                id: "weight_plates", name: "Plates", needsColour: true, isPlates: true,
                range: [1.25, 2.5, 5, 10, 15, 20, 25].map {
                    FreeWeightsAvailable(id: "p\($0)", availableWeights: $0, unit: .kilograms, isActive: true)
                },
                isActive: true
            )],
            loadableBars: [bar]
        )
    }

    private static let barbell = [EquipmentRef(kind: .loadableBar, id: "barbell")]

    private func base(_ gym: GymProfileModel) -> Double? {
        WeightStepper.steps(for: Self.barbell, profile: gym, unit: .kilograms).baseWeight
    }

    /// Every bar used to default to its first weight, the 7 kg technique bar, so 50 kg could
    /// never be stepped to. With nothing chosen the heaviest bar switched on is loaded.
    @Test func withNothingChosenTheHeaviestBarIsLoaded() {
        let gym = Self.gym(bars: [("b7", 7), ("b15", 15), ("b20", 20)])
        #expect(base(gym) == 20)
        let step = WeightStepper.steps(for: Self.barbell, profile: gym, unit: .kilograms)
        #expect(step.next(after: 47.5) == 50)
        #expect(step.nearest(to: 50) == 50)
    }

    @Test func theChosenBarIsLoadedWhileItIsOn() {
        #expect(base(Self.gym(bars: [("b7", 7), ("b15", 15), ("b20", 20)], chosen: "b15")) == 15)
        #expect(base(Self.gym(bars: [("b7", 7), ("b15", 15), ("b20", 20)], off: ["b15"], chosen: "b15")) == 20)
        #expect(base(Self.gym(bars: [("b7", 7), ("b20", 20)], off: ["b20"])) == 7)
    }

    /// The catalogue barbell, as every existing gym holds it.
    @Test func theCatalogueBarbellLoadsTheTwentyKilogramBar() {
        #expect(base(GymProfileModel(authorId: "u")) == 20)
    }

    @Test func choosingABarIsStoredOnTheGym() throws {
        var gym = Self.gym(bars: [("b7", 7), ("b20", 20)])
        gym.chooseBarWeight("b7", typeId: "barbell")
        #expect(base(gym) == 7)

        let decoded = try JSONDecoder().decode(GymProfileModel.self, from: JSONEncoder().encode(gym))
        #expect(decoded.loadedBar(typeId: "barbell")?.chosenBaseWeightId == "b7")
        #expect(base(decoded) == 7)
    }
}

@MainActor
struct PlateChoiceTests {

    private static func plates(_ id: String, _ weights: [(Double, Bool)], unit: ExerciseWeightUnit = .kilograms) -> FreeWeights {
        FreeWeights(
            id: id, name: id, needsColour: true, isPlates: true,
            range: weights.map { FreeWeightsAvailable(id: "\(id)\($0.0)", availableWeights: $0.0, unit: unit, isActive: $0.1) },
            isActive: true
        )
    }

    @Test func choicesAreEveryWeightInTheUnitHeaviestFirst() {
        let gym = GymProfileModel(authorId: "u", freeWeights: [
            Self.plates("iron", [(20, true), (10, false), (2.5, true)]),
            Self.plates("bumper", [(20, false), (15, true)]),
            Self.plates("pounds", [(45, true)], unit: .pounds)
        ])
        #expect(gym.plateChoices(unit: .kilograms) == [
            PlateChoice(weight: 20, isOn: true),
            PlateChoice(weight: 15, isOn: true),
            PlateChoice(weight: 10, isOn: false),
            PlateChoice(weight: 2.5, isOn: true)
        ])
    }

    /// Off is off for every plate of that weight, iron and bumper alike, and the keyboard stops
    /// loading it.
    @Test func switchingAWeightOffReachesEveryPlateOfIt() {
        var gym = GymProfileModel(authorId: "u", freeWeights: [
            Self.plates("iron", [(20, true), (2.5, true)]),
            Self.plates("bumper", [(20, true)])
        ])
        gym.setPlate(20, unit: .kilograms, isOn: false)
        #expect(gym.plateChoices(unit: .kilograms).first == PlateChoice(weight: 20, isOn: false))
        #expect(!WeightStepper.availablePlates(profile: gym, unit: .kilograms).contains { $0.weight == 20 })

        gym.setPlate(20, unit: .kilograms, isOn: true)
        let twenties = gym.freeWeights.flatMap(\.range).filter { $0.availableWeights == 20 }
        #expect(twenties.allSatisfy { $0.isActive })
    }
}

struct PlateLoadingTests {

    @Test func aBarSaysWhatGoesOnEachSide() {
        let loading = PlateLoading(perSide: [25, 10, 10, 2.5], base: 20, sleeves: 2, unit: .kilograms)
        #expect(loading.total == 115)
        #expect(loading.counts == "1 × 25 · 2 × 10 · 1 × 2.5")
        #expect(loading.equation == "47.5 kg on each side + 20 kg bar = 115 kg")
    }

    @Test func aSingleSleeveMachineSaysItsPlatesAndBase() {
        let loading = PlateLoading(perSide: [20, 5], base: 18, sleeves: 1, unit: .kilograms)
        #expect(loading.total == 43)
        #expect(loading.equation == "25 kg of plates + 18 kg base = 43 kg")
    }

    @Test func anEmptyBarSaysSo() {
        let loading = PlateLoading(perSide: [], base: 20, sleeves: 2, unit: .kilograms)
        #expect(loading.counts.isEmpty)
        #expect(loading.equation == "Empty bar = 20 kg")
    }
}

@MainActor
struct PlateCalculatorPresenterTests {

    private final class Interactor: SpyGlobalInteractor, PlateCalculatorInteractor { }

    private final class Router: PlateCalculatorRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    /// The gyms Done handed back.
    private final class Saved {
        var gyms: [GymProfileModel] = []
    }

    private static func gym() -> GymProfileModel {
        GymProfileModel(
            authorId: "u",
            freeWeights: [FreeWeights(
                id: "weight_plates", name: "Plates", needsColour: true, isPlates: true,
                range: [2.5, 5, 10, 25].map { FreeWeightsAvailable(id: "p\($0)", availableWeights: $0, unit: .kilograms, isActive: true) },
                isActive: true
            )],
            loadableBars: [LoadableBars(id: "barbell", name: "Barbell", description: nil, baseWeights: [
                LoadableBarsBaseWeight(id: "b7", baseWeight: 7, unit: .kilograms, isActive: true),
                LoadableBarsBaseWeight(id: "b20", baseWeight: 20, unit: .kilograms, isActive: true)
            ], isActive: true)]
        )
    }

    private func presenter(total: Double?, saved: Saved = Saved()) -> (PlateCalculatorPresenter, Interactor) {
        let interactor = Interactor()
        let presenter = PlateCalculatorPresenter(
            interactor: interactor,
            router: Router(),
            delegate: PlateCalculatorDelegate(
                gym: Self.gym(),
                equipment: EquipmentRef(kind: .loadableBar, id: "barbell"),
                unit: .kilograms,
                total: total,
                onSave: { saved.gyms.append($0) }
            )
        )
        return (presenter, interactor)
    }

    @Test func itLoadsTheSetsWeightOnTheHeaviestBar() {
        let (presenter, _) = presenter(total: 70)
        #expect(presenter.subtitle == "70 kg")
        #expect(presenter.chosenBarId == "b20")
        #expect(presenter.barChoices.map(\.id) == ["b7", "b20"])
        #expect(presenter.loading == PlateLoading(perSide: [25], base: 20, sleeves: 2, unit: .kilograms))
    }

    @Test func choosingABarReloadsTheWeight() {
        let (presenter, interactor) = presenter(total: 57)
        presenter.onBarChosen("b7")
        #expect(presenter.chosenBarId == "b7")
        #expect(presenter.loading == PlateLoading(perSide: [25], base: 7, sleeves: 2, unit: .kilograms))
        #expect(interactor.trackedEventNames.contains("PlateCalculatorView_Bar_Chosen"))
    }

    @Test func aWeightThePlatesCannotMakeSaysTheNearest() {
        let (presenter, _) = presenter(total: 21)
        #expect(presenter.loading == nil)
        #expect(presenter.notLoadableText != nil)
    }

    @Test func doneHandsBackTheEditedGymAndCloseDoesNot() {
        let saved = Saved()
        let (presenter, _) = presenter(total: 70, saved: saved)
        presenter.onBarChosen("b7")
        presenter.onPlateToggled(PlateChoice(weight: 25, isOn: true))
        presenter.onClosePressed()
        #expect(saved.gyms.isEmpty)

        presenter.onDonePressed()
        #expect(saved.gyms.count == 1)
        #expect(saved.gyms.first?.loadedBar(typeId: "barbell")?.chosenBaseWeightId == "b7")
        #expect(saved.gyms.first?.plateChoices(unit: .kilograms).first == PlateChoice(weight: 25, isOn: false))
    }
}

/// The set row's side: the loading bar opens the calculator on the exercise's bar, and a bar
/// chosen there is what the open keyboard steps on straight away, while the gym saves behind it.
@MainActor
struct SetTrackerRowPlateCalculatorTests {

    private struct Row {
        let presenter: SetTrackerRowPresenter
        let interactor: SetTrackerRowInteractorDouble
        let router: SetTrackerRowRouterDouble
        let delegate: SetTrackerRowDelegate
        let exercise: GymEquipmentBox<WorkoutExerciseModel>
    }

    private func makeRow() -> Row {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let exercise = GymEquipmentBox(WorkoutExerciseModel(
            id: "e", authorId: "u", templateId: "t", name: "Bench", trackingMode: .weightReps, index: 0,
            sets: [WorkoutSetModel(id: "s0", authorId: "u", index: 0, isWarmup: false, dateCreated: start)],
            equipmentVariations: [EquipmentVariation(id: "v", resistanceEquipment: [EquipmentRef(kind: .loadableBar, id: "barbell")])]
        ))
        let set = Binding(get: { exercise.value.sets[0] }, set: { exercise.value.sets[0] = $0 })
        let interactor = SetTrackerRowInteractorDouble()
        interactor.favouriteGymProfile = GymProfileModel(authorId: "u")
        let router = SetTrackerRowRouterDouble()
        return Row(
            presenter: SetTrackerRowPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router,
            delegate: SetTrackerRowDelegate(exercise: exercise.binding, set: set, lastSet: nil),
            exercise: exercise
        )
    }

    @Test func aBarChosenInThePlateCalculatorIsSteppedOnAndSaved() async throws {
        let row = makeRow()
        row.presenter.onKeyboardFieldBegan(.weight, delegate: row.delegate)
        #expect(row.presenter.keyboard.showsLoadingBar)
        #expect(row.presenter.keyboard.context.step.baseWeight == 20)

        row.presenter.keyboard.openPlateCalculator?()
        let calculator = try #require(row.router.plateCalculators.first)
        #expect(calculator.equipment == EquipmentRef(kind: .loadableBar, id: "barbell"))
        #expect(calculator.total == nil)

        var gym = calculator.gym
        let fifteen = try #require(gym.loadedBar(typeId: "barbell")?.baseWeights.first { $0.baseWeight == 15 })
        gym.chooseBarWeight(fifteen.id, typeId: "barbell")
        calculator.onSave(gym)
        #expect(row.presenter.keyboard.context.step.baseWeight == 15)
        #expect(row.exercise.value.sets[0].weightKg == nil)
        #expect(await TestManagers.eventually { row.interactor.savedGyms.count == 1 })
    }

    @Test func aRepsFieldShowsNoLoadingBar() {
        let row = makeRow()
        row.presenter.onKeyboardFieldBegan(.reps, delegate: row.delegate)
        #expect(!row.presenter.keyboard.showsLoadingBar)
    }
}
